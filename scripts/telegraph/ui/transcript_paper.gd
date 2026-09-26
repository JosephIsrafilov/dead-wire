class_name TranscriptPaper
extends Node3D

signal transcript_inspected(text: String)
signal transcript_closed()
signal copy_finished(scenario_id: String)
## The fresh blank physically landed on the writing zone. The feed's paper
## sound belongs to this moment, not to the viewer's open/close.
signal sheet_fed
## The finished sheet started its slide to the stack.
signal sheet_archived

## The physical sheet of paper, owned by whoever is writing on it.
##
## Two cursors govern the ink: how many glyphs the signal has authorized
## (availability) and how many glyphs the hand has physically written. They are
## the same only while a seated operator keeps pace. Standing up freezes the
## written cursor; the available cursor keeps filling from the signal so nothing
## is lost, and a bounded catch-up drains the backlog after the hand returns.
##
## A new telegram is a physical change of sheet, not a text swap: the old
## ink is archived onto the stack layer and slides to the stack edge while the
## fresh blank feeds onto the writing zone (PREPARING). The hand enters only
## once the blank is in place; cues that arrive meanwhile are buffered by the
## available cursor and never delay the signal.
##
## Terminal states are honest: READY_TO_INSPECT means every glyph was written,
## INCOMPLETE_CLOSED means the sheet was closed with ink still missing and will
## never accept more.

enum PaperState {
	EMPTY,
	PREPARING,
	COPYING,
	COPYING_PAUSED,
	READY_TO_INSPECT,
	INCOMPLETE_CLOSED,
}

@export var prompt_message: String = "Read Telegram Transcript"
@export var empty_placeholder: String = ""
## Bounded catch-up after a pause, in glyphs per second. The continuous seated
## path follows authored cue timing; this rate only drains accumulated backlog.
@export var backlog_glyphs_per_second: float = 3.5
## Hard cap on how many glyphs may become visible in one presentation tick. A
## frame hitch must not reveal a pile of letters with a single pen jump: each
## glyph gets its own contact point in its own rendered frame.
@export var max_glyphs_per_tick: int = 1
## The fresh blank slides in from the message hook as Elias lays it — a few
## centimetres of travel before the hand enters, never covering the writing
## zone, and never delaying the signal.
@export var feed_travel: Vector3 = Vector3(0.0, 0.0, -0.12)
@export var feed_seconds: float = 0.30
## Where the archived sheet settles, in WORLD axes relative to the sheet's
## rest position: a flat slide across the desk top (down 2 mm to lie on it),
## independent of the writing sheet's own tilt. Two layers maximum — the
## active sheet and the last archived one.
## World offset of the finished sheet: set down on the blotter beside the copy
## board (the board, pad and sheet stack 11 mm above the blotter).
@export var previous_sheet_offset: Vector3 = Vector3(0.0, -0.0115, 0.19)
@export var previous_slide_seconds: float = 0.35

var interactable: Interactable = null
var label_3d: Label3D = null
var writer_rig: WriterRig = null

var paper_state: PaperState = PaperState.EMPTY

var _transcript_text: String = ""
var _is_revealed: bool = false

## Characters currently on the pad. -1 means the whole transcript is written.
var _visible_characters: int = -1
var _reveal_cues: PackedFloat32Array = PackedFloat32Array()
var _cue_character_indices: PackedInt32Array = PackedInt32Array()
var _last_writing_progress: float = 0.0

## Glyphs the signal has authorized (only ever increases while a sheet lives).
var _available_glyphs: int = 0
## Glyphs physically written by the hand.
var _written_glyphs: int = 0
var _paper_scenario_id: String = ""
var _copy_finished_emitted: bool = false
var _catchup_budget: float = 0.0

## Feed clocks. Deterministic on purpose: tests drive them straight through
## advance_paper, and production ticks them from _process frames.
var _sheet_rest_position: Vector3 = Vector3.ZERO
var _sheet_rest_captured: bool = false
var _feed_elapsed: float = 0.0
var _feed_paused: bool = false
var _previous_slide_elapsed: float = 0.0
var _previous_slide_active: bool = false

func _ready() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	label_3d = get_node_or_null("Sheet/Label3D") as Label3D
	if label_3d == null:
		label_3d = get_node_or_null("Label3D") as Label3D
	writer_rig = get_node_or_null("WriterRig") as WriterRig
	if writer_rig != null and not writer_rig.glyph_contact.is_connected(_on_glyph_contact):
		# Q2: ink appears when the nib physically arrives on the glyph, which
		# the rig — and only the rig — can report.
		writer_rig.glyph_contact.connect(_on_glyph_contact)
	var sheet := _get_sheet_node()
	if sheet != null and not _sheet_rest_captured:
		_sheet_rest_position = sheet.position
		_sheet_rest_captured = true

	if interactable != null:
		interactable.prompt_text = prompt_message
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	_update_display()

func _process(delta: float) -> void:
	advance_paper(delta)

## Deterministic presentation tick: the archived sheet's slide, the feed of
## the fresh blank, then ONE clock pass through the rig's entry and glyph
## motions, with the pass's honest leftover starting a catch-up request.
## Production runs this from _process; tests may call it directly. Ink lands
## on the rig's contact event, never on the cue itself.
func advance_paper(delta: float) -> void:
	var remaining := maxf(delta, 0.0)
	if _previous_slide_active:
		_advance_previous_slide(remaining)
	if paper_state == PaperState.PREPARING:
		remaining = _advance_sheet_feed(remaining)
		if remaining <= 0.0:
			return
	if paper_state != PaperState.COPYING:
		return
	var rig := get_writer_rig()
	if rig != null:
		# One clock pass: the tick's time is spent once, sequentially —
		# entry first, then any in-flight motion. The leftover is the only
		# time a glyph motion started inside this same tick may consume.
		var written_before_tick := _written_glyphs
		var leftover := rig.advance_presentation(remaining)
		if rig.is_ready_to_write() and _written_glyphs < _available_glyphs:
			# Catch-up drains only time the hand was actually at the paper,
			# so a tick that finished the entry cannot also pop a glyph.
			_catchup_budget += backlog_glyphs_per_second * leftover
			if _catchup_budget >= 1.0 and not rig.is_motion_pending() \
					and _written_glyphs == written_before_tick:
				_catchup_budget -= 1.0
				if _request_next_glyph(rig):
					rig.advance_presentation(leftover)
			if _written_glyphs >= _available_glyphs:
				_catchup_budget = 0.0
		return
	# No rig (a logic-only sheet): bounded direct reveal, same caps.
	if _written_glyphs < _available_glyphs:
		_catchup_budget += backlog_glyphs_per_second * remaining
		var revealed_this_tick := 0
		while _catchup_budget >= 1.0 and _written_glyphs < _available_glyphs \
				and revealed_this_tick < maxi(max_glyphs_per_tick, 1):
			_catchup_budget -= 1.0
			_commit_ink()
			revealed_this_tick += 1
		if _written_glyphs >= _available_glyphs:
			_catchup_budget = 0.0

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	return interactable

func get_label_3d() -> Label3D:
	if label_3d == null:
		label_3d = get_node_or_null("Sheet/Label3D") as Label3D
	if label_3d == null:
		label_3d = get_node_or_null("Label3D") as Label3D
	return label_3d

func get_writer_rig() -> WriterRig:
	if writer_rig == null:
		writer_rig = get_node_or_null("WriterRig") as WriterRig
	return writer_rig

func get_sheet_node() -> Node3D:
	return _get_sheet_node()

func _get_sheet_node() -> Node3D:
	var sheet := get_node_or_null("Sheet") as Node3D
	if sheet != null:
		return sheet
	return self

func get_previous_sheet_node() -> Node3D:
	return get_node_or_null("PreviousSheet") as Node3D

func get_transcript_text() -> String:
	return _transcript_text

func get_paper_scenario_id() -> String:
	return _paper_scenario_id

func is_revealed() -> bool:
	return _is_revealed

## The hand is actively putting ink on the sheet right now.
func is_writing() -> bool:
	return paper_state == PaperState.COPYING

## The sheet is live but unfinished, whether the hand is on it or not.
func is_copy_in_progress() -> bool:
	return paper_state in [PaperState.PREPARING, PaperState.COPYING, PaperState.COPYING_PAUSED]

func is_copy_paused() -> bool:
	return paper_state == PaperState.COPYING_PAUSED \
		or (paper_state == PaperState.PREPARING and _feed_paused)

func is_ready_to_inspect() -> bool:
	return paper_state == PaperState.READY_TO_INSPECT

func is_incomplete_closed() -> bool:
	return paper_state == PaperState.INCOMPLETE_CLOSED

func is_terminal() -> bool:
	return paper_state in [PaperState.READY_TO_INSPECT, PaperState.INCOMPLETE_CLOSED]

func get_state() -> PaperState:
	return paper_state

func get_visible_character_count() -> int:
	if _visible_characters < 0:
		return _transcript_text.length()
	return mini(_visible_characters, _transcript_text.length())

func get_available_glyph_count() -> int:
	return _available_glyphs

func get_written_glyph_count() -> int:
	return _written_glyphs

func get_reveal_cues() -> PackedFloat32Array:
	return _reveal_cues

func is_using_authored_cues() -> bool:
	return not _reveal_cues.is_empty() and _reveal_cues.size() == _cue_character_indices.size()

func get_revealed_glyph_count() -> int:
	return _written_glyphs

## Starts Elias's hand writing. The whole hook of the game is that the player can
## watch WATCHER appear on the pad while WATER is still coming out of the
## sounder; dumping the finished text at the end of the message hides the one
## moment the design exists for.
##
## The previous sheet's ink is archived first: it physically slides to the
## stack edge while the fresh blank feeds in. The hand enters only after the
## blank arrives; the signal never waits for any of it.
func begin_writing(
	text: String,
	reveal_cues: PackedFloat32Array = PackedFloat32Array(),
	scenario_id: String = ""
) -> void:
	_cancel_writer_animation()
	_archive_visible_sheet()
	_transcript_text = text
	_is_revealed = true
	_visible_characters = 0
	_last_writing_progress = 0.0
	_set_authored_cues(reveal_cues)
	_paper_scenario_id = scenario_id
	_available_glyphs = 0
	_written_glyphs = 0
	_copy_finished_emitted = false
	_catchup_budget = 0.0
	_start_sheet_feed()
	_update_display()

## Progress is driven by the Morse schedule, not a private timer, so the hand
## keeps pace with the signal exactly. This only authorizes glyphs (the
## available cursor); ink appears through the writing path below. Cues arriving
## while the blank is still feeding are buffered here, never lost.
func set_writing_progress(ratio: float) -> void:
	if not is_copy_in_progress() or _transcript_text.is_empty():
		return
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped < _last_writing_progress:
		clamped = _last_writing_progress
	_last_writing_progress = clamped

	var total := _total_glyphs()
	if is_using_authored_cues():
		var authorized := 0
		for cue in _reveal_cues:
			if cue <= clamped + 0.00001:
				authorized += 1
			else:
				break
		_available_glyphs = maxi(_available_glyphs, authorized)
	else:
		_available_glyphs = maxi(_available_glyphs, int(floor(clamped * float(total) + 0.0001)))

	# Authored pace: while the hand is physically on the paper and exactly one
	# new glyph has been authorized, its motion begins now. Ink follows the
	# actual contact, one short motion later — never before it. A rig-less
	# logic sheet has no hand to wait for and writes immediately.
	if paper_state == PaperState.COPYING \
			and _is_rig_ready_to_write() \
			and _available_glyphs - _written_glyphs == 1:
		if _request_next_glyph(get_writer_rig()) == false and get_writer_rig() == null:
			_commit_ink()

## The rig's own readiness is the gate for ink. A rig-less sheet (logic-only
## tests) is always ready: there is no hand to wait for.
func _is_rig_ready_to_write() -> bool:
	var rig := get_writer_rig()
	return rig == null or rig.is_ready_to_write()

func set_transcript_text(text: String) -> void:
	_transcript_text = text
	_update_display()

## Authoring shortcut: show the finished sheet without the physical writing
## pass. Production never calls this; the session ends the sheet only through
## the writing path or a terminal close.
func reveal_transcript() -> void:
	_is_revealed = true
	_visible_characters = -1
	_last_writing_progress = 1.0
	_available_glyphs = _total_glyphs()
	_written_glyphs = _total_glyphs()
	paper_state = PaperState.READY_TO_INSPECT
	_feed_paused = false
	var rig := get_writer_rig()
	if rig != null:
		rig.finish_writing()
	_update_display()

func clear_transcript() -> void:
	_cancel_writer_animation()
	_cancel_sheet_feed()
	_previous_slide_active = false
	var previous := get_previous_sheet_node()
	if previous != null:
		previous.visible = false
	_transcript_text = ""
	_is_revealed = false
	_visible_characters = -1
	_reveal_cues = PackedFloat32Array()
	_cue_character_indices = PackedInt32Array()
	_last_writing_progress = 0.0
	_available_glyphs = 0
	_written_glyphs = 0
	_paper_scenario_id = ""
	_copy_finished_emitted = false
	_catchup_budget = 0.0
	paper_state = PaperState.EMPTY
	_update_display()

func reset_for_new_transmission() -> void:
	clear_transcript()

## The archived layer: the last sheet's visible ink, kept as a physical record
## beside the writing zone. At most one archived sheet exists at a time.
func _archive_visible_sheet() -> void:
	var previous := get_previous_sheet_node()
	var previous_label := get_node_or_null("PreviousSheet/PreviousSheetText") as Label3D
	if previous == null or previous_label == null:
		return
	if not _is_revealed or _transcript_text.is_empty():
		previous.visible = false
		return
	var snapshot := get_display_text()
	if snapshot.is_empty():
		previous.visible = false
		return
	previous_label.text = _layout_prefix(snapshot)
	previous.visible = true
	# The old sheet starts exactly where it lay (the sheet rest, in world
	# space so the tilt of the writing sheet cannot drag it underground),
	# then slides flat across the desk to the stack.
	previous.global_position = to_global(_sheet_rest_position)
	_previous_slide_elapsed = 0.0
	_previous_slide_active = true
	sheet_archived.emit()

func _advance_previous_slide(delta: float) -> void:
	var previous := get_previous_sheet_node()
	if previous == null:
		_previous_slide_active = false
		return
	var rest_world := to_global(_sheet_rest_position)
	if previous_slide_seconds <= 0.0:
		previous.global_position = rest_world + previous_sheet_offset
		_previous_slide_active = false
		return
	_previous_slide_elapsed += delta
	var t := clampf(_previous_slide_elapsed / previous_slide_seconds, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 2.0)
	previous.global_position = rest_world + previous_sheet_offset * eased
	if t >= 1.0:
		_previous_slide_active = false

## The fresh blank slides onto the writing zone: short travel from the message
## hook side, eased, ending exactly at the rest position. Consumes at most
## feed_seconds of the tick and returns any leftover so the hand may begin
## entering in the same presentation tick the blank lands.
func _advance_sheet_feed(delta: float) -> float:
	if _feed_paused:
		return 0.0
	var sheet := _get_sheet_node()
	if sheet == null or feed_seconds <= 0.0 or feed_travel.length_squared() < 0.000001:
		_finish_sheet_feed()
		return delta
	_feed_elapsed += delta
	var t := clampf(_feed_elapsed / feed_seconds, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 2.0)
	sheet.position = _sheet_rest_position + feed_travel * (1.0 - eased)
	if t >= 1.0:
		_finish_sheet_feed()
		return _feed_elapsed - feed_seconds
	return 0.0

func _start_sheet_feed() -> void:
	_feed_elapsed = 0.0
	_feed_paused = false
	paper_state = PaperState.PREPARING
	var sheet := _get_sheet_node()
	if sheet == null or not _sheet_rest_captured:
		_finish_sheet_feed()
		return
	if feed_seconds <= 0.0 or feed_travel.length_squared() < 0.000001:
		_finish_sheet_feed()
		return
	sheet.position = _sheet_rest_position + feed_travel

func _finish_sheet_feed() -> void:
	paper_state = PaperState.COPYING
	var sheet := _get_sheet_node()
	if sheet != null and _sheet_rest_captured:
		sheet.position = _sheet_rest_position
	sheet_fed.emit()
	# The hand enters only once the blank is physically in place.
	var rig := get_writer_rig()
	if rig != null:
		rig.begin_writing(_transcript_text)

func _cancel_sheet_feed() -> void:
	_feed_paused = false
	var sheet := _get_sheet_node()
	if sheet != null and _sheet_rest_captured:
		sheet.position = _sheet_rest_position

## The operator stood up. The visible prefix freezes exactly as it is; the
## available cursor keeps filling from the signal so no authorization is lost.
## A feed interrupted by standing is paused with it.
func suspend() -> void:
	match paper_state:
		PaperState.PREPARING:
			_feed_paused = true
		PaperState.COPYING:
			paper_state = PaperState.COPYING_PAUSED
			_catchup_budget = 0.0
			var rig := get_writer_rig()
			if rig != null:
				rig.suspend()
		_:
			return

## The operator is back and settled. The feed resumes, or the hand re-enters
## first — to the pose it left, with its glyph index intact; ink resumes only
## after contact, then drains the backlog at a bounded rate. Never resets the
## written cursor.
func resume_writing() -> void:
	if paper_state == PaperState.PREPARING and _feed_paused:
		_feed_paused = false
		return
	if paper_state != PaperState.COPYING_PAUSED:
		return
	paper_state = PaperState.COPYING
	_catchup_budget = 0.0
	var rig := get_writer_rig()
	if rig != null:
		rig.resume_writing()

## Terminal close with ink missing. The sheet keeps its partial prefix and will
## never accept another glyph, in this session or any later one. An in-flight
## feed is cancelled with it — nothing keeps sliding after the work is closed.
func close_incomplete() -> void:
	if not is_copy_in_progress():
		return
	paper_state = PaperState.INCOMPLETE_CLOSED
	_catchup_budget = 0.0
	_cancel_sheet_feed()
	_cancel_writer_animation()

## Ask the hand to bring the nib onto the next unwritten glyph. The ink lands
## when the rig reports the contact. Returns whether a motion was accepted.
func _request_next_glyph(rig: WriterRig) -> bool:
	if rig == null:
		return false
	var glyph_index := _written_glyphs
	if glyph_index >= _available_glyphs or glyph_index >= _total_glyphs():
		return false
	return rig.request_glyph_motion(glyph_index, _transcript_text)

## The rig reports the nib has physically arrived on a glyph: this — and only
## this — lets ink appear. A stale contact (the sheet moved on, the operator
## stood up) writes nothing.
func _on_glyph_contact(glyph_index: int) -> void:
	if paper_state != PaperState.COPYING:
		return
	if glyph_index != _written_glyphs:
		return
	_commit_ink()

## The ink itself: one glyph becomes visible, the label updates, and the
## sheet's completion follows its own rules.
func _commit_ink() -> void:
	if _written_glyphs >= _available_glyphs or _written_glyphs >= _total_glyphs():
		return
	_written_glyphs += 1
	if _written_glyphs >= _total_glyphs():
		_visible_characters = -1
	else:
		_visible_characters = _character_index_of_glyph(_written_glyphs)
	_update_display()
	if _written_glyphs >= _total_glyphs() and not _copy_finished_emitted:
		_copy_finished_emitted = true
		paper_state = PaperState.READY_TO_INSPECT
		var finished_rig := get_writer_rig()
		if finished_rig != null:
			finished_rig.finish_writing()
		_update_display()
		copy_finished.emit(_paper_scenario_id)

func _total_glyphs() -> int:
	if is_using_authored_cues():
		return _cue_character_indices.size()
	var count := 0
	for index in _transcript_text.length():
		if not _is_layout_whitespace(_transcript_text.substr(index, 1)):
			count += 1
	return count

## One whitespace contract for the whole sheet: space, tab, newline and
## carriage return carry no glyph, no cue and no contact. Every glyph scan
## goes through here so indexing cannot drift between counters.
func _is_layout_whitespace(character: String) -> bool:
	return character in [" ", "\t", "\n", "\r"]

## Character prefix that covers the first `glyph_count` non-space glyphs,
## including the spaces that follow them as part of the written prefix.
func _character_index_of_glyph(glyph_count: int) -> int:
	if is_using_authored_cues():
		if glyph_count <= 0:
			return 0
		if glyph_count >= _cue_character_indices.size():
			return _transcript_text.length()
		return _cue_character_indices[glyph_count - 1] + 1
	var seen := 0
	for index in _transcript_text.length():
		if not _is_layout_whitespace(_transcript_text.substr(index, 1)):
			if seen == glyph_count:
				return index
			seen += 1
	return _transcript_text.length()

func _set_authored_cues(cues: PackedFloat32Array) -> void:
	_reveal_cues = PackedFloat32Array()
	_cue_character_indices = PackedInt32Array()
	if cues.is_empty():
		return

	for index in _transcript_text.length():
		if not _is_layout_whitespace(_transcript_text.substr(index, 1)):
			_cue_character_indices.append(index)
	if cues.size() != _cue_character_indices.size():
		# An invalid authored map must never strand the transcript. The legacy
		# duration ratio remains the deterministic fallback for old scenarios.
		_cue_character_indices = PackedInt32Array()
		return
	var previous := -1.0
	for cue in cues:
		if not is_finite(cue) or cue < 0.0 or cue > 1.0 or cue < previous:
			_reveal_cues = PackedFloat32Array()
			_cue_character_indices = PackedInt32Array()
			return
		_reveal_cues.append(cue)
		previous = cue

func _cancel_writer_animation() -> void:
	var rig := get_writer_rig()
	if rig != null:
		rig.reset()

## What is physically on the pad right now, which during a transmission is less
## than the full transcript.
func get_display_text() -> String:
	if not _is_revealed or _transcript_text.is_empty():
		return empty_placeholder
	if _visible_characters < 0 or _visible_characters >= _transcript_text.length():
		return _transcript_text
	return _transcript_text.substr(0, _visible_characters)

func _update_display() -> void:
	var lbl := get_label_3d()
	if lbl != null:
		lbl.text = _layout_prefix(get_display_text())

## Columns per written line. Eight keeps a full row of the current lettering
## inside the sheet's margins; the layout and the pen contact share it, so
## nib and ink cannot drift apart.
const GLYPH_COLUMNS: int = 8

## Fixed columns keep existing ink still as each new glyph is written. The
## same layout defines pen contact, so nib and ink cannot drift apart.
func _layout_prefix(prefix: String) -> String:
	var result := ""
	var column := 0
	for index in prefix.length():
		if column == GLYPH_COLUMNS:
			result += "\n"
			column = 0
		result += prefix[index]
		column += 1
	return result

func get_glyph_contact(glyph_index: int) -> Vector3:
	var character := 0
	var glyph := 0
	for index in _transcript_text.length():
		if not _is_layout_whitespace(_transcript_text.substr(index, 1)):
			if glyph == glyph_index:
				character = index
				break
			glyph += 1
	var lbl := get_label_3d()
	if lbl == null:
		return Vector3.ZERO
	var font := lbl.font if lbl.font != null else ThemeDB.fallback_font
	var line_start := (character / GLYPH_COLUMNS) * GLYPH_COLUMNS
	var preceding := _transcript_text.substr(line_start, character % GLYPH_COLUMNS)
	var x := font.get_string_size(preceding, HORIZONTAL_ALIGNMENT_LEFT, -1, lbl.font_size).x
	var y := font.get_height(lbl.font_size) * float(character / GLYPH_COLUMNS) + font.get_ascent(lbl.font_size)
	return lbl.position + lbl.basis * Vector3(x * lbl.pixel_size, -y * lbl.pixel_size, 0.0005)

func _on_interacted() -> void:
	transcript_inspected.emit(get_display_text())
