extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var intro: IntroCard = load("res://scenes/ui/intro_card.tscn").instantiate()
	root.add_child(intro)
	await process_frame
	var music := intro.get_node("IntroMusic") as AudioStreamPlayer
	check(music != null and music.stream != null, "The opening drone is loaded")
	check(music.playing and music.bus == &"Music", "Intro music uses the independently controlled Music bus")
	var wav := music.stream as AudioStreamWAV
	check(wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Opening cue never loops")
	# Plan 7.12: the opening is the project's own drone, so no third-party cue
	# ships and no credit line has to sit on the order card.
	check(not music.stream.resource_path.contains("/temp/")
		and intro.get_node_or_null("CenterContainer/VBoxContainer/MusicCredit") == null,
		"The opening cue is the game's own, with no borrowed music to credit")
	intro.skip_immediately()
	check(not music.playing, "Skip stops music before handing controls to Morse operator")
	var fading: IntroCard = load("res://scenes/ui/intro_card.tscn").instantiate()
	fading.fade_duration = 0.05
	root.add_child(fading)
	await process_frame
	var releases: Array[bool] = []
	fading.intro_finished.connect(func(): releases.append(not (fading.get_node("IntroMusic") as AudioStreamPlayer).playing))
	fading.finish()
	# SceneTree timers run before tween callbacks in the same frame. Wait for
	# semantic release with a finite guard rather than assuming wall-clock order.
	var guard := 0
	while releases.is_empty() and guard < 120:
		await process_frame
		guard += 1
	check(not releases.is_empty() and releases[0],
		"Normal intro fade also stops source music before releasing controls")
	fading.queue_free()
	intro.queue_free()
	await process_frame
	# Plan 9.4: standing another watch goes straight back to the room; the
	# order card is read once, and only the next card is spared.
	var end_card: ShiftEndCard = load("res://scenes/ui/shift_end_card.tscn").instantiate()
	end_card.stand_another_watch()
	end_card.free()
	var second: IntroCard = load("res://scenes/ui/intro_card.tscn").instantiate()
	root.add_child(second)
	await process_frame
	check(second.is_finished() and not second.is_running() and not second.visible,
		"Another watch does not show the order card again")
	var third: IntroCard = load("res://scenes/ui/intro_card.tscn").instantiate()
	root.add_child(third)
	await process_frame
	check(third.is_running(), "Only that one card is spared: a new game reads the order")
	third.skip_immediately()
	second.queue_free()
	third.queue_free()
	await process_frame
	quit(1 if failures else 0)
func check(ok: bool, text: String) -> void:
	if ok: print("PASS: ",text)
	else: failures += 1; printerr("FAIL: ",text)
