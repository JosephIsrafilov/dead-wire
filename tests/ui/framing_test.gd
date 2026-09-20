extends SceneTree

## The frame around the game: what the player sees before the office, what
## Escape does, and what the wire says about the night once it is over.
##
## Before this pass the game opened with an unexplained man in a dark room and
## Escape did nothing but drop the mouse cursor, leaving the shift running behind
## an uncaptured pointer with no way back except clicking.

var _assertions_passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Framing Test Suite ---")

	# 1. Settings round-trip through disk.
	var settings := GameSettings.new()
	settings.mouse_sensitivity = 0.0042
	settings.head_bob_enabled = false
	settings.master_volume_db = -7.0
	settings.ambience_volume_db = -12.0
	if not assert_condition(settings.save() == OK, "Settings write to disk"): return

	var reloaded := GameSettings.load_settings()
	if not assert_condition(is_equal_approx(reloaded.mouse_sensitivity, 0.0042), "Sensitivity survives a reload"): return
	if not assert_condition(reloaded.head_bob_enabled == false, "Head bob choice survives a reload"): return
	if not assert_condition(is_equal_approx(reloaded.master_volume_db, -7.0), "Master volume survives a reload"): return
	if not assert_condition(is_equal_approx(reloaded.ambience_volume_db, -12.0), "Ambience volume survives a reload"): return

	var office := _office()
	if office == null: return
	var player := office.player

	# 2. Settings actually reach the things they name. Head bob in particular has
	#    to be the player's call, not an exported constant.
	reloaded.apply(player)
	if not assert_condition(is_equal_approx(player.mouse_sensitivity, 0.0042), "Sensitivity reaches the controller"): return
	if not assert_condition(player.head_bob_enabled == false, "Head bob toggle reaches the controller"): return
	var ambience_bus := AudioServer.get_bus_index("Ambience")
	if not assert_condition(ambience_bus >= 0, "Ambience bus exists"): return
	if not assert_condition(is_equal_approx(AudioServer.get_bus_volume_db(ambience_bus), -12.0), "Ambience volume reaches the bus"): return

	# Restore defaults so a test run does not leave the game quiet.
	var defaults := GameSettings.new()
	defaults.apply(player)
	defaults.save()

	# 3. The intro holds the player still until it is done.
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if not assert_condition(intro != null, "The game opens on an intro card"): return
	if not assert_condition(intro.is_running(), "The intro is running at scene start"): return
	if not assert_condition(intro.visible, "The intro is on screen"): return
	if not assert_condition(player.is_movement_locked and player.is_look_locked, "The operator cannot move or look during the intro"): return

	intro.skip_immediately()
	if not assert_condition(not intro.is_running() and intro.is_finished(), "The intro can be skipped"): return
	if not assert_condition(not intro.visible, "The intro clears the screen"): return
	if not assert_condition(not player.is_movement_locked and not player.is_look_locked, "Skipping hands control back"): return

	# 4. Escape holds the line rather than dropping the cursor.
	var pause_menu := office.get_node_or_null("PauseMenu") as PauseMenu
	if not assert_condition(pause_menu != null, "There is a pause menu"): return
	if not assert_condition(pause_menu.process_mode == Node.PROCESS_MODE_ALWAYS, "The pause menu still runs while the tree is paused"): return
	if not assert_condition(not pause_menu.is_paused and not pause_menu.visible, "It starts closed"): return

	pause_menu.pause()
	if not assert_condition(pause_menu.is_paused and pause_menu.visible, "Escape holds the line"): return
	if not assert_condition(root.get_tree().paused, "The shift actually stops"): return

	pause_menu.resume()
	if not assert_condition(not pause_menu.is_paused and not pause_menu.visible, "Resuming closes the menu"): return
	if not assert_condition(not root.get_tree().paused, "The shift runs again"): return

	# 5. A document in hand takes Escape first: put the paper down before you stop
	#    the shift.
	var viewer := office.document_viewer
	if not assert_condition(viewer != null, "Document viewer is wired"): return
	viewer.open_document("test_doc", "TEST", "body")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	pause_menu._input(escape)
	if not assert_condition(not pause_menu.is_paused, "Escape with a document open does not pause"): return
	viewer.close_document()
	pause_menu._input(escape)
	if not assert_condition(pause_menu.is_paused, "Escape with empty hands pauses"): return
	pause_menu.resume()

	# 5b. Escape with the routing board open: the board takes the key first.
	var board := office.routing_board
	if not assert_condition(board != null, "Routing board is wired"): return
	board.reset_for_new_transmission()
	board.set_awaiting_route(true)
	board.open_board()
	if not assert_condition(board.is_open, "Board opens while a route is pending"): return
	pause_menu._input(escape)
	if not assert_condition(not pause_menu.is_paused, "Escape with the board open does not pause"): return
	board._input(escape)
	if not assert_condition(not board.is_open, "Escape reaches the board and closes it"): return
	pause_menu._input(escape)
	if not assert_condition(pause_menu.is_paused, "Escape with the board closed pauses"): return
	pause_menu.resume()

	# 5c. E on an idle board is a no-op: no invisible modal, no locked movement.
	# The counter is a mutable array: a captured scalar would never change and
	# the check would pass even after a signal.
	board.reset_for_new_transmission()
	var opened_count: Array[int] = [0]
	board.board_opened.connect(func(): opened_count[0] += 1)
	board._on_interacted()
	if not assert_condition(not board.is_open, "E on an idle board opens nothing"): return
	if not assert_condition(opened_count[0] == 0, "Idle board emits no board_opened"): return
	if not assert_condition(not player.is_movement_locked, "Idle board leaves movement free"): return
	# Positive control: the same counter does increment on a real opening.
	board.set_awaiting_route(true)
	board._on_interacted()
	if not assert_condition(opened_count[0] == 1, "Awaiting board interaction emits exactly one board_opened"): return
	board.close_board()

	# 5d. A half-written transcript is not a readable document.
	var session := office.session_controller
	var paper := office._get_transcript_paper()
	if not assert_condition(session != null and paper != null, "Session and paper are wired"): return
	# Before any message, the pad is blank: no document, no fake read.
	office._process(0.0)
	if not assert_condition(paper.get_state() == TranscriptPaper.PaperState.EMPTY, "The pad starts EMPTY before the first message"): return
	if not assert_condition(paper.get_interactable().prompt_text == "No Copy Yet", "A blank pad reports no copy yet"): return
	if not assert_condition(not paper.get_interactable().is_actionable, "A blank pad offers no [E] read"): return
	paper.get_interactable().interact()
	if not assert_condition(not viewer.is_open(), "E on a blank pad opens no viewer"): return
	if not assert_condition(session.start_transmission(), "Transmission starts for the read-gate case"): return
	if not assert_condition(session.get_state() == TelegraphSessionController.State.RECEIVING, "Session is receiving"): return
	if not assert_condition(paper.is_copy_paused(), "A standing operator's hand leaves the sheet waiting"): return
	office._process(0.0)
	if not assert_condition(paper.get_interactable().prompt_text == "Return to the Chair to Finish the Copy", "Standing prompt tells the truth: finish the copy at the chair"): return
	if not assert_condition(not paper.get_interactable().is_actionable, "A half-written sheet offers no [E] read"): return
	paper.get_interactable().interact()
	if not assert_condition(not viewer.is_open(), "E on an actively written sheet opens no viewer"): return
	if not assert_condition(session.get_state() == TelegraphSessionController.State.RECEIVING, "Inspecting a partial sheet verifies nothing"): return
	session.reset_session()

	# 5d-2. Answering mid-sit does not start ink before the body arrives (R7).
	# The approach glides the capsule onto the seat; during that glide the
	# operator is neither seated nor settled.
	office.operator_seat.sit_duration = 0.05
	office.operator_seat.approach_duration = 0.05
	if not assert_condition(office.operator_seat.sit(), "Operator can sit back down"): return
	if not assert_condition(not office.operator_seat.is_settled(), "Sit starts with the body still travelling"): return
	office.load_scenario_by_index(0)
	if not assert_condition(session.start_transmission(), "A call answered mid-sit still starts the signal"): return
	if not assert_condition(paper.is_copy_paused(), "No ink while the body is still settling into the chair"): return
	# Let the approach and sit transition physically finish; sit_completed
	# resumes the sheet.
	var settle_guard := 0
	while not office.operator_seat.is_settled() and settle_guard < 120:
		await process_frame
		settle_guard += 1
	if not assert_condition(office.operator_seat.is_settled(), "The sit transition finishes"): return
	if not assert_condition(office.operator_seat.is_seated, "Approach ends seated at the chair"): return
	# The blank finishes feeding now that the hand has a seat to come back to,
	# then the arm enters and the ink resumes.
	paper.advance_paper(paper.feed_seconds + paper.get_writer_rig().enter_duration + 0.05)
	if not assert_condition(paper.is_writing(), "The hand resumes once the body has arrived"): return
	session.reset_session()
	office.operator_seat.stand()
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0

	# 5d-3. A deadline warning is readable behind an open document (R9).
	office.load_scenario_by_index(2)
	if not assert_condition(session.start_transmission(), "Warning-footer case starts a transmission"): return
	session.scheduler.advance_time(4.0)
	if not assert_condition(session.get_state() == TelegraphSessionController.State.COPYING, "Standing operator leaves the copy open at t0"): return
	viewer.open_document("test_doc", "TEST", "body")
	if not assert_condition(viewer.footer_label.text == "[E / Esc] Put Down Document", "The opened footer is the document's own"): return
	# Reach the grace-warning threshold on the real clock.
	session.advance_post_signal(session.unfinished_copy_grace_seconds - session.copy_grace_warning_seconds + 0.1)
	office._process(0.0)
	if not assert_condition(viewer.footer_label.text.begins_with("Finish the copy — the sender is waiting"), "The open document's footer carries the warning"): return
	if not assert_condition(viewer.get_current_doc_id() == "test_doc", "The warning updates the footer without reopening the document"): return
	if not assert_condition(viewer.body_label.text == "body", "The warning never touches the document body"): return
	# Let the grace expire: the situation resolves and the footer must recover.
	session.advance_post_signal(session.copy_grace_warning_seconds)
	office._process(0.0)
	if not assert_condition(session.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Grace expiry resolves the slot"): return
	if not assert_condition(viewer.footer_label.text == "[E / Esc] Put Down Document", "A resolved warning restores the opened footer"): return
	viewer.close_document()
	session.reset_session()

	# 5e. One definition of a world-hidden-by-UI, pause included (R4).
	if not assert_condition(not office.is_world_view_blocked(), "Nothing covering the world"): return
	viewer.open_document("test_doc", "TEST", "body")
	if not assert_condition(office.is_world_view_blocked(), "An open document blocks the world view"): return
	viewer.close_document()
	board.set_awaiting_route(true)
	board.open_board()
	if not assert_condition(office.is_world_view_blocked(), "An open board blocks the world view"): return
	board.close_board()
	pause_menu.pause()
	if not assert_condition(office.is_world_view_blocked(), "A paused shift blocks the world view"): return
	pause_menu.resume()
	if not assert_condition(not office.is_world_view_blocked(), "Closing the surfaces and resuming restores the view"): return

	# 5f. Escape through real engine dispatch, in both subscription orders:
	# the key must close exactly one surface per press regardless of which
	# node hears it first.
	for order in ["default", "reversed"]:
		if order == "reversed":
			office.move_child(pause_menu, 0)
		board.reset_for_new_transmission()
		board.set_awaiting_route(true)
		board.open_board()
		if not assert_condition(board.is_open, "Board opens for the %s-order Escape case" % order): return
		root.push_input(_esc_event())
		if not assert_condition(not board.is_open, "%s order: engine-dispatched Escape closes the board" % order): return
		if not assert_condition(not pause_menu.is_paused, "%s order: closing the board does not pause" % order): return
		root.push_input(_esc_event())
		if not assert_condition(pause_menu.is_paused, "%s order: Escape with the board closed pauses" % order): return
		root.push_input(_esc_event())
		if not assert_condition(not pause_menu.is_paused, "%s order: Escape while paused resumes" % order): return
	if office.get_child(pause_menu.get_index()) != pause_menu:
		pass # move_child already restored nothing; ensure original order below.
	# Restore the authored node order for the rest of the suite.
	office.move_child(pause_menu, office.get_child_count() - 1)

	# 6. The controls the menu offers are the ones that exist.
	if not assert_condition(pause_menu.sensitivity_slider != null, "Sensitivity is adjustable"): return
	if not assert_condition(pause_menu.head_bob_check != null, "Head bob is toggleable by the player"): return
	if not assert_condition(pause_menu.master_slider != null and pause_menu.ambience_slider != null, "Both volumes are adjustable"): return
	if not assert_condition(pause_menu.resume_button != null and pause_menu.quit_button != null, "Resume and quit exist"): return

	# 7. The wire answers for the night. A clean watch is signed off; a watch with
	#    a hole in it gets asked where the train is. This is the objective world
	#    replying — Elias's own paperwork never learns it.
	var director := office.shift_director
	if not assert_condition(not director.had_trouble(), "A shift with nothing gone wrong reports no trouble"): return
	director.messages_missed = 1
	if not assert_condition(director.had_trouble(), "A missed message counts as trouble"): return
	director.messages_missed = 0
	director.routes_defaulted = 1
	if not assert_condition(director.had_trouble(), "A lapsed route counts as trouble"): return
	director.routes_defaulted = 0
	director.routes_misdirected = 1
	if not assert_condition(director.had_trouble(), "A wrong route counts as trouble"): return

	var encoder := AmericanMorseEncoder.new()
	if not assert_condition(encoder.encode(director.closing_sign, director.alphabet) != null, "The clean sign-off is sendable American Morse"): return
	if not assert_condition(encoder.encode(director.closing_sign_trouble, director.alphabet) != null, "The trouble query is sendable American Morse"): return
	if not assert_condition(director.closing_sign != director.closing_sign_trouble, "The two nights do not sound the same"): return

	# 8. Elias can see the gap in his own paperwork without learning what it cost.
	var sheet := office.get_node_or_null("DutySheet") as DutySheet
	if not assert_condition(sheet != null, "Duty sheet is present"): return
	var text := sheet.get_sheet_text()
	if not assert_condition(text.contains("Not every item on this sheet is closed"), "An unfinished sheet says so"): return
	if not assert_condition(not text.contains("missed") and not text.contains("WATER"), "It still never reports what actually happened"): return

	print("--- All Framing Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

## A fresh Escape press, as the OS would deliver it.
func _esc_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = false
	return event

func _office() -> M1OfficeController:
	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not assert_condition(scene != null, "m1_office.tscn loads"): return null
	var office: M1OfficeController = scene.instantiate() as M1OfficeController
	if not assert_condition(office != null, "Office instantiates"): return null
	root.add_child(office)
	office.session_controller.scheduler.auto_process = false
	office.shift_director.set_process(false)
	return office

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	if root != null and root.get_tree() != null:
		root.get_tree().paused = false
	quit(1)
	return false
