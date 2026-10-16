extends SceneTree
## The register's clockwork belongs to the watch, not to the scene load: the
## spring starts running down on the first wire playback, and the teaching
## surfaces (wind prompt, guidance) read one shared needs_winding() answer.
##   godot --headless --audio-driver Dummy --path . --script tests/telegraph/tape_clockwork_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Tape Clockwork Test Suite ---")
	if not _test_spring_waits_for_the_first_wire_playback(): return
	if not _test_run_down_pace_is_authored_360_seconds(): return
	if not _test_reset_stops_the_clockwork_for_the_next_watch(): return
	if not _test_winding_restores_the_clockwork(): return
	print("--- All Tape Clockwork Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

## PRE_SHIFT silence must not spend the spring: the strip slowdown has to line
## up with the watch's wire time, not with the scene's load time.
func _test_spring_waits_for_the_first_wire_playback() -> bool:
	var tape := _make_register()
	var scheduler := _make_scheduler()
	tape.connect_scheduler(scheduler)
	if not _a(is_equal_approx(tape.spring_tension, 1.0) and not tape.needs_winding(),
		"A connected but silent register keeps full spring tension"): return false
	for _step in 60:
		tape._process(0.5)
	if not _a(is_equal_approx(tape.spring_tension, 1.0) and not tape.needs_winding(),
		"Thirty seconds of line silence before any call do not run the spring down"): return false
	var schedule := _schedule([1, 2, 1, 3, 1])
	scheduler.start(schedule)
	scheduler.advance_time(schedule.total_duration_seconds + 1.0)
	tape._process(1.0)
	if not _a(tape.spring_tension < 1.0,
		"The first wire playback starts the clockwork"): return false
	_cleanup(tape, scheduler)
	return true

## The authored pace is 360 s from full to empty: prompt near 90 s after the
## first call, slack near 162 s — the hook's take stays readable past midnight.
func _test_run_down_pace_is_authored_360_seconds() -> bool:
	var tape := _make_register()
	var scheduler := _make_scheduler()
	tape.connect_scheduler(scheduler)
	var schedule := _schedule([1, 2, 1, 3, 1])
	scheduler.start(schedule)
	scheduler.advance_time(schedule.total_duration_seconds + 1.0)
	tape._process(95.0)
	if not _a(absf(tape.spring_tension - (1.0 - 95.0 / 360.0)) < 0.001,
		"The spring runs down at the authored 360 s pace (tension %.3f after 95 s)" % tape.spring_tension): return false
	if not _a(tape.needs_winding(),
		"needs_winding() reports the clockwork as due roughly 90 s after the first call"): return false
	_cleanup(tape, scheduler)
	return true

## reset() is the between-watches reset: the clockwork stops until the next
## wire playback arms it again.
func _test_reset_stops_the_clockwork_for_the_next_watch() -> bool:
	var tape := _make_register()
	var scheduler := _make_scheduler()
	tape.connect_scheduler(scheduler)
	var schedule := _schedule([1, 2, 1, 3, 1])
	scheduler.start(schedule)
	scheduler.advance_time(schedule.total_duration_seconds + 1.0)
	tape._process(50.0)
	var after_watch := tape.spring_tension
	tape.reset()
	for _step in 60:
		tape._process(0.5)
	if not _a(is_equal_approx(tape.spring_tension, after_watch),
		"After reset the spring does not run down while the wire is silent"): return false
	var next_schedule := _schedule([1, 1, 1])
	scheduler.start(next_schedule)
	scheduler.advance_time(next_schedule.total_duration_seconds + 1.0)
	tape._process(1.0)
	if not _a(tape.spring_tension < after_watch,
		"The next wire playback arms the clockwork again"): return false
	_cleanup(tape, scheduler)
	return true

## Winding restores full tension and clears needs_winding() until the spring
## runs down again.
func _test_winding_restores_the_clockwork() -> bool:
	var tape := _make_register()
	var scheduler := _make_scheduler()
	tape.connect_scheduler(scheduler)
	var schedule := _schedule([1, 2, 1, 3, 1])
	scheduler.start(schedule)
	scheduler.advance_time(schedule.total_duration_seconds + 1.0)
	tape._process(95.0)
	if not _a(tape.needs_winding(), "The worn register asks to be wound"): return false
	tape.wind()
	if not _a(is_equal_approx(tape.spring_tension, 1.0) and not tape.needs_winding(),
		"Winding restores the spring and clears the wind prompt"): return false
	tape._process(30.0)
	if not _a(tape.spring_tension < 1.0 and not tape.needs_winding(),
		"The wound spring keeps its measured pace afterwards"): return false
	_cleanup(tape, scheduler)
	return true

func _make_register() -> TapeRegisterController:
	var scene: PackedScene = load("res://scenes/telegraph/tape_register.tscn")
	var tape := scene.instantiate() as TapeRegisterController
	root.add_child(tape)
	return tape

func _make_scheduler() -> MorseRuntimeScheduler:
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	root.add_child(scheduler)
	return scheduler

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

func _cleanup(tape: TapeRegisterController, scheduler: MorseRuntimeScheduler) -> void:
	tape.disconnect_scheduler()
	tape.queue_free()
	scheduler.queue_free()

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
