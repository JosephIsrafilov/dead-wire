extends SceneTree

func _init() -> void:
	print("--- Starting Telegraph Session Controller Test Suite (Gate 12) ---")

	# Set up WorldState singleton node on root
	var world: WorldStateStore = root.get_node_or_null("WorldState") as WorldStateStore
	if world == null:
		world = WorldStateStore.new()
		world.name = "WorldState"
		root.add_child(world)

	# Set up components
	var controller := TelegraphSessionController.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	var sounder := SounderController.new()
	var key := TelegraphKey.new()
	var paper := TranscriptPaper.new()

	root.add_child(controller)
	root.add_child(scheduler)
	root.add_child(sounder)
	root.add_child(key)
	root.add_child(paper)

	controller.world_state = world
	controller.scheduler = scheduler
	controller.sounder = sounder
	controller.telegraph_key = key
	controller.transcript_paper = paper
	controller._bind_components()

	# Load scenario fixtures
	var scen1: TelegraphScenarioData = ResourceLoader.load("res://data/scenarios/m1_scenario_1_baseline.tres")
	var scen2: TelegraphScenarioData = ResourceLoader.load("res://data/scenarios/m1_scenario_2_attention.tres")
	var scen3: TelegraphScenarioData = ResourceLoader.load("res://data/scenarios/m1_scenario_3_core_hook.tres")

	# 1. Flow Test: Scenario 1 with Correct Routing
	world.reset_for_new_game()
	controller.load_scenario(scen1)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.READY, "Scenario 1 loaded -> state READY"): return

	# Press key to answer line and start transmission
	key.press()
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.RECEIVING, "Key press transitions to RECEIVING"): return

	# Advance time through 13.60s (TRAIN 17 schedule duration)
	scheduler.advance_time(14.0)

	if not assert_condition(controller.get_state() == TelegraphSessionController.State.AWAITING_ROUTE, "Transmission end transitions to AWAITING_ROUTE"): return
	if not assert_condition(paper.get_transcript_text() == "TRAIN 17 CLEAR EAST", "Paper text set to written_transcript"): return
	if not assert_condition(paper.is_revealed(), "Paper is revealed after transmission"): return

	# Submit correct decision
	var route_ok := controller.submit_routing_decision("CLEAR EAST")
	if not assert_condition(route_ok, "Routing decision submitted"): return
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COMPLETE, "State is COMPLETE after routing"): return
	if not assert_condition(world.has_fact("train_17_routed_clear") and world.get_fact("train_17_routed_clear") == true, "WorldState recorded correct fact"): return
	if not assert_condition(not world.has_fact("train_17_held_in_error"), "Incorrect fact is NOT set"): return

	# 2. Consequence Test: Scenario 1 with Wrong Routing (no reload)
	world.reset_for_new_game()
	controller.load_scenario(scen1)
	key.press()
	scheduler.advance_time(14.0)
	controller.submit_routing_decision("HOLD")
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COMPLETE, "State is COMPLETE after incorrect routing"): return
	if not assert_condition(world.has_fact("train_17_held_in_error") and world.get_fact("train_17_held_in_error") == true, "WorldState recorded incorrect consequence"): return
	if not assert_condition(not world.has_fact("train_17_routed_clear"), "Correct fact is NOT set on mistake"): return

	# 3. Flow Test: Scenario 2 (Attention event at 4.0s)
	world.reset_for_new_game()
	var attention_fired: Array[String] = []
	controller.attention_event_triggered.connect(func(id: String): attention_fired.append(id))

	controller.load_scenario(scen2)
	key.press()
	if not assert_condition(attention_fired.is_empty(), "Attention event not fired before 4.0s"): return

	# Advance 4.5s
	scheduler.advance_time(4.5)
	if not assert_condition(attention_fired.size() == 1 and attention_fired[0] == "door_footsteps", "Attention event 'door_footsteps' triggered at 4.0s"): return

	# Complete transmission (total 15.60s)
	scheduler.advance_time(12.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.AWAITING_ROUTE, "Scenario 2 reaches AWAITING_ROUTE"): return
	controller.submit_routing_decision("HOLD")
	if not assert_condition(world.has_fact("freight_held_correctly") and world.get_fact("freight_held_correctly") == true, "Scenario 2 correct routing recorded"): return

	# 4. Flow Test: Scenario 3 (Core Hook: Sounder WATER, Paper WATCHER)
	world.reset_for_new_game()
	sounder.reset_telemetry()
	controller.load_scenario(scen3)
	key.press()

	# Run transmission (3.60s)
	scheduler.advance_time(4.0)

	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COMPLETE, "Scenario 3 completes without routing"): return
	if not assert_condition(paper.get_transcript_text() == "WATCHER", "Paper displays WATCHER"): return
	if not assert_condition(sounder.down_clicks_played > 0, "Sounder played clicks during transmission"): return
	if not assert_condition(world.has_fact("water_watcher_transmission_received") and world.get_fact("water_watcher_transmission_received") == true, "Scenario 3 completion fact recorded"): return

	# Clean up
	controller.queue_free()
	scheduler.queue_free()
	sounder.queue_free()
	key.queue_free()
	paper.queue_free()

	print("--- All Telegraph Session Controller Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
