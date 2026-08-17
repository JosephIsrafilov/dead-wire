extends SceneTree

func _init() -> void:
	print("--- Starting Morse Schedule Compiler Test Suite (Gate 09B) ---")

	# 1. Instantiate compiler and verify classes
	var compiler := MorseScheduleCompiler.new()
	if not assert_condition(compiler != null, "MorseScheduleCompiler instantiates"): return
	if not assert_condition(compiler is RefCounted, "MorseScheduleCompiler is RefCounted"): return

	var sched_ev := MorseScheduledEvent.new()
	if not assert_condition(sched_ev != null and sched_ev is RefCounted, "MorseScheduledEvent is RefCounted"): return

	var sched_data := MorsePlaybackScheduleData.new()
	if not assert_condition(sched_data != null and sched_data is RefCounted, "MorsePlaybackScheduleData is RefCounted"): return

	# Load canonical M1 alphabet and profile fixtures
	var alph_path := "res://data/morse/m1_american_morse_alphabet.tres"
	var alphabet: AmericanMorseAlphabetData = ResourceLoader.load(alph_path, "", ResourceLoader.CACHE_MODE_IGNORE) as AmericanMorseAlphabetData
	if not assert_condition(alphabet != null and alphabet.get_validation_errors().is_empty(), "M1 Alphabet fixture loads cleanly"): return

	var prof_path := "res://data/morse/m1_morse_playback_profile.tres"
	var profile: MorsePlaybackProfileData = ResourceLoader.load(prof_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MorsePlaybackProfileData
	if not assert_condition(profile != null and profile.get_validation_errors().is_empty(), "M1 Profile fixture loads cleanly"): return

	var encoder := AmericanMorseEncoder.new()

	# 2. Golden Schedule 1: "ET"
	var seq_et: MorseSequenceData = encoder.encode("ET", alphabet)
	if not assert_condition(seq_et != null, "Encode 'ET' succeeds"): return
	var sched_et: MorsePlaybackScheduleData = compiler.compile(seq_et, profile)
	if not assert_condition(sched_et != null, "Compile 'ET' succeeds"): return
	if not assert_condition(sched_et.get_validation_errors().is_empty(), "'ET' schedule has zero validation errors"): return
	if not assert_condition(sched_et.events.size() == 3, "'ET' schedule has 3 events"): return

	# Check exact timestamps for ET
	var et0 := sched_et.events[0]
	if not assert_condition(et0.kind == MorseTimingEvent.Kind.MARK and is_equal_approx(et0.start_seconds, 0.0) and is_equal_approx(et0.duration_seconds, 0.10) and is_equal_approx(et0.end_seconds, 0.10), "'ET' ev0 is MARK 0.00..0.10"): return

	var et1 := sched_et.events[1]
	if not assert_condition(et1.kind == MorseTimingEvent.Kind.GAP and is_equal_approx(et1.start_seconds, 0.10) and is_equal_approx(et1.duration_seconds, 0.30) and is_equal_approx(et1.end_seconds, 0.40), "'ET' ev1 is GAP 0.10..0.40"): return

	var et2 := sched_et.events[2]
	if not assert_condition(et2.kind == MorseTimingEvent.Kind.MARK and is_equal_approx(et2.start_seconds, 0.40) and is_equal_approx(et2.duration_seconds, 0.30) and is_equal_approx(et2.end_seconds, 0.70), "'ET' ev2 is MARK 0.40..0.70"): return

	if not assert_condition(is_equal_approx(sched_et.total_duration_seconds, 0.70), "'ET' total duration is exactly 0.70s"): return

	# 3. Golden Schedule 2: "E T"
	var seq_e_t: MorseSequenceData = encoder.encode("E T", alphabet)
	var sched_e_t: MorsePlaybackScheduleData = compiler.compile(seq_e_t, profile)
	if not assert_condition(sched_e_t != null and sched_e_t.get_validation_errors().is_empty(), "'E T' schedule compiles cleanly"): return
	if not assert_condition(sched_e_t.events.size() == 3, "'E T' schedule has 3 events"): return

	var e_t0 := sched_e_t.events[0]
	if not assert_condition(e_t0.kind == MorseTimingEvent.Kind.MARK and is_equal_approx(e_t0.start_seconds, 0.0) and is_equal_approx(e_t0.duration_seconds, 0.10) and is_equal_approx(e_t0.end_seconds, 0.10), "'E T' ev0 is MARK 0.00..0.10"): return

	var e_t1 := sched_e_t.events[1]
	if not assert_condition(e_t1.kind == MorseTimingEvent.Kind.GAP and is_equal_approx(e_t1.start_seconds, 0.10) and is_equal_approx(e_t1.duration_seconds, 0.60) and is_equal_approx(e_t1.end_seconds, 0.70), "'E T' ev1 is GAP 0.10..0.70"): return

	var e_t2 := sched_e_t.events[2]
	if not assert_condition(e_t2.kind == MorseTimingEvent.Kind.MARK and is_equal_approx(e_t2.start_seconds, 0.70) and is_equal_approx(e_t2.duration_seconds, 0.30) and is_equal_approx(e_t2.end_seconds, 1.00), "'E T' ev2 is MARK 0.70..1.00"): return

	if not assert_condition(is_equal_approx(sched_e_t.total_duration_seconds, 1.00), "'E T' total duration is exactly 1.00s"): return

	# 4. Golden M1 Messages: WATER, WATCHER, TRAIN 17 CLEAR EAST, HOLD FREIGHT UNTIL TEN
	var seq_water := encoder.encode("WATER", alphabet)
	var sched_water := compiler.compile(seq_water, profile)
	if not assert_condition(sched_water != null and sched_water.get_validation_errors().is_empty(), "WATER schedule valid"): return
	if not assert_condition(is_equal_approx(sched_water.total_duration_seconds, 3.60), "WATER total duration == 3.60s"): return

	var seq_watcher := encoder.encode("WATCHER", alphabet)
	var sched_watcher := compiler.compile(seq_watcher, profile)
	if not assert_condition(sched_watcher != null and sched_watcher.get_validation_errors().is_empty(), "WATCHER schedule valid"): return
	if not assert_condition(is_equal_approx(sched_watcher.total_duration_seconds, 5.50), "WATCHER total duration == 5.50s"): return

	var seq_train := encoder.encode("TRAIN 17 CLEAR EAST", alphabet)
	var sched_train := compiler.compile(seq_train, profile)
	if not assert_condition(sched_train != null and sched_train.get_validation_errors().is_empty(), "TRAIN 17 schedule valid"): return
	if not assert_condition(is_equal_approx(sched_train.total_duration_seconds, 13.60), "TRAIN 17 total duration == 13.60s"): return

	var seq_hold := encoder.encode("HOLD FREIGHT UNTIL TEN", alphabet)
	var sched_hold := compiler.compile(seq_hold, profile)
	if not assert_condition(sched_hold != null and sched_hold.get_validation_errors().is_empty(), "HOLD FREIGHT schedule valid"): return
	if not assert_condition(is_equal_approx(sched_hold.total_duration_seconds, 15.60), "HOLD FREIGHT total duration == 15.60s"): return

	# 5. Validation error handling
	var err_null_seq := compiler.get_compilation_errors(null, profile)
	if not assert_condition(err_null_seq.size() > 0 and compiler.compile(null, profile) == null, "Null sequence rejected"): return

	var err_null_prof := compiler.get_compilation_errors(seq_water, null)
	if not assert_condition(err_null_prof.size() > 0 and compiler.compile(seq_water, null) == null, "Null profile rejected"): return

	var bad_seq := MorseSequenceData.new()
	var err_bad_seq := compiler.get_compilation_errors(bad_seq, profile)
	if not assert_condition(err_bad_seq.size() > 0 and compiler.compile(bad_seq, profile) == null, "Empty/invalid sequence rejected"): return

	var bad_prof := MorsePlaybackProfileData.new()
	bad_prof.seconds_per_unit = -0.10
	var err_bad_prof := compiler.get_compilation_errors(seq_water, bad_prof)
	if not assert_condition(err_bad_prof.size() > 0 and compiler.compile(seq_water, bad_prof) == null, "Invalid profile rejected"): return

	# 6. Data isolation and independent instances
	var res1 := compiler.compile(seq_water, profile)
	var res2 := compiler.compile(seq_water, profile)
	if not assert_condition(res1.get_instance_id() != res2.get_instance_id(), "Two compile calls yield distinct schedule instances"): return
	if not assert_condition(res1.events[0].get_instance_id() != res2.events[0].get_instance_id(), "Two compile calls yield distinct event instances"): return

	# Mutate res1 event and verify res2 and source sequence are unaffected
	var orig_dur := res2.events[0].duration_seconds
	res1.events[0].duration_seconds = 999.0
	if not assert_condition(is_equal_approx(res2.events[0].duration_seconds, orig_dur), "Mutating one schedule does not affect another"): return
	if not assert_condition(seq_water.events[0].duration_units == 1, "Source sequence untouched by schedule mutation"): return

	# 7. WorldState and KnowledgeState remain unchanged
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

	var _probe_sched := compiler.compile(seq_train, profile)

	if not assert_condition(world.snapshot() == initial_world_snapshot, "WorldState untouched during compiler operations"): return
	if not assert_condition(knowledge.snapshot() == initial_knowledge_snapshot, "KnowledgeState untouched during compiler operations"): return

	# 8. SceneTree child count unchanged
	var child_count_before: int = root.get_child_count()
	var _probe_sched2 := compiler.compile(seq_hold, profile)
	if not assert_condition(root.get_child_count() == child_count_before, "No scene tree nodes created by compiler"): return

	print("--- All Morse Schedule Compiler Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
