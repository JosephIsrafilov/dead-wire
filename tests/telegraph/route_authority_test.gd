extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var session := TelegraphSessionController.new()
	root.add_child(session)
	var scenario := load("res://data/scenarios/m1_scenario_1_baseline.tres") as TelegraphScenarioData
	session.load_scenario(scenario)
	session._state = TelegraphSessionController.State.AWAITING_ROUTE
	var world := root.get_node("WorldState") as WorldStateStore
	var before := world.snapshot()
	var accepted := session.submit_routing_decision("BANANA")
	if accepted or world.snapshot() != before:
		printerr("  FAIL: Invalid route intent cannot resolve or change objective facts")
		quit(1)
		return
	print("  PASS: Invalid route intent cannot resolve or change objective facts")
	session.queue_free()
	await process_frame
	quit(0)
