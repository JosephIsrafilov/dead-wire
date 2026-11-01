extends SceneTree

## Plan 10.1: does the first sight of something new hitch? Measures frame time
## in the windows that matter: the figure entering the frame for the first
## time, the dawn beginning, the lamp turned down. Each is compared with the
## steady room just before it. Run it after clearing the shader cache to see a
## first launch:
##
##   godot --path . --script tools/first_sight_hitch_probe.gd
##
## Windowed only. Prints one HITCH line per moment.

var office: M1OfficeController

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Frame times need a window.")
		quit(2)
		return
	print("USER DIR ", ProjectSettings.globalize_path("user://"))
	var started := Time.get_ticks_msec()
	office = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	print("LOAD office %d ms" % (Time.get_ticks_msec() - started))
	var intro := office.get_node("IntroCard")
	var first := await _measure(3)
	print("HITCH intro_card_first_3 max %.1f ms avg %.1f ms" % [first.x, first.y])
	var warm := await _measure(60)
	print("HITCH intro_card_next_60 max %.1f ms avg %.1f ms" % [warm.x, warm.y])
	intro.skip_immediately()
	office.shift_director.set_process(false)
	office.session_controller.set_process(false)
	office.session_controller.scheduler.auto_process = false
	office.player.set_process(false)
	office.player.set_physics_process(false)
	office.player.set_process_input(false)
	var cam := office.player.get_node("Head/Camera3D") as Camera3D
	var figure := office.window_observation.get_visual_indicator()

	# First look at the room, away from the window.
	cam.global_position = Vector3(-0.9, 1.5, 0.7)
	cam.look_at(Vector3(-2.4, 0.8, -0.6), Vector3.UP)
	var room := await _measure(90)
	print("HITCH first_room max %.1f ms avg %.1f ms" % [room.x, room.y])
	cam.global_position = Vector3(0.3, 1.55, -0.75)
	cam.look_at(Vector3(-1.5, 1.45, -2.36), Vector3.UP)
	var window := await _measure(90)
	print("HITCH first_window max %.1f ms avg %.1f ms" % [window.x, window.y])
	var steady := await _measure(60)
	print("HITCH steady_window max %.1f ms avg %.1f ms" % [steady.x, steady.y])

	figure.visible = true
	var first_figure := await _measure(30)
	print("HITCH first_figure max %.1f ms avg %.1f ms" % [first_figure.x, first_figure.y])
	figure.visible = false
	await _measure(30)

	var moon := office.get_node("MoonWeather") as MoonWeather
	(office.get_node("DawnRitual") as DawnRitual).begin()
	var dawn_start := await _measure(60)
	print("HITCH dawn_begins max %.1f ms avg %.1f ms" % [dawn_start.x, dawn_start.y])
	moon.advance(moon.dawn_seconds)
	var dawn_full := await _measure(60)
	print("HITCH dawn_full max %.1f ms avg %.1f ms" % [dawn_full.x, dawn_full.y])
	(office.get_node("LampLife") as LampLife).turn_down_wick()
	var lamp := await _measure(120)
	print("HITCH lamp_down max %.1f ms avg %.1f ms" % [lamp.x, lamp.y])
	quit(0)

## (max, average) frame time in milliseconds over the next `frames` frames.
func _measure(frames: int) -> Vector2:
	var worst := 0.0
	var total := 0.0
	var last := Time.get_ticks_usec()
	for _i in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		worst = maxf(worst, ms)
		total += ms
	return Vector2(worst, total / frames)
