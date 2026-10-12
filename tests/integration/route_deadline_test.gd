extends SceneTree
var count := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok: quit(1); return false
	count += 1
	return true
func _run() -> void:
	for offset in [-0.001, 0.0, 0.001]:
		var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
		root.add_child(office)
		await process_frame
		await process_frame
		office.get_node("IntroCard").skip_immediately()
		var director := office.shift_director
		var session := office.session_controller
		director.set_process(false)
		session.set_process(false)
		office.load_scenario_by_index(0)
		session._state = TelegraphSessionController.State.AWAITING_ROUTE
		session._post_signal_elapsed = director.route_deadline_seconds + offset
		director._slot_index = 0
		director._phase = ShiftDirector.Phase.AWAITING_ROUTE
		var board := office.routing_board
		board.set_awaiting_route(true)
		board.open_board()
		var before := board._last_route_action
		var accepted: Array = []
		board.route_accepted.connect(func(action): accepted.append(action))
		var result := board.select_action("CLEAR EAST")
		if offset < 0:
			if not check(result and accepted == ["CLEAR EAST"], "Order before original deadline receives one acceptance"): return
			if not check(board._last_route_action == "CLEAR EAST", "Accepted old-slot route survives actual synchronous office progression"): return
		else:
			if not check(not result and accepted.is_empty(), "Exact/late original deadline rejects without accepted sound"): return
			if not check(board._last_route_action == before, "Rejected request does not invent route memory"): return
			var lever := office.get_node("OfficeFoley/LeverThrow") as AudioStreamPlayer3D
			if not check(not lever.playing, "Deadline rejection creates no physical throw sound"): return
		office.queue_free()
		await process_frame
	print("Office route boundary assertions: ", count)
	quit(0)
