class_name DeskAmendment
extends Node

## Plan 6.3: a correction is the hand's work, done at the desk. Seated, with a
## finished copy waiting to be filed, the operator takes the pen to the lower
## part of the sheet: the copied lines are struck through and Elias's hand
## writes the correction beneath them as it is typed — typing is an invisible
## buffer, the ink is the only thing on screen. Enter keeps it on the sheet,
## Escape restores the previous draft. The filing table seals the finished copy.
## Ink lands on the writer rig's contact; no glyph appears on the keypress.

const GROUP := &"desk_amendment"

@export var office: M1OfficeController

var writing: bool = false
## Written corrections waiting to be filed, by scenario id.
var _pending: Dictionary = {}
var _requested: int = 0
var _finishing: bool = false
var _saved_word: String = ""
var _target: Interactable = null
var _resting_pen: Node3D
var _cramp_hold: float = 0.0
var _cramp_triggered_once: bool = false
var _cramp_player: AudioStreamPlayer = null

const CRAMP_SCRATCH_STREAM := preload("res://audio/sfx/foley/pen_scratch_3.wav")

func _ready() -> void:
	add_to_group(GROUP)
	if office == null:
		office = get_parent() as M1OfficeController
	_build_target.call_deferred()

## The lower part of the sheet takes the pen: a target over it, raised a
## little above the reading target so an aim there lands on it first.
func _build_target() -> void:
	var paper := _paper()
	if paper == null or paper.get_node_or_null("AmendInteractable") != null:
		return
	_target = Interactable.new()
	_target.name = "AmendInteractable"
	_target.prompt_text = GameLocale.pick("Взять перо для правки", "Pick Up Pen to Correct")
	_target.collision_layer = 0
	_target.collision_mask = 0
	_target.enabled = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.24, 0.03, 0.11)
	shape.shape = box
	_target.add_child(shape)
	_target.position = Vector3(0.0, 0.016, 0.095)
	_target.interacted.connect(begin)
	paper.add_child(_target)
	_resting_pen = paper.get_node_or_null("RestingPen") as Node3D

func get_pending(scenario_id: String) -> String:
	return str(_pending.get(scenario_id, ""))

func reset_for_new_copy() -> void:
	_pending.clear()
	_cramp_triggered_once = false

func get_target() -> Interactable:
	return _target

## Whether the pen may go to the copy now: seated, the copy finished and
## awaiting filing, a correction possible for it, none written yet.
func can_amend() -> bool:
	if office == null or writing or office.is_world_view_blocked():
		return false
	var session := office.session_controller
	var scenario := session.get_current_scenario() if session != null else null
	if scenario == null or session.get_state() != TelegraphSessionController.State.AWAITING_COMMIT:
		return false
	if office.operator_seat == null or not office.operator_seat.is_seated:
		return false
	for option in scenario.commit_options:
		if option != null and option.requires_correction:
			return true
	return false

func begin() -> bool:
	if not can_amend():
		return false
	var paper := _paper()
	var amendment := paper.get_amendment() if paper != null else null
	var rig := paper.get_writer_rig() if paper != null else null
	if amendment == null or rig == null:
		return false
	_saved_word = get_pending(office.session_controller.get_current_scenario().scenario_id)
	amendment.begin()
	for letter in _saved_word:
		amendment.type_letter(letter)
		amendment.ink(amendment.inked)
	_requested = _saved_word.length()
	_finishing = false
	_cramp_hold = 0.0
	writing = true
	_block_room(true)
	rig.begin_writing("")
	rig.cramp_tremor_intensity = 0.65 if _is_core_hook_scenario() else 0.0
	return true

func refresh_locale() -> void:
	if _target != null:
		_target.prompt_text = GameLocale.pick("Взять перо для правки", "Pick Up Pen to Correct")

func _process(delta: float) -> void:
	if _target != null:
		var open := can_amend()
		_target.enabled = open
		_target.is_actionable = open
		# An off target leaves the ray's layer, so reading the copy is never
		# intercepted by a pen that cannot be taken up.
		_target.collision_layer = 2 if open else 0
		if _resting_pen != null:
			_resting_pen.visible = open
	if writing:
		advance(delta)

## One presentation tick of the hand: entry, the stroke in flight, then the
## next typed letter that has no ink yet.
func advance(delta: float) -> void:
	var paper := _paper()
	var amendment := paper.get_amendment() if paper != null else null
	var rig := paper.get_writer_rig() if paper != null else null
	if amendment == null or rig == null:
		return
	rig.advance_presentation(delta)
	if _cramp_hold > 0.0:
		_cramp_hold = maxf(_cramp_hold - maxf(delta, 0.0), 0.0)
		return
	_requested = mini(_requested, amendment.word.length())
	_requested = maxi(_requested, amendment.inked)
	if rig.is_ready_to_write() and not rig.is_motion_pending() and _requested < amendment.word.length():
		if rig.request_glyph_motion(_requested, amendment.word):
			_requested += 1
	if _finishing and amendment.is_fully_inked() and not rig.is_motion_pending():
		_close(true)

func _input(event: InputEvent) -> void:
	if not writing or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var amendment := _paper().get_amendment()
	if key.keycode == KEY_ESCAPE:
		cancel()
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		finish()
	elif key.keycode == KEY_BACKSPACE:
		if not _finishing:
			amendment.erase_letter()
	elif not _finishing and key.keycode >= KEY_A and key.keycode <= KEY_Z \
			and amendment.word.length() < AmendmentText.MAX_LETTERS:
		amendment.type_letter(char(key.keycode))
		_maybe_trigger_cramp(amendment.word.length())
	get_viewport().set_input_as_handled()

## Enter: the word stands once its last letter is inked. An empty or invalid
## word is not a correction; the pen simply waits.
func finish() -> bool:
	var amendment := _paper().get_amendment()
	if not writing or not AmendmentText.validation_error(amendment.word).is_empty():
		return false
	_finishing = true
	return true

func cancel() -> void:
	if not writing:
		return
	var amendment := _paper().get_amendment()
	amendment.clear()
	if not _saved_word.is_empty():
		amendment.begin()
		for letter in _saved_word:
			amendment.type_letter(letter)
			amendment.ink(amendment.inked)
		amendment.end_writing()
	_close(false)

func _close(keep: bool) -> void:
	var paper := _paper()
	var amendment := paper.get_amendment()
	var rig := paper.get_writer_rig()
	writing = false
	_finishing = false
	_cramp_hold = 0.0
	rig.cramp_tremor_intensity = 0.0
	if keep:
		amendment.end_writing()
		_pending[office.session_controller.get_current_scenario().scenario_id] = amendment.word
		rig.finish_with_dip()
		if office.copy_commit_desk != null:
			office.copy_commit_desk.set_enabled(office.copy_commit_desk.is_enabled())
	else:
		rig.finish_writing()
	_block_room(false)

func _is_core_hook_scenario() -> bool:
	if office == null or office.session_controller == null:
		return false
	var scen := office.session_controller.get_current_scenario()
	return scen != null and scen.scenario_id == "core_hook_water_watcher"

func _maybe_trigger_cramp(word_len: int) -> void:
	if _cramp_triggered_once or word_len != 4 or not _is_core_hook_scenario():
		return
	_cramp_triggered_once = true
	_cramp_hold = 0.28
	if _cramp_player == null:
		_cramp_player = AudioStreamPlayer.new()
		_cramp_player.name = "CrampScratchPlayer"
		_cramp_player.stream = CRAMP_SCRATCH_STREAM
		_cramp_player.volume_db = -14.0
		_cramp_player.pitch_scale = 0.82
		_cramp_player.bus = &"Foley" if AudioServer.get_bus_index(&"Foley") >= 0 else &"Master"
		add_child(_cramp_player)
	if _cramp_player.is_inside_tree() and DisplayServer.get_name() != "headless":
		_cramp_player.play()
	var murmur := office.get_node_or_null("MurmurCaption") as MurmurCaption if office != null else null
	if murmur != null:
		murmur.show_outside_line("Hand's stiff...", 2.6)

## While the pen is on the paper, the room's own keys stay with the pen.
func _block_room(blocked: bool) -> void:
	if office == null or office.player == null:
		return
	if blocked:
		office._on_document_opened("desk_amendment")
	elif not office.is_world_view_blocked():
		office._on_document_closed("desk_amendment")
	var controller := office.player.get_node_or_null("InteractionController") as InteractionController
	if controller != null:
		var hint := "Type a word  [Backspace] Erase  [Enter] Keep on sheet  [Esc] Cancel" if blocked else ""
		controller.set_persistent_hint(hint)

func _paper() -> TranscriptPaper:
	return office.session_controller.transcript_paper if office != null and office.session_controller != null else null
