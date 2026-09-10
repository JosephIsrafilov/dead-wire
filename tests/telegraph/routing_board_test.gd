extends SceneTree

func _init() -> void:
	print("--- Starting Routing Board Test Suite (Phase F / Gate 13A) ---")

	var board_scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/routing_board.tscn")
	if not assert_condition(board_scene != null, "routing_board.tscn loads"): return
	var board_node: RoutingBoard = board_scene.instantiate() as RoutingBoard
	if not assert_condition(board_node != null and board_node is RoutingBoard, "instantiates as RoutingBoard"): return
	root.add_child(board_node)

	var act: Interactable = board_node.get_interactable()
	if not assert_condition(act != null, "board has Interactable component"): return
	if not assert_condition(act.prompt_text == "Inspect Routing Board (East Wall)", "prompt text matches"): return

	# 1. Open / Close
	if not assert_condition(not board_node.is_open, "Initially closed"): return
	board_node.open_board()
	if not assert_condition(board_node.is_open, "Board is open after open_board()"): return
	board_node.close_board()
	if not assert_condition(not board_node.is_open, "Board is closed after close_board()"): return

	# 2. Input actions when board is CLOSED (Must do nothing)
	var selected_actions: Array[String] = []
	board_node.routing_action_selected.connect(func(a: String): selected_actions.append(a))

	var ev_1_closed: InputEventKey = InputEventKey.new()
	ev_1_closed.physical_keycode = KEY_1
	ev_1_closed.pressed = true
	ev_1_closed.echo = false
	board_node._input(ev_1_closed)
	if not assert_condition(selected_actions.is_empty(), "Key 1 does nothing when board is closed"): return

	# 3. Input actions when board is OPEN but NOT AWAITING ROUTE (e.g. READY or RECEIVING)
	board_node.open_board()
	board_node.set_awaiting_route(false)

	var ev_1_open: InputEventKey = InputEventKey.new()
	ev_1_open.physical_keycode = KEY_1
	ev_1_open.pressed = true
	ev_1_open.echo = false
	board_node._input(ev_1_open)
	if not assert_condition(selected_actions.is_empty(), "Key 1 rejected when not awaiting route"): return
	if not assert_condition(not board_node.has_submitted_this_session, "has_submitted_this_session remains false on rejected early input"): return

	# 4. Input action 1 when board is OPEN and AWAITING ROUTE -> Selects CLEAR EAST
	board_node.set_awaiting_route(true)

	var ev_echo: InputEventKey = InputEventKey.new()
	ev_echo.physical_keycode = KEY_1
	ev_echo.pressed = true
	ev_echo.echo = true
	board_node._input(ev_echo)
	if not assert_condition(selected_actions.is_empty(), "Keyboard echo is ignored"): return

	board_node._input(ev_1_open)
	if not assert_condition(selected_actions.size() == 1 and selected_actions[0] == "CLEAR EAST", "Key 1 selects CLEAR EAST when awaiting route"): return
	if not assert_condition(not board_node.is_open, "Board automatically closes after selection"): return
	if not assert_condition(board_node.has_submitted_this_session, "has_submitted_this_session is true after submission"): return
	board_node.get_interactable().interact()
	if not assert_condition(not board_node.is_open and not board_node.get_interactable().is_actionable and board_node.get_interactable().prompt_text == "Route recorded: CLEAR EAST", "Repeated board interaction is safe read-only status"): return

	# 5. Duplicate input rejection in same session
	board_node.open_board()
	var ev_dup: InputEventKey = InputEventKey.new()
	ev_dup.physical_keycode = KEY_2
	ev_dup.pressed = true
	ev_dup.echo = false
	board_node._input(ev_dup)
	if not assert_condition(selected_actions.size() == 1, "Duplicate input in same session rejected"): return

	# 6. Reset for new transmission -> Input action 2 selects HOLD
	board_node.reset_for_new_transmission()
	board_node.set_awaiting_route(true)
	board_node.open_board()
	var ev_2_open: InputEventKey = InputEventKey.new()
	ev_2_open.physical_keycode = KEY_2
	ev_2_open.pressed = true
	ev_2_open.echo = false
	board_node._input(ev_2_open)
	if not assert_condition(selected_actions.size() == 2 and selected_actions[1] == "HOLD", "Key 2 selects HOLD after reset"): return
	if not assert_condition(not board_node.is_open, "Board automatically closes after HOLD"): return

	# 7. Close via Esc
	board_node.reset_for_new_transmission()
	board_node.open_board()
	var ev_esc: InputEventKey = InputEventKey.new()
	ev_esc.physical_keycode = KEY_ESCAPE
	ev_esc.pressed = true
	ev_esc.echo = false
	board_node._input(ev_esc)
	if not assert_condition(not board_node.is_open, "Board closes on Esc (ui_cancel)"): return

	# Clean up
	board_node.queue_free()

	print("--- All Routing Board Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
