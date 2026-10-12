extends SceneTree
var assertions := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, description: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + description)
	if not ok: quit(1); return false
	assertions += 1
	return true
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
	session.mark_transcript_verified()
	var desk := office.copy_commit_desk
	var editor := office.get_node_or_null("AmendmentEditor")
	if not check(editor != null, "Production office includes correction editor"): return
	if not check(desk.select_option(0), "Physical amendment action expresses edit intent"): return
	if not check(editor.call("is_open") and not desk.has_committed(), "Amend opens a draft, not an automatic WATER filing"): return
	if not check(office.player.is_movement_locked and office.player.is_look_locked, "Draft locks world movement/look"): return
	var interaction := office.player.get_node("InteractionController") as InteractionController
	if not check(interaction.is_ui_blocked and office.is_world_view_blocked(), "Draft blocks world actions and observation"): return
	if not check(session.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "Editing leaves authoritative decision pending"): return
	var pause_menu := office.get_node("PauseMenu") as PauseMenu
	if not check(not pause_menu.pause() and not paused, "Active editor also rejects programmatic pause acquisition"): return
	var input := editor.get_node("CenterContainer/Panel/Margin/VBox/Correction") as LineEdit
	input.text = "WAITER"
	input.text_changed.emit(input.text)
	editor.call("submit_draft")
	if not check(desk.has_committed() and session.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Submit passes exact text through office to session and desk"): return
	if not check(not editor.call("is_open"), "Accepted filing closes draft"): return
	if not check(root.get_node("WorldState").get_fact(&"core_hook_filed_word") == "WAITER", "Production stores actual wrong choice unchanged"): return
	await process_frame
	await process_frame
	if not check(not interaction.is_ui_blocked, "World controls return after transition event is consumed"): return
	session.reset_session()
	office.load_scenario_by_index(2)
	session._state = TelegraphSessionController.State.VERIFYING
	session._post_signal_elapsed = 3.0
	session.mark_transcript_verified()
	desk.select_option(0)
	if not check(editor.call("is_open"), "A later unfinished amendment opens normally"): return
	session.advance_post_signal(session.commit_deadline_seconds)
	if not check(not editor.call("is_open") and desk.get_result_text() == "UNFILED", "Original deadline closes editing into honest unfiled outcome"): return
	await process_frame
	await process_frame
	if not check(not interaction.is_ui_blocked and not office.player.is_look_locked, "Timeout releases modal control locks once"): return
	office.queue_free()
	await process_frame
	print("Amendment integration assertions: ", assertions)
	quit(0)
