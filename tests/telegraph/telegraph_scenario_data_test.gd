extends SceneTree

func _init() -> void:
	print("--- Starting Telegraph Scenario Data Test Suite ---")

	# 1. Test validation error handling
	var empty_scen := TelegraphScenarioData.new()
	if not assert_condition(empty_scen.get_validation_errors().size() > 0, "Empty scenario has validation errors"): return
	var malformed_commit := TelegraphScenarioData.new()
	malformed_commit.scenario_id = "malformed_commit"
	var malformed_transmission := TransmissionData.new()
	malformed_transmission.transmission_id = &"malformed"
	malformed_transmission.true_message = "A"
	malformed_transmission.elias_perception = "A"
	malformed_transmission.written_transcript = "A"
	malformed_commit.transmission_data = malformed_transmission
	var malformed_option := TelegraphCommitOption.new()
	malformed_option.action_id = &"only_option"
	malformed_option.display_label = "ONLY"
	malformed_option.world_fact = "only_fact"
	malformed_option.knowledge_fact = "only_knowledge"
	malformed_option.result_text = "ONLY"
	malformed_commit.commit_options = [malformed_option]
	if not assert_condition(str(malformed_commit.get_validation_errors()).contains("at least two options"), "Single commit option is rejected by validation"): return

	# 2. Load Scenario 1 fixture
	var scen1_path := "res://data/scenarios/m1_scenario_1_baseline.tres"
	var scen1: TelegraphScenarioData = ResourceLoader.load(scen1_path, "", ResourceLoader.CACHE_MODE_IGNORE) as TelegraphScenarioData
	if not assert_condition(scen1 != null, "Scenario 1 loads"): return
	if not assert_condition(scen1.get_validation_errors().is_empty(), "Scenario 1 is valid"): return
	if not assert_condition(scen1.scenario_id == "baseline_train_17", "Scenario 1 id matches"): return
	if not assert_condition(scen1.transmission_data.true_message == "TRAIN 17 CLEAR EAST", "Scenario 1 true_message matches"): return
	if not assert_condition(scen1.expected_routing_action == "CLEAR EAST", "Scenario 1 expected routing matches"): return
	if not assert_condition(scen1.requires_transcript_verification, "Scenario 1 requires transcript verification"): return
	if not assert_condition(scen1.transcript_reveal_cues.size() == 16, "Scenario 1 has authored glyph cues"): return

	# 3. Load Scenario 2 fixture
	var scen2_path := "res://data/scenarios/m1_scenario_2_attention.tres"
	var scen2: TelegraphScenarioData = ResourceLoader.load(scen2_path, "", ResourceLoader.CACHE_MODE_IGNORE) as TelegraphScenarioData
	if not assert_condition(scen2 != null, "Scenario 2 loads"): return
	if not assert_condition(scen2.get_validation_errors().is_empty(), "Scenario 2 is valid"): return
	if not assert_condition(scen2.scenario_id == "attention_hold_freight", "Scenario 2 id matches"): return
	if not assert_condition(scen2.transmission_data.true_message == "HOLD FREIGHT UNTIL TEN", "Scenario 2 true_message matches"): return
	if not assert_condition(scen2.attention_event_id == "door_footsteps", "Scenario 2 attention event matches"): return
	if not assert_condition(is_equal_approx(scen2.attention_event_start_time, 4.0), "Scenario 2 start time is 4.0s"): return
	if not assert_condition(scen2.requires_transcript_verification, "Scenario 2 requires transcript verification"): return
	if not assert_condition(scen2.transcript_reveal_cues.size() == 19, "Scenario 2 has authored glyph cues"): return

	# 4. Load Scenario 3 fixture
	var scen3_path := "res://data/scenarios/m1_scenario_3_core_hook.tres"
	var scen3: TelegraphScenarioData = ResourceLoader.load(scen3_path, "", ResourceLoader.CACHE_MODE_IGNORE) as TelegraphScenarioData
	if not assert_condition(scen3 != null, "Scenario 3 loads"): return
	if not assert_condition(scen3.get_validation_errors().is_empty(), "Scenario 3 is valid"): return
	if not assert_condition(scen3.scenario_id == "core_hook_water_watcher", "Scenario 3 id matches"): return
	if not assert_condition(scen3.transmission_data.true_message == "WATER", "Scenario 3 true_message is WATER"): return
	if not assert_condition(scen3.transmission_data.written_transcript == "WATCHER", "Scenario 3 written_transcript is WATCHER"): return
	if not assert_condition(scen3.requires_transcript_verification, "Scenario 3 requires transcript verification"): return
	if not assert_condition(scen3.commit_options.size() == 2, "Scenario 3 exposes two commit options"): return
	if not assert_condition(scen3.commit_options[0].display_label == "CORRECT COPY\nWATER", "Scenario 3 water label is concrete"): return
	if not assert_condition(scen3.commit_options[1].display_label == "FILE COPY\nWATCHER", "Scenario 3 watcher label is concrete"): return
	if not assert_condition(scen3.consequence_event_id == "window_figure", "Scenario 3 consequence event is authored"): return

	print("--- All Telegraph Scenario Data Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
