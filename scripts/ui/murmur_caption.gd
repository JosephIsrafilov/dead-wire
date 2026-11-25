class_name MurmurCaption
extends CanvasLayer

## Elias murmuring under the copy: the letters he hears, spelled out as a
## quiet caption while the sounder works. This is the perception layer made
## visible — it listens to the session's whisper signal alone and never
## learns what the hand writes or what the sender truly sent, so the voice
## and the ink may disagree.

@export var session: TelegraphSessionController
## How long the finished whisper stays readable after the wire falls silent,
## and how slowly it fades afterwards.
@export var hold_seconds: float = 4.0
@export var fade_seconds: float = 1.5
## Reading the sheet or leaving the chair cuts the whisper short — faster than
## the natural fade, so the voice never doubles as a cheat sheet the player
## holds next to the ink or carries across the room.
@export var dismiss_fade_seconds: float = 0.6

## Letter and word spacing of the whispered string; the word gap is pure
## space — a dot there would read as one more murmured letter, and on the
## 2026-10-16 frames the dotted gap merged into the letter run.
const GLYPH_SEPARATOR := " · "
const WORD_SEPARATOR := "     "
const HEARD_PREFIX := "Heard — "
const WIRE_PREFIX := "WIRE (Party Line) — "
## Clear enough to read effortlessly over desk and paper while staying calm.
const MURMUR_ALPHA := 0.84
const MURMUR_COLOR := Color(0.92, 0.87, 0.76, MURMUR_ALPHA)
const WIRE_COLOR := Color(0.76, 0.84, 0.94, 0.90)
const WIRE_HOLD_SECONDS := 6.8
const RESPONSE_HOLD_SECONDS := 5.0
## A newly heard letter surfaces instead of popping in.
@export var letter_fade_seconds: float = 0.35
## The murmur sits just under the copy board (owner's choice, plan 5.6): the
## eye reading the ink finds the voice right below it. It only ever rises from
## its authored place toward the sheet, never lower, so the thought line and
## the prompt keep their places.
@export var follow_sheet: bool = true
@export var sheet_gap: float = 14.0
## The board's near edge in the paper's own space.
const SHEET_NEAR_EDGE := Vector3(0.0, 0.0, 0.17)
const AUTHORED_TOP := -268.0
const LINE_HEIGHT := 70.0

static func _heard_prefix() -> String:
	return GameLocale.pick("Слышу — ", "Heard — ")

static func _wire_prefix() -> String:
	return GameLocale.pick("ЛИНИЯ — ", "WIRE (Party Line) — ")

enum VoiceState {
	SILENT,
	WHISPERING,
	HOLDING,
	FADING,
	DISMISSING,
}

var _state: VoiceState = VoiceState.SILENT
var _perception_text: String = ""
var _revealed: int = 0
var _label: RichTextLabel = null
## Seconds since the newest letter was heard; drives its fade-in.
var _fresh_elapsed: float = 0.0
var _hold_elapsed: float = 0.0
var _active_hold_seconds: float = 4.0
var _fade_elapsed: float = 0.0
## Alpha the current dismissal started from, so a dismiss mid-fade never pops.
var _dismiss_from_alpha: float = 1.0
var _active_prefix: String = HEARD_PREFIX

func _ready() -> void:
	# Pausing the night pauses the whisper with it (default pausable mode).
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = AUTHORED_TOP
	_label.offset_bottom = AUTHORED_TOP + LINE_HEIGHT
	_label.offset_left = 24.0
	_label.offset_right = -24.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Crisp high-contrast outline + shadow so letters read clearly over paper.
	_label.add_theme_font_override("normal_font", preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf"))
	_label.add_theme_font_size_override("normal_font_size", 22)
	_label.add_theme_color_override("default_color", MURMUR_COLOR)
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.01, 0.92))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_apply_text("")
	_bind_session()

func _bind_session() -> void:
	if session == null:
		return
	if not session.transmission_started.is_connected(_on_transmission_started):
		session.transmission_started.connect(_on_transmission_started)
	if not session.perception_glyph.is_connected(_on_perception_glyph):
		session.perception_glyph.connect(_on_perception_glyph)
	if not session.transmission_finished.is_connected(_on_transmission_finished):
		session.transmission_finished.connect(_on_transmission_finished)
	if not session.operator_stood.is_connected(_on_operator_stood):
		session.operator_stood.connect(_on_operator_stood)
	var paper: TranscriptPaper = session.transcript_paper
	if paper != null and not paper.transcript_inspected.is_connected(_on_transcript_inspected):
		paper.transcript_inspected.connect(_on_transcript_inspected)
	var office := get_parent()
	if office != null:
		var director := office.get_node_or_null("ShiftDirector") as ShiftDirector
		if director != null and not director.foreign_traffic_heard.is_connected(_on_foreign_traffic_heard):
			director.foreign_traffic_heard.connect(_on_foreign_traffic_heard)
		var sender := office.get_node_or_null("OperatorKeySender") as OperatorKeySender
		if sender != null and not sender.wire_response_sent.is_connected(_on_wire_response_sent):
			sender.wire_response_sent.connect(_on_wire_response_sent)

func _on_foreign_traffic_heard(text: String) -> void:
	show_wire_line(text, true)

func _on_wire_response_sent(text: String) -> void:
	show_wire_line(text, false)

## Displays distant party-line chatter or a reply on the wire without touching
## an active main telegram whisper.
func show_wire_line(text: String, distant: bool = false) -> void:
	if text.is_empty() or _state == VoiceState.WHISPERING:
		return
	_perception_text = text
	_revealed = text.replace(" ", "").length()
	_fresh_elapsed = letter_fade_seconds
	_hold_elapsed = 0.0
	_fade_elapsed = 0.0
	_active_hold_seconds = WIRE_HOLD_SECONDS if distant else RESPONSE_HOLD_SECONDS
	_active_prefix = _wire_prefix() if distant else _heard_prefix()
	_state = VoiceState.HOLDING
	if _label != null:
		_label.add_theme_color_override("default_color", WIRE_COLOR if distant else MURMUR_COLOR)
	var rendered := text.to_upper() if distant else _render(1.0)
	_apply_text(rendered)

## Shows an exterior human voice or short inner reaction without the Morse prefix.
func show_outside_line(text: String, duration: float = 5.5) -> void:
	if text.is_empty() or _state == VoiceState.WHISPERING:
		return
	_perception_text = text
	_revealed = text.length()
	_fresh_elapsed = letter_fade_seconds
	_hold_elapsed = 0.0
	_fade_elapsed = 0.0
	_active_hold_seconds = duration
	_active_prefix = ""
	_state = VoiceState.HOLDING
	if _label != null:
		_label.add_theme_color_override("default_color", Color(0.90, 0.82, 0.66, 0.82))
	_apply_text(text)

## A new telegram clears the murmur: the voice only ever spells the message
## currently being heard.
func _on_transmission_started(scenario: TelegraphScenarioData) -> void:
	_perception_text = scenario.transmission_data.elias_perception
	_revealed = 0
	_state = VoiceState.WHISPERING
	_hold_elapsed = 0.0
	_active_hold_seconds = hold_seconds
	_active_prefix = _heard_prefix()
	_fade_elapsed = 0.0
	if _label != null:
		_label.add_theme_color_override("default_color", MURMUR_COLOR)
	_apply_text("")

func _on_perception_glyph(_scenario_id: String, index: int, _glyph: String) -> void:
	if _state != VoiceState.WHISPERING:
		return
	if index == 0:
		_revealed = 0
	_revealed = maxi(_revealed, index + 1)
	_fresh_elapsed = 0.0
	_apply_text(_render(_fresh_alpha()))

## The wire falls silent; the finished whisper lingers, then fades.
func _on_transmission_finished(_scenario: TelegraphScenarioData) -> void:
	if _state == VoiceState.WHISPERING:
		_state = VoiceState.HOLDING
		_hold_elapsed = 0.0
		_apply_text(_render(1.0))

func _process(delta: float) -> void:
	_place_near_sheet()
	if _revealed > 0 and _fresh_elapsed < letter_fade_seconds:
		_fresh_elapsed += delta
		if _state != VoiceState.SILENT:
			var alpha := _label.modulate.a if _label != null else 1.0
			_apply_text(_render(_fresh_alpha()))
			if _label != null:
				_label.modulate.a = alpha
	match _state:
		VoiceState.HOLDING:
			_hold_elapsed += delta
			if _hold_elapsed >= _active_hold_seconds:
				_state = VoiceState.FADING
				_fade_elapsed = 0.0
		VoiceState.FADING:
			_fade_elapsed += delta
			if _label != null:
				_label.modulate.a = 1.0 - clampf(_fade_elapsed / maxf(fade_seconds, 0.01), 0.0, 1.0)
			if _fade_elapsed >= fade_seconds:
				_go_silent()
		VoiceState.DISMISSING:
			_fade_elapsed += delta
			if _label != null:
				var progress := clampf(_fade_elapsed / maxf(dismiss_fade_seconds, 0.01), 0.0, 1.0)
				_label.modulate.a = _dismiss_from_alpha * (1.0 - progress)
			if _fade_elapsed >= dismiss_fade_seconds:
				_go_silent()
		_:
			pass

## The sheet is in the player's hands: the voice stops being a reference.
func _on_transcript_inspected(_text: String) -> void:
	_dismiss()

## Leaving the chair takes the ear with it.
func _on_operator_stood() -> void:
	_dismiss()

## Cut the current whisper short, from whatever alpha it has right now.
func _dismiss() -> void:
	match _state:
		VoiceState.SILENT, VoiceState.DISMISSING:
			return
		_:
			_dismiss_from_alpha = _label.modulate.a if _label != null else 1.0
			_state = VoiceState.DISMISSING
			_fade_elapsed = 0.0

## Projects the board's near edge through the camera that sees the paper and
## lifts the murmur to just below it, clamped to the authored place.
func _place_near_sheet() -> void:
	if not follow_sheet or _label == null or session == null or not _label.visible:
		return
	var paper: TranscriptPaper = session.transcript_paper
	if paper == null or not paper.is_inside_tree():
		return
	var view := paper.get_viewport()
	var camera := view.get_camera_3d() if view != null else null
	var edge := paper.to_global(SHEET_NEAR_EDGE)
	if camera == null or camera.is_position_behind(edge):
		return
	var view_height := view.get_visible_rect().size.y
	var canvas_height := _label.get_viewport_rect().size.y
	if view_height <= 0.0 or canvas_height <= 0.0:
		return
	var below := camera.unproject_position(edge).y / view_height * canvas_height + sheet_gap
	var top := clampf(below - canvas_height, -canvas_height * 0.6, AUTHORED_TOP)
	_label.offset_top = top
	_label.offset_bottom = top + LINE_HEIGHT

func get_murmur_top() -> float:
	return _label.offset_top if _label != null else AUTHORED_TOP

func get_display_text() -> String:
	if _label == null:
		return ""
	var raw := _label.get_parsed_text()
	for pfx in [_heard_prefix(), _wire_prefix(), HEARD_PREFIX, WIRE_PREFIX]:
		if raw.begins_with(pfx):
			raw = raw.substr(pfx.length())
			break
	var nl := raw.find("\n")
	return raw.substr(0, nl) if nl >= 0 else raw

## How far the newest letter has surfaced, 0..1.
func get_newest_letter_alpha() -> float:
	return _fresh_alpha()

func _fresh_alpha() -> float:
	return clampf(_fresh_elapsed / maxf(letter_fade_seconds, 0.001), 0.0, 1.0)

func is_holding() -> bool:
	return _state == VoiceState.HOLDING

func is_fading() -> bool:
	return _state == VoiceState.FADING

func is_dismissing() -> bool:
	return _state == VoiceState.DISMISSING

func is_visible_on_screen() -> bool:
	return _label != null and _label.is_visible_in_tree()

## The whispered prefix: `count` heard glyphs of the perception text, lower
## case, letter-spaced, with a double interval at word boundaries. The newest
## letter carries `fresh` of the murmur's alpha while it surfaces.
func _render(fresh: float = 1.0) -> String:
	var out := ""
	var glyph_index := 0
	var word_gap_pending := false
	for i in range(_perception_text.length()):
		var character := _perception_text[i]
		if character == " ":
			word_gap_pending = true
			continue
		if glyph_index >= _revealed:
			break
		if glyph_index > 0:
			out += WORD_SEPARATOR if word_gap_pending else GLYPH_SEPARATOR
		var letter := character.to_lower().replace("[", "[lb]")
		if glyph_index == _revealed - 1 and fresh < 1.0:
			var tint := MURMUR_COLOR
			tint.a *= fresh
			letter = "[color=#%s]%s[/color]" % [tint.to_html(true), letter]
		out += letter
		word_gap_pending = false
		glyph_index += 1
	return out

func _apply_text(text: String) -> void:
	if _label == null:
		return
	var out := ""
	if not text.is_empty():
		out = _active_prefix + text
		if GameLocale.is_ru() and _state == VoiceState.HOLDING and not _active_prefix.is_empty():
			var gloss := GameLocale.wire_gloss_ru(_perception_text)
			if not gloss.is_empty():
				out += "\n[font_size=17][color=#b8aa8e](%s)[/color][/font_size]" % gloss
	_label.text = out
	_label.visible = not text.is_empty()
	_label.modulate.a = 1.0

func _go_silent() -> void:
	_state = VoiceState.SILENT
	_apply_text("")
