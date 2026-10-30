extends SceneTree

## The sky through the pane and the moonlight in the room are one weather.
## A cloud MoonWeather sends dims the room AND crosses the moon in the sky,
## and the sky clears with the light; the dawn reaches the sky as well.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Moon Sky Test Suite ---")
	var holder := Node3D.new()
	root.add_child(holder)
	var light := SpotLight3D.new()
	light.light_energy = 2.0
	holder.add_child(light)
	var sky := ShaderMaterial.new()
	sky.shader = load("res://materials/shaders/night_sky.gdshader")
	var weather := MoonWeather.new()
	weather.moon_light = light
	weather.sky_material = sky
	weather.cloud_interval_min = 9999.0
	weather.cloud_interval_max = 9999.0
	holder.add_child(weather)
	weather.set_process(false)
	weather._until_cloud = 9999.0

	_step(weather, 3.0)
	if not _check(is_zero_approx(float(sky.get_shader_parameter("cloud_cover"))), "A clear night draws no cloud over the moon"): return

	weather.force_cloud(6.0)
	_step(weather, 3.0)
	if not _check(float(sky.get_shader_parameter("cloud_cover")) > 0.99, "A cloud that dims the room crosses the moon in the sky"): return
	if not _check(light.light_energy < 2.0 * 0.6, "The same cloud dims the moonlight in the room"): return

	_step(weather, 8.0)
	if not _check(float(sky.get_shader_parameter("cloud_cover")) < 0.01, "The sky clears when the cloud has passed"): return

	weather.begin_dawn()
	_step(weather, weather.dawn_seconds + 1.0)
	if not _check(is_equal_approx(float(sky.get_shader_parameter("dawn")), 1.0), "The dawn reaches the sky, not only the room"): return

	holder.queue_free()
	await process_frame
	print("--- All Moon Sky Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _step(weather: MoonWeather, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		weather.advance(0.1)
		left -= 0.1

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
