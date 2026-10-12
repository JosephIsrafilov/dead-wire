extends SceneTree

## Actual-only tape evidence; the planned wire schedule is never a public ink value.
## godot --headless --audio-driver Dummy --path . --script tests/telegraph/tape_evidence_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Tape Evidence Test Suite ---")
	var tape := TapeRegisterController.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	root.add_child(tape)
	root.add_child(scheduler)
	tape.connect_scheduler(scheduler)
	var schedule := _schedule([1])
	if not _a(scheduler.start(schedule), "Real scheduler starts the evidence fixture"): return
	var record := tape.get_record()
	if not _a(record.size() == 1 and is_zero_approx(record[0].duration_units),
		"Started MARK exposes zero delivered units, not its future dot length"): return
	if not _a(is_zero_approx(record[0].duration_seconds), "Started MARK exposes zero delivered seconds"): return
	var ink = record[0]
	if not _a(ink.get_script().get_global_name() == "TapeInkEvent", "Public record uses the tape-ink value type"): return
	if not _a(not ink.is_complete and not ink.interrupted, "Started ink is incomplete and not interrupted"): return
	var names: Array[String] = []
	for property in ink.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(property.name)
	names.sort()
	if not _a(names == ["duration_seconds", "duration_units", "interrupted", "is_complete", "kind"],
		"Public ink has only observed fields, with no planned units, index, end or source metadata"): return
	var copy = ink.snapshot()
	if not _a(copy != ink and copy.kind == ink.kind and is_zero_approx(copy.duration_seconds),
		"snapshot creates an independent value with identical observed fields"): return
	ink.kind = MorseTimingEvent.Kind.GAP
	ink.duration_units = 99.0
	ink.duration_seconds = 99.0
	ink.is_complete = true
	ink.interrupted = true
	record.clear()
	var fresh := tape.get_record()
	if not _a(fresh.size() == 1 and fresh[0].kind == MorseTimingEvent.Kind.MARK
		and is_zero_approx(fresh[0].duration_units) and is_zero_approx(fresh[0].duration_seconds)
		and not fresh[0].is_complete and not fresh[0].interrupted,
		"Mutating every returned field and array leaves the register unchanged"): return
	if not _a(schedule.events[0].kind == MorseTimingEvent.Kind.MARK
		and schedule.events[0].duration_units == 1 and is_equal_approx(schedule.events[0].duration_seconds, 0.1),
		"Returned ink never aliases the scheduler's source event"): return
	var advance_observed: Array[float] = []
	var observe_advance := func(_previous, _current):
		advance_observed.append(tape.get_record()[0].duration_seconds)
	scheduler.playback_time_advanced.connect(observe_advance)
	scheduler.advance_time(0.05)
	fresh = tape.get_record()
	if not _a(is_equal_approx(fresh[0].duration_seconds, 0.05)
		and is_equal_approx(fresh[0].duration_units, 0.5), "Half a dot records only 0.05 seconds and 0.5 units"): return
	if not _a(advance_observed == [0.05], "Advance observers see current ink before event callbacks"): return
	if not _a(not fresh[0].is_complete and not fresh[0].interrupted, "Advanced ink remains incomplete until finish"): return
	var started_copy = copy
	if not _a(started_copy.kind == MorseTimingEvent.Kind.MARK and is_zero_approx(started_copy.duration_units)
		and is_zero_approx(started_copy.duration_seconds) and not started_copy.is_complete and not started_copy.interrupted,
		"Earlier snapshots never gain later time or returned-value mutations"): return
	scheduler.cancel()
	fresh = tape.get_record()
	if not _a(fresh.size() == 1 and is_equal_approx(fresh[0].duration_seconds, 0.05)
		and is_equal_approx(fresh[0].duration_units, 0.5), "Cancel keeps the exact fractional ink and invents no GAP"): return
	if not _a(not fresh[0].is_complete and fresh[0].interrupted, "Cancelled MARK is interrupted, not a valid complete dot"): return
	if not _a(schedule.events[0].duration_units == 1
		and is_equal_approx(schedule.events[0].duration_seconds, 0.1), "Fractional cancellation leaves the source intact"): return
	scheduler.advance_time(10.0)
	if not _a(is_equal_approx(tape.get_record()[0].duration_seconds, 0.05), "Cancelled/idle time never grows ink"): return
	scheduler.playback_time_advanced.disconnect(observe_advance)
	tape.reset()
	var finished_observed: Array[float] = []
	scheduler.timing_event_finished.connect(func(_event):
		finished_observed.append(tape.get_record()[0].duration_seconds))
	if not _a(scheduler.start(schedule), "A completed fixture starts after cancellation"): return
	scheduler.advance_time(1.0)
	fresh = tape.get_record()
	if not _a(fresh.size() == 1, "Completion records one real event with no phantom 12-unit GAP"): return
	if not _a(fresh[0].is_complete and not fresh[0].interrupted
		and is_equal_approx(fresh[0].duration_seconds, 0.1)
		and is_equal_approx(fresh[0].duration_units, 1.0), "Finished ink has the exact delivered full duration"): return
	if not _a(finished_observed == [0.1], "Finished callbacks see finalized ink, not the hitch's extra elapsed time"): return
	var complete_copy = fresh[0].snapshot()
	fresh[0].duration_seconds = -1.0
	scheduler.advance_time(20.0)
	if not _a(is_equal_approx(tape.get_record()[0].duration_seconds, 0.1)
		and complete_copy.is_complete and not complete_copy.interrupted
		and is_equal_approx(complete_copy.duration_units, 1.0), "Completed snapshots remain immutable through idle and mutation"): return
	if not _a(scheduler.timing_event_finished.is_connected(tape._on_timing_event_finished)
		and scheduler.playback_time_advanced.is_connected(tape._on_playback_time_advanced),
		"Register binds finish and actual-time advance signals"): return
	tape.disconnect_scheduler()
	if not _a(not scheduler.timing_event_finished.is_connected(tape._on_timing_event_finished)
		and not scheduler.playback_time_advanced.is_connected(tape._on_playback_time_advanced),
		"Disconnect removes finish and actual-time advance signals"): return
	tape.free()
	scheduler.free()
	if not _test_mark_rendering(): return
	if not _test_take_boundaries(): return
	if not await _test_callback_elapsed_and_pause(): return
	if not _test_current_call_answer_path(): return
	if not _test_american_internal_pauses(): return
	if not _test_cancel_elapsed_authority(): return
	print("--- All Tape Evidence Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _test_mark_rendering() -> bool:
	var tape := TapeRegisterController.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	tape.connect_scheduler(scheduler)
	var long_mark := _schedule([6])
	if not _a(scheduler.start(long_mark), "Long American Morse MARK starts"): return false
	if not _a(tape.get_tape_text() == "?", "An unfinished MARK uses the incomplete-ink symbol, not a dot or dash"): return false
	scheduler.advance_time(0.3)
	if not _a(tape.get_tape_text() == "?", "Three delivered units of a live long MARK do not reveal L or classify a dash"): return false
	scheduler.cancel()
	if not _a(tape.get_tape_text() == "?" and tape.get_record()[0].interrupted,
		"Interrupted MARK keeps the incomplete symbol even at an intermediate Morse threshold"): return false
	if not _a(is_equal_approx(tape.get_record()[0].duration_units, 3.0)
		and is_equal_approx(tape.get_record()[0].duration_seconds, 0.3),
		"The incomplete symbol retains exact actual duration through the record API"): return false
	tape.reset()
	var lengths := _schedule([1, 2, 3, 3, 6])
	if not _a(scheduler.start(lengths), "Mixed completed MARK lengths start"): return false
	scheduler.advance_time(10.0)
	if not _a(tape.get_tape_text() == "·  —   ———", "Completed MARK 1/3/6 agree with the reference card and preserve GAP columns"): return false
	if not _a(tape.get_record().size() == 5, "Rendering long marks adds no artificial ink events"): return false
	tape.reset()
	if not _a(scheduler.start(_schedule([1, 3, 1])), "Partial GAP fixture starts"): return false
	scheduler.advance_time(0.15)
	if not _a(is_equal_approx(tape.get_record()[1].duration_units, 0.5)
		and tape.get_tape_text() == "·", "A fractional GAP exposes actual units without a future blank column"): return false
	scheduler.cancel()
	if not _a(tape.get_record()[1].interrupted and tape.get_tape_text() == "·",
		"Cancelled fractional GAP never renders its remaining planned silence"): return false
	tape.reset()
	if not _a(scheduler.start(_schedule([2])), "Two-unit completed fixture starts"): return false
	scheduler.advance_time(0.2)
	if not _a(tape.get_tape_text() == "·", "Existing completed two-unit MARK remains dot-compatible"): return false
	tape.disconnect_scheduler()
	tape.free()
	scheduler.free()
	return true

func _test_take_boundaries() -> bool:
	var tape := TapeRegisterController.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	tape.connect_scheduler(scheduler)
	if not _a(tape.has_method("get_segment_snapshots") and tape.has_method("get_tape_display_text"),
		"Tape exposes readable wire-take metadata separately from raw ink"): return false
	if not _a(tape.get_segment_snapshots().is_empty() and tape.get_tape_display_text().is_empty(),
		"A blank register invents no take or boundary"): return false
	var start_snapshots: Array = []
	var observe_start := func(_schedule):
		start_snapshots.append(tape.get_segment_snapshots())
	scheduler.playback_started.connect(observe_start)
	if not _a(scheduler.start(_schedule([6])), "First wire take starts"): return false
	var opening: Array = start_snapshots[0]
	if not _a(opening.size() == 1 and opening[0].number == 1 and opening[0].events.is_empty()
		and not opening[0].complete and not opening[0].interrupted,
		"Playback start creates take metadata before its first MARK without future events"): return false
	var segments: Array = tape.get_segment_snapshots()
	var keys: Array = segments[0].keys()
	keys.sort()
	if not _a(keys == ["complete", "events", "interrupted", "number"],
		"Take metadata contains only a number, completion/interruption and actual ink"): return false
	scheduler.advance_time(0.05)
	scheduler.cancel()
	segments = tape.get_segment_snapshots()
	if not _a(segments.size() == 1 and segments[0].interrupted and not segments[0].complete
		and segments[0].events.size() == 1 and is_equal_approx(segments[0].events[0].duration_units, 0.5),
		"Cancelled take retains only its actual fractional interrupted ink"): return false
	var first_take_copy: Dictionary = segments[0]
	var cancelled_display: String = tape.get_tape_display_text()
	if not _a(cancelled_display == "[WIRE TAKE 1 | INTERRUPTED | NON-INK BOUNDARY]\n?",
		"Readable take header clearly distinguishes interruption and non-ink boundary"): return false
	scheduler.advance_time(999.0)
	if not _a(tape.get_tape_display_text() == cancelled_display and tape.get_record().size() == 1,
		"Real inter-take idle adds neither elapsed ink nor a synthetic GAP"): return false
	if not _a(scheduler.start(_schedule([3])), "Second wire take starts"): return false
	scheduler.advance_time(0.3)
	segments = tape.get_segment_snapshots()
	if not _a(segments.size() == 2 and segments[0].number == 1 and segments[1].number == 2
		and segments[1].complete and not segments[1].interrupted,
		"Wire takes retain numbered oldest-to-newest chronology and independent status"): return false
	if not _a(tape.get_record().size() == 2 and tape.get_tape_text() == "?\n—",
		"Raw strip uses a non-ink newline between takes, never fake timed silence"): return false
	if not _a(tape.get_tape_display_text() == cancelled_display
		+ "\n[WIRE TAKE 2 | COMPLETE | NON-INK BOUNDARY]\n—",
		"Display puts newest ink last with no telegram identity or automatic decoding"): return false
	if not _a(first_take_copy.interrupted and first_take_copy.events.size() == 1
		and is_equal_approx(first_take_copy.events[0].duration_seconds, 0.05),
		"Historical segment snapshots do not change when a later take completes"): return false
	segments[0].number = 77
	segments[0].complete = true
	segments[0].interrupted = false
	segments[0].events[0].duration_units = 99.0
	segments[0].events.clear()
	segments.clear()
	segments = tape.get_segment_snapshots()
	if not _a(segments.size() == 2 and segments[0].number == 1 and not segments[0].complete
		and segments[0].interrupted and segments[0].events.size() == 1
		and is_equal_approx(segments[0].events[0].duration_units, 0.5),
		"Returned segment dictionaries, arrays and ink values are all independent clones"): return false
	var inspected: Array[String] = []
	tape.tape_inspected.connect(func(text): inspected.append(text))
	tape._on_interacted()
	if not _a(inspected == [tape.get_tape_display_text()], "Inspection emits the readable numbered take presentation"): return false
	if not _a(scheduler.playback_started.is_connected(tape._on_playback_started),
		"Scheduler start signal is connected exactly once"): return false
	tape.reset()
	if not _a(tape.get_record().is_empty() and tape.get_segment_snapshots().is_empty()
		and tape.get_tape_display_text().is_empty(), "Reset clears all take metadata and physical ink"): return false
	if not _a(scheduler.start(_schedule([1])), "First take starts again after reset"): return false
	if not _a(tape.get_segment_snapshots()[0].number == 1, "Reset restarts take numbering without changing subscription"): return false
	scheduler.cancel()
	tape.disconnect_scheduler()
	if not _a(not scheduler.playback_started.is_connected(tape._on_playback_started), "Disconnect removes take-start signal"): return false
	tape.free()
	scheduler.free()
	return true

func _test_callback_elapsed_and_pause() -> bool:
	var tape := TapeRegisterController.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	root.add_child(tape)
	root.add_child(scheduler)
	tape.connect_scheduler(scheduler)
	var started_units: Array[float] = []
	var observe_start := func(_event):
		var record := tape.get_record()
		started_units.append(record[-1].duration_units)
	scheduler.timing_event_started.connect(observe_start)
	if not _a(scheduler.start(_schedule([1, 2, 6])), "Hitch fixture starts on the real scheduler"): return false
	scheduler.advance_time(0.35)
	var record := tape.get_record()
	if not _a(record.size() == 3 and record[0].is_complete and record[1].is_complete
		and is_equal_approx(record[0].duration_seconds, 0.1)
		and is_equal_approx(record[1].duration_seconds, 0.2), "A hitch records completed earlier events exactly once"): return false
	if not _a(is_equal_approx(record[2].duration_seconds, 0.05)
		and is_equal_approx(record[2].duration_units, 0.5) and not record[2].is_complete,
		"Hitch-started live MARK subtracts its start and exposes only actual elapsed time"): return false
	if not _a(started_units.size() == 3 and is_zero_approx(started_units[0])
		and is_equal_approx(started_units[1], 2.0) and is_equal_approx(started_units[2], 0.5),
		"Timing-start observers see delivered duration after the advance-before-callback ordering"): return false
	var paused_record := tape.get_record()
	paused = true
	scheduler.auto_process = true
	await process_frame
	await process_frame
	scheduler.auto_process = false
	paused = false
	if not _a(is_equal_approx(tape.get_record()[2].duration_seconds, paused_record[2].duration_seconds),
		"Paused scene frames never advance the physical record"): return false
	if not _a(tape.get_tape_text() == "·  ?", "Hitch/pause reveals no future long-MARK classification"): return false
	scheduler.cancel()
	scheduler.timing_event_started.disconnect(observe_start)
	tape.reset()
	var alternate_profile := _schedule([3])
	alternate_profile.events[0].duration_seconds = 0.6
	alternate_profile.events[0].end_seconds = 0.6
	alternate_profile.total_duration_seconds = 0.6
	if not _a(scheduler.start(alternate_profile), "Alternate actual seconds-per-unit fixture starts"): return false
	scheduler.advance_time(0.1)
	scheduler.cancel()
	if not _a(is_equal_approx(tape.get_record()[0].duration_seconds, 0.1)
		and is_equal_approx(tape.get_record()[0].duration_units, 0.5),
		"Fractional actual units use the private event profile, not a hardcoded speed"): return false
	tape.disconnect_scheduler()
	tape.free()
	scheduler.free()
	return true

func _test_current_call_answer_path() -> bool:
	var tape := TapeRegisterController.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	var session := TelegraphSessionController.new()
	session.scheduler = scheduler
	session.tape_register = tape
	session.set_process(false)
	var director := ShiftDirector.new()
	director.session = session
	director.set_process(false)
	root.add_child(scheduler)
	root.add_child(tape)
	root.add_child(session)
	root.add_child(director)
	if not _a(session.load_scenario(load("res://data/scenarios/m1_scenario_1_baseline.tres")),
		"Current session loads the baseline telegram independently of its call"): return false
	director._begin_call_cycle()
	if not _a(director.get_phase() == ShiftDirector.Phase.CALLING
		and scheduler.is_playing() and tape.get_segment_snapshots().size() == 1,
		"Current ShiftDirector call uses the shared scheduler and creates wire take one"): return false
	scheduler.advance_time(0.05)
	director._answer_call()
	var segments := tape.get_segment_snapshots()
	if not _a(director.get_phase() == ShiftDirector.Phase.ANSWERING and not scheduler.is_playing()
		and segments[0].interrupted and segments[0].events.size() == 1
		and is_equal_approx(segments[0].events[0].duration_seconds, 0.05),
		"Answering the actual call truncates its MARK and closes the interrupted take"): return false
	var before_beat := tape.get_tape_display_text()
	director.advance(director.answer_beat_seconds * 0.5)
	scheduler.advance_time(director.answer_beat_seconds * 0.5)
	if not _a(tape.get_tape_display_text() == before_beat and tape.get_record().size() == 1,
		"The real answer beat is not fabricated as measured tape silence"): return false
	director.advance(director.answer_beat_seconds)
	segments = tape.get_segment_snapshots()
	if not _a(director.get_phase() == ShiftDirector.Phase.RECEIVING and segments.size() == 2
		and segments[1].number == 2 and not segments[1].complete and not segments[1].interrupted
		and segments[1].events.size() == 1 and is_zero_approx(segments[1].events[0].duration_units),
		"Telegram starts a distinct second wire take with zero future ink"): return false
	var active := scheduler.get_active_schedule()
	scheduler.advance_time(active.total_duration_seconds + 1.0)
	segments = tape.get_segment_snapshots()
	if not _a(segments.size() == 2 and segments[0].interrupted and segments[1].complete
		and tape.get_record().size() == 1 + active.events.size(),
		"Cancelled call plus completed telegram has only delivered events and two boundaries"): return false
	var source_match := true
	for i in range(active.events.size()):
		var ink: TapeInkEvent = segments[1].events[i]
		var source: MorseScheduledEvent = active.events[i]
		source_match = source_match and ink.kind == source.kind and ink.is_complete and not ink.interrupted \
			and is_equal_approx(ink.duration_units, float(source.duration_units)) \
			and is_equal_approx(ink.duration_seconds, source.duration_seconds)
	if not _a(source_match, "Every telegram event preserves exact completed actual units/seconds after the call"): return false
	var display := tape.get_tape_display_text()
	if not _a(display.begins_with("[WIRE TAKE 1 | INTERRUPTED | NON-INK BOUNDARY]\n?\n")
		and display.contains("[WIRE TAKE 2 | COMPLETE | NON-INK BOUNDARY]\n")
		and not display.contains("baseline_train_17") and not display.contains("CR CR")
		and not display.contains("TRAIN"), "Call/telegram presentation has chronology but no message names or decoding"): return false
	director._play_on_wire(director.call_sign)
	scheduler.advance_time(0.05)
	director._play_on_wire(director.call_sign)
	segments = tape.get_segment_snapshots()
	if not _a(segments.size() == 4 and segments[2].number == 3 and segments[2].interrupted
		and is_equal_approx(segments[2].events[0].duration_seconds, 0.05)
		and segments[3].number == 4 and is_zero_approx(segments[3].events[0].duration_seconds),
		"Current service/nag replacement cancels one take before starting the next without future ink"): return false
	scheduler.cancel()
	tape.disconnect_scheduler()
	director.free()
	session.free()
	tape.free()
	scheduler.free()
	return true

func _test_american_internal_pauses() -> bool:
	var tape := TapeRegisterController.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	tape.connect_scheduler(scheduler)
	var alphabet: AmericanMorseAlphabetData = load("res://data/morse/m1_american_morse_alphabet.tres")
	var profile: MorsePlaybackProfileData = load("res://data/morse/m1_morse_playback_profile.tres")
	var encoder := AmericanMorseEncoder.new()
	var compiler := MorseScheduleCompiler.new()
	var expected: Dictionary = {"C": "· ·  ·", "O": "·  ·", "R": "·  · ·"}
	for letter in ["C", "O", "R"]:
		tape.reset()
		var schedule := compiler.compile(encoder.encode(letter, alphabet), profile)
		if not _a(scheduler.start(schedule), "Real American Morse %s fixture starts" % letter): return false
		scheduler.advance_time(schedule.total_duration_seconds + 1.0)
		if not _a(tape.get_tape_text() == expected[letter],
			"%s preserves its exact American Morse internal two-unit pause" % letter): return false
	var record := tape.get_record()
	if not _a(record.is_typed() and record.get_typed_script() == TapeInkEvent
		and typeof(record[0].duration_units) == TYPE_FLOAT and typeof(record[0].duration_seconds) == TYPE_FLOAT,
		"Record is a typed tape-ink array with floating actual units and seconds"): return false
	var segments := tape.get_segment_snapshots()
	if not _a(segments.is_typed() and segments.get_typed_builtin() == TYPE_DICTIONARY
		and segments[0].events.is_typed() and segments[0].events.get_typed_script() == TapeInkEvent,
		"Segment snapshots expose typed dictionaries and typed cloned tape-ink events"): return false
	tape.disconnect_scheduler()
	tape.free()
	scheduler.free()
	return true

func _schedule(units: Array) -> MorsePlaybackScheduleData:
	var schedule := MorsePlaybackScheduleData.new()
	var elapsed := 0.0
	for i in range(units.size()):
		var event := MorseScheduledEvent.new()
		event.event_index = i
		event.kind = MorseTimingEvent.Kind.MARK if i % 2 == 0 else MorseTimingEvent.Kind.GAP
		event.duration_units = units[i]
		event.duration_seconds = units[i] * 0.1
		event.start_seconds = elapsed
		event.end_seconds = elapsed + event.duration_seconds
		elapsed = event.end_seconds
		schedule.events.append(event)
	schedule.total_duration_seconds = elapsed
	return schedule

func _test_cancel_elapsed_authority() -> bool:
	var tape := TapeRegisterController.new()
	var schedule := _schedule([1, 2, 6])
	tape._on_playback_started(schedule)
	tape._on_timing_event_started(schedule.events[0])
	tape._on_timing_event_finished(schedule.events[0])
	tape._on_timing_event_started(schedule.events[1])
	tape._on_timing_event_finished(schedule.events[1])
	tape._on_timing_event_started(schedule.events[2])
	tape._on_playback_cancelled(schedule, 0.35)
	var record := tape.get_record()
	if not _a(is_equal_approx(record[2].duration_seconds, 0.05)
		and is_equal_approx(record[2].duration_units, 0.5) and record[2].interrupted and not record[2].is_complete,
		"Cancel's elapsed timestamp alone truncates the active event relative to its start"): return false
	if not _a(record[0].is_complete and record[1].is_complete
		and not record[0].interrupted and not record[1].interrupted and tape.get_tape_text() == "·  ?",
		"Cancellation never retroactively interrupts completed ink or invents silence"): return false
	if not _a(schedule.events[2].duration_units == 6 and is_equal_approx(schedule.events[2].duration_seconds, 0.6)
		and is_equal_approx(schedule.events[2].start_seconds, 0.3) and is_equal_approx(schedule.events[2].end_seconds, 0.9),
		"Truncating the physical tape never mutates source timing or its private planned length"): return false
	tape.free()
	return true

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
