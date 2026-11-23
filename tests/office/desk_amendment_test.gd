extends SceneTree
## Plan 6.3: a correction is the hand's work at the desk. Seated with a copy
## awaiting filing, the operator takes the pen to the sheet: the copied lines
## are struck, the typed word is written beneath them by Elias's hand — ink
## only on the rig's contact — and the filing table files what is written,
## with no box opened for it.
##   godot --headless --audio-driver Dummy --path . --script tests/office/desk_amendment_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Desk Amendment Test Suite ---")
	GameLocale.lock_language_for_test("en")
	MainMenu.clear_state()
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.set_process(false)
	var session := office.session_controller
	session.set_process(false)
	session.scheduler.auto_process = false
	var desk := office.get_node_or_null("DeskAmendment") as DeskAmendment
	if not _a(desk != null, "The office lets the hand correct the copy"): return
	await process_frame
	var paper := session.transcript_paper
	var amendment := paper.get_amendment()
	var rig := paper.get_writer_rig()
	if not _a(amendment != null and desk.get_target() != null, "The sheet has a place for a correction and a target for the pen"): return

	# The third copy, written and read, waiting to be filed.
	office.load_scenario_by_index(2)
	paper.set_transcript_text("WATCHER")
	paper.reveal_transcript()
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	if not _a(session.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "The copy waits to be filed"): return
	if not _a(not office.copy_commit_desk.select_option(0) and not office.amendment_editor.is_open(),
		"The filing table requires a written correction before it can seal one"): return
	if not _a(not desk.can_amend(), "Standing, the pen does not go to the paper"): return
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	await process_frame
	if not _a(desk.can_amend(), "Seated, the copy can be corrected"): return
	if not _a(desk.begin() and desk.writing, "The pen goes to the paper"): return
	if not _a(amendment.get_strike_count() > 0, "The copied lines are struck through"): return

	Input.action_press("move_forward")
	desk._input(_key(KEY_W))
	for _frame in 4:
		await process_frame
	Input.action_release("move_forward")
	if not _a(office.operator_seat.is_seated and desk.writing and amendment.word == "W",
		"W types a letter without standing from the chair"): return
	for letter in "ATER":
		desk._input(_key(OS.find_keycode_from_string(letter)))
	if not _a(amendment.word == "WATER" and amendment.get_written_text().is_empty(),
		"Typing is a buffer: no ink lands on the keypress"): return
	var contacts: Array = []
	rig.glyph_contact.connect(func(index: int) -> void: contacts.append(index))
	for _step in 120:
		desk.advance(0.05)
	if not _a(amendment.get_written_text() == "WATER" and contacts == [0, 1, 2, 3, 4],
		"The hand writes the correction glyph by glyph, ink on each contact"): return
	desk._input(_key(KEY_ENTER))
	for _step in 20:
		desk.advance(0.05)
	if not _a(not desk.writing and desk.get_pending("core_hook_water_watcher") == "WATER",
		"Enter leaves the correction standing on the sheet"): return
	if not _a(desk.can_amend(), "An unfiled correction stays available for revision"): return

	# Reading and putting down the sheet must preserve the actual correction.
	office._on_transcript_inspected(paper.get_display_text())
	var shown := office.document_viewer.get_node_or_null("TranscriptSheet/AmendmentInk") as Label
	if not _a(shown != null and shown.text == "WATER", "The lifted sheet shows its inked correction"): return
	if not _a(not session._commit_resolved, "Reading a correction is not filing it"): return
	office.document_viewer.close_document()
	office.document_viewer._finish_put_down()
	office._on_transcript_inspected(paper.get_display_text())
	shown = office.document_viewer.get_node_or_null("TranscriptSheet/AmendmentInk") as Label
	if not _a(shown.text == "WATER" and amendment.get_strike_count() > 0,
		"Putting down and reopening preserves the word and struck original"): return
	office.document_viewer.close_document()
	office.document_viewer._finish_put_down()
	var prompt := office.player.get_node("InteractionController") as InteractionController
	if not _a(desk.begin(), "An unfiled correction can be reopened for review"): return
	if not _a(not prompt.persistent_hint.is_empty(), "Writing mode explains its keyboard controls"): return
	desk.cancel()
	if not _a(desk.get_pending("core_hook_water_watcher") == "WATER" and amendment.get_written_text() == "WATER",
		"Cancelling a reopened correction restores the saved unfiled word"): return
	# At the filing table, AMEND COPY files what is on the sheet; no box opens.
	if not _a(office.copy_commit_desk.commit_option(&"amend_copy"), "The table takes the amended copy"): return
	if not _a(not office.amendment_editor.is_open(), "No box opens for a correction already written"): return
	if not _a(session.get_resolved_outcome() == TelegraphScenarioData.OUTCOME_AMENDED_TRUE
		and session.get_filed_word() == "WATER", "The written word is the one filed"): return
	if not _a(not office.copy_commit_desk.commit_option(&"amend_copy"),
		"Filing the same correction twice is refused"): return

	session.reset_session()
	office.load_scenario_by_index(2)
	session._state = TelegraphSessionController.State.VERIFYING
	session._post_signal_elapsed = 0.0
	session.mark_transcript_verified()
	if not _a(desk.begin(), "The pen can edit the current copy before its deadline"): return
	desk._input(_key(KEY_A))
	session.advance_post_signal(session.get_commit_deadline_seconds() + 1.0)
	if not _a(not desk.writing and not office.player.is_look_locked and office.operator_seat.is_seated
		and office.copy_commit_desk.get_result_text() == "UNFILED",
		"A deadline puts away the pen, releases look, and leaves the copy unfiled"): return

	office.queue_free()
	for _frame in 5:
		await process_frame
	print("--- All Desk Amendment Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
