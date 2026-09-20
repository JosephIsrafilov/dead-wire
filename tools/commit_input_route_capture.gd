extends SceneTree

## B1 input-route evidence: the commit keys work through the REAL unprompted
## path — mouse look brings an option target under the crosshair, the raw key
## travels the input pipeline, the desk accepts, the press lands, the fact is
## in the world. Windowed on purpose: the ray and the captured mouse are the
## production conditions.

const OUT_DIR := "res://.dream-loop/commit_route"

var shots: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("COMMIT ROUTE: needs a window; run without --headless")
		quit(2)
		return

	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	var player := office.player
	var interaction := player.get_node("InteractionController") as InteractionController
	var session := office.session_controller
	var knowledge := root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	var world := root.get_node_or_null("WorldState") as WorldStateStore
	knowledge.reset_for_new_game()
	world.reset_for_new_game()
	office.shift_director.enabled = false
	session.allow_key_start = true
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	office.load_scenario_by_index(2)
	session.start_transmission()
	session.scheduler.auto_process = false
	session.scheduler.advance_time(60.0)
	var paper := office._get_transcript_paper()
	var guard := 0
	while paper.is_copy_in_progress() and guard < 400:
		paper.advance_paper(0.25)
		guard += 1
	session.mark_transcript_verified()
	await process_frame

	var desk := office.copy_commit_desk
	check(desk.is_enabled(), "Desk armed after verification")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Mouse captured the way the game captures it")

	# 0. The natural route: stand and walk to the commit desk. The key only
	# means anything with the ray actually holding a target at real range.
	Input.action_press("move_forward")
	var stand_wait := 0
	while office.operator_seat.is_seated and stand_wait < 300:
		await process_frame
		stand_wait += 1
	Input.action_release("move_forward")
	check(not office.operator_seat.is_seated, "The operator rose from the chair")
	var desk_side := Vector3(1.35, 0.0, 0.7)
	await _walk_to(player, desk_side)
	check(player.global_position.distance_to(desk_side) < 0.5, "The operator walked to the commit desk")

	# 1. Aim with the mouse until the ray holds the first option.
	var option1 := desk.get_node("Option1Interactable") as Interactable
	var shape1 := option1.get_node("CollisionShape3D") as CollisionShape3D
	await _aim_at(shape1.global_position)
	var hold := 0
	while interaction.current_target != option1 and hold < 240:
		await process_frame
		hold += 1
	check(interaction.current_target == option1, "The ray holds the WATER option under the crosshair")

	# 2. Raw key through the input pipeline.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	await process_frame
	check(desk.has_committed(), "Key 1 filed WATER through the real input pipeline")
	check(world.get_fact("core_hook_filed_water", false), "WATER world fact recorded")
	check(desk.is_press_in_flight(), "The press travels")
	var press_frames := 0
	while desk.is_press_in_flight() and press_frames < 120:
		await process_frame
		press_frames += 1
	check(not desk.is_press_in_flight(), "The press landed on the paper")
	var stamp := desk.get_node("OptionOneStamp") as Label3D
	check(stamp.visible and stamp.text == "FILED", "FILED ink shows on the filed copy")
	var voided := desk.get_node("OptionTwoStamp") as Label3D
	check(voided.visible and voided.text == "VOID", "The other copy is voided")
	var stamp_player := office.get_node("OfficeFoley/Stamp") as AudioStreamPlayer3D
	check(stamp_player.playing, "The stamp sound plays at the contact")

	await _shot("c1_commit_water_filed")
	office.queue_free()

	# 3. A key behind an open document files nothing (the gate, live).
	office = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	player = office.player
	interaction = player.get_node("InteractionController") as InteractionController
	session = office.session_controller
	knowledge = root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	world = root.get_node_or_null("WorldState") as WorldStateStore
	knowledge.reset_for_new_game()
	world.reset_for_new_game()
	office.shift_director.enabled = false
	session.allow_key_start = true
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	office.load_scenario_by_index(2)
	session.start_transmission()
	session.scheduler.auto_process = false
	session.scheduler.advance_time(60.0)
	paper = office._get_transcript_paper()
	guard = 0
	while paper.is_copy_in_progress() and guard < 400:
		paper.advance_paper(0.25)
		guard += 1
	session.mark_transcript_verified()
	desk = office.copy_commit_desk
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	Input.action_press("move_forward")
	var stand_wait2 := 0
	while office.operator_seat.is_seated and stand_wait2 < 300:
		await process_frame
		stand_wait2 += 1
	Input.action_release("move_forward")
	await _walk_to(player, desk_side)
	option1 = desk.get_node("Option1Interactable") as Interactable
	shape1 = option1.get_node("CollisionShape3D") as CollisionShape3D
	await _aim_at_player(player, shape1.global_position)
	hold = 0
	while interaction.current_target != option1 and hold < 240:
		await process_frame
		hold += 1
	check(interaction.current_target == option1, "The ray holds the option again")
	office.document_viewer.open_document("gate_doc", "TEST", "body")
	key = InputEventKey.new()
	key.physical_keycode = KEY_1
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	await process_frame
	check(not desk.has_committed() and not world.get_fact("core_hook_filed_water", false), "A key behind an open document files nothing")
	office.document_viewer.close_document()
	office.queue_free()

	print("COMMIT ROUTE: %d failures; %d screenshots" % [failures, shots])
	quit(1 if failures else 0)

func _aim_at(world_point: Vector3) -> void:
	await _aim_at_player(root.get_node("M1Office").player, world_point)

## Movement input only: the body walks there on its own legs.
func _walk_to(player: PlayerController, target: Vector3) -> void:
	Input.action_press("move_forward")
	var guard := 0
	while player.global_position.distance_to(Vector3(target.x, player.global_position.y, target.z)) > 0.4 and guard < 2400:
		guard += 1
		await process_frame
		await _aim_at_player(player, target)
	Input.action_release("move_forward")

func _aim_at_player(player: PlayerController, world_point: Vector3) -> void:
	var flat := Vector3(world_point.x - player.global_position.x, 0.0, world_point.z - player.global_position.z)
	var desired_yaw := atan2(-flat.x, -flat.z)
	var desired_pitch := atan2(world_point.y - player.camera.global_position.y, maxf(flat.length(), 0.001))
	for i in 160:
		var yaw_err: float = wrapf(desired_yaw - player.rotation.y, -PI, PI)
		var pitch_err: float = desired_pitch - player.head.rotation.x
		if absf(yaw_err) < 0.004 and absf(pitch_err) < 0.004:
			return
		_send_mouse(clampf(-yaw_err / player.mouse_sensitivity, -60.0, 60.0),
			clampf(-pitch_err / player.mouse_sensitivity, -60.0, 60.0))
		await process_frame

func _send_mouse(dx: float, dy: float = 0.0) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, dy)
	Input.parse_input_event(ev)

func _shot(label: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var image := root.get_texture().get_image()
	if image != null:
		check(image.save_png(OUT_DIR.path_join(label + ".png")) == OK, "Captured " + label)
		shots += 1

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
