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
	var environment := Environment.new()
	environment.fog_light_color = Color(0.16, 0.19, 0.24)
	environment.fog_light_energy = 0.55
	var night_fog := environment.fog_light_color.get_luminance() * environment.fog_light_energy
	weather.set("environment", environment)
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
	if not _check(is_equal_approx(environment.fog_light_color.get_luminance() * environment.fog_light_energy, night_fog),
		"The night leaves the fog over the yard as it was"): return

	weather.begin_dawn()
	_step(weather, weather.dawn_seconds + 1.0)
	if not _check(is_equal_approx(float(sky.get_shader_parameter("dawn")), 1.0), "The dawn reaches the sky, not only the room"): return
	# Plan 9.5: the yard is unlit silhouette against the fog; the morning is
	# the fog lifting to grey, so the yard stands out of it.
	if not _check(environment.fog_light_color.get_luminance() * environment.fog_light_energy > night_fog * 2.0,
		"The morning lifts the fog the yard stands in"): return

	holder.queue_free()
	await process_frame

	# A watch's morning stays in that watch: the scene's air is shared by every
	# office, and the next watch must open at night.
	var scene := load("res://scenes/office/m1_office.tscn") as PackedScene
	var first := scene.instantiate()
	root.add_child(first)
	var first_air := (first.get_node("WorldEnvironment") as WorldEnvironment).environment
	var night_energy := first_air.fog_light_energy
	var first_moon := first.get_node("MoonWeather") as MoonWeather
	first_moon.set_process(false)
	first_moon.begin_dawn()
	_step(first_moon, first_moon.dawn_seconds + 1.0)
	if not _check(first_air.fog_light_energy > night_energy, "The office's own morning reaches its air"): return
	first.queue_free()
	await process_frame
	var second := scene.instantiate()
	root.add_child(second)
	var second_air := (second.get_node("WorldEnvironment") as WorldEnvironment).environment
	if not _check(is_equal_approx(second_air.fog_light_energy, night_energy) and second_air != first_air,
		"The next watch opens at night, not in the last one's morning"): return
	second.queue_free()
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
