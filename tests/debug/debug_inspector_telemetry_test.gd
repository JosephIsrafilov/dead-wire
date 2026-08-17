extends SceneTree

func _init() -> void:
	print("--- Starting Debug Inspector Telemetry Test Suite (Gate 19) ---")

	var controller := TelegraphSessionController.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	controller.scheduler = scheduler

	var scen3: TelegraphScenarioData = ResourceLoader.load("res://data/scenarios/m1_scenario_3_core_hook.tres")
	controller.load_scenario(scen3)

	var world_data: Dictionary = {"alpha": true}
	var know_data: Dictionary = {"alpha": true}

	var output_text := DebugInspector.build_session_display_text(world_data, know_data, controller)

	if not assert_condition(output_text.contains("CURRENT TRANSMISSION:\ncore_hook_water_watcher"), "Shows scenario ID"): return
	if not assert_condition(output_text.contains("TRUE SIGNAL:\nWATER"), "Shows TRUE SIGNAL = WATER"): return
	if not assert_condition(output_text.contains("ELIAS PERCEPTION:\nWATER"), "Shows ELIAS PERCEPTION = WATER"): return
	if not assert_condition(output_text.contains("WRITTEN TRANSCRIPT:\nWATCHER"), "Shows WRITTEN TRANSCRIPT = WATCHER"): return
	if not assert_condition(output_text.contains("MORSE STATE:\nREADY (Waiting for Key)"), "Shows MORSE STATE = READY"): return

	controller.queue_free()
	scheduler.queue_free()

	print("--- All Debug Inspector Telemetry Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
