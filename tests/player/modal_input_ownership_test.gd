extends SceneTree
## Typing in the amendment editor must not move, stand, or walk the seated operator.
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, text: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok: failures += 1
func _release_all() -> void:
	for action in ["move_forward", "move_left", "move_backward", "move_right"]:
		Input.action_release(action)
func _walk_input_held() -> bool:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward").length_squared() > 0.01
func _run() -> void:
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	var seat := office.operator_seat
	seat.sit_duration = 0.0
	seat.approach_duration = 0.0
	check(seat.sit(), "Operator sits before editing")
	await process_frame
	var session := office.session_controller
	session.set_process(false)
	office.load_scenario_by_index(2)
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	check(office.copy_commit_desk.select_option(0), "AMEND opens through the real desk")
	await process_frame
	check(office.amendment_editor.is_open(), "Amendment editor is open")
	var before := office.player.global_transform
	for action in ["move_forward", "move_left", "move_backward", "move_right"]:
		Input.action_press(action)
		seat._process(0.016)
		check(seat.is_seated and office.player.global_transform.is_equal_approx(before), "Typed direction cannot leave seat: " + action)
		Input.action_release(action)

	# Closing frame: walk input is held when the editor closes, in the same frame.
	Input.action_press("move_forward")
	check(_walk_input_held(), "Closing frame holds a nonzero walk input")
	office.amendment_editor.close_editor(true)
	check(office.amendment_editor.owns_transition_frame(), "Closing frame is owned by the editor transition")
	check(office.is_world_view_blocked(), "Closing frame blocks the world view")
	check(not seat._player_wants_to_walk(), "Held walk input is ignored during the editor's closing frame")
	Input.action_release("move_forward")
	for i in 5: await process_frame
	check(not office.amendment_editor.owns_transition_frame(), "Transition ownership ends after the frame")
	Input.action_press("move_forward")
	check(_walk_input_held(), "Walk input is held after modal release")
	check(not office.is_world_view_blocked(), "World view is unblocked after modal release")
	check(seat._player_wants_to_walk(), "World walk becomes available after modal release")
	Input.action_release("move_forward")

	# Pause menu blocks walking while walk input is held.
	var pause_menu := office.get_node("PauseMenu") as PauseMenu
	Input.action_press("move_forward")
	check(pause_menu.pause(), "Pause menu opens")
	check(_walk_input_held() and office.is_world_view_blocked(), "Paused shift blocks the world view with walk held")
	check(not seat._player_wants_to_walk(), "Held walk input is ignored while paused")
	check(pause_menu.resume(), "Pause menu resumes")
	check(seat._player_wants_to_walk(), "Held walk input counts again after resume")
	Input.action_release("move_forward")

	# Running shift end card blocks walking while walk input is held.
	office.shift_end_card.play("TEST", "record")
	Input.action_press("move_forward")
	check(_walk_input_held() and office.is_world_view_blocked(), "Running end card blocks the world view with walk held")
	check(not seat._player_wants_to_walk(), "Held walk input is ignored while the end card runs")
	Input.action_release("move_forward")
	_release_all()
	office.queue_free()
	await process_frame
	quit(1 if failures else 0)
