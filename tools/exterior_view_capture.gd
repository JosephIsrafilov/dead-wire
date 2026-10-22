extends SceneTree

## Looks out of the north window and nothing else.
##
## The full window fixture drives a whole night to get four frames; this one
## only exists to judge the view itself, from the three places the plan names:
## standing in the room, seated at the desk, and from the filing table. The
## figure is hidden so the exterior can be read on its own.
##
##   godot --path . --script tools/exterior_view_capture.gd

var out_dir := "res://.dream-loop/exterior"
var shots := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.set_process(false)
	office.session_controller.set_process(false)
	office.session_controller.scheduler.auto_process = false
	# The figure is not the subject here.
	var figure := office.window_observation
	if figure != null:
		figure.reset_state()
		set_process_recursive(figure, false)

	# 1. Standing in the middle of the room.
	office.player.global_position = Vector3(-1.4, 0.0, -0.4)
	await _aim(office, Vector3(-1.5, 1.55, -2.36))
	await _shot("e1_standing")

	# 2. Seated at the desk, the way the operator actually sees it.
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	await process_frame
	await process_frame
	await _aim(office, Vector3(-1.5, 1.5, -2.36))
	await _shot("e2_seated")

	# 3. From the filing table by the south door.
	office.operator_seat.stand_duration = 0.0
	office.operator_seat.stand()
	await process_frame
	office.player.global_position = Vector3(0.45, 0.0, 0.95)
	await _aim(office, Vector3(-1.5, 1.55, -2.36))
	await _shot("e3_filing_table")

	# 4. A head's width to the left of the seated view, to read the parallax
	#    between the fence, the mine and the slope.
	office.player.global_position = Vector3(-1.85, 0.0, -0.4)
	await _aim(office, Vector3(-1.5, 1.55, -2.36))
	await _shot("e4_parallax_left")

	# 5. And to the right.
	office.player.global_position = Vector3(-1.0, 0.0, -0.4)
	await _aim(office, Vector3(-1.5, 1.55, -2.36))
	await _shot("e5_parallax_right")

	print("EXTERIOR VIEW: %d screenshots" % shots)
	quit(0)

func set_process_recursive(node: Node, enabled: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = enabled
	for child in node.get_children():
		set_process_recursive(child, enabled)

func _aim(office: M1OfficeController, point: Vector3) -> void:
	var direction := point - office.player.camera.global_position
	office.player.rotation.y = atan2(-direction.x, -direction.z)
	office.player.head.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())
	await physics_frame
	await process_frame

func _shot(label: String) -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var image := root.get_texture().get_image()
	image.save_png(out_dir.path_join(label + ".png"))
	shots += 1
	print("shot ", label)
