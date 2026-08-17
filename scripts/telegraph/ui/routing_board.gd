class_name RoutingBoard
extends Node3D

signal routing_action_selected(action: String)
signal board_opened()
signal board_closed()

@export var prompt_message: String = "Inspect Routing Board (East Wall)"
@export var is_awaiting_route: bool = false

var interactable: Interactable = null
var route_prompt: Control = null
var is_open: bool = false
var has_submitted_this_session: bool = false

func _ready() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	route_prompt = get_node_or_null("RoutePromptUI/Panel") as Control

	if interactable != null:
		interactable.prompt_text = prompt_message
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	_update_presentation()

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	return interactable

func set_awaiting_route(awaiting: bool) -> void:
	is_awaiting_route = awaiting
	_update_presentation()

func _update_presentation() -> void:
	if route_prompt == null:
		route_prompt = get_node_or_null("RoutePromptUI/Panel") as Control
	if route_prompt != null:
		route_prompt.visible = is_open and is_awaiting_route and not has_submitted_this_session

func _input(event: InputEvent) -> void:
	if not is_open:
		return

	var is_cancel: bool = event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE))
	if is_cancel and not event.is_echo():
		close_board()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		return

	if event.is_echo() or not event.is_pressed():
		return

	var is_route_1: bool = event.is_action_pressed("route_clear_east") or (event is InputEventKey and (event.physical_keycode == KEY_1 or event.keycode == KEY_1))
	var is_route_2: bool = event.is_action_pressed("route_hold") or (event is InputEventKey and (event.physical_keycode == KEY_2 or event.keycode == KEY_2))

	if is_route_1:
		if select_action("CLEAR EAST"):
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
	elif is_route_2:
		if select_action("HOLD"):
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()

func open_board() -> void:
	if is_open:
		return
	is_open = true
	_update_presentation()
	board_opened.emit()

func close_board() -> void:
	if not is_open:
		return
	is_open = false
	_update_presentation()
	board_closed.emit()

func select_action(action: String) -> bool:
	# Only permit submission when session is awaiting route decision and board is open
	if not is_open or has_submitted_this_session or not is_awaiting_route:
		return false

	if action != "CLEAR EAST" and action != "HOLD":
		return false

	has_submitted_this_session = true
	routing_action_selected.emit(action)
	close_board()
	return true

func reset_for_new_transmission() -> void:
	has_submitted_this_session = false
	is_open = false
	is_awaiting_route = false
	_update_presentation()

func _on_interacted() -> void:
	if is_open:
		close_board()
	else:
		open_board()
