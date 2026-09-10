extends SceneTree

## Uses production scenes, raycasts and InputMap events. Rendering can be
## recorded with -- --capture; otherwise timers are advanced explicitly.
var office: M1OfficeController
var failures := 0
var capture := false
var branch := "water"
var screenshots := 0
var audio_recording: AudioEffectRecord
var output_folder := "res://.dream-loop/playthrough"

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if "--watcher" in OS.get_cmdline_user_args():
		branch = "watcher"
	elif "--lapsed" in OS.get_cmdline_user_args():
		branch = "lapsed"
	output_folder += "_" + branch
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Interactive playthrough needs a window. Run night_recovery_test.gd for headless branch coverage.")
		quit(1)
		return
	if capture:
		audio_recording = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, audio_recording)
		audio_recording.set_recording_active(true)
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu.begin_button.pressed.emit()
	await process_frame
	await process_frame
	office = current_scene as M1OfficeController
	check(office != null, "Title button enters production office")
	if office == null:
		quit(1)
		return
	office.get_node("IntroCard").skip_immediately()
	if not capture:
		office.shift_director.set_process(false)
		office.session_controller.scheduler.auto_process = false
		office.session_controller.set_process(false)
	await _shot("01_entry")
	# Read standing orders and ledger through the same ray and E action as play.
	await _interact_at(Vector3(1.2, 0, 1.1), office.get_node("DutySheet/Interactable"))
	check(office.document_viewer.is_open(), "Duty sheet opens through E")
	await _shot("02_orders")
	await _press("interact")
	await _interact_at(Vector3(-1.25, 0, -0.1), office.get_node("DispatchLedger/Interactable"))
	check(office.document_viewer.is_open(), "Ledger is reachable and readable")
	await _press("ui_cancel")
	await _interact_at(Vector3(-0.75, 0, -0.1), office.get_node("Chair/Interactable"))
	check(office.operator_seat.is_seated, "Chair is reachable through production ray")
	await create_timer(0.9).timeout
	await _aim_and_interact(office.session_controller.telegraph_key.get_interactable())
	check(office.shift_director.get_phase() == ShiftDirector.Phase.WAITING, "Seated key opens the watch")
	for slot in 3:
		if capture:
			await _until_call()
		else:
			office.shift_director.advance(office.shift_director.wait_seconds_before_call[slot] + 0.1)
		check(office.shift_director.get_phase() == ShiftDirector.Phase.CALLING, "Wire calls for slot %d" % slot)
		if not office.operator_seat.is_seated:
			await _interact_at(Vector3(-0.75, 0, -0.1), office.get_node("Chair/Interactable"))
			await create_timer(0.9).timeout
		await _aim_and_interact(office.session_controller.telegraph_key.get_interactable())
		check(office.session_controller.get_state() == TelegraphSessionController.State.RECEIVING, "E answers traffic %d" % slot)
		if slot == 0:
			await _press("ui_cancel")
			var before := office.session_controller.scheduler.get_elapsed_seconds()
			await create_timer(0.2, true).timeout
			check(paused and is_equal_approx(before, office.session_controller.scheduler.get_elapsed_seconds()), "Pause holds objective Morse clock")
			await _press("ui_cancel")
			check(not paused, "Escape resumes the same transmission")
		if capture:
			await create_timer(office.session_controller.scheduler.get_total_duration_seconds() * 0.5).timeout
			await _aim(office.session_controller.transcript_paper.get_interactable())
			await _shot("03_writing_%d" % slot)
			var timeout := 0.0
			while office.session_controller.get_state() == TelegraphSessionController.State.RECEIVING and timeout < 30:
				await create_timer(0.1).timeout
				timeout += 0.1
		else:
			office.session_controller.scheduler.advance_time(30.0)
		check(office.session_controller.get_state() == TelegraphSessionController.State.VERIFYING, "Traffic requires transcript inspection")
		await _aim_and_interact(office.session_controller.transcript_paper.get_interactable())
		check(office.document_viewer.is_open(), "Transcript lifts through E")
		if slot == 2:
			await _press("commit_option_1")
			check(not office.copy_commit_desk.has_committed(), "Number keys cannot file behind an open document")
		await _shot("04_transcript_%d" % slot)
		await _press("interact")
		check(not office.document_viewer.is_open(), "E puts the transcript down")
		if slot < 2:
			await _stand()
			await _interact_at(Vector3(1.4, 0, -0.75), office.routing_board.get_interactable())
			check(office.routing_board.is_open, "Routing board opens from reachable floor")
			await _shot("05_routing_%d" % slot)
			await _press("route_clear_east" if slot == 0 else "route_hold")
			check(office.shift_director.get_slot_index() == slot + 1, "Route advances night exactly once")
		else:
			await _press("commit_option_2")
			check(not office.copy_commit_desk.has_committed(), "Unseen filing desk rejects remote shortcut")
			await _stand()
			if branch == "lapsed":
				if capture:
					await create_timer(office.session_controller.commit_deadline_seconds + 0.1).timeout
				else:
					office.session_controller._process(office.session_controller.commit_deadline_seconds + 0.1)
				check(office.copy_commit_desk.get_result_text() == "UNFILED", "Unfiled deadline resolves without a selected copy")
			else:
				await _interact_at(Vector3(0.95, 0, 0.45), office.copy_commit_desk.get_node("Option2Interactable" if branch == "watcher" else "Option1Interactable"))
				check(office.copy_commit_desk.get_selected_action_id() == StringName("file_" + branch), "Physical %s paper commits through E" % branch)
			await _shot("06_filed")
	if capture:
		await create_timer(0.8).timeout
		await _aim(office.window_observation)
		await _shot("07_window")
		await create_timer(15.0).timeout
	else:
		office.session_controller.advance_consequence(1.0)
		await process_frame
		office.session_controller.advance_consequence(15.0)
		office.shift_director.advance(5.0)
	check(office.shift_director.is_shift_over(), "Final consequence reaches shift end")
	check(not office.office_door.is_locked(), "Dawn unlocks exit")
	await _interact_at(Vector3(0, 0, 1.2), office.dawn_evidence.get_interactable())
	check(office.dawn_evidence.is_inspected(), "Handover can be inspected")
	await _shot("08_handover")
	await _press("interact")
	await _interact_at(Vector3(-1.6, 0, 1.35), office.office_door.get_interactable())
	check(office.office_door.is_open, "Door opens after night")
	await create_timer(1.3).timeout
	# Walk across the actual trigger with collision enabled.
	office.player.rotation.y = PI
	office.player.head.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	await create_timer(0.7).timeout
	Input.action_release("move_forward")
	check(office.shift_end_card.is_running(), "Walking through threshold starts ending")
	await create_timer(3.1).timeout
	await _shot("09_ending")
	await _press("ui_cancel")
	check(not paused, "Ending cannot be covered by pause menu")
	office.shift_end_card.again_button.pressed.emit()
	await process_frame
	await process_frame
	office = current_scene as M1OfficeController
	check(office != null and office.shift_director.get_phase() == ShiftDirector.Phase.PRE_SHIFT, "Restart button creates a fresh watch")
	check(root.get_node("WorldState").snapshot().is_empty() and root.get_node("KnowledgeState").snapshot().is_empty(), "Restart clears both independent state stores")
	check(not office.window_observation.is_active and not office.copy_commit_desk.has_committed(), "Restart clears figure and filing presentation")
	if capture:
		audio_recording.set_recording_active(false)
		check(audio_recording.get_recording().save_to_wav(output_folder.path_join("watch_audio.wav")) == OK, "Recorded actual master audio")
	current_scene.queue_free()
	await process_frame
	print("PLAYTHROUGH: %d failures; %d screenshots" % [failures, screenshots])
	quit(1 if failures else 0)

func _until_call() -> void:
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		if office.shift_director.get_phase() == ShiftDirector.Phase.CALLING:
			return
		await process_frame

func _stand() -> void:
	Input.action_press("move_backward")
	await process_frame
	await process_frame
	Input.action_release("move_backward")
	await create_timer(0.7).timeout
	check(not office.operator_seat.is_seated, "Movement rises from chair")

func _interact_at(position: Vector3, target: Node3D) -> void:
	office.player.global_position = position
	office.player.velocity = Vector3.ZERO
	await physics_frame
	await _aim_and_interact(target)

func _aim(target: Node3D) -> void:
	var point := target.global_position
	var shape := target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		point = shape.global_position
	var direction := point - office.player.camera.global_position
	office.player.rotation.y = atan2(-direction.x, -direction.z)
	office.player.head.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())
	await physics_frame
	await process_frame

func _aim_and_interact(target: Node3D) -> void:
	await _aim(target)
	var interaction := office.player.get_node("InteractionController") as InteractionController
	interaction.refresh_prompt()
	if interaction.current_target == null:
		interaction.interaction_ray.force_raycast_update()
		print("RAY DIAGNOSTIC: mode=", Input.mouse_mode, " blocked=", interaction.is_ui_blocked, " from=", office.player.camera.global_position, " forward=", -office.player.camera.global_basis.z, " target=", target.global_position, " hit=", interaction.interaction_ray.get_collider())
	check(interaction.current_target == target, "Ray reaches %s (got %s)" % [target.name, interaction.current_target])
	await _press("interact")

func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _shot(label: String) -> void:
	if not capture:
		return
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output_folder)
	var image := root.get_texture().get_image()
	check(image.save_png(output_folder.path_join(label + ".png")) == OK, "Captured " + label)
	screenshots += 1
	print("RENDER FPS: ", Engine.get_frames_per_second())

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
