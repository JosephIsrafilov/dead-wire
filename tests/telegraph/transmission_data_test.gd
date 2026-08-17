extends SceneTree

func _init() -> void:
	print("--- Starting TransmissionData Foundation Test ---")

	# 1. Resource is created
	var trans: TransmissionData = TransmissionData.new()
	if not assert_condition(trans != null, "TransmissionData instantiates"): return
	if not assert_condition(trans is Resource, "TransmissionData is a Resource"): return
	if not assert_condition(trans.get_class() == "Resource", "TransmissionData underlying class is Resource"): return

	# 2. All fields serialize to .tres and load from disk
	var fixture: TransmissionData = load("res://tests/fixtures/transmissions/distinct_layers.tres") as TransmissionData
	if not assert_condition(fixture != null, "Fixture distinct_layers.tres loads successfully"): return
	if not assert_condition(fixture.transmission_id == &"test_distinct_layers", "Fixture transmission_id matches"): return
	if not assert_condition(fixture.true_message == "ALPHA", "Fixture true_message matches"): return
	if not assert_condition(fixture.elias_perception == "BRAVO", "Fixture elias_perception matches"): return
	if not assert_condition(fixture.written_transcript == "CHARLIE", "Fixture written_transcript matches"): return

	# Round-trip serialization verification
	var rt_data := TransmissionData.new()
	rt_data.transmission_id = &"roundtrip_id"
	rt_data.true_message = "RT_TRUE"
	rt_data.elias_perception = "RT_PERCEPTION"
	rt_data.written_transcript = "RT_WRITTEN"
	var save_err := ResourceSaver.save(rt_data, "user://temp_transmission_test.tres")
	if not assert_condition(save_err == OK, "TransmissionData saves to .tres without error"): return
	var rt_loaded: TransmissionData = ResourceLoader.load("user://temp_transmission_test.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as TransmissionData
	if not assert_condition(rt_loaded != null, "Roundtrip saved resource loads successfully"): return
	if not assert_condition(rt_loaded.transmission_id == &"roundtrip_id", "Roundtrip transmission_id matches"): return
	if not assert_condition(rt_loaded.true_message == "RT_TRUE", "Roundtrip true_message matches"): return
	if not assert_condition(rt_loaded.elias_perception == "RT_PERCEPTION", "Roundtrip elias_perception matches"): return
	if not assert_condition(rt_loaded.written_transcript == "RT_WRITTEN", "Roundtrip written_transcript matches"): return

	# 3. Three layers can be read independently
	var distinct := TransmissionData.new()
	distinct.transmission_id = &"layer_isolation_id"
	distinct.true_message = "CANONICAL_MSG"
	distinct.elias_perception = "ELIAS_HEARS"
	distinct.written_transcript = "PAPER_TRANSCRIPT"
	if not assert_condition(distinct.true_message == "CANONICAL_MSG", "true_message reads independently"): return
	if not assert_condition(distinct.elias_perception == "ELIAS_HEARS", "elias_perception reads independently"): return
	if not assert_condition(distinct.written_transcript == "PAPER_TRANSCRIPT", "written_transcript reads independently"): return
	if not assert_condition(distinct.true_message != distinct.elias_perception, "true_message differs from elias_perception"): return
	if not assert_condition(distinct.elias_perception != distinct.written_transcript, "elias_perception differs from written_transcript"): return
	if not assert_condition(distinct.true_message != distinct.written_transcript, "true_message differs from written_transcript"): return

	# 4. Modifying written transcript does not change true message or perception
	distinct.written_transcript = "NEW_WRITTEN_TRANSCRIPT"
	if not assert_condition(distinct.written_transcript == "NEW_WRITTEN_TRANSCRIPT", "written_transcript mutated"): return
	if not assert_condition(distinct.true_message == "CANONICAL_MSG", "true_message untouched after written_transcript mutation"): return
	if not assert_condition(distinct.elias_perception == "ELIAS_HEARS", "elias_perception untouched after written_transcript mutation"): return

	# 5. Modifying perception does not change other layers
	distinct.elias_perception = "NEW_PERCEPTION"
	if not assert_condition(distinct.elias_perception == "NEW_PERCEPTION", "elias_perception mutated"): return
	if not assert_condition(distinct.true_message == "CANONICAL_MSG", "true_message untouched after elias_perception mutation"): return
	if not assert_condition(distinct.written_transcript == "NEW_WRITTEN_TRANSCRIPT", "written_transcript untouched after elias_perception mutation"): return

	# 6. Empty ID returns validation error
	var missing_id := TransmissionData.new()
	missing_id.true_message = "VALID_MSG"
	missing_id.elias_perception = "VALID_PERC"
	missing_id.written_transcript = "VALID_TRANS"
	var id_errors: PackedStringArray = missing_id.get_validation_errors()
	if not assert_condition(id_errors.size() == 1, "Empty transmission_id yields exactly 1 validation error"): return
	if not assert_condition(id_errors[0].contains("transmission_id"), "Error string identifies transmission_id"): return

	# 7. Each empty layer returns a separate error
	var empty_res := TransmissionData.new()
	var all_errors: PackedStringArray = empty_res.get_validation_errors()
	if not assert_condition(all_errors.size() == 4, "Fully empty Resource yields 4 validation errors"): return

	var missing_true := TransmissionData.new()
	missing_true.transmission_id = &"tx_id"
	missing_true.elias_perception = "PERC"
	missing_true.written_transcript = "WRIT"
	var true_errors: PackedStringArray = missing_true.get_validation_errors()
	if not assert_condition(true_errors.size() == 1 and true_errors[0].contains("true_message"), "Missing true_message yields dedicated error"): return

	var missing_perc := TransmissionData.new()
	missing_perc.transmission_id = &"tx_id"
	missing_perc.true_message = "TRUE"
	missing_perc.written_transcript = "WRIT"
	var perc_errors: PackedStringArray = missing_perc.get_validation_errors()
	if not assert_condition(perc_errors.size() == 1 and perc_errors[0].contains("elias_perception"), "Missing elias_perception yields dedicated error"): return

	var missing_writ := TransmissionData.new()
	missing_writ.transmission_id = &"tx_id"
	missing_writ.true_message = "TRUE"
	missing_writ.elias_perception = "PERC"
	var writ_errors: PackedStringArray = missing_writ.get_validation_errors()
	if not assert_condition(writ_errors.size() == 1 and writ_errors[0].contains("written_transcript"), "Missing written_transcript yields dedicated error"): return

	# 8. Fully filled Resource has no validation errors
	var valid_res := TransmissionData.new()
	valid_res.transmission_id = &"tx_complete"
	valid_res.true_message = "COMPLETE_TRUE"
	valid_res.elias_perception = "COMPLETE_PERCEPTION"
	valid_res.written_transcript = "COMPLETE_TRANSCRIPT"
	var valid_errors: PackedStringArray = valid_res.get_validation_errors()
	if not assert_condition(valid_errors.is_empty(), "Fully populated TransmissionData has 0 validation errors"): return

	# Also verify fixture has 0 validation errors
	var fixture_errors: PackedStringArray = fixture.get_validation_errors()
	if not assert_condition(fixture_errors.is_empty(), "Fixture distinct_layers.tres has 0 validation errors"): return

	# 9. Resource does not access WorldState or KnowledgeState
	var world: WorldStateStore = root.get_node_or_null("WorldState") as WorldStateStore
	if world == null:
		world = WorldStateStore.new()
		world.name = "WorldState"
		root.add_child(world)

	var knowledge: KnowledgeStateStore = root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge == null:
		knowledge = KnowledgeStateStore.new()
		knowledge.name = "KnowledgeState"
		root.add_child(knowledge)

	var initial_world_snapshot: Dictionary = world.snapshot()
	var initial_knowledge_snapshot: Dictionary = knowledge.snapshot()

	var isolated_res := TransmissionData.new()
	isolated_res.transmission_id = &"isolated_test"
	isolated_res.true_message = "ISOLATED_TRUE"
	isolated_res.elias_perception = "ISOLATED_PERCEPTION"
	isolated_res.written_transcript = "ISOLATED_TRANSCRIPT"
	var _probe_errs = isolated_res.get_validation_errors()

	if not assert_condition(world.snapshot() == initial_world_snapshot, "WorldState untouched during TransmissionData operations"): return
	if not assert_condition(knowledge.snapshot() == initial_knowledge_snapshot, "KnowledgeState untouched during TransmissionData operations"): return

	# 10. Does not create Morse events, scheduler, or audio nodes
	var child_count_before: int = root.get_child_count()
	var passive_res := TransmissionData.new()
	passive_res.transmission_id = &"passive_test"
	passive_res.true_message = "PASSIVE_TRUE"
	passive_res.elias_perception = "PASSIVE_PERC"
	passive_res.written_transcript = "PASSIVE_TRANS"
	var _passive_errs = passive_res.get_validation_errors()

	if not assert_condition(root.get_child_count() == child_count_before, "No scene nodes or runtime objects added to tree"): return
	if not assert_condition(not ClassDB.class_exists("MorseScheduler"), "No MorseScheduler runtime class exists"): return
	if not assert_condition(not ClassDB.class_exists("SounderController"), "No SounderController runtime class exists"): return
	if not assert_condition(not ClassDB.class_exists("TelegraphStateMachine"), "No TelegraphStateMachine class exists"): return

	print("--- All TransmissionData Foundation Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
