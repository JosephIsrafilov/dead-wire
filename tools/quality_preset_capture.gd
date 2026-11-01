extends SceneTree

## Plan 10.3: the same night cameras at Low, Medium and High, with the frame
## time each costs on this machine.
##
##   godot --path . --script tools/quality_preset_capture.gd
##
## Windowed only. Writes to .dream-loop/quality/.

const OUT_DIR := "res://.dream-loop/quality"
const VIEWS := {
	"desk": [Vector3(-0.9, 1.5, 0.7), Vector3(-2.4, 0.8, -0.6)],
	"window": [Vector3(0.3, 1.55, -0.75), Vector3(-1.5, 1.45, -2.36)],
	"room": [Vector3(1.6, 1.6, 1.7), Vector3(-1.8, 1.0, -1.4)],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Quality has to be looked at: run windowed.")
		quit(2)
		return
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 4:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.set_process(false)
	(office.get_node("LampLife") as LampLife).set_wick_immediate(1.0)
	var player := office.player
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	var cam := player.get_node("Head/Camera3D") as Camera3D
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	# VSync caps the wall-clock frame; the GPU's own time for the office frame
	# is what a preset actually changes.
	var frame_rid := player.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(frame_rid, true)
	for quality in GameSettings.QUALITY_NAMES.size():
		var settings := GameSettings.load_settings()
		settings.quality = quality
		settings.apply(player)
		var label: String = GameSettings.QUALITY_NAMES[quality].to_lower()
		for view_name in VIEWS:
			var view: Array = VIEWS[view_name]
			cam.global_position = view[0]
			cam.look_at(view[1], Vector3.UP)
			for _i in 30:
				await process_frame
			var gpu := 0.0
			for _i in 60:
				await process_frame
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(frame_rid)
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png(OUT_DIR.path_join("%s_%s.png" % [label, view_name]))
			print("QUALITY %s %s office frame GPU %.2f ms" % [label, view_name, gpu / 60.0])
	GameSettings.load_settings().apply(player)
	quit(0)
