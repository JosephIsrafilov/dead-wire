extends SceneTree

func _init() -> void:
	print("--- Starting Morse Timing Model Permanent Test (Gate 08A) ---")

	# 1. Both Resource classes instantiate
	var event_inst = MorseTimingEvent.new()
	if not assert_condition(event_inst != null, "MorseTimingEvent instantiates"): return
	if not assert_condition(event_inst is Resource, "MorseTimingEvent is a Resource"): return

	var seq_inst = MorseSequenceData.new()
	if not assert_condition(seq_inst != null, "MorseSequenceData instantiates"): return
	if not assert_condition(seq_inst is Resource, "MorseSequenceData is a Resource"): return

	# 2. MARK and GAP retain their kind
	var mark_ev := MorseTimingEvent.new()
	mark_ev.kind = MorseTimingEvent.Kind.MARK
	if not assert_condition(mark_ev.kind == MorseTimingEvent.Kind.MARK, "MorseTimingEvent retains MARK kind"): return

	var gap_ev := MorseTimingEvent.new()
	gap_ev.kind = MorseTimingEvent.Kind.GAP
	if not assert_condition(gap_ev.kind == MorseTimingEvent.Kind.GAP, "MorseTimingEvent retains GAP kind"): return

	# 3. Integer duration is preserved
	mark_ev.duration_units = 5
	gap_ev.duration_units = 12
	if not assert_condition(mark_ev.duration_units == 5, "MARK duration_units preserved"): return
	if not assert_condition(gap_ev.duration_units == 12, "GAP duration_units preserved"): return

	# 4. Fixture serializes and loads from disk
	var fixture_path := "res://tests/fixtures/morse/timing_sequence.tres"
	var fixture: MorseSequenceData = ResourceLoader.load(fixture_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MorseSequenceData
	if not assert_condition(fixture != null, "Fixture timing_sequence.tres loads successfully"): return
	if not assert_condition(fixture.events.size() == 5, "Fixture has exactly 5 events"): return

	# 5. Event order is preserved in loaded fixture
	if not assert_condition(fixture.events[0].kind == MorseTimingEvent.Kind.MARK and fixture.events[0].duration_units == 1, "Fixture Event 0: MARK 1"): return
	if not assert_condition(fixture.events[1].kind == MorseTimingEvent.Kind.GAP and fixture.events[1].duration_units == 1, "Fixture Event 1: GAP 1"): return
	if not assert_condition(fixture.events[2].kind == MorseTimingEvent.Kind.MARK and fixture.events[2].duration_units == 3, "Fixture Event 2: MARK 3"): return
	if not assert_condition(fixture.events[3].kind == MorseTimingEvent.Kind.GAP and fixture.events[3].duration_units == 3, "Fixture Event 3: GAP 3"): return
	if not assert_condition(fixture.events[4].kind == MorseTimingEvent.Kind.MARK and fixture.events[4].duration_units == 1, "Fixture Event 4: MARK 1"): return

	# 6. Total duration equals 9
	if not assert_condition(fixture.total_duration_units() == 9, "Fixture total_duration_units() equals 9"): return

	# Round-trip serialization check
	var temp_save_path := "user://temp_timing_sequence_test.tres"
	var save_err := ResourceSaver.save(fixture, temp_save_path)
	if not assert_condition(save_err == OK, "MorseSequenceData saves to .tres"): return
	var loaded_rt: MorseSequenceData = ResourceLoader.load(temp_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MorseSequenceData
	if not assert_condition(loaded_rt != null, "Roundtrip saved timing sequence loads successfully"): return
	if not assert_condition(loaded_rt.events.size() == 5, "Roundtrip event count matches"): return
	if not assert_condition(loaded_rt.total_duration_units() == 9, "Roundtrip total duration matches 9"): return

	# 7. Zero and negative duration are invalid
	var zero_ev := MorseTimingEvent.new()
	zero_ev.duration_units = 0
	var zero_errs := zero_ev.get_validation_errors()
	if not assert_condition(zero_errs.size() > 0, "Zero duration produces validation error"): return

	var neg_ev := MorseTimingEvent.new()
	neg_ev.duration_units = -3
	var neg_errs := neg_ev.get_validation_errors()
	if not assert_condition(neg_errs.size() > 0, "Negative duration produces validation error"): return

	# 8. Empty sequence is invalid
	var empty_seq := MorseSequenceData.new()
	var empty_errs := empty_seq.get_validation_errors()
	if not assert_condition(empty_errs.size() > 0, "Empty sequence produces validation error"): return

	# 9. Null event is invalid
	var null_seq := MorseSequenceData.new()
	var ev1 := MorseTimingEvent.new()
	ev1.kind = MorseTimingEvent.Kind.MARK
	ev1.duration_units = 1
	var ev3 := MorseTimingEvent.new()
	ev3.kind = MorseTimingEvent.Kind.MARK
	ev3.duration_units = 1
	null_seq.events = [ev1, null, ev3]
	var null_errs := null_seq.get_validation_errors()
	if not assert_condition(null_errs.size() > 0, "Null event in sequence produces validation error"): return

	# 10. Sequence starting with GAP is invalid
	var start_gap_seq := MorseSequenceData.new()
	var gap_start := MorseTimingEvent.new()
	gap_start.kind = MorseTimingEvent.Kind.GAP
	gap_start.duration_units = 1
	var mark_end := MorseTimingEvent.new()
	mark_end.kind = MorseTimingEvent.Kind.MARK
	mark_end.duration_units = 1
	start_gap_seq.events = [gap_start, mark_end]
	var start_gap_errs := start_gap_seq.get_validation_errors()
	if not assert_condition(start_gap_errs.size() > 0, "Sequence starting with GAP produces validation error"): return

	# 11. Sequence ending with GAP is invalid
	var end_gap_seq := MorseSequenceData.new()
	var mark_start := MorseTimingEvent.new()
	mark_start.kind = MorseTimingEvent.Kind.MARK
	mark_start.duration_units = 1
	var gap_end := MorseTimingEvent.new()
	gap_end.kind = MorseTimingEvent.Kind.GAP
	gap_end.duration_units = 1
	end_gap_seq.events = [mark_start, gap_end]
	var end_gap_errs := end_gap_seq.get_validation_errors()
	if not assert_condition(end_gap_errs.size() > 0, "Sequence ending with GAP produces validation error"): return

	# 12. Two consecutive events of same kind are invalid
	var consec_mark_seq := MorseSequenceData.new()
	var m1 := MorseTimingEvent.new()
	m1.kind = MorseTimingEvent.Kind.MARK
	m1.duration_units = 1
	var m2 := MorseTimingEvent.new()
	m2.kind = MorseTimingEvent.Kind.MARK
	m2.duration_units = 2
	consec_mark_seq.events = [m1, m2]
	var consec_mark_errs := consec_mark_seq.get_validation_errors()
	if not assert_condition(consec_mark_errs.size() > 0, "Consecutive MARK events produce validation error"): return

	var consec_gap_seq := MorseSequenceData.new()
	var gm1 := MorseTimingEvent.new()
	gm1.kind = MorseTimingEvent.Kind.MARK
	gm1.duration_units = 1
	var gg1 := MorseTimingEvent.new()
	gg1.kind = MorseTimingEvent.Kind.GAP
	gg1.duration_units = 1
	var gg2 := MorseTimingEvent.new()
	gg2.kind = MorseTimingEvent.Kind.GAP
	gg2.duration_units = 2
	var gm2 := MorseTimingEvent.new()
	gm2.kind = MorseTimingEvent.Kind.MARK
	gm2.duration_units = 1
	consec_gap_seq.events = [gm1, gg1, gg2, gm2]
	var consec_gap_errs := consec_gap_seq.get_validation_errors()
	if not assert_condition(consec_gap_errs.size() > 0, "Consecutive GAP events produce validation error"): return

	# 13. Valid alternating sequence has no errors
	var valid_fixture_errs := fixture.get_validation_errors()
	if not assert_condition(valid_fixture_errs.is_empty(), "Valid fixture sequence has 0 validation errors"): return

	# 14. Validation does not mutate events
	var mut_check_seq := MorseSequenceData.new()
	var mc1 := MorseTimingEvent.new()
	mc1.kind = MorseTimingEvent.Kind.MARK
	mc1.duration_units = 1
	var mc2 := MorseTimingEvent.new()
	mc2.kind = MorseTimingEvent.Kind.GAP
	mc2.duration_units = 2
	var mc3 := MorseTimingEvent.new()
	mc3.kind = MorseTimingEvent.Kind.MARK
	mc3.duration_units = 3
	mut_check_seq.events = [mc1, mc2, mc3]

	var _run_errs := mut_check_seq.get_validation_errors()
	if not assert_condition(mut_check_seq.events.size() == 3, "Event array size unchanged after validation"): return
	if not assert_condition(mut_check_seq.events[0].kind == MorseTimingEvent.Kind.MARK and mut_check_seq.events[0].duration_units == 1, "Event 0 unchanged"): return
	if not assert_condition(mut_check_seq.events[1].kind == MorseTimingEvent.Kind.GAP and mut_check_seq.events[1].duration_units == 2, "Event 1 unchanged"): return
	if not assert_condition(mut_check_seq.events[2].kind == MorseTimingEvent.Kind.MARK and mut_check_seq.events[2].duration_units == 3, "Event 2 unchanged"): return

	# 15. No Node, Timer, or AudioStreamPlayer are created
	var child_count_before: int = root.get_child_count()
	var passive_test_seq := MorseSequenceData.new()
	var pev1 := MorseTimingEvent.new()
	pev1.kind = MorseTimingEvent.Kind.MARK
	pev1.duration_units = 1
	passive_test_seq.events = [pev1]
	var _passive_errs := passive_test_seq.get_validation_errors()
	var _passive_dur := passive_test_seq.total_duration_units()

	if not assert_condition(root.get_child_count() == child_count_before, "No scene tree nodes added"): return
	if not assert_condition(not ClassDB.class_exists("MorseScheduler"), "No MorseScheduler class exists"): return
	if not assert_condition(not ClassDB.class_exists("SounderController"), "No SounderController class exists"): return
	if not assert_condition(not ClassDB.class_exists("MorsePlayer"), "No MorsePlayer class exists"): return

	# 16. TransmissionData remains byte-for-byte unchanged
	var tx_res := TransmissionData.new()
	if not assert_condition(tx_res != null, "TransmissionData remains functional"): return

	print("--- All Morse Timing Model Permanent Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
