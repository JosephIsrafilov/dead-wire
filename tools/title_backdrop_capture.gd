extends SceneTree

## Title-screen backdrops (plan 6.7): the office at night from two fixed
## cameras — the desk under the lamp, and the window with the moon — with no
## arm, no interface and no hint text. Windowed only.
##
##   godot --path . --resolution 1920x1080 --script tools/title_backdrop_capture.gd -- <out_dir>
##
## Default out dir is .dream-loop/title/. The owner picks one; only the chosen
## frame is copied into assets/textures/title/.

const VIEWS := {
	"desk": [Vector3(-1.05, 1.45, -0.15), Vector3(-2.45, 0.85, -0.7), 62.0],
	"window": [Vector3(-0.4, 1.5, 0.4), Vector3(-1.5, 1.35, -2.9), 58.0],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if not args.is_empty() else "res://.dream-loop/title"
	DirAccess.make_dir_recursive_absolute(out_dir)
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
	# No interface in a backdrop: every canvas layer of the office goes dark.
	for layer in office.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var cam := player.get_node("Head/Camera3D") as Camera3D
	for view_name in VIEWS:
		var view: Array = VIEWS[view_name]
		cam.global_position = view[0]
		cam.look_at(view[1], Vector3.UP)
		cam.fov = view[2]
		for _i in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		print("SHOT ", view_name, " ", img.save_png(out_dir.path_join("title_%s.png" % view_name)))
	quit(0)
