class_name CopyCommitDesk
extends Node3D

## The filing surface for the night's one decision.
##
## Contract (B1): this desk never decides the outcome. Input expresses an
## INTENT (`option_committed`); the session is the authority that accepts or
## rejects it; only the accepted result, arriving back through
## `apply_commit_result`, may stamp the surface and fire the contact sound.
## A rejected intent leaves no stamp, no sound and the desk still enabled.

signal option_committed(action_id: StringName)
## Fires exactly once per accepted outcome, immediately: the authority has
## spoken and the surface shows it. Facts never wait for an animation.
signal commit_accepted(action_id: StringName)
## Fires when the physical stamp press reaches the paper: the moment of
## contact. The stamp sound belongs here, never to the intent.
signal stamp_contact(action_id: StringName)

@export var enabled: bool = false
@export var prompt_message: String = "File one copy"
## The press travels this far onto the paper, over this long. Cosmetic: the
## accepted result is already on the surface while the press is moving.
@export var stamp_press_distance: float = 0.07
@export var stamp_press_duration: float = 0.16

var interactable: Interactable = null
var _options: Array = []
var _committed: bool = false
## Intent currently awaiting the session's verdict. One at a time: a second
## keypress while the authority has not answered is dropped, not queued.
var _pending_intent: StringName = StringName()
var _selected_action_id: StringName = StringName()
var _result_text: String = ""
## The press animation: a deterministic clock, driven from _process.
var _press_elapsed: float = -1.0
var _press_action_id: StringName = StringName()
var _press_plate_index: int = -1
const OPTION_LABEL_NAMES := [&"OptionOneLabel", &"OptionTwoLabel"]
const OPTION_STAMP_NAMES := [&"OptionOneStamp", &"OptionTwoStamp"]
const LAPSED_ACTION_ID: StringName = &"lapsed"

func _ready() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		interactable.prompt_text = prompt_message
	for index in 2:
		var target := get_node_or_null("Option%dInteractable" % (index + 1)) as Interactable
		if target != null:
			target.interacted.connect(select_option.bind(index))
	_update_presentation()

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	return interactable

func configure(options: Array) -> void:
	_options = options.duplicate()
	_committed = false
	_pending_intent = StringName()
	_selected_action_id = StringName()
	_result_text = ""
	_update_presentation()

func set_enabled(value: bool) -> void:
	enabled = value and not _committed and _options.size() >= 2
	_update_presentation()

func is_enabled() -> bool:
	return enabled and not _committed and _options.size() >= 2

func has_committed() -> bool:
	return _committed

func has_pending_intent() -> bool:
	return _pending_intent != StringName()

func get_selected_action_id() -> StringName:
	return _selected_action_id

func get_result_text() -> String:
	return _result_text

func get_options() -> Array:
	return _options.duplicate()

## Input expresses intent only. The surface does not change here: no stamp,
## no result text, no sound. The session answers synchronously through
## commit_resolved -> apply_commit_result in the normal case, so an accepted
## filing still lands within the same frame — but a REJECTED intent (state
## moved on, deadline expired, unknown id) leaves the desk untouched.
func select_option(index: int) -> bool:
	if not is_enabled() or _committed or index < 0 or index >= mini(_options.size(), 2):
		return false
	if _pending_intent != StringName():
		return false
	var option = _options[index]
	var action_id := _string_name_property(option, "action_id")
	if action_id == StringName():
		return false
	_pending_intent = action_id
	option_committed.emit(action_id)
	# The authority answered within the intent (submit_commit is synchronous
	# and emits commit_resolved back). Clear the intent unless it is still
	# unresolved, in which case it stays dropped: nothing was filed.
	if _pending_intent == action_id and not _committed:
		_pending_intent = StringName()
	return true

func commit_option(action_id: StringName) -> bool:
	for index in mini(_options.size(), 2):
		if _string_name_property(_options[index], "action_id") == action_id:
			return select_option(index)
	return false

## The authoritative outcome, as the session resolved it. This is the only
## path that stamps the desk. A lapse is a resolved outcome too, but it never
## selects either authored copy and never claims a filing sound.
func apply_commit_result(action_id: StringName, result_text: String) -> void:
	if _committed:
		return
	if action_id == LAPSED_ACTION_ID:
		show_lapsed(result_text)
		return
	_committed = true
	_pending_intent = StringName()
	enabled = false
	_selected_action_id = action_id
	_result_text = result_text
	# The press is a physical act after the acceptance: the result text is
	# already honest on the surface, the stamp itself lands with the contact.
	_begin_stamp_press(_selected_index(), action_id)
	_update_presentation()
	commit_accepted.emit(action_id)

## The stamp presses onto the chosen plate. Ink and sound follow the contact,
## not the keypress.
func _begin_stamp_press(plate_index: int, action_id: StringName) -> void:
	if plate_index < 0:
		return
	_press_plate_index = plate_index
	_press_action_id = action_id
	_press_elapsed = 0.0

func _process(delta: float) -> void:
	if _press_elapsed < 0.0:
		return
	_press_elapsed += maxf(delta, 0.0)
	if _press_elapsed >= stamp_press_duration:
		# Contact: the mark appears and the sound belongs to this moment.
		_press_elapsed = -1.0
		_update_presentation()
		stamp_contact.emit(_press_action_id)

## True while the press is travelling: the result is accepted, the ink has
## not landed yet.
func is_press_in_flight() -> bool:
	return _press_elapsed >= 0.0

## Reflects the session's explicit timeout path. A lapse is a resolved desk
## state, but it never selects either authored copy or stamps a line as filed.
func show_lapsed(result_text: String = "UNFILED") -> void:
	if _committed:
		return
	_committed = true
	_pending_intent = StringName()
	enabled = false
	_selected_action_id = LAPSED_ACTION_ID
	_result_text = result_text
	_update_presentation()

func reset() -> void:
	_committed = false
	_pending_intent = StringName()
	enabled = false
	_selected_action_id = StringName()
	_result_text = ""
	_press_elapsed = -1.0
	_press_plate_index = -1
	_press_action_id = StringName()
	_update_presentation()

func reset_for_new_transmission() -> void:
	reset()

## Node input hook: the desk's key gate. Only a captured mouse, an unblocked
## world and the ray actually holding one of this desk's option targets let a
## key file a copy.
func _input(event: InputEvent) -> void:
	_handle_key_event(event)

## Returns whether the event was consumed. Exposed so the gate itself is
## testable without faking the whole input pipeline.
func _handle_key_event(event: InputEvent) -> bool:
	if not is_enabled() or event.is_echo() or not event.is_pressed():
		return false
	var office := get_parent() as M1OfficeController
	if office != null:
		var controller := office.player.get_node_or_null("InteractionController") as InteractionController
		if controller == null or controller.is_ui_blocked:
			return false
		# The ray must be holding one of this desk's option targets: a key
		# files a copy only while the operator is actually looking at the
		# desk he means to file on.
		if controller.current_target == null or controller.current_target.get_parent() != self:
			return false
	var option_index := -1
	if _action_pressed(event, "commit_option_1") or _key_pressed(event, KEY_1):
		option_index = 0
	elif _action_pressed(event, "commit_option_2") or _key_pressed(event, KEY_2):
		option_index = 1
	if option_index >= 0 and select_option(option_index):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return true
	return false

func _action_pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action)

func _key_pressed(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and (event.physical_keycode == keycode or event.keycode == keycode)

func _update_presentation() -> void:
	var interact := get_interactable()
	if interact != null:
		interact.enabled = is_enabled()
	for index in 2:
		var target := get_node_or_null("Option%dInteractable" % (index + 1)) as Interactable
		if target != null:
			target.enabled = is_enabled()
			if index < _options.size():
				target.prompt_text = _string_property(_options[index], "display_label").replace("\n", ": ")
	var selected_index := _selected_index()
	var options_visible := is_enabled() or _committed
	# While the press is in flight the ink has not landed: the stamps stay
	# hidden until the physical contact.
	var ink_landed := _committed and not is_press_in_flight()
	for index in 2:
		var label := get_node_or_null(String(OPTION_LABEL_NAMES[index]))
		var stamp := get_node_or_null(String(OPTION_STAMP_NAMES[index]))
		var has_option := index < _options.size()
		_set_text(label, _string_property(_options[index], "display_label") if has_option else "UNAVAILABLE")
		if label != null:
			label.visible = options_visible and has_option
		if stamp != null:
			# A stamp exists only for a filed copy, and only once the press
			# has physically landed. A lapse resolves the desk without filing
			# anything: no stamp is drawn at all.
			stamp.visible = ink_landed and has_option and selected_index >= 0
			_set_text(stamp, "FILED" if index == selected_index else "VOID")
			_set_modulate(stamp, Color(0.72, 0.18, 0.12, 1.0) if index == selected_index else Color(0.42, 0.4, 0.35, 0.65))
	var result := get_node_or_null("ResultLabel")
	_set_text(result, _result_text if _committed and not _result_text.is_empty() else "NO FILE")
	var prompt := get_node_or_null("PromptLabel")
	var resolved_prompt := "NO COPY FILED" if _selected_action_id == LAPSED_ACTION_ID else "COPY FILED"
	_set_text(prompt, prompt_message if is_enabled() else (resolved_prompt if _committed else "AWAITING TRANSCRIPT"))

func _selected_index() -> int:
	if _selected_action_id == StringName():
		return -1
	for index in mini(_options.size(), 2):
		if _string_name_property(_options[index], "action_id") == _selected_action_id:
			return index
	return -1

func _string_name_property(option, property_name: String) -> StringName:
	var value = _property(option, property_name)
	return StringName() if value == null else StringName(str(value))

func _string_property(option, property_name: String) -> String:
	var value = _property(option, property_name)
	return "" if value == null else str(value)

func _property(option, property_name: String):
	if option is Dictionary:
		return option.get(property_name)
	if option is Object:
		return option.get(property_name)
	return null

func _set_text(node: Node, text: String) -> void:
	if node is Label3D or node is Label:
		node.text = text

func _set_modulate(node: Node, value: Color) -> void:
	if node is Label3D or node is CanvasItem:
		node.modulate = value
