class_name DeskAmendment
extends Node

## Plan 6.3: a correction is the hand's work, done at the desk. Seated, with a
## finished copy waiting to be filed, the operator takes the pen to the lower
## part of the sheet: the copied lines are struck through and Elias's hand
## writes the correction beneath them as it is typed — typing is an invisible
## buffer, the ink is the only thing on screen. Enter ends it, Escape takes it
## back. At the filing table "AMEND COPY" then files what is on the sheet.
## Ink lands on the writer rig's contact; no glyph appears on the keypress.

const GROUP := &"desk_amendment"

@export var office: M1OfficeController

var writing: bool = false
## Written corrections waiting to be filed, by scenario id.
var _pending: Dictionary = {}
var _requested: int = 0
var _finishing: bool = false
var _target: Interactable = null

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
	_target.prompt_text = "Amend the Copy"
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

func get_pending(scenario_id: String) -> String:
	return str(_pending.get(scenario_id, ""))

func get_target() -> Interactable:
	return _target

## Whether the pen may go to the copy now: seated, the copy finished and
## awaiting filing, a correction possible for it, none written yet.
func can_amend() -> bool:
	if office == null or writing:
		return false
	var session := office.session_controller
	var scenario := session.get_current_scenario() if session != null else null
	if scenario == null or session.get_state() != TelegraphSessionController.State.AWAITING_COMMIT:
		return false
	if office.operator_seat == null or not office.operator_seat.is_seated:
		return false
	if not get_pending(scenario.scenario_id).is_empty():
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
	amendment.begin()
	_requested = 0
	_finishing = false
	writing = true
	_block_room(true)
	rig.begin_writing("")
	return true

func _process(delta: float) -> void:
	if _target != null:
		var open := can_amend()
		_target.enabled = open
		_target.is_actionable = open
		# An off target leaves the ray's layer, so reading the copy is never
		# intercepted by a pen that cannot be taken up.
		_target.collision_layer = 2 if open else 0
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
	_paper().get_amendment().clear()
	_close(false)

func _close(keep: bool) -> void:
	var paper := _paper()
	var amendment := paper.get_amendment()
	var rig := paper.get_writer_rig()
	writing = false
	_finishing = false
	if keep:
		amendment.end_writing()
		_pending[office.session_controller.get_current_scenario().scenario_id] = amendment.word
		rig.finish_with_dip()
	else:
		rig.finish_writing()
	_block_room(false)

## While the pen is on the paper, the room's own keys stay with the pen.
func _block_room(blocked: bool) -> void:
	if office == null or office.player == null:
		return
	var controller := office.player.get_node_or_null("InteractionController") as InteractionController
	if controller != null:
		controller.is_ui_blocked = blocked
		controller.refresh_prompt()

func _paper() -> TranscriptPaper:
	return office.session_controller.transcript_paper if office != null and office.session_controller != null else null
