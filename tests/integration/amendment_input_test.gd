extends SceneTree
## Real event dispatch at the modal boundary, plus independent deadline ownership.
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _key(code: Key, unicode: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
func check(ok: bool, message: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + message)
	if not ok: failures += 1
func _run() -> void:
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
	session._post_signal_elapsed = 4.0
	session.mark_transcript_verified()
	var editor := office.amendment_editor
	var interaction := office.player.get_node("InteractionController") as InteractionController
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if DisplayServer.get_name() == "headless":
		office.copy_commit_desk.select_option(0)
		check(editor.is_open(), "Headless fixture opens the editor without pretending mouse capture")
	else:
		# Windowed verification exercises the real ray and input activation.
		office.player.global_position = Vector3(0.95, 0, 0.45)
		var target := office.copy_commit_desk.get_node("Option1Interactable/CollisionShape3D") as Node3D
		var direction := target.global_position - office.player.camera.global_position
		office.player.rotation.y = atan2(-direction.x, -direction.z)
		office.player.head.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())
		await physics_frame
		interaction.refresh_prompt()
		check(interaction.current_target == target.get_parent(), "Production ray holds the amendment action")
		await _key(KEY_E, 101)
	await process_frame
	await process_frame
	await process_frame
	check(editor.is_open(), "Correction remains open after activation")
	check(editor.correction.text.is_empty(), "Opening activation is not entered into the draft")
	var deadline_before := session.get_post_signal_elapsed()
	await _key(KEY_E, 101)
	await process_frame
	check(editor.correction.text == "E", "While editing, E is text rather than interaction")
	check(not office.copy_commit_desk.has_committed(), "Typing never files behind the editor")
	await _key(KEY_ESCAPE)
	await process_frame
	await process_frame
	check(not editor.is_open() and not paused, "Escape puts down editor without pausing the world")
	check(is_equal_approx(session.get_post_signal_elapsed(), deadline_before), "Opening/cancelling never reset original t0")
	await process_frame
	await _key(KEY_1, 49)
	await process_frame
	check(not office.copy_commit_desk.has_committed(), "A remote number key still cannot file")
	office.copy_commit_desk.select_option(0)
	await process_frame
	await process_frame
	check(editor.correction.text == "E", "Cancel and reopen retain draft")
	editor.correction.text = "WAITER"
	editor.correction.text_changed.emit("WAITER")
	await _key(KEY_ENTER)
	await process_frame
	await process_frame
	check(office.copy_commit_desk.has_committed(), "Explicit Enter submits chosen correction")
	check(root.get_node("WorldState").get_fact(&"core_hook_filed_word") == "WAITER", "Enter preserves a wrong word exactly")
	check(not editor.is_open(), "Accepted submission closes the editor")
	for i in 5: await process_frame
	check(not interaction.is_ui_blocked and not office.player.is_look_locked, "After raw Enter, world controls cannot remain locked on a transition frame")
	office.queue_free()
	await process_frame
	print("Amendment input failures: ", failures)
	quit(1 if failures else 0)
