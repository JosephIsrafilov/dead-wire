extends SceneTree

func _init() -> void:
	print("--- Starting American Morse Alphabet Data Foundation Test (Gate 08B-2A) ---")

	# 1. Both Resource classes instantiate
	var char_inst = AmericanMorseCharacterData.new()
	if not assert_condition(char_inst != null, "AmericanMorseCharacterData instantiates"): return
	if not assert_condition(char_inst is Resource, "AmericanMorseCharacterData is a Resource"): return

	var alph_inst = AmericanMorseAlphabetData.new()
	if not assert_condition(alph_inst != null, "AmericanMorseAlphabetData instantiates"): return
	if not assert_condition(alph_inst is Resource, "AmericanMorseAlphabetData is a Resource"): return

	# 2. Fixture loads as AmericanMorseAlphabetData
	var fixture_path := "res://data/morse/m1_american_morse_alphabet.tres"
	var fixture: AmericanMorseAlphabetData = ResourceLoader.load(fixture_path, "", ResourceLoader.CACHE_MODE_IGNORE) as AmericanMorseAlphabetData
	if not assert_condition(fixture != null, "Fixture m1_american_morse_alphabet.tres loads successfully"): return
	if not assert_condition(fixture is AmericanMorseAlphabetData, "Fixture is of type AmericanMorseAlphabetData"): return

	# 3. Fixture validation returns zero errors
	var fixture_errors: PackedStringArray = fixture.get_validation_errors()
	if not assert_condition(fixture_errors.is_empty(), "Fixture has zero validation errors"): return

	# 4. Fixture contains exactly 18 entries
	if not assert_condition(fixture.entries.size() == 18, "Fixture contains exactly 18 entries"): return

	# 5. Set of symbols exactly matches the required M1 set
	var expected_symbols: Array[String] = [
		"A", "C", "D", "E", "F", "G", "H", "I", "L", "N", "O", "R", "S", "T", "U", "W", "1", "7"
	]
	var found_symbols: Array[String] = []
	for entry in fixture.entries:
		if entry != null:
			found_symbols.append(entry.symbol)

	if not assert_condition(found_symbols.size() == 18, "Found exactly 18 non-null entry symbols"): return
	for sym in expected_symbols:
		if not assert_condition(found_symbols.has(sym), "Expected symbol '%s' is present in fixture" % sym): return
	for sym in found_symbols:
		if not assert_condition(expected_symbols.has(sym), "Found symbol '%s' belongs to expected M1 set" % sym): return

	# 6. Duplicate symbols are rejected by validation
	var dup_alph := AmericanMorseAlphabetData.new()
	var c1 := AmericanMorseCharacterData.new()
	c1.symbol = "A"
	c1.sequence = _make_test_seq([0, 1])
	var c2 := AmericanMorseCharacterData.new()
	c2.symbol = "A"
	c2.sequence = _make_test_seq([0, 3])
	dup_alph.entries = [c1, c2]
	var dup_errors := dup_alph.get_validation_errors()
	if not assert_condition(dup_errors.size() > 0, "Duplicate symbol produces validation error"): return
	if not assert_condition(dup_errors[0].contains("Duplicate symbol"), "Error message specifies Duplicate symbol"): return

	# 7. Null entry is rejected by validation
	var null_entry_alph := AmericanMorseAlphabetData.new()
	null_entry_alph.entries = [c1, null]
	var null_entry_errors := null_entry_alph.get_validation_errors()
	if not assert_condition(null_entry_errors.size() > 0, "Null entry in alphabet produces validation error"): return

	# 8. Empty alphabet is rejected by validation
	var empty_alph := AmericanMorseAlphabetData.new()
	var empty_alph_errors := empty_alph.get_validation_errors()
	if not assert_condition(empty_alph_errors.size() > 0, "Empty alphabet produces validation error"): return

	# 9. Empty symbol is rejected by validation
	var empty_sym_char := AmericanMorseCharacterData.new()
	empty_sym_char.symbol = ""
	empty_sym_char.sequence = _make_test_seq([0, 1])
	var empty_sym_errors := empty_sym_char.get_validation_errors()
	if not assert_condition(empty_sym_errors.size() > 0, "Empty symbol produces validation error"): return

	# 10. Multi-character symbol is rejected by validation
	var multi_char := AmericanMorseCharacterData.new()
	multi_char.symbol = "AB"
	multi_char.sequence = _make_test_seq([0, 1])
	var multi_errors := multi_char.get_validation_errors()
	if not assert_condition(multi_errors.size() > 0, "Multi-character symbol produces validation error"): return

	# 11. Whitespace symbol is rejected by validation
	var space_char := AmericanMorseCharacterData.new()
	space_char.symbol = " "
	space_char.sequence = _make_test_seq([0, 1])
	var space_errors := space_char.get_validation_errors()
	if not assert_condition(space_errors.size() > 0, "Whitespace symbol produces validation error"): return

	var tab_char := AmericanMorseCharacterData.new()
	tab_char.symbol = "\t"
	tab_char.sequence = _make_test_seq([0, 1])
	var tab_errors := tab_char.get_validation_errors()
	if not assert_condition(tab_errors.size() > 0, "Tab whitespace symbol produces validation error"): return

	# 12. Lowercase symbol is rejected by validation
	var lower_char := AmericanMorseCharacterData.new()
	lower_char.symbol = "a"
	lower_char.sequence = _make_test_seq([0, 1])
	var lower_errors := lower_char.get_validation_errors()
	if not assert_condition(lower_errors.size() > 0, "Lowercase symbol produces validation error"): return

	# 13. Null sequence is rejected by validation
	var null_seq_char := AmericanMorseCharacterData.new()
	null_seq_char.symbol = "A"
	null_seq_char.sequence = null
	var null_seq_errors := null_seq_char.get_validation_errors()
	if not assert_condition(null_seq_errors.size() > 0, "Null sequence produces validation error"): return

	# 14. Invalid child sequence is rejected by validation
	var invalid_seq_char := AmericanMorseCharacterData.new()
	invalid_seq_char.symbol = "A"
	invalid_seq_char.sequence = MorseSequenceData.new() # empty sequence is invalid
	var invalid_seq_errors := invalid_seq_char.get_validation_errors()
	if not assert_condition(invalid_seq_errors.size() > 0, "Invalid child sequence produces validation error"): return

	# 15. All 18 sequences pass MorseSequenceData validation
	for entry in fixture.entries:
		var seq_errs := entry.sequence.get_validation_errors()
		if not assert_condition(seq_errs.is_empty(), "Sequence for '%s' is valid MorseSequenceData" % entry.symbol): return

	# 16. All 18 sequences start and end with MARK
	for entry in fixture.entries:
		var evs: Array[MorseTimingEvent] = entry.sequence.events
		if not assert_condition(evs[0].kind == MorseTimingEvent.Kind.MARK, "Symbol '%s' starts with MARK" % entry.symbol): return
		if not assert_condition(evs[evs.size() - 1].kind == MorseTimingEvent.Kind.MARK, "Symbol '%s' ends with MARK" % entry.symbol): return

	# 17 & 18. Exact sequences of kind/duration and total durations
	var expected_specs: Dictionary = {
		"A": {"events": [[MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 3]], "duration": 5},
		"C": {"events": [[MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 2], [MorseTimingEvent.Kind.MARK, 1]], "duration": 6},
		"D": {"events": [[MorseTimingEvent.Kind.MARK, 3], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1]], "duration": 7},
		"E": {"events": [[MorseTimingEvent.Kind.MARK, 1]], "duration": 1},
		"F": {"events": [[MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 3], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1]], "duration": 7},
		"G": {"events": [[MorseTimingEvent.Kind.MARK, 3], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 3], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1]], "duration": 9},
		"H": {"events": [[MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1]], "duration": 7},
		"I": {"events": [[MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1]], "duration": 3},
		"L": {"events": [[MorseTimingEvent.Kind.MARK, 6]], "duration": 6},
		"N": {"events": [[MorseTimingEvent.Kind.MARK, 3], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1]], "duration": 5},
		"O": {"events": [[MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 2], [MorseTimingEvent.Kind.MARK, 1]], "duration": 4},
		"R": {"events": [[MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 2], [MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1]], "duration": 6},
		"S": {"events": [[MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1]], "duration": 5},
		"T": {"events": [[MorseTimingEvent.Kind.MARK, 3]], "duration": 3},
		"U": {"events": [[MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 3]], "duration": 7},
		"W": {"events": [[MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 3], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 3]], "duration": 9},
		"1": {"events": [[MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 3], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 3], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1]], "duration": 11},
		"7": {"events": [[MorseTimingEvent.Kind.MARK, 3], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 3], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1], [MorseTimingEvent.Kind.GAP, 1], [MorseTimingEvent.Kind.MARK, 1]], "duration": 11}
	}

	for sym in expected_symbols:
		var seq: MorseSequenceData = fixture.get_sequence(sym)
		if not assert_condition(seq != null, "Lookup get_sequence('%s') returns non-null" % sym): return
		var spec: Dictionary = expected_specs[sym]
		var exp_events: Array = spec["events"]
		var exp_dur: int = spec["duration"]
		
		if not assert_condition(seq.events.size() == exp_events.size(), "Symbol '%s' event count == %d" % [sym, exp_events.size()]): return
		if not assert_condition(seq.total_duration_units() == exp_dur, "Symbol '%s' total duration == %d" % [sym, exp_dur]): return
		
		for idx in range(exp_events.size()):
			var ev: MorseTimingEvent = seq.events[idx]
			var exp_kind: MorseTimingEvent.Kind = exp_events[idx][0]
			var exp_units: int = exp_events[idx][1]
			if not assert_condition(ev.kind == exp_kind and ev.duration_units == exp_units, "Symbol '%s' Event %d: kind=%d, dur=%d" % [sym, idx, exp_kind, exp_units]): return

	# 19. Spaced letters C, O, R contain internal GAP(2)
	var seq_c := fixture.get_sequence("C")
	if not assert_condition(seq_c.events[3].kind == MorseTimingEvent.Kind.GAP and seq_c.events[3].duration_units == 2, "C contains internal GAP(2) at event 3"): return

	var seq_o := fixture.get_sequence("O")
	if not assert_condition(seq_o.events[1].kind == MorseTimingEvent.Kind.GAP and seq_o.events[1].duration_units == 2, "O contains internal GAP(2) at event 1"): return

	var seq_r := fixture.get_sequence("R")
	if not assert_condition(seq_r.events[1].kind == MorseTimingEvent.Kind.GAP and seq_r.events[1].duration_units == 2, "R contains internal GAP(2) at event 1"): return

	# 20. L contains exactly MARK(6)
	var seq_l := fixture.get_sequence("L")
	if not assert_condition(seq_l.events.size() == 1 and seq_l.events[0].kind == MorseTimingEvent.Kind.MARK and seq_l.events[0].duration_units == 6, "L is exactly single MARK(6)"): return

	# 21. Numerals 1 and 7 match source audit
	var seq_1 := fixture.get_sequence("1")
	if not assert_condition(seq_1.total_duration_units() == 11, "Numeral 1 total duration is 11"): return
	var seq_7 := fixture.get_sequence("7")
	if not assert_condition(seq_7.total_duration_units() == 11, "Numeral 7 total duration is 11"): return

	# 22. Space is absent from alphabet
	if not assert_condition(not fixture.has_symbol(" "), "Alphabet has_symbol(' ') is false"): return
	if not assert_condition(fixture.get_sequence(" ") == null, "Alphabet get_sequence(' ') is null"): return

	# 23. Numeral 0 is absent from alphabet
	if not assert_condition(not fixture.has_symbol("0"), "Alphabet has_symbol('0') is false"): return
	if not assert_condition(fixture.get_sequence("0") == null, "Alphabet get_sequence('0') is null"): return

	# 24. Unknown lookup returns false/null (exact match, no normalization)
	if not assert_condition(not fixture.has_symbol("Z"), "Alphabet has_symbol('Z') is false"): return
	if not assert_condition(fixture.get_sequence("Z") == null, "Alphabet get_sequence('Z') is null"): return
	if not assert_condition(not fixture.has_symbol("a"), "Alphabet has_symbol('a') is false (case-sensitive)"): return
	if not assert_condition(fixture.get_sequence("a") == null, "Alphabet get_sequence('a') is null (case-sensitive)"): return
	if not assert_condition(not fixture.has_symbol(""), "Alphabet has_symbol('') is false"): return
	if not assert_condition(fixture.get_sequence("") == null, "Alphabet get_sequence('') is null"): return

	# 25. Validation and lookup do not mutate Resource
	var orig_entry_count: int = fixture.entries.size()
	var _probe_has := fixture.has_symbol("A")
	var _probe_seq := fixture.get_sequence("A")
	var _probe_errs := fixture.get_validation_errors()
	if not assert_condition(fixture.entries.size() == orig_entry_count, "Validation and lookup do not modify entry count"): return
	if not assert_condition(fixture.entries[0].symbol == "A", "First entry remains 'A'"): return

	# 26. Different characters do not share mutable event instances
	var seen_event_ids: Dictionary = {}
	var shared_event_found: bool = false
	for entry in fixture.entries:
		for ev in entry.sequence.events:
			var inst_id: int = ev.get_instance_id()
			if seen_event_ids.has(inst_id):
				shared_event_found = true
				break
			seen_event_ids[inst_id] = true
	if not assert_condition(not shared_event_found, "All MorseTimingEvent instances in fixture are distinct (no shared mutable state)"): return

	var seen_seq_ids: Dictionary = {}
	var shared_seq_found: bool = false
	for entry in fixture.entries:
		var seq_id: int = entry.sequence.get_instance_id()
		if seen_seq_ids.has(seq_id):
			shared_seq_found = true
			break
		seen_seq_ids[seq_id] = true
	if not assert_condition(not shared_seq_found, "All MorseSequenceData instances in fixture are distinct"): return

	# 27. WorldState and KnowledgeState are not modified
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

	var test_alph := AmericanMorseAlphabetData.new()
	test_alph.entries = [c1]
	var _test_alph_errs := test_alph.get_validation_errors()
	var _test_alph_has := test_alph.has_symbol("A")
	var _test_alph_seq := test_alph.get_sequence("A")

	if not assert_condition(world.snapshot() == initial_world_snapshot, "WorldState untouched during AmericanMorseAlphabetData operations"): return
	if not assert_condition(knowledge.snapshot() == initial_knowledge_snapshot, "KnowledgeState untouched during AmericanMorseAlphabetData operations"): return

	# 28. SceneTree nodes are not created
	var child_count_before: int = root.get_child_count()
	var passive_alph := AmericanMorseAlphabetData.new()
	passive_alph.entries = [c1]
	var _passive_errs = passive_alph.get_validation_errors()
	if not assert_condition(root.get_child_count() == child_count_before, "No scene tree nodes added by alphabet data operations"): return

	print("--- All American Morse Alphabet Data Tests PASSED ---")
	quit(0)

func _make_test_seq(kind_dur_pairs: Array) -> MorseSequenceData:
	var seq := MorseSequenceData.new()
	var evs: Array[MorseTimingEvent] = []
	for i in range(0, kind_dur_pairs.size(), 2):
		var ev := MorseTimingEvent.new()
		ev.kind = MorseTimingEvent.Kind.MARK if kind_dur_pairs[i] == 0 else MorseTimingEvent.Kind.GAP
		ev.duration_units = kind_dur_pairs[i + 1]
		evs.append(ev)
	seq.events = evs
	return seq

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
