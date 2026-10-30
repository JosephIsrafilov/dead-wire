extends SceneTree

## Mood variants for the owner to choose from (plan 2.15, with 2.14 SSAO as an
## experiment): the same four cameras under "strict" (the shipped look), "more
## moon", "more lamp" and "strict + SSAO". Nothing here changes the game; the
## variants exist only in this run.
##
##   godot --path . --script tools/mood_variants_capture.gd
##
## Windowed only. Writes to .dream-loop/moods/<variant>_<view>.png.

const OUT_DIR := "res://.dream-loop/moods"

const VIEWS := {
	"desk": [Vector3(0.8, 1.6, 0.6), Vector3(-2.4, 0.9, -0.6)],
	"seated": [Vector3(-1.55, 1.19, -0.6), Vector3(-2.3, 0.78, -0.75)],
	"door": [Vector3(0.0, 1.62, -0.2), Vector3(0.0, 1.4, 2.3)],
	"window": [Vector3(0.0, 1.62, 0.2), Vector3(-1.5, 1.4, -2.3)],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: Node = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 4:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	(office.get_node("LampLife") as LampLife).set_wick_immediate(1.0)
	office.get_node("ShiftDirector").set("enabled", false)
	var player := office.get_node("Player") as Node3D
	player.set_process(false)
	player.set_physics_process(false)
	var cam := player.get_node("Head/Camera3D") as Camera3D
	var env := (office.get_node("WorldEnvironment") as WorldEnvironment).environment
	var moon := office.get_node("WindowBounceLight") as SpotLight3D
	var lamp := office.get_node("DeskLampLight") as OmniLight3D
	var weather := office.get_node("MoonWeather") as MoonWeather
	weather.set_process(false)
	var base := {"exposure": env.tonemap_exposure, "ambient": env.ambient_light_energy,
		"moon": moon.light_energy, "lamp_range": lamp.omni_range}
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for variant in ["strict", "more_moon", "more_lamp", "strict_ssao"]:
		env.tonemap_exposure = base.exposure
		env.ambient_light_energy = base.ambient
		moon.light_energy = base.moon
		lamp.omni_range = base.lamp_range
		env.ssao_enabled = false
		match variant:
			"more_moon":
				moon.light_energy = base.moon * 1.6
				env.ambient_light_energy = base.ambient * 1.3
			"more_lamp":
				lamp.omni_range = base.lamp_range + 0.8
				env.tonemap_exposure = base.exposure * 1.12
			"strict_ssao":
				env.ssao_enabled = true
				env.ssao_radius = 0.6
				env.ssao_intensity = 1.4
		for view_name in VIEWS:
			var view: Array = VIEWS[view_name]
			cam.global_position = view[0]
			cam.look_at(view[1], Vector3.UP)
			for _i in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			print("SHOT ", variant, "_", view_name, " ", img.save_png(OUT_DIR.path_join("%s_%s.png" % [variant, view_name])))
	quit(0)
