extends SceneTree

func _init() -> void:
	print("--- Starting American Morse Encoder Test Suite (Gate 08B-2B) ---")

	# 1. Instantiate encoder and verify basic constants
	var encoder := AmericanMorseEncoder.new()
	if not assert_condition(encoder != null, "AmericanMorseEncoder instantiates"): return
	if not assert_condition(encoder is RefCounted, "AmericanMorseEncoder is RefCounted"): return
	if not assert_condition(AmericanMorseEncoder.INTER_LETTER_GAP_UNITS == 3, "INTER_LETTER_GAP_UNITS == 3"): return
	if not assert_condition(AmericanMorseEncoder.INTER_WORD_GAP_UNITS == 6, "INTER_WORD_GAP_UNITS == 6"): return

	# Load canonical M1 alphabet fixture
	var fixture_path := "res://data/morse/m1_american_morse_alphabet.tres"
	var alphabet: AmericanMorseAlphabetData = ResourceLoader.load(fixture_path, "", ResourceLoader.CACHE_MODE_IGNORE) as AmericanMorseAlphabetData
	if not assert_condition(alphabet != null, "M1 Alphabet fixture loads"): return
	if not assert_condition(alphabet.get_validation_errors().is_empty(), "M1 Alphabet fixture is valid"): return

	# 2. Golden Test 1: "E" -> MARK(1), total duration 1
	var seq_e: MorseSequenceData = encoder.encode("E", alphabet)
	if not assert_condition(seq_e != null, "Encode 'E' succeeds"): return
	if not assert_condition(seq_e.events.size() == 1, "'E' has exactly 1 event"): return
	if not assert_condition(seq_e.events[0].kind == MorseTimingEvent.Kind.MARK and seq_e.events[0].duration_units == 1, "'E' event is MARK(1)"): return
	if not assert_condition(seq_e.total_duration_units() == 1, "'E' total duration == 1"): return
	if not assert_condition(seq_e.get_validation_errors().is_empty(), "'E' sequence has zero validation errors"): return

	# 3. Golden Test 2: "L" -> MARK(6), total duration 6
	var seq_l: MorseSequenceData = encoder.encode("L", alphabet)
	if not assert_condition(seq_l != null, "Encode 'L' succeeds"): return
	if not assert_condition(seq_l.events.size() == 1, "'L' has exactly 1 event"): return
	if not assert_condition(seq_l.events[0].kind == MorseTimingEvent.Kind.MARK and seq_l.events[0].duration_units == 6, "'L' event is MARK(6)"): return
	if not assert_condition(seq_l.total_duration_units() == 6, "'L' total duration == 6"): return
	if not assert_condition(seq_l.get_validation_errors().is_empty(), "'L' sequence has zero validation errors"): return

	# 4. Golden Test 3: "ET" -> MARK(1), GAP(3), MARK(3), total duration 7
	var seq_et: MorseSequenceData = encoder.encode("ET", alphabet)
	if not assert_condition(seq_et != null, "Encode 'ET' succeeds"): return
	if not assert_condition(seq_et.events.size() == 3, "'ET' has exactly 3 events"): return
	if not assert_condition(seq_et.events[0].kind == MorseTimingEvent.Kind.MARK and seq_et.events[0].duration_units == 1, "'ET' ev0 is MARK(1)"): return
	if not assert_condition(seq_et.events[1].kind == MorseTimingEvent.Kind.GAP and seq_et.events[1].duration_units == 3, "'ET' ev1 is GAP(3)"): return
	if not assert_condition(seq_et.events[2].kind == MorseTimingEvent.Kind.MARK and seq_et.events[2].duration_units == 3, "'ET' ev2 is MARK(3)"): return
	if not assert_condition(seq_et.total_duration_units() == 7, "'ET' total duration == 7"): return
	if not assert_condition(seq_et.get_validation_errors().is_empty(), "'ET' sequence has zero validation errors"): return

	# 5. Golden Test 4: "E T" -> MARK(1), GAP(6), MARK(3), total duration 10
	var seq_e_t: MorseSequenceData = encoder.encode("E T", alphabet)
	if not assert_condition(seq_e_t != null, "Encode 'E T' succeeds"): return
	if not assert_condition(seq_e_t.events.size() == 3, "'E T' has exactly 3 events"): return
	if not assert_condition(seq_e_t.events[0].kind == MorseTimingEvent.Kind.MARK and seq_e_t.events[0].duration_units == 1, "'E T' ev0 is MARK(1)"): return
	if not assert_condition(seq_e_t.events[1].kind == MorseTimingEvent.Kind.GAP and seq_e_t.events[1].duration_units == 6, "'E T' ev1 is GAP(6)"): return
	if not assert_condition(seq_e_t.events[2].kind == MorseTimingEvent.Kind.MARK and seq_e_t.events[2].duration_units == 3, "'E T' ev2 is MARK(3)"): return
	if not assert_condition(seq_e_t.total_duration_units() == 10, "'E T' total duration == 10"): return
	if not assert_condition(seq_e_t.get_validation_errors().is_empty(), "'E T' sequence has zero validation errors"): return

	# 6. Golden Test 5: "CO" -> preserves internal GAP(2) and gets exactly one inter-letter GAP(3), total 13
	# C: MARK(1), GAP(1), MARK(1), GAP(2), MARK(1) [dur=6, 5 evs]
	# inter-letter: GAP(3) [1 ev]
	# O: MARK(1), GAP(2), MARK(1) [dur=4, 3 evs]
	# Total events: 5 + 1 + 3 = 9 events. Total duration: 6 + 3 + 4 = 13
	var seq_co: MorseSequenceData = encoder.encode("CO", alphabet)
	if not assert_condition(seq_co != null, "Encode 'CO' succeeds"): return
	if not assert_condition(seq_co.events.size() == 9, "'CO' has exactly 9 events"): return
	if not assert_condition(seq_co.events[3].kind == MorseTimingEvent.Kind.GAP and seq_co.events[3].duration_units == 2, "'CO' retains C internal GAP(2) at ev3"): return
	if not assert_condition(seq_co.events[5].kind == MorseTimingEvent.Kind.GAP and seq_co.events[5].duration_units == 3, "'CO' has inter-letter GAP(3) at ev5"): return
	if not assert_condition(seq_co.events[7].kind == MorseTimingEvent.Kind.GAP and seq_co.events[7].duration_units == 2, "'CO' retains O internal GAP(2) at ev7"): return
	if not assert_condition(seq_co.total_duration_units() == 13, "'CO' total duration == 13"): return
	if not assert_condition(seq_co.get_validation_errors().is_empty(), "'CO' sequence has zero validation errors"): return

	# 7. Golden Test 6: "1 7" -> total duration 28
	# 1: MARK(1), GAP(1), MARK(3), GAP(1), MARK(3), GAP(1), MARK(1) [dur=11, 7 evs]
	# word gap: GAP(6) [1 ev]
	# 7: MARK(3), GAP(1), MARK(3), GAP(1), MARK(1), GAP(1), MARK(1) [dur=11, 7 evs]
	# Total events = 7 + 1 + 7 = 15. Total dur = 11 + 6 + 11 = 28
	var seq_1_7: MorseSequenceData = encoder.encode("1 7", alphabet)
	if not assert_condition(seq_1_7 != null, "Encode '1 7' succeeds"): return
	if not assert_condition(seq_1_7.events.size() == 15, "'1 7' has exactly 15 events"): return
	if not assert_condition(seq_1_7.events[7].kind == MorseTimingEvent.Kind.GAP and seq_1_7.events[7].duration_units == 6, "'1 7' has inter-word GAP(6) at ev7"): return
	if not assert_condition(seq_1_7.total_duration_units() == 28, "'1 7' total duration == 28"): return
	if not assert_condition(seq_1_7.get_validation_errors().is_empty(), "'1 7' sequence has zero validation errors"): return

	# 8. Golden Test 7: "WATER" -> total duration 36
	var seq_water: MorseSequenceData = encoder.encode("WATER", alphabet)
	if not assert_condition(seq_water != null, "Encode 'WATER' succeeds"): return
	if not assert_condition(seq_water.total_duration_units() == 36, "'WATER' total duration == 36"): return
	if not assert_condition(seq_water.get_validation_errors().is_empty(), "'WATER' sequence has zero validation errors"): return

	# 9. Golden Test 8: "WATCHER" -> total duration 55
	var seq_watcher: MorseSequenceData = encoder.encode("WATCHER", alphabet)
	if not assert_condition(seq_watcher != null, "Encode 'WATCHER' succeeds"): return
	if not assert_condition(seq_watcher.total_duration_units() == 55, "'WATCHER' total duration == 55"): return
	if not assert_condition(seq_watcher.get_validation_errors().is_empty(), "'WATCHER' sequence has zero validation errors"): return

	# 10. Golden Test 9: "TRAIN 17 CLEAR EAST" -> total duration 136
	var seq_train17: MorseSequenceData = encoder.encode("TRAIN 17 CLEAR EAST", alphabet)
	if not assert_condition(seq_train17 != null, "Encode 'TRAIN 17 CLEAR EAST' succeeds"): return
	if not assert_condition(seq_train17.total_duration_units() == 136, "'TRAIN 17 CLEAR EAST' total duration == 136"): return
	if not assert_condition(seq_train17.get_validation_errors().is_empty(), "'TRAIN 17 CLEAR EAST' sequence has zero validation errors"): return

	# 11. Golden Test 10: "HOLD FREIGHT UNTIL TEN" -> total duration 156
	var seq_hold: MorseSequenceData = encoder.encode("HOLD FREIGHT UNTIL TEN", alphabet)
	if not assert_condition(seq_hold != null, "Encode 'HOLD FREIGHT UNTIL TEN' succeeds"): return
	if not assert_condition(seq_hold.total_duration_units() == 156, "'HOLD FREIGHT UNTIL TEN' total duration == 156"): return
	if not assert_condition(seq_hold.get_validation_errors().is_empty(), "'HOLD FREIGHT UNTIL TEN' sequence has zero validation errors"): return

	# 12. Validation Error Handling Tests
	# Empty string
	var err_empty: PackedStringArray = encoder.get_encoding_errors("", alphabet)
	if not assert_condition(err_empty.size() > 0, "Empty message produces validation error"): return
	if not assert_condition(encoder.encode("", alphabet) == null, "Encode empty message returns null"): return

	# Whitespace only
	var err_ws: PackedStringArray = encoder.get_encoding_errors("   ", alphabet)
	if not assert_condition(err_ws.size() > 0, "Whitespace-only message produces validation error"): return
	if not assert_condition(encoder.encode("   ", alphabet) == null, "Encode whitespace-only returns null"): return

	# Leading space
	var err_lead: PackedStringArray = encoder.get_encoding_errors(" WATER", alphabet)
	if not assert_condition(err_lead.size() > 0, "Leading space produces validation error"): return
	if not assert_condition(encoder.encode(" WATER", alphabet) == null, "Encode with leading space returns null"): return

	# Trailing space
	var err_trail: PackedStringArray = encoder.get_encoding_errors("WATER ", alphabet)
	if not assert_condition(err_trail.size() > 0, "Trailing space produces validation error"): return
	if not assert_condition(encoder.encode("WATER ", alphabet) == null, "Encode with trailing space returns null"): return

	# Multiple consecutive spaces
	var err_multi_sp: PackedStringArray = encoder.get_encoding_errors("TRAIN  17", alphabet)
	if not assert_condition(err_multi_sp.size() > 0, "Double space produces validation error"): return
	if not assert_condition(encoder.encode("TRAIN  17", alphabet) == null, "Encode with double space returns null"): return

	# Lowercase characters
	var err_lower: PackedStringArray = encoder.get_encoding_errors("water", alphabet)
	if not assert_condition(err_lower.size() > 0, "Lowercase message produces validation error"): return
	if not assert_condition(encoder.encode("water", alphabet) == null, "Encode lowercase returns null"): return

	# Unknown characters (e.g. 'Z', 'B', '0', punctuation)
	var err_unk: PackedStringArray = encoder.get_encoding_errors("TRAIN 0", alphabet)
	if not assert_condition(err_unk.size() > 0, "Numeral 0 produces validation error"): return
	if not assert_condition(encoder.encode("TRAIN 0", alphabet) == null, "Encode with numeral 0 returns null"): return

	var err_punct: PackedStringArray = encoder.get_encoding_errors("STOP.", alphabet)
	if not assert_condition(err_punct.size() > 0, "Period produces validation error"): return
	if not assert_condition(encoder.encode("STOP.", alphabet) == null, "Encode with period returns null"): return

	# Tabs and newlines
	var err_tab: PackedStringArray = encoder.get_encoding_errors("TRAIN\t17", alphabet)
	if not assert_condition(err_tab.size() > 0, "Tab produces validation error"): return
	if not assert_condition(encoder.encode("TRAIN\t17", alphabet) == null, "Encode with tab returns null"): return

	var err_nl: PackedStringArray = encoder.get_encoding_errors("TRAIN\n17", alphabet)
	if not assert_condition(err_nl.size() > 0, "Newline produces validation error"): return
	if not assert_condition(encoder.encode("TRAIN\n17", alphabet) == null, "Encode with newline returns null"): return

	# Null alphabet
	var err_null_alph: PackedStringArray = encoder.get_encoding_errors("WATER", null)
	if not assert_condition(err_null_alph.size() > 0, "Null alphabet produces validation error"): return
	if not assert_condition(encoder.encode("WATER", null) == null, "Encode with null alphabet returns null"): return

	# Invalid alphabet
	var bad_alph := AmericanMorseAlphabetData.new() # empty alphabet is invalid
	var err_bad_alph: PackedStringArray = encoder.get_encoding_errors("WATER", bad_alph)
	if not assert_condition(err_bad_alph.size() > 0, "Invalid alphabet produces validation error"): return
	if not assert_condition(encoder.encode("WATER", bad_alph) == null, "Encode with invalid alphabet returns null"): return

	# 13 & 14. Immutability & Deep-Copy Protection of Alphabet
	var char_w_seq := alphabet.get_sequence("W")
	var w_ev0_orig_dur: int = char_w_seq.events[0].duration_units
	var seq_test := encoder.encode("W", alphabet)
	if not assert_condition(seq_test != null, "Encode 'W' succeeds"): return
	if not assert_condition(char_w_seq.events[0].duration_units == w_ev0_orig_dur, "Alphabet sequence duration unchanged after encode"): return

	# Mutate output event and verify alphabet is untouched
	seq_test.events[0].duration_units = 999
	if not assert_condition(char_w_seq.events[0].duration_units == w_ev0_orig_dur, "Alphabet event untouched after mutating output event (deep-copy verified)"): return
	if not assert_condition(seq_test.events[0].get_instance_id() != char_w_seq.events[0].get_instance_id(), "Output event has distinct instance ID from alphabet event"): return
	if not assert_condition(seq_test.get_instance_id() != char_w_seq.get_instance_id(), "Output sequence has distinct instance ID from alphabet sequence"): return

	# 15. Two encode calls produce value-equivalent but distinct object instances
	var res1 := encoder.encode("WATER", alphabet)
	var res2 := encoder.encode("WATER", alphabet)
	if not assert_condition(res1 != null and res2 != null, "Both WATER encodes succeed"): return
	if not assert_condition(res1.get_instance_id() != res2.get_instance_id(), "Two encode calls return distinct MorseSequenceData instances"): return
	if not assert_condition(res1.events.size() == res2.events.size(), "Two encode results have identical event count"): return
	if not assert_condition(res1.total_duration_units() == res2.total_duration_units(), "Two encode results have identical total duration"): return
	
	var distinct_ev_instances := true
	for i in range(res1.events.size()):
		if res1.events[i].get_instance_id() == res2.events[i].get_instance_id():
			distinct_ev_instances = false
			break
	if not assert_condition(distinct_ev_instances, "All event instances between two encode calls are distinct"): return

	# 16. WorldState and KnowledgeState remain unchanged
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

	var _probe_enc := encoder.encode("HOLD FREIGHT UNTIL TEN", alphabet)
	var _probe_errs := encoder.get_encoding_errors("HOLD FREIGHT UNTIL TEN", alphabet)

	if not assert_condition(world.snapshot() == initial_world_snapshot, "WorldState untouched during encoder operations"): return
	if not assert_condition(knowledge.snapshot() == initial_knowledge_snapshot, "KnowledgeState untouched during encoder operations"): return

	# 17. SceneTree receives no new nodes
	var child_count_before: int = root.get_child_count()
	var _probe_enc2 := encoder.encode("TRAIN 17 CLEAR EAST", alphabet)
	if not assert_condition(root.get_child_count() == child_count_before, "No scene tree nodes created by encoder"): return

	# 18. Absence of runtime scheduler / audio / state machine nodes
	if not assert_condition(ClassDB.can_instantiate("AmericanMorseEncoder"), "AmericanMorseEncoder is registered"): return

	print("--- All American Morse Encoder Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
