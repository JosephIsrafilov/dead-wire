extends SceneTree

## Two stills of the coat: settled, and mid-swing after someone walks past it.
##
## A Verlet cloth cannot show its work in one frame — the point is that the
## garment is in a different pose because a body moved through the room. This
## captures the same camera twice, once at rest and once 10 steps after a body
## passes, so the difference is visible rather than asserted.
##
##   godot --path . --script tools/coat_sway_capture.gd

const OUT_DIR := "res://.dream-loop/coat_sway"
const EYE := Vector3(-0.05, 1.62, 1.30)
const LOOK := Vector3(-0.35, 1.60, 2.25)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: Node = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 6:
		await process_frame
	var intro := office.get_node_or_null("IntroCard")
	if intro != null and intro.has_method("skip_immediately"):
		intro.skip_immediately()
	var director := office.get_node_or_null("ShiftDirector")
	if director != null:
		director.set("enabled", false)
	var coat := office.get_node_or_null("HangingCoat") as HangingCoat
	if coat == null:
		print("NO COAT")
		quit(1)
		return
	var player := office.get_node("Player") as Node3D
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	var cam := player.get_node("Head/Camera3D") as Camera3D
	cam.global_position = EYE
	cam.look_at(LOOK, Vector3.UP)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	# Let the coat find its rest pose before the first frame.
	coat.set_process(false)
	for _i in 240:
		coat.step(1.0 / 60.0)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	_shot("coat_rest.png")

	# A body walks past at 1.35 m/s, the game's own walk speed.
	coat.disturb(Vector3(0.35, 1.25, 1.95), Vector3(0.0, 0.0, 1.35))
	for _i in 10:
		coat.step(1.0 / 60.0)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	_shot("coat_sway.png")

	# And again 40 steps later, to show it is settling rather than frozen.
	for _i in 40:
		coat.step(1.0 / 60.0)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	_shot("coat_settling.png")

	quit(0)

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	print("SHOT ", name, " ", img.save_png(OUT_DIR.path_join(name)))
