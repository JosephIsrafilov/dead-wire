extends SceneTree

## Filing-desk light variants for the owner (plan 4.4 follow-up): the same two
## cameras with the desk's sconce off, low (shipped) and brighter. The desk
## shows a filed copy so the plates and stamps can be read. Nothing here
## changes the game; the variants exist only in this run.
##
##   godot --path . --script tools/filing_light_variants_capture.gd
##
## Windowed only. Writes to .dream-loop/filing_light/<variant>_<view>.png.

const OUT_DIR := "res://.dream-loop/filing_light"

const VIEWS := {
	"standing": [Vector3(0.45, 1.56, 0.95), Vector3(0.45, 0.78, 1.85)],
	"seated": [Vector3(-1.55, 1.19, -0.6), Vector3(0.45, 0.9, 2.0)],
}

const VARIANTS := {"off": 0.0, "low": 0.5, "bright": 0.9}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 4:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	(office.get_node("LampLife") as LampLife).set_wick_immediate(1.0)
	office.shift_director.enabled = false
	var player := office.player
	player.set_process(false)
	player.set_physics_process(false)
	var cam := player.get_node("Head/Camera3D") as Camera3D
	(office.get_node("MoonWeather") as MoonWeather).set_process(false)
	var sconce := office.get_node("FilingDeskSconceLight") as OmniLight3D
	# A filed copy on the desk: the plates, the stamp and the result line.
	var scenario := office.get_scenario_list()[0] as TelegraphScenarioData
	office.copy_commit_desk.configure(scenario.commit_options)
	office.copy_commit_desk.apply_commit_result(&"file_as_copied", "COPY FILED")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for variant in VARIANTS:
		sconce.light_energy = VARIANTS[variant]
		sconce.visible = VARIANTS[variant] > 0.0
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
