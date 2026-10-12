class_name AmendmentEditor
extends CanvasLayer
## A draft is not a decision. Only explicit submit reaches the session authority.
signal editor_opened()
signal editor_closed()
signal correction_submitted(word: String)
var _is_open: bool = false
var _scenario_id: String = ""
var _draft: String = ""
var _open_token: int = 0
var _submitting: bool = false
var _opening_frame: int = -1
var _transition_frame: int = -1
@onready var correction: LineEdit = $CenterContainer/Panel/Margin/VBox/Correction
@onready var status: Label = $CenterContainer/Panel/Margin/VBox/Status
@onready var submit_button: Button = $CenterContainer/Panel/Margin/VBox/Buttons/Submit
@onready var cancel_button: Button = $CenterContainer/Panel/Margin/VBox/Buttons/Cancel

func _ready() -> void:
	visible = false
	correction.text_changed.connect(_on_text_changed)
	correction.text_submitted.connect(_on_text_submitted)
	submit_button.pressed.connect(submit_draft)
	cancel_button.pressed.connect(close_editor.bind(true))

func is_open() -> bool:
	return _is_open

func owns_transition_frame() -> bool:
	return _transition_frame == Engine.get_process_frames()

func open_editor(scenario_id: String) -> void:
	if _is_open:
		return
	if _scenario_id != scenario_id:
		_draft = ""
	_scenario_id = scenario_id
	_is_open = true
	_open_token += 1
	_submitting = false
	_opening_frame = Engine.get_process_frames()
	_transition_frame = _opening_frame
	correction.text = _draft
	status.text = "Enter the word you intend to file. The line is still running."
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	editor_opened.emit()
	_focus_after_activation.call_deferred()

func _focus_after_activation() -> void:
	if not _is_open or not is_inside_tree():
		return
	var token := _open_token
	await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if _is_open and token == _open_token:
		correction.grab_focus()
		correction.edit()
		correction.caret_column = correction.text.length()

func _on_text_changed(text: String) -> void:
	# Uppercase conversion is visible; no trimming, dictionary or hidden repair.
	var canonical := ""
	for index in text.length():
		var code := text.unicode_at(index)
		canonical += char(code - 32) if code >= 97 and code <= 122 else text[index]
	var caret := correction.caret_column
	if correction.text != canonical:
		correction.text = canonical
		correction.caret_column = mini(caret, canonical.length())
	_draft = canonical
	_submitting = false
	var error := AmendmentText.validation_error(canonical)
	status.text = "Ready to file exactly: " + canonical if error.is_empty() else error

func _on_text_submitted(_text: String) -> void:
	submit_draft()

func submit_draft() -> void:
	if not _is_open or _submitting:
		return
	var error := AmendmentText.validation_error(correction.text)
	if not error.is_empty():
		status.text = error
		return
	_submitting = true
	var word := correction.text
	_transition_frame = Engine.get_process_frames()
	get_viewport().set_input_as_handled()
	correction_submitted.emit(word)

func reject_submission(message: String) -> void:
	_submitting = false
	if _is_open:
		status.text = message

func close_editor(keep_draft: bool = true) -> void:
	if not _is_open:
		if not keep_draft:
			_draft = ""
			_scenario_id = ""
			if is_node_ready():
				correction.text = ""
		return
	_transition_frame = Engine.get_process_frames()
	get_viewport().set_input_as_handled()
	if keep_draft:
		_draft = correction.text
	else:
		_draft = ""
		_scenario_id = ""
	_is_open = false
	_submitting = false
	visible = false
	correction.release_focus()
	editor_closed.emit()
	_restore_capture.call_deferred()

func _restore_capture() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if not _is_open and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if Engine.get_process_frames() == _opening_frame:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close_editor(true)
	elif event is InputEventKey and event.pressed and not event.echo \
		and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		submit_draft()
