class_name CopyCommitDesk
extends Node3D

signal option_committed(action_id: StringName)

@export var enabled: bool = false
@export var prompt_message: String = "File one copy"

var interactable: Interactable = null
var _options: Array = []
var _committed: bool = false
var _selected_action_id: StringName = StringName()
var _result_text: String = ""
const OPTION_LABEL_NAMES := [&"OptionOneLabel", &"OptionTwoLabel"]
const OPTION_STAMP_NAMES := [&"OptionOneStamp", &"OptionTwoStamp"]
const LAPSED_ACTION_ID: StringName = &"lapsed"

func _ready() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		interactable.prompt_text = prompt_message
	_update_presentation()

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	return interactable

func configure(options: Array) -> void:
	_options = options.duplicate()
	_committed = false
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

func get_selected_action_id() -> StringName:
	return _selected_action_id

func get_result_text() -> String:
	return _result_text

func get_options() -> Array:
	return _options.duplicate()

func select_option(index: int) -> bool:
	if not is_enabled() or _committed or index < 0 or index >= mini(_options.size(), 2):
		return false
	var option = _options[index]
	var action_id := _string_name_property(option, "action_id")
	if action_id == StringName():
		return false
	_committed = true
	enabled = false
	_selected_action_id = action_id
	_result_text = _string_property(option, "result_text")
	_update_presentation()
	option_committed.emit(action_id)
	return true

func commit_option(action_id: StringName) -> bool:
	for index in mini(_options.size(), 2):
		if _string_name_property(_options[index], "action_id") == action_id:
			return select_option(index)
	return false

## Reflects the session's explicit timeout path. A lapse is a resolved desk
## state, but it never selects either authored copy or stamps a line as filed.
func show_lapsed(result_text: String = "UNFILED") -> void:
	if _committed:
		return
	_committed = true
	enabled = false
	_selected_action_id = LAPSED_ACTION_ID
	_result_text = result_text
	_update_presentation()

func reset() -> void:
	_committed = false
	enabled = false
	_selected_action_id = StringName()
	_result_text = ""
	_update_presentation()

func reset_for_new_transmission() -> void:
	reset()

func _input(event: InputEvent) -> void:
	if not is_enabled() or event.is_echo() or not event.is_pressed():
		return
	var option_index := -1
	if _action_pressed(event, "commit_option_1") or _key_pressed(event, KEY_1):
		option_index = 0
	elif _action_pressed(event, "commit_option_2") or _key_pressed(event, KEY_2):
		option_index = 1
	if option_index >= 0 and select_option(option_index):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _action_pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action)

func _key_pressed(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and (event.physical_keycode == keycode or event.keycode == keycode)

func _update_presentation() -> void:
	var interact := get_interactable()
	if interact != null:
		interact.enabled = is_enabled()
	var selected_index := _selected_index()
	var options_visible := is_enabled() or _committed
	for index in 2:
		var label := get_node_or_null(String(OPTION_LABEL_NAMES[index]))
		var stamp := get_node_or_null(String(OPTION_STAMP_NAMES[index]))
		var has_option := index < _options.size()
		_set_text(label, _string_property(_options[index], "display_label") if has_option else "UNAVAILABLE")
		if label != null:
			label.visible = options_visible and has_option
		if stamp != null:
			stamp.visible = _committed and has_option
			_set_text(stamp, "STAMPED" if index == selected_index else "VOID")
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
