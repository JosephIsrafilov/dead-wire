class_name RoutingBoard
extends Node3D

signal routing_action_selected(action: String)
signal board_opened()
signal board_closed()

@export var prompt_message: String = "Train-Order Board"
@export var is_awaiting_route: bool = false

## The switch lever physically throws when a route is set. Angles in degrees from
## the lever's rest pose; CLEAR EAST throws one way, HOLD the other.
@export var lever_throw_degrees: float = 34.0
@export var lever_throw_duration: float = 0.42
@export var lever_impact_stream: AudioStream = preload("res://assets/audio/sfx/kenney_impact/lever_stop.ogg")
## The lever stop is furniture working, not the wire: it rides the Foley bus.
@export var lever_impact_bus: StringName = &"Foley"

var interactable: Interactable = null
var route_prompt: Control = null
var is_open: bool = false
var has_submitted_this_session: bool = false
## The last route that actually went out this watch. A new slot may reset the
## ability to submit, but the physical lever keeps the result until the watch
## itself is reset (plan R01).
var _last_route_action: String = ""

var _lever_rest_rotation: float = 0.0
var _lever_rest_captured: bool = false
var _lever_tween: Tween = null

func _capture_lever_rest() -> void:
	if _lever_rest_captured:
		return
	var pivot := get_node_or_null("LeverPivot") as Node3D
	if pivot != null:
		_lever_rest_rotation = pivot.rotation.z
		_lever_rest_captured = true

func _ready() -> void:
	_capture_lever_rest()
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
	if interactable == null:
		return
	if is_awaiting_route and not has_submitted_this_session:
		# A decision is pending: the board is an action again.
		interactable.prompt_text = prompt_message
		interactable.is_actionable = true
	elif not _last_route_action.is_empty():
		# The night's last route stays on the board after the slot moves on —
		# "Last route", not a fresh promise of an interaction.
		interactable.prompt_text = "Route recorded: %s" % _last_route_action
		interactable.is_actionable = false
	elif not is_awaiting_route:
		# No decision is pending. E must not promise an interaction that does
		# nothing, so an idle board reads as plain line status.
		interactable.prompt_text = "Routing Board — Line Status"
		interactable.is_actionable = false
	else:
		interactable.prompt_text = prompt_message
		interactable.is_actionable = true

func _input(event: InputEvent) -> void:
	if not is_open:
		return

	var escape_key: bool = event is InputEventKey and event.pressed \
		and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE)
	var is_cancel: bool = event.is_action_pressed("ui_cancel") or escape_key
	if is_cancel and not event.is_echo():
		close_board()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		return

	if event.is_echo() or not event.is_pressed():
		return

	var key_1: bool = event is InputEventKey \
		and (event.physical_keycode == KEY_1 or event.keycode == KEY_1)
	var is_route_1: bool = event.is_action_pressed("route_clear_east") or key_1
	var key_2: bool = event is InputEventKey \
		and (event.physical_keycode == KEY_2 or event.keycode == KEY_2)
	var is_route_2: bool = event.is_action_pressed("route_hold") or key_2

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
	# An idle board is a status surface, not a modal. Opening it would lock
	# movement behind a panel with nothing to decide.
	if not is_awaiting_route or has_submitted_this_session:
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
	_last_route_action = action
	# The lever throw waits for the session's own confirmation: a rejected or
	# lapsed deadline must not leave the apparatus showing a route that never
	# entered the world.
	routing_action_selected.emit(action)
	close_board()
	return true

## The session resolved the slot: an accepted route (correct or not — the order
## physically went out) throws the lever to its stop with the impact sound; a
## lapsed "NO ORDER" leaves the lever exactly where it was.
func play_route_accept(action: String, accepted: bool) -> void:
	if not accepted or action.is_empty():
		return
	_throw_lever(action)

## A route order is a physical act: the lever pivot swings to its stop, the
## mechanical needle follows, and the stop announces itself on the wire-side
## of the room. Targets are absolute against the once-captured rest pose, so
## repeated throws cannot drift; a new accepted throw kills the previous
## tween so a late result can never overwrite the fresh record.
func _throw_lever(action: String) -> void:
	var pivot := get_node_or_null("LeverPivot") as Node3D
	var needle := get_node_or_null("IndicatorPivot") as Node3D
	if pivot == null:
		return
	# Capture the authored rest exactly once, before any throw can move it.
	_capture_lever_rest()

	var direction := 1.0 if action == "CLEAR EAST" else -1.0
	var target := _lever_rest_rotation + direction * deg_to_rad(lever_throw_degrees)

	if _lever_tween != null and is_instance_valid(_lever_tween):
		_lever_tween.kill()

	if not is_inside_tree():
		pivot.rotation.z = target
		if needle != null:
			needle.rotation.z = direction * deg_to_rad(50.0)
		return

	_lever_tween = create_tween()
	_lever_tween.set_parallel(true)
	_lever_tween.tween_property(pivot, "rotation:z", target, lever_throw_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if needle != null:
		# The needle leans the same way as the lever: toward the route taken.
		_lever_tween.tween_property(needle, "rotation:z", direction * deg_to_rad(50.0), lever_throw_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Impact lands when the lever meets the stop, not when the hand starts it.
	var sfx := get_node_or_null("LeverSfx") as AudioStreamPlayer3D
	if sfx != null:
		sfx.stream = lever_impact_stream
		sfx.bus = lever_impact_bus
		_lever_tween.chain().tween_callback(sfx.play)

## A new slot resets the ability to submit — nothing else. The lever, the
## needle and the recorded route are the night's memory, not this slot's.
func reset_for_new_transmission() -> void:
	has_submitted_this_session = false
	is_open = false
	is_awaiting_route = false
	_update_presentation()

## Only a new watch wipes the physical record: lever and needle return to
## rest and the board forgets the last route.
func reset_for_new_watch() -> void:
	reset_for_new_transmission()
	_last_route_action = ""
	if _lever_tween != null and is_instance_valid(_lever_tween):
		_lever_tween.kill()
	_lever_tween = null
	_capture_lever_rest()
	var pivot := get_node_or_null("LeverPivot") as Node3D
	var needle := get_node_or_null("IndicatorPivot") as Node3D
	if _lever_rest_captured and pivot != null:
		pivot.rotation.z = _lever_rest_rotation
	if needle != null:
		needle.rotation.z = 0.0
	_update_presentation()

func _on_interacted() -> void:
	# A completed route is a terminal state for this board instance. Keep the
	# physical board inspectable as status, but never reopen a modal with no
	# choices and trap player controls behind it.
	if has_submitted_this_session:
		return
	if not is_awaiting_route:
		# Same contract as open_board(): no pending decision, no modal.
		return
	if is_open:
		close_board()
	else:
		open_board()
