extends SceneTree
## Intent never becomes the physical record without the session's acknowledgement.
## godot --headless --audio-driver Dummy --path . --script tests/telegraph/route_acceptance_test.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Route Acceptance Test Suite ---")
	if not _test_rejected_intent(): return
	if not _test_accepted_intent(): return
	if not _test_duplicate_pending_acknowledgement(): return
	if not _test_reset_during_accepted_feedback(): return
	if not _test_reset_before_acknowledgement(): return
	if not _test_watch_reset_during_intent(): return
	if not _test_direct_feedback_cannot_reenter(): return
	if not _test_unacknowledged_intent(): return
	if not _test_rejection_preserves_prior_memory(): return
	print("--- All Route Acceptance Tests PASSED ---")
	quit(0)

func _test_rejected_intent() -> bool:
	var board := _make_board()
	var intents: Array[String] = []
	var before_ack: Array[bool] = []
	var reject := func(action: String) -> void:
		intents.append(action)
		before_ack.append(board.has_submitted_this_session or not board._last_route_action.is_empty())
		board.play_route_accept(action, false)
	board.routing_action_selected.connect(reject)
	_prepare(board)
	var pivot := board.get_node("LeverPivot") as Node3D
	var rest := pivot.rotation.z
	var result := board.select_action("CLEAR EAST")
	var checks := [
		[result == false, "Rejected intent returns false"],
		[intents == ["CLEAR EAST"], "Rejected intent reaches authority once"],
		[before_ack == [false], "Intent dispatch does not pre-record acceptance"],
		[not board.has_submitted_this_session, "Rejected intent leaves the slot unsubmitted"],
		[board._last_route_action.is_empty(), "Rejected intent creates no accepted memory"],
		[is_equal_approx(pivot.rotation.z, rest), "Rejected intent never moves the lever"],
		[board.is_open and board.get_interactable().is_actionable, "Rejected intent leaves the pending board actionable"],
	]
	board.free()
	return _assert_checks(checks)

func _test_accepted_intent() -> bool:
	var board := _make_board()
	if not assert_condition(board.has_signal("route_accepted"), "Board exposes acceptance-only feedback"):
		board.free()
		return false
	var intents: Array[String] = []
	var feedback: Array[String] = []
	var state_at_feedback: Array[bool] = []
	var on_feedback := func(action: String) -> void:
		feedback.append(action)
		state_at_feedback.append(board.has_submitted_this_session and board._last_route_action == action)
	board.connect("route_accepted", on_feedback)
	var accept := func(action: String) -> void:
		intents.append(action)
		board.play_route_accept(action, true)
	board.routing_action_selected.connect(accept)
	_prepare(board)
	var result := board.select_action("CLEAR EAST")
	var pivot := board.get_node("LeverPivot") as Node3D
	var checks := [
		[result, "Accepted intent returns true"],
		[intents == ["CLEAR EAST"], "Accepted request reaches authority once"],
		[board.has_submitted_this_session, "Acknowledgement submits the slot"],
		[board._last_route_action == "CLEAR EAST", "Acknowledgement records its exact route"],
		[feedback == ["CLEAR EAST"], "Accepted route publishes one physical feedback signal"],
		[state_at_feedback == [true], "Accepted state is committed before feedback is published"],
		[is_equal_approx(pivot.rotation.z, deg_to_rad(board.lever_throw_degrees)), "Acknowledgement moves the lever"],
		[not board.is_open, "Accepted request closes the board"],
		[not board.get_interactable().is_actionable and board.get_interactable().prompt_text == "Route recorded: CLEAR EAST", "Accepted board presents read-only route status"],
		[not board.select_action("HOLD") and intents.size() == 1, "Terminal slot rejects another request"],
	]
	board.free()
	return _assert_checks(checks)

func _test_duplicate_pending_acknowledgement() -> bool:
	var board := _make_board()
	var intents: Array[String] = []
	var feedback: Array[String] = []
	var nested_results: Array[bool] = []
	var on_feedback := func(action: String) -> void:
		feedback.append(action)
		if feedback.size() == 1:
			board.play_route_accept(action, true)
			nested_results.append(board.select_action("HOLD"))
	board.connect("route_accepted", on_feedback)
	var accept := func(action: String) -> void:
		intents.append(action)
		nested_results.append(board.select_action(action))
		board.play_route_accept(action, true)
		board.play_route_accept(action, true)
		board.play_route_accept("HOLD", true)
	board.routing_action_selected.connect(accept)
	_prepare(board)
	var result := board.select_action("CLEAR EAST")
	var checks := [
		[result, "Original pending request is accepted"],
		[intents == ["CLEAR EAST"] and nested_results == [false, false], "Reentrant pending requests never emit another intent"],
		[feedback == ["CLEAR EAST"], "Duplicate and reentrant acknowledgements publish only once"],
		[board._last_route_action == "CLEAR EAST", "Another payload cannot overwrite a resolved pending request"],
		[board.has_submitted_this_session, "Duplicate acknowledgement keeps the accepted slot terminal"],
	]
	board.free()
	return _assert_checks(checks)

func _test_reset_during_accepted_feedback() -> bool:
	var board := _make_board()
	var feedback: Array[String] = []
	var intents: Array[String] = []
	var nested_results: Array[bool] = []
	var reset := func(action: String) -> void:
		feedback.append(action)
		board.reset_for_new_transmission()
		_prepare(board)
		nested_results.append(board.select_action("HOLD"))
		board.play_route_accept(action, true)
	board.connect("route_accepted", reset)
	var accept := func(action: String) -> void:
		intents.append(action)
		board.play_route_accept(action, true)
		board.play_route_accept(action, true)
	board.routing_action_selected.connect(accept)
	_prepare(board)
	var result := board.select_action("CLEAR EAST")
	var checks := [
		[result, "Accepted return value survives a synchronous slot reset"],
		[feedback == ["CLEAR EAST"] and intents == ["CLEAR EAST"], "Slot reset cannot replay the old acknowledgement"],
		[nested_results == [false], "Slot reset cannot reenter the still-dispatching request"],
		[board._last_route_action == "CLEAR EAST", "Next slot preserves the old accepted route memory"],
		[not board.has_submitted_this_session, "Old acknowledgement never submits the new slot"],
		[board.is_open and board.get_interactable().is_actionable, "Old request cannot close the new slot's board"],
	]
	if not _assert_checks(checks):
		board.free()
		return false
	board.disconnect("route_accepted", reset)
	var next_result := board.select_action("HOLD")
	var next_checks := [
		[next_result and board.has_submitted_this_session, "Next slot can accept its own request after dispatch finishes"],
		[board._last_route_action == "HOLD" and intents == ["CLEAR EAST", "HOLD"], "Next accepted request replaces only the prior memory"],
	]
	board.free()
	return _assert_checks(next_checks)

func _test_reset_before_acknowledgement() -> bool:
	var board := _make_board()
	var feedback: Array[String] = []
	board.connect("route_accepted", func(action: String): feedback.append(action))
	var accept_after_reset := func(action: String) -> void:
		board.reset_for_new_transmission()
		_prepare(board)
		board.play_route_accept(action, true)
	board.routing_action_selected.connect(accept_after_reset)
	_prepare(board)
	var result := board.select_action("CLEAR EAST")
	var pivot := board.get_node("LeverPivot") as Node3D
	var checks := [
		[result and feedback == ["CLEAR EAST"], "Captured old request can still receive its acknowledgement"],
		[not board.has_submitted_this_session, "Acknowledgement after reset cannot mark the next slot submitted"],
		[board._last_route_action == "CLEAR EAST", "Acknowledgement after reset preserves the old accepted payload"],
		[is_equal_approx(pivot.rotation.z, deg_to_rad(board.lever_throw_degrees)), "Old accepted payload still drives its physical lever"],
		[board.is_open and board.get_interactable().is_actionable, "Old acknowledgement leaves the new pending board open"],
	]
	board.free()
	return _assert_checks(checks)

func _test_watch_reset_during_intent() -> bool:
	var board := _make_board()
	var feedback: Array[String] = []
	board.connect("route_accepted", func(action: String): feedback.append(action))
	var reset_watch := func(action: String) -> void:
		board.reset_for_new_watch()
		_prepare(board)
		board.play_route_accept(action, true)
	board.routing_action_selected.connect(reset_watch)
	_prepare(board)
	var result := board.select_action("CLEAR EAST")
	var pivot := board.get_node("LeverPivot") as Node3D
	var checks := [
		[not result and feedback.is_empty(), "New watch invalidates an old pending acknowledgement"],
		[not board.has_submitted_this_session and board._last_route_action.is_empty(), "New watch retains no old pending route state"],
		[is_zero_approx(pivot.rotation.z), "New watch retains its rest position after stale acknowledgement"],
		[board.is_open and board.get_interactable().is_actionable, "Stale watch request leaves the new watch actionable"],
	]
	board.free()
	return _assert_checks(checks)

func _test_direct_feedback_cannot_reenter() -> bool:
	var board := _make_board()
	var intents: Array[String] = []
	var nested: Array[bool] = []
	board.routing_action_selected.connect(func(action: String): intents.append(action))
	var on_feedback := func(_action: String) -> void:
		board.reset_for_new_transmission()
		_prepare(board)
		nested.append(board.select_action("HOLD"))
	board.connect("route_accepted", on_feedback)
	board.play_route_accept("CLEAR EAST", true)
	var checks := [
		[nested == [false] and intents.is_empty(), "Direct acceptance feedback cannot dispatch a reentrant request"],
		[not board.has_submitted_this_session and board._last_route_action == "CLEAR EAST", "Direct feedback slot reset preserves only the prior accepted memory"],
	]
	board.free()
	return _assert_checks(checks)

func _test_unacknowledged_intent() -> bool:
	var board := _make_board()
	var intents: Array[String] = []
	var feedback: Array[String] = []
	board.routing_action_selected.connect(func(action: String): intents.append(action))
	board.connect("route_accepted", func(action: String): feedback.append(action))
	_prepare(board)
	var first_result := board.select_action("CLEAR EAST")
	var second_result := board.select_action("HOLD")
	var checks := [
		[not first_result and not second_result, "Intent alone never reports acceptance"],
		[intents == ["CLEAR EAST", "HOLD"], "Unacknowledged synchronous request clears its pending guard"],
		[feedback.is_empty() and not board.has_submitted_this_session and board._last_route_action.is_empty(), "Unacknowledged intent has no feedback or accepted state"],
	]
	board.free()
	return _assert_checks(checks)

func _test_rejection_preserves_prior_memory() -> bool:
	var board := _make_board()
	board.play_route_accept("HOLD", true)
	board.reset_for_new_transmission()
	var pivot := board.get_node("LeverPivot") as Node3D
	var needle := board.get_node("IndicatorPivot") as Node3D
	var old_lever := pivot.rotation.z
	var old_needle := needle.rotation.z
	var feedback: Array[String] = []
	board.connect("route_accepted", func(action: String): feedback.append(action))
	board.routing_action_selected.connect(func(action: String): board.play_route_accept(action, false))
	_prepare(board)
	var result := board.select_action("CLEAR EAST")
	board.play_route_accept("NO ORDER", false)
	var checks := [
		[not result and not board.has_submitted_this_session, "Rejected next-slot request leaves that slot unsubmitted"],
		[board._last_route_action == "HOLD", "Rejected next-slot request preserves prior accepted memory"],
		[is_equal_approx(pivot.rotation.z, old_lever) and is_equal_approx(needle.rotation.z, old_needle), "Rejected and lapsed requests preserve both physical indicators"],
		[feedback.is_empty(), "Rejected and lapsed requests publish no accepted feedback"],
	]
	board.free()
	return _assert_checks(checks)

func _make_board() -> RoutingBoard:
	var board := RoutingBoard.new()
	var pivot := Node3D.new()
	pivot.name = "LeverPivot"
	board.add_child(pivot)
	var needle := Node3D.new()
	needle.name = "IndicatorPivot"
	board.add_child(needle)
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	board.add_child(interactable)
	board.get_interactable()
	return board

func _prepare(board: RoutingBoard) -> void:
	board.set_awaiting_route(true)
	board.open_board()

func _assert_checks(checks: Array) -> bool:
	for check in checks:
		if not assert_condition(check[0], check[1]): return false
	return true

func assert_condition(ok: bool, desc: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + desc)
	if not ok:
		quit(1)
	return ok
