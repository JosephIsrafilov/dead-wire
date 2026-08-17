extends SceneTree

var events_started: Array[int] = []
var events_finished: Array[int] = []
var playback_started_count: int = 0
var playback_completed_count: int = 0
var playback_cancelled_count: int = 0

func _init() -> void:
	print("--- Starting Morse Runtime Scheduler Test Suite (Gate 09C) ---")

	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	root.add_child(scheduler)

	scheduler.playback_started.connect(func(_s): playback_started_count += 1)
	scheduler.playback_completed.connect(func(_s): playback_completed_count += 1)
	scheduler.playback_cancelled.connect(func(_s, _e): playback_cancelled_count += 1)
	scheduler.timing_event_started.connect(func(ev: MorseScheduledEvent): events_started.append(ev.event_index))
	scheduler.timing_event_finished.connect(func(ev: MorseScheduledEvent): events_finished.append(ev.event_index))

	if not assert_condition(scheduler.get_playback_state() == MorseRuntimeScheduler.State.IDLE, "Initial state is IDLE"): return
	if not assert_condition(not scheduler.is_playing(), "is_playing() is false initially"): return

	# Load alphabet and profile to build ET schedule
	var alph_path := "res://data/morse/m1_american_morse_alphabet.tres"
	var alphabet: AmericanMorseAlphabetData = ResourceLoader.load(alph_path, "", ResourceLoader.CACHE_MODE_IGNORE) as AmericanMorseAlphabetData
	var prof_path := "res://data/morse/m1_morse_playback_profile.tres"
	var profile: MorsePlaybackProfileData = ResourceLoader.load(prof_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MorsePlaybackProfileData

	var encoder := AmericanMorseEncoder.new()
	var compiler := MorseScheduleCompiler.new()

	var seq_et := encoder.encode("ET", alphabet)
	var sched_et := compiler.compile(seq_et, profile)

	# 1. Start ET schedule
	var start_ok := scheduler.start(sched_et)
	if not assert_condition(start_ok, "Start ET schedule succeeds"): return
	if not assert_condition(scheduler.get_playback_state() == MorseRuntimeScheduler.State.PLAYING, "State is PLAYING"): return
	if not assert_condition(scheduler.is_playing(), "is_playing() is true"): return
	if not assert_condition(playback_started_count == 1, "playback_started emitted"): return
	if not assert_condition(events_started.size() == 1 and events_started[0] == 0, "Event 0 started at t=0.0"): return
	if not assert_condition(scheduler.get_current_event_index() == 0, "Current event index is 0"): return

	# 2. Advance 0.05s -> still in event 0
	scheduler.advance_time(0.05)
	if not assert_condition(is_equal_approx(scheduler.get_elapsed_seconds(), 0.05), "Elapsed time is 0.05s"): return
	if not assert_condition(events_started.size() == 1 and events_finished.is_empty(), "Event 0 still running at 0.05s"): return

	# 3. Advance 0.05s (t = 0.10s) -> event 0 finishes, event 1 starts
	scheduler.advance_time(0.05)
	if not assert_condition(is_equal_approx(scheduler.get_elapsed_seconds(), 0.10), "Elapsed time is 0.10s"): return
	if not assert_condition(events_finished.size() == 1 and events_finished[0] == 0, "Event 0 finished at t=0.10s"): return
	if not assert_condition(events_started.size() == 2 and events_started[1] == 1, "Event 1 started at t=0.10s"): return
	if not assert_condition(scheduler.get_current_event_index() == 1, "Current event index is 1"): return

	# 4. Advance 0.30s (t = 0.40s) -> event 1 finishes, event 2 starts
	scheduler.advance_time(0.30)
	if not assert_condition(is_equal_approx(scheduler.get_elapsed_seconds(), 0.40), "Elapsed time is 0.40s"): return
	if not assert_condition(events_finished.size() == 2 and events_finished[1] == 1, "Event 1 finished at t=0.40s"): return
	if not assert_condition(events_started.size() == 3 and events_started[2] == 2, "Event 2 started at t=0.40s"): return

	# 5. Advance 0.30s (t = 0.70s) -> event 2 finishes, playback completes
	scheduler.advance_time(0.30)
	if not assert_condition(is_equal_approx(scheduler.get_elapsed_seconds(), 0.70), "Elapsed time is 0.70s"): return
	if not assert_condition(events_finished.size() == 3 and events_finished[2] == 2, "Event 2 finished at t=0.70s"): return
	if not assert_condition(playback_completed_count == 1, "playback_completed emitted once"): return
	if not assert_condition(scheduler.get_playback_state() == MorseRuntimeScheduler.State.COMPLETED, "State is COMPLETED"): return

	# 6. Test Start while Playing Rejection
	scheduler.reset()
	events_started.clear()
	events_finished.clear()
	playback_started_count = 0
	playback_completed_count = 0

	scheduler.start(sched_et)
	var double_start := scheduler.start(sched_et)
	if not assert_condition(not double_start, "Double start while playing is rejected"): return
	if not assert_condition(playback_started_count == 1, "playback_started not emitted again"): return

	# 7. Test Cancel
	scheduler.cancel()
	if not assert_condition(scheduler.get_playback_state() == MorseRuntimeScheduler.State.IDLE, "Cancel transitions to IDLE"): return
	if not assert_condition(playback_cancelled_count == 1, "playback_cancelled emitted"): return

	# 8. Frame-hitch / Large Delta Step Test with "WATER"
	var seq_water := encoder.encode("WATER", alphabet)
	var sched_water := compiler.compile(seq_water, profile)
	var water_event_count: int = sched_water.events.size()

	events_started.clear()
	events_finished.clear()
	playback_started_count = 0
	playback_completed_count = 0

	scheduler.start(sched_water)
	if not assert_condition(events_started.size() == 1, "WATER event 0 started at t=0.0"): return

	# Jump immediately past end (4.0 seconds for a 3.60s schedule)
	scheduler.advance_time(4.0)

	if not assert_condition(playback_completed_count == 1, "WATER completed after large delta hitch"): return
	if not assert_condition(scheduler.get_playback_state() == MorseRuntimeScheduler.State.COMPLETED, "State is COMPLETED after hitch"): return
	if not assert_condition(events_started.size() == water_event_count, "All WATER events started in order"): return
	if not assert_condition(events_finished.size() == water_event_count, "All WATER events finished in order"): return

	var in_order := true
	for i in range(water_event_count):
		if events_started[i] != i or events_finished[i] != i:
			in_order = false
			break
	if not assert_condition(in_order, "All events executed in strict index order"): return

	# 9. Clean up test scheduler node
	scheduler.queue_free()

	print("--- All Morse Runtime Scheduler Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
