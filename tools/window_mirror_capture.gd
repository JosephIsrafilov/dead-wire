extends SceneTree

## Lamp against window (plan 3.7) and the figure in the yard (3.6), as stills.
##
## The figure is forced visible and held, and the wick is set by hand, so one
## run shows the same pane at three lamp levels from the chair, and standing at
## the glass with and without a lean.
##
##   godot --path . --script tools/window_mirror_capture.gd
##
## Windowed only. Writes to .dream-loop/window_mirror/.

var out_dir := "res://.dream-loop/window_mirror"

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
	var figure := office.window_observation
	figure.set_process(false)
	figure.get_visual_indicator().visible = true
	var lamp := office.get_node("LampLife") as LampLife

	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	# Let the seated pitch settle before the first aim, so all three match.
	await create_timer(1.0).timeout
	for wick in [1.0, 0.6, 0.3]:
		lamp.set_wick_immediate(wick)
		await _aim(office, Vector3(-1.5, 1.45, -2.36))
		await _shot("m_seated_wick_%d" % int(wick * 100))

	office.operator_seat.stand_duration = 0.0
	office.operator_seat.stand()
	await process_frame
	lamp.set_wick_immediate(1.0)
	office.player.global_position = Vector3(-1.5, 0.0, -1.75)
	await _aim(office, Vector3(-1.5, 1.4, -4.0))
	await _shot("m_standing_window_wick_100")
	Input.action_press("lean")
	for _i in 40:
		await process_frame
	await _shot("m_standing_window_lean_wick_100")
	Input.action_release("lean")
	quit(0)

func _aim(office: M1OfficeController, point: Vector3) -> void:
	var direction := point - office.player.camera.global_position
	office.player.rotation.y = atan2(-direction.x, -direction.z)
	office.player.head.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())
	for _i in 6:
		await physics_frame
	await process_frame

func _shot(label: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
	print("shot ", label)
