extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var intro: IntroCard = load("res://scenes/ui/intro_card.tscn").instantiate()
	root.add_child(intro)
	await process_frame
	var music := intro.get_node("IntroMusic") as AudioStreamPlayer
	check(music != null and music.stream != null, "Temporary source music is loaded")
	check(music.playing and music.bus == &"Ambience", "Intro music respects ambience and master settings")
	check((music.stream as AudioStreamMP3).loop == false, "Opening cue never loops")
	check(intro.get_node("CenterContainer/VBoxContainer/MusicCredit").text.contains("Kevin MacLeod"), "Author attribution is visible in game")
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
	quit(1 if failures else 0)
func check(ok: bool, text: String) -> void:
	if ok: print("PASS: ",text)
	else: failures += 1; printerr("FAIL: ",text)
