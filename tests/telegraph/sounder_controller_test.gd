extends SceneTree

func _init() -> void:
	print("--- Starting Sounder Controller Test Suite (Gate 10) ---")

	var sounder := SounderController.new()
	root.add_child(sounder)

	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	root.add_child(scheduler)

	sounder.connect_scheduler(scheduler)

	if not assert_condition(sounder.down_clicks_played == 0, "Initial down clicks is 0"): return
	if not assert_condition(sounder.up_clacks_played == 0, "Initial up clacks is 0"): return
	if not assert_condition(not sounder.is_lever_down, "Initial lever position is up"): return

	# Load alphabet and profile to build ET schedule
	var alph_path := "res://data/morse/m1_american_morse_alphabet.tres"
	var alphabet: AmericanMorseAlphabetData = ResourceLoader.load(alph_path, "", ResourceLoader.CACHE_MODE_IGNORE) as AmericanMorseAlphabetData
	var prof_path := "res://data/morse/m1_morse_playback_profile.tres"
	var profile: MorsePlaybackProfileData = ResourceLoader.load(prof_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MorsePlaybackProfileData

	var encoder := AmericanMorseEncoder.new()
	var compiler := MorseScheduleCompiler.new()

	var seq_et := encoder.encode("ET", alphabet)
	var sched_et := compiler.compile(seq_et, profile)

	# 1. Start ET schedule (t = 0.0) -> ev0 (MARK) starts
	scheduler.start(sched_et)
	if not assert_condition(sounder.down_clicks_played == 1, "MARK ev0 start triggers down click (1)"): return
	if not assert_condition(sounder.up_clacks_played == 0, "Up clacks is 0 at t=0.0"): return
	if not assert_condition(sounder.is_lever_down, "Lever is down during MARK"): return

	# 2. Advance to t = 0.10s -> ev1 (GAP) starts
	scheduler.advance_time(0.10)
	if not assert_condition(sounder.down_clicks_played == 1, "Down clicks still 1"): return
	if not assert_condition(sounder.up_clacks_played == 1, "GAP ev1 start triggers up clack (1)"): return
	if not assert_condition(not sounder.is_lever_down, "Lever is up during GAP"): return

	# 3. Advance to t = 0.40s -> ev2 (MARK) starts
	scheduler.advance_time(0.30)
	if not assert_condition(sounder.down_clicks_played == 2, "MARK ev2 start triggers down click (2)"): return
	if not assert_condition(sounder.up_clacks_played == 1, "Up clacks still 1"): return
	if not assert_condition(sounder.is_lever_down, "Lever is down during MARK ev2"): return

	# 4. Advance to t = 0.70s -> ev2 ends, playback complete -> terminal release clack
	scheduler.advance_time(0.30)
	if not assert_condition(sounder.down_clicks_played == 2, "Final down clicks == 2"): return
	if not assert_condition(sounder.up_clacks_played == 2, "Final MARK end triggers terminal up clack (2)"): return
	if not assert_condition(not sounder.is_lever_down, "Lever is up after completion"): return

	# 5. Clean up nodes
	sounder.disconnect_scheduler()
	sounder.queue_free()
	scheduler.queue_free()

	print("--- All Sounder Controller Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
