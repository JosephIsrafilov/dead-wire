extends SceneTree
## Session authority, not merely board input, owns exactly one old-slot resolution.
var passed := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok: quit(1); return false
	passed += 1
	return true
func _run() -> void:
	var world := root.get_node("WorldState") as WorldStateStore
	var knowledge := root.get_node("KnowledgeState") as KnowledgeStateStore
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	var session := TelegraphSessionController.new()
	root.add_child(session)
	session.set_process(false)
	var original := load("res://data/scenarios/m1_scenario_1_baseline.tres").duplicate(true) as TelegraphScenarioData
	original.completion_fact = "original_completed"
	var next := load("res://data/scenarios/m1_scenario_2_attention.tres").duplicate(true) as TelegraphScenarioData
	next.completion_fact = "next_completed"
	session.load_scenario(original)
	session._state = TelegraphSessionController.State.AWAITING_ROUTE
	var resolutions: Array = []
	var attempts: Array = []
	var completions: Array = []
	var on_resolved := func(action, outcome):
		resolutions.append([action, outcome])
		if resolutions.size() == 1:
			attempts.append(session.submit_routing_decision("HOLD"))
			attempts.append(session.load_scenario(next))
			session.reset_session()
	session.routing_resolved.connect(on_resolved)
	session.session_completed.connect(func(scenario): completions.append(scenario))
	if not check(session.submit_routing_decision("CLEAR EAST"), "Original route is accepted"): return
	if not check(resolutions.size() == 1 and attempts == [false, false], "Routing listeners cannot reenter acceptance or replace its scenario"): return
	if not check(world.get_fact(&"train_17_routed_clear", false) and not world.get_fact(&"train_17_held_in_error", false), "Only the originally chosen objective route is written"): return
	if not check(world.get_fact(&"original_completed", false) and not world.get_fact(&"next_completed", false), "Completion facts belong only to captured original slot"): return
	if not check(completions == [original] and session.get_current_scenario() == original, "Completion payload stays attributed to original despite reset attempt"): return
	session.routing_resolved.disconnect(on_resolved)
	session.load_scenario(original)
	session._state = TelegraphSessionController.State.AWAITING_ROUTE
	var fact_attempts: Array = []
	var on_fact := func(id, _old, _value):
		if id == &"train_17_routed_clear":
			fact_attempts.append(session.submit_routing_decision("HOLD"))
			fact_attempts.append(session.load_scenario(next))
	world.fact_changed.connect(on_fact)
	world.reset_for_new_game()
	if not check(session.submit_routing_decision("CLEAR EAST") and fact_attempts == [false, false], "Even synchronous objective-fact callbacks cannot replace or double-resolve the route"): return
	world.fact_changed.disconnect(on_fact)
	session.load_scenario(original)
	session._state = TelegraphSessionController.State.AWAITING_ROUTE
	var progression := func(_scenario): session.load_scenario(next)
	session.session_completed.connect(progression)
	if not check(session.submit_routing_decision("CLEAR EAST"), "Another ordinary route resolves"): return
	if not check(session.get_current_scenario() == next and session.get_state() == TelegraphSessionController.State.READY, "Legitimate completion can synchronously load next slot after resolution guard clears"): return
	session.queue_free()
	await process_frame
	print("Route authority reentrancy assertions: ", passed)
	quit(0)
