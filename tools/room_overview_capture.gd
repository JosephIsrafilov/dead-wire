extends SceneTree

## Art review stills: fixed viewpoints around the office, no gameplay route.
##
##   godot --path . --script tools/room_overview_capture.gd
##
## Windowed only (needs a real framebuffer). Writes to .dream-loop/overview/.
## The player's camera is placed directly — this is a camera rig for looking at
## the room, not evidence of how the room plays (production_evidence does that).

const OUT_DIR := "res://.dream-loop/overview"

## name -> [eye position, look-at point]
const VIEWS := {
	"o1_north_window": [Vector3(0.4, 1.6, 1.2), Vector3(-1.2, 1.4, -2.3)],
	"o2_east_board": [Vector3(-0.6, 1.6, 0.2), Vector3(2.9, 1.3, -0.9)],
	"o3_south_door": [Vector3(0.2, 1.6, -1.2), Vector3(-1.6, 1.1, 2.4)],
	"o4_west_desk": [Vector3(0.8, 1.6, 0.6), Vector3(-2.4, 0.9, -0.6)],
	"o5_desk_close": [Vector3(-1.45, 1.25, -0.65), Vector3(-2.3, 0.78, -0.7)],
	"o6_stove_corner": [Vector3(-0.4, 1.6, -0.6), Vector3(2.4, 0.8, 1.9)],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: Node = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 4:
		await process_frame
	var intro := office.get_node_or_null("IntroCard")
	if intro != null and intro.has_method("skip_immediately"):
		intro.skip_immediately()
	var director := office.get_node_or_null("ShiftDirector")
	if director != null:
		director.set("enabled", false)
	var player := office.get_node("Player") as Node3D
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	var cam := player.get_node("Head/Camera3D") as Camera3D
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for name in VIEWS:
		var view: Array = VIEWS[name]
		cam.global_position = view[0]
		cam.look_at(view[1], Vector3.UP)
		for _i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		print("SHOT ", name, " ", img.save_png(OUT_DIR.path_join(name + ".png")))
	quit(0)
