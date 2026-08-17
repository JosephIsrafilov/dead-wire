extends SceneTree

func _init() -> void:
	print("--- Starting Morse Playback Profile Test Suite (Gate 09A) ---")

	# 1. Instantiate default resource
	var profile := MorsePlaybackProfileData.new()
	if not assert_condition(profile != null, "MorsePlaybackProfileData instantiates"): return
	if not assert_condition(profile is Resource, "MorsePlaybackProfileData is a Resource"): return
	if not assert_condition((profile as Object) is not Node, "MorsePlaybackProfileData is not a Node"): return

	# 2. Verify default seconds_per_unit == 0.10
	if not assert_condition(is_equal_approx(profile.seconds_per_unit, 0.10), "Default seconds_per_unit is approx 0.10"): return
	if not assert_condition(profile.get_validation_errors().is_empty(), "Default profile has zero validation errors"): return

	# 3. Load M1 fixture .tres
	var fixture_path := "res://data/morse/m1_morse_playback_profile.tres"
	var fixture: MorsePlaybackProfileData = ResourceLoader.load(fixture_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MorsePlaybackProfileData
	if not assert_condition(fixture != null, "Fixture m1_morse_playback_profile.tres loads"): return
	if not assert_condition(fixture is MorsePlaybackProfileData, "Fixture is of type MorsePlaybackProfileData"): return

	# 4. Fixture validation check
	if not assert_condition(is_equal_approx(fixture.seconds_per_unit, 0.10), "Fixture seconds_per_unit is approx 0.10"): return
	if not assert_condition(fixture.get_validation_errors().is_empty(), "Fixture has zero validation errors"): return

	# 5. Roundtrip serialization test
	var temp_save_path := "user://temp_playback_profile_test.tres"
	var save_err := ResourceSaver.save(fixture, temp_save_path)
	if not assert_condition(save_err == OK, "ResourceSaver saves playback profile"): return
	var roundtrip: MorsePlaybackProfileData = ResourceLoader.load(temp_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MorsePlaybackProfileData
	if not assert_condition(roundtrip != null, "Roundtrip playback profile loads"): return
	if not assert_condition(is_equal_approx(roundtrip.seconds_per_unit, 0.10), "Roundtrip seconds_per_unit matches"): return
	if not assert_condition(roundtrip.get_validation_errors().is_empty(), "Roundtrip profile has zero validation errors"): return
	DirAccess.remove_absolute(temp_save_path)

	# 6. Zero value is rejected
	var p_zero := MorsePlaybackProfileData.new()
	p_zero.seconds_per_unit = 0.0
	var err_zero := p_zero.get_validation_errors()
	if not assert_condition(err_zero.size() > 0, "Zero seconds_per_unit produces validation error"): return

	# 7. Negative value is rejected
	var p_neg := MorsePlaybackProfileData.new()
	p_neg.seconds_per_unit = -0.05
	var err_neg := p_neg.get_validation_errors()
	if not assert_condition(err_neg.size() > 0, "Negative seconds_per_unit produces validation error"): return

	# 8. NAN value is rejected
	var p_nan := MorsePlaybackProfileData.new()
	p_nan.seconds_per_unit = NAN
	var err_nan := p_nan.get_validation_errors()
	if not assert_condition(err_nan.size() > 0, "NAN seconds_per_unit produces validation error"): return

	# 9. Positive infinity is rejected
	var p_inf := MorsePlaybackProfileData.new()
	p_inf.seconds_per_unit = INF
	var err_inf := p_inf.get_validation_errors()
	if not assert_condition(err_inf.size() > 0, "Positive infinity produces validation error"): return

	# 10. Negative infinity is rejected
	var p_ninf := MorsePlaybackProfileData.new()
	p_ninf.seconds_per_unit = -INF
	var err_ninf := p_ninf.get_validation_errors()
	if not assert_condition(err_ninf.size() > 0, "Negative infinity produces validation error"): return

	# 11. Validation does not mutate resource
	var p_mut := MorsePlaybackProfileData.new()
	p_mut.seconds_per_unit = 0.25
	var _err_mut := p_mut.get_validation_errors()
	if not assert_condition(is_equal_approx(p_mut.seconds_per_unit, 0.25), "Validation does not modify seconds_per_unit"): return

	# 12. Projected duration calculations
	var spu: float = fixture.seconds_per_unit
	if not assert_condition(is_equal_approx(1.0 * spu, 0.10), "1 unit projected duration == 0.10s"): return
	if not assert_condition(is_equal_approx(3.0 * spu, 0.30), "3 units projected duration == 0.30s"): return
	if not assert_condition(is_equal_approx(6.0 * spu, 0.60), "6 units projected duration == 0.60s"): return
	if not assert_condition(is_equal_approx(36.0 * spu, 3.60), "36 units (WATER) projected duration == 3.60s"): return
	if not assert_condition(is_equal_approx(55.0 * spu, 5.50), "55 units (WATCHER) projected duration == 5.50s"): return
	if not assert_condition(is_equal_approx(136.0 * spu, 13.60), "136 units (TRAIN 17 CLEAR EAST) projected duration == 13.60s"): return
	if not assert_condition(is_equal_approx(156.0 * spu, 15.60), "156 units (HOLD FREIGHT UNTIL TEN) projected duration == 15.60s"): return

	# 13. WorldState and KnowledgeState remain unchanged
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

	var _probe_profile := MorsePlaybackProfileData.new()
	var _probe_errs := _probe_profile.get_validation_errors()

	if not assert_condition(world.snapshot() == initial_world_snapshot, "WorldState untouched during profile operations"): return
	if not assert_condition(knowledge.snapshot() == initial_knowledge_snapshot, "KnowledgeState untouched during profile operations"): return

	# 14. SceneTree child count remains unchanged
	var child_count_before: int = root.get_child_count()
	var _test_p := MorsePlaybackProfileData.new()
	var _test_errs := _test_p.get_validation_errors()
	if not assert_condition(root.get_child_count() == child_count_before, "No scene tree nodes added by profile operations"): return

	print("--- All Morse Playback Profile Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
