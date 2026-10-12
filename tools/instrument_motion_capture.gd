extends SceneTree
## Fixed-camera visual/kinematic evidence. Not human-input or pacing acceptance.
const OUT := "res://docs/art/state_2026-10-10/instruments/motion"
var office: M1OfficeController
var camera: Camera3D
var telemetry: Array = []
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	office = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for i in 5:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	office.session_controller.set_process(false)
	office.session_controller.scheduler.auto_process = false
	var lamp := office.get_node("LampLife")
	lamp.set_wick_immediate(1.0)
	var player := office.player
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	camera = player.camera
	camera.global_position = Vector3(-1.75, 1.05, -0.95)
	camera.look_at(Vector3(-2.38, 0.8, -0.98), Vector3.UP)
	var key := office.session_controller.telegraph_key
	key.set_enabled(true)
	var sounder := office.session_controller.sounder
	var tape := office.session_controller.get_tape_register()
	if tape == null:
		printerr("Production session has no tape register")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	for i in 20:
		await process_frame
	for frame in 90:
		if frame % 30 == 0:
			key.press()
		if frame % 15 == 0:
			sounder.play_down(frame)
		elif frame % 15 == 6:
			sounder.play_up(frame)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var error := image.save_png(OUT.path_join("frame_%03d.png" % frame))
		if error != OK:
			quit(1)
			return
		telemetry.append({"frame": frame, "key_y": key.get_node("Lever").position.y,
			"armature_y": sounder.armature.position.y, "spool_rotation": tape.get_node("Body/Spool").rotation.z,
			"viewport": [image.get_width(), image.get_height()]})
	var file := FileAccess.open(OUT.path_join("telemetry.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(telemetry, "\t"))
	file.close()
	print("MOTION FRAMES ", telemetry.size(), " key presses ", key.press_count, " sounder marks ", sounder.down_clicks_played)
	quit(0)
