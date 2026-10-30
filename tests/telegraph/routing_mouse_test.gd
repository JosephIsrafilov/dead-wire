extends SceneTree
## Plan 6.5: the order is given with the hand on the lever. A click or E on
## either notch submits through the same route authority as the keys, and
## there are no 2D buttons left to click instead.
## godot --headless --audio-driver Dummy --path . --script tests/telegraph/routing_mouse_test.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var board := load("res://scenes/telegraph/routing_board.tscn").instantiate() as RoutingBoard
	root.add_child(board)
	board.set_awaiting_route(true)
	var actions: Array[String] = []
	board.routing_action_selected.connect(func(action: String) -> void: actions.append(action))
	board.routing_action_selected.connect(func(action: String) -> void: board.play_route_accept(action, true))
	if not _check(board.find_children("*", "Button", true, false).is_empty(), "No 2D route buttons are drawn over the room"): return
	var clear_stop := board.get_node_or_null("ClearStopInteractable") as Interactable
	var hold_stop := board.get_node_or_null("HoldStopInteractable") as Interactable
	if not _check(clear_stop != null and hold_stop != null, "Both route choices are notches of the lever"): return
	clear_stop.interact()
	if not _check(actions == ["CLEAR EAST"] and board.has_submitted_this_session, "The CLEAR EAST notch uses accepted route authority"): return
	board.reset_for_new_transmission()
	board.set_awaiting_route(true)
	hold_stop.interact()
	if not _check(actions == ["CLEAR EAST", "HOLD"] and board.has_submitted_this_session, "The HOLD notch uses the same accepted route authority"): return
	board.free()
	quit(0)

func _check(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok:
		quit(1)
	return ok
