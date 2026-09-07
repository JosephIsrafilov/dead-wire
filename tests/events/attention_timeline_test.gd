extends SceneTree

func _init() -> void:
	print("--- Starting Attention Timeline Hitch-Proof Test Suite (Phase H) ---")

	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	var controller := TelegraphSessionController.new()
	controller.scheduler = scheduler
	root.add_child(scheduler)
	root.add_child(controller)

	var scen2: TelegraphScenarioData = ResourceLoader.load("res://data/scenarios/m1_scenario_2_attention.tres")
	if not assert_condition(scen2 != null, "m1_scenario_2_attention loads"): return
	if not assert_condition(scen2.attention_event_id == "door_footsteps", "scenario has door_footsteps event"): return
	if not assert_condition(scen2.attention_event_start_time == 4.0, "attention_event_start_time is 4.0s"): return

	# 1. Normal frame-by-frame progression
	var events_fired: Array[String] = []
	controller.attention_event_triggered.connect(func(id: String): events_fired.append(id))

	controller.load_scenario(scen2)
	controller.start_transmission()
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.RECEIVING, "Controller is in RECEIVING state"): return

	# Advance to 2.0s -> no event
	scheduler.advance_time(2.0)
	if not assert_condition(events_fired.is_empty(), "No event fired before 4.0s"): return

	# Advance to 4.5s -> event fired
	scheduler.advance_time(2.5)
	if not assert_condition(events_fired.size() == 1 and events_fired[0] == "door_footsteps", "Attention event emitted when crossing 4.0s"): return

	# Advance to completion -> no duplicate event
	scheduler.advance_time(12.0)
	if not assert_condition(events_fired.size() == 1, "Exactly one event emitted during normal transmission"): return
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.VERIFYING, "Transmission completed to VERIFYING"): return
	if not assert_condition(controller.mark_transcript_verified(), "Transcript inspection unlocks routing"): return
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.AWAITING_ROUTE, "Verified transcript reaches AWAITING_ROUTE"): return

	# 2. Giant Hitch Step Test: advance_time(20.0) in a single tick
	events_fired.clear()
	controller.load_scenario(scen2)
	controller.start_transmission()

	# Huge hitch crossing 0.0s -> 20.0s (past attention time 4.0s and total duration 15.6s) in one call
	scheduler.advance_time(20.0)
	if not assert_condition(events_fired.size() == 1 and events_fired[0] == "door_footsteps", "Attention event emitted even with single giant 20s hitch step"): return
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.VERIFYING, "Hitch reaches VERIFYING cleanly"): return
	controller.mark_transcript_verified()
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.AWAITING_ROUTE, "Verified hitch reaches AWAITING_ROUTE"): return

	# 3. Reset clears pending event marker
	controller.reset_session()
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.IDLE, "State is IDLE after reset"): return

	# Clean up
	controller.queue_free()
	scheduler.queue_free()

	print("--- All Attention Timeline Hitch-Proof Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
