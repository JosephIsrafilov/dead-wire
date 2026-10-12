extends SceneTree
## Route buttons submit through select_action and therefore the same route authority as keys.
## godot --headless --audio-driver Dummy --path . --script tests/telegraph/routing_mouse_test.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var board := load("res://scenes/telegraph/routing_board.tscn").instantiate() as RoutingBoard
	root.add_child(board)
	board.set_awaiting_route(true)
	board.open_board()
	var actions: Array[String] = []
	board.routing_action_selected.connect(func(action: String) -> void: actions.append(action))
	board.routing_action_selected.connect(func(action: String) -> void: board.play_route_accept(action, true))
	var clear_button := board.get_node_or_null("RoutePromptUI/Panel/ClearEastButton") as Button
	var hold_button := board.get_node_or_null("RoutePromptUI/Panel/HoldButton") as Button
	if not _check(clear_button != null and hold_button != null, "Both route choices have mouse buttons"): return
	clear_button.pressed.emit()
	if not _check(actions == ["CLEAR EAST"] and board.has_submitted_this_session, "Mouse CLEAR EAST uses accepted route authority"): return
	board.reset_for_new_transmission()
	board.set_awaiting_route(true)
	board.open_board()
	hold_button.pressed.emit()
	if not _check(actions == ["CLEAR EAST", "HOLD"] and board.has_submitted_this_session, "Mouse HOLD uses the same accepted route authority"): return
	board.free()
	quit(0)

func _check(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok:
		quit(1)
	return ok
