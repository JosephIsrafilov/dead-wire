extends SceneTree
## Mouse button submit must not click the world after closing the paper.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280, 720)
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	var session := office.session_controller
	session.set_process(false)
	office.load_scenario_by_index(2)
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	office.copy_commit_desk.select_option(0)
	await process_frame
	await process_frame
	var editor := office.amendment_editor
	editor.correction.text = "WAITER"
	editor.correction.text_changed.emit("WAITER")
	var button := editor.submit_button
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	var ok: bool = office.copy_commit_desk.has_committed() and not editor.is_open() \
		and root.get_node("WorldState").get_fact(&"core_hook_filed_word") == "WAITER"
	print(("  PASS: " if ok else "  FAIL: ") + "Pointer submission closes paper and files only its exact word")
	for i in 5: await process_frame
	var released := not office.player.is_look_locked and not (office.player.get_node("InteractionController") as InteractionController).is_ui_blocked
	print(("  PASS: " if released else "  FAIL: ") + "Closing pointer event cannot leave control ownership trapped")
	ok = ok and released
	office.queue_free()
	await process_frame
	quit(0 if ok else 1)
