extends SceneTree

## The train-order signal by the east wall (plan 6.5), from fixed cameras:
## standing at it, from across the room, and from the operator's chair, with
## an order pending and then thrown to HOLD. Windowed only.
##
##   godot --path . --resolution 1920x1080 --script tools/signal_stand_capture.gd -- <label>
##
## Writes to .dream-loop/signal_stand/<label>_<view>.png.

const OUT_DIR := "res://.dream-loop/signal_stand"

const VIEWS := {
	"standing": [Vector3(1.6, 1.58, -0.85), Vector3(2.74, 1.0, -0.95)],
	"across": [Vector3(-0.4, 1.6, 0.2), Vector3(2.74, 1.0, -0.85)],
	"seated": [Vector3(-1.55, 1.19, -0.6), Vector3(2.74, 1.1, -0.85)],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var label: String = args[0] if not args.is_empty() else "shot"
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
	var board := office.routing_board
	board.set_awaiting_route(true)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for stage in ["pending", "held"]:
		if stage == "held":
			board.play_route_accept("HOLD", true)
			for _i in 40:
				await process_frame
		for view_name in VIEWS:
			var view: Array = VIEWS[view_name]
			cam.global_position = view[0]
			cam.look_at(view[1], Vector3.UP)
			for _i in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			print("SHOT ", stage, "_", view_name, " ", img.save_png(OUT_DIR.path_join("%s_%s_%s.png" % [label, stage, view_name])))
	# The rules beside the signal, taken up and read like any paper.
	if board.has_method("read_rules") and board.call("read_rules"):
		for _i in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var rules_img := root.get_texture().get_image()
		print("SHOT rules ", rules_img.save_png(OUT_DIR.path_join("%s_rules.png" % label)))
	quit(0)
