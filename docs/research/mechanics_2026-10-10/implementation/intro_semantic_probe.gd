extends SceneTree
## Semantic intro completion beats SceneTree timer/tween ordering races.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var intro: IntroCard = load("res://scenes/ui/intro_card.tscn").instantiate()
	intro.fade_duration = 0.05
	root.add_child(intro)
	await process_frame
	var events: Array = []
	intro.intro_finished.connect(func(): events.append({"event":"release", "music":intro.get_node("IntroMusic").playing}))
	intro.finish()
	await create_timer(0.1).timeout
	events.append({"event":"fixed_timer", "music":intro.get_node("IntroMusic").playing})
	await create_timer(0.3).timeout
	print(JSON.stringify(events))
	intro.queue_free()
	await process_frame
	quit(0)
