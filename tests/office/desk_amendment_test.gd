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
	MainMenu.clear_state()
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
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
	if not _a(not desk.can_amend(), "Standing, the pen does not go to the paper"): return
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	await process_frame
	if not _a(desk.can_amend(), "Seated, the copy can be corrected"): return
	if not _a(desk.begin() and desk.writing, "The pen goes to the paper"): return
	if not _a(amendment.get_strike_count() > 0, "The copied lines are struck through"): return

	for letter in "WATER":
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
	if not _a(not desk.can_amend(), "One correction to a copy"): return

	# At the filing table, AMEND COPY files what is on the sheet; no box opens.
	if not _a(office.copy_commit_desk.commit_option(&"amend_copy"), "The table takes the amended copy"): return
	if not _a(not office.amendment_editor.is_open(), "No box opens for a correction already written"): return
	if not _a(session.get_resolved_outcome() == TelegraphScenarioData.OUTCOME_AMENDED_TRUE
		and session.get_filed_word() == "WATER", "The written word is the one filed"): return

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
