extends SceneTree
## Reveal cues follow the letters the wire actually sends, so the hand's pace
## is learnable — and on the hook it visibly hurries past the last heard letter.
##   godot --headless --audio-driver Dummy --path . --script tests/telegraph/transcript_cue_alignment_test.gd

const ALPHABET_PATH := "res://data/morse/m1_american_morse_alphabet.tres"
const PROFILE_PATH := "res://data/morse/m1_morse_playback_profile.tres"
const SCEN1_PATH := "res://data/scenarios/m1_scenario_1_baseline.tres"
const SCEN2_PATH := "res://data/scenarios/m1_scenario_2_attention.tres"
const SCEN3_PATH := "res://data/scenarios/m1_scenario_3_core_hook.tres"
const TOLERANCE := 0.005

var _encoder := AmericanMorseEncoder.new()
var _compiler := MorseScheduleCompiler.new()
var _alphabet: AmericanMorseAlphabetData
var _profile: MorsePlaybackProfileData

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_alphabet = ResourceLoader.load(ALPHABET_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as AmericanMorseAlphabetData
	_profile = ResourceLoader.load(PROFILE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MorsePlaybackProfileData
	if not assert_condition(_alphabet != null and _profile != null, "Alphabet and playback profile load"): return

	# --- 1. Helper contracts on a single-letter message ---
	var e_only := MorseLetterTiming.letter_end_fractions("E", _alphabet)
	if not assert_condition(e_only.size() == 1 and absf(e_only[0] - 1.0) < 0.0001, "Single letter E ends at 1.0"): return

	# --- 2. Helper matches the encoder's own letter boundaries for all three messages ---
	for message in ["TRAIN 17 CLEAR EAST", "FREIGHT 71 EAST", "WATER"]:
		if not assert_condition(_check_message(message), "Letter ends match the encoded schedule for '%s'" % message): return

	# --- 3. Fair scenarios: every cue is the end of its letter, +/- 0.005 ---
	var scen1 := ResourceLoader.load(SCEN1_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TelegraphScenarioData
	var scen2 := ResourceLoader.load(SCEN2_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TelegraphScenarioData
	var scen3 := ResourceLoader.load(SCEN3_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as TelegraphScenarioData
	if not assert_condition(scen1 != null and scen2 != null and scen3 != null, "All three scenario resources load"): return
	if not assert_condition(scen1.transmission_data.written_transcript == scen1.transmission_data.true_message \
			and scen2.transmission_data.written_transcript == scen2.transmission_data.true_message,
			"Scenarios 1 and 2 are fair copies (written equals true)"): return

	if not assert_condition(_cues_match_letter_ends(scen1), "Scenario 1 cues are the letter ends of its message"): return
	if not assert_condition(_cues_match_letter_ends(scen2), "Scenario 2 cues are the letter ends of its message"): return

	# --- 4. The hook: W, A, T on the heard letter ends; C, H, E, R hurried ---
	var water_ends := MorseLetterTiming.letter_end_fractions(scen3.transmission_data.true_message, _alphabet)
	if not assert_condition(water_ends.size() == 5, "WATER has five letter ends"): return
	var cues := scen3.transcript_reveal_cues
	if not assert_condition(cues.size() == 7, "The hook sheet has seven glyphs"): return
	for i in range(3):
		if not assert_condition(absf(cues[i] - water_ends[i]) <= TOLERANCE,
				"Hook cue %d matches the end of heard '%s'" % [i, scen3.transmission_data.true_message[i]]): return

	var t_end := water_ends[2]
	var tail_ok := true
	var tail_steps: PackedFloat32Array = PackedFloat32Array()
	for i in range(3, 7):
		tail_steps.append(cues[i] - cues[i - 1])
		if cues[i] <= t_end or cues[i] > 1.0 + 0.0001:
			tail_ok = false
	if not assert_condition(tail_ok, "Hook tail C-H-E-R starts strictly after the heard T and stays within 1.0"): return
	if not assert_condition(absf(cues[6] - 1.0) <= 0.0001, "The last written glyph is authorized exactly at signal end"): return
	var step_spread := absf(tail_steps[0] - tail_steps[1]) + absf(tail_steps[1] - tail_steps[2]) + absf(tail_steps[2] - tail_steps[3])
	if not assert_condition(step_spread <= 0.002, "Hook tail C-H-E-R is evenly spaced"): return

	# The hand hurries: the tail's mean interval is shorter than fair scenario
	# 1's mean cue interval, in seconds on each message's own clock.
	var water_seconds := _total_seconds(scen3.transmission_data.true_message)
	var hook_mean_seconds := (tail_steps[0] + tail_steps[1] + tail_steps[2] + tail_steps[3]) / 4.0 * water_seconds
	var scen1_seconds := _total_seconds(scen1.transmission_data.true_message)
	var scen1_cues := scen1.transcript_reveal_cues
	var fair_mean_seconds := (scen1_cues[scen1_cues.size() - 1] - scen1_cues[0]) \
			/ float(scen1_cues.size() - 1) * scen1_seconds
	if not assert_condition(hook_mean_seconds < fair_mean_seconds,
			"The hand writes the hook tail faster than a fair copy (%.3fs vs %.3fs per glyph)" % [hook_mean_seconds, fair_mean_seconds]): return

	quit(0)

## Cross-check against the encoder and compiler: one fraction per non-space
## glyph, strictly rising, last exactly 1.0, and every letter end sits on the
## encoded schedule's own clock (total_duration_seconds / seconds_per_unit).
func _check_message(message: String) -> bool:
	var fractions := MorseLetterTiming.letter_end_fractions(message, _alphabet)
	var glyph_count := 0
	for i in range(message.length()):
		if message[i] != " ":
			glyph_count += 1
	if fractions.size() != glyph_count:
		printerr("FAIL: fraction count %d != glyph count %d for '%s'" % [fractions.size(), glyph_count, message])
		return false
	if absf(fractions[fractions.size() - 1] - 1.0) > 0.0001:
		printerr("FAIL: last fraction is not 1.0 for '%s'" % message)
		return false
	for i in range(1, fractions.size()):
		if fractions[i] <= fractions[i - 1]:
			printerr("FAIL: fractions are not strictly rising for '%s'" % message)
			return false

	var schedule := _compile(message)
	if schedule == null:
		printerr("FAIL: message does not compile: '%s'" % message)
		return false
	var spu := _profile.seconds_per_unit
	var total_units := int(round(schedule.total_duration_seconds / spu))
	if absf(schedule.total_duration_seconds - total_units * spu) > 0.0001:
		printerr("FAIL: schedule duration is not a whole unit count for '%s'" % message)
		return false
	var encoder_ends := _encoder_letter_end_units(message)
	if encoder_ends.size() != glyph_count:
		printerr("FAIL: encoder walk found %d letters, expected %d" % [encoder_ends.size(), glyph_count])
		return false
	for i in range(glyph_count):
		var expected := float(encoder_ends[i]) / float(total_units)
		if absf(fractions[i] - expected) > 0.0001:
			printerr("FAIL: letter %d of '%s' ends at %.5f, encoder says %.5f" % [i, message, fractions[i], expected])
			return false
	return true

## Letter ends read straight off the encoded event stream: a gap of 3 or more
## units is the encoder's letter boundary, and the final letter ends on the
## last MARK, which is the message's total unit count.
func _encoder_letter_end_units(message: String) -> PackedInt32Array:
	var ends := PackedInt32Array()
	var sequence := _encoder.encode(message, _alphabet)
	if sequence == null:
		return ends
	var units := 0
	for ev in sequence.events:
		if ev.kind == MorseTimingEvent.Kind.GAP and ev.duration_units >= 3:
			ends.append(units)
		units += ev.duration_units
	ends.append(units)
	return ends

func _compile(message: String) -> MorsePlaybackScheduleData:
	var sequence := _encoder.encode(message, _alphabet)
	if sequence == null:
		return null
	return _compiler.compile(sequence, _profile)

func _total_seconds(message: String) -> float:
	var schedule := _compile(message)
	return schedule.total_duration_seconds if schedule != null else 0.0

## Fair scenario: every cue is its message's letter end within tolerance.
func _cues_match_letter_ends(scenario: TelegraphScenarioData) -> bool:
	var message := scenario.transmission_data.true_message
	var fractions := MorseLetterTiming.letter_end_fractions(message, _alphabet)
	var cues := scenario.transcript_reveal_cues
	if cues.size() != fractions.size():
		printerr("FAIL: '%s' has %d cues for %d letters" % [scenario.scenario_id, cues.size(), fractions.size()])
		return false
	for i in range(cues.size()):
		if absf(cues[i] - fractions[i]) > TOLERANCE:
			printerr("FAIL: '%s' cue %d is %.5f, letter ends at %.5f" % [scenario.scenario_id, i, cues[i], fractions[i]])
			return false
	return true

func assert_condition(condition: bool, description: String) -> bool:
	if condition:
		print("  PASS: %s" % description)
		return true
	printerr("FAIL: %s" % description)
	quit(1)
	return false
