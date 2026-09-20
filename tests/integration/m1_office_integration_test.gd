extends SceneTree

func _init() -> void:
	print("--- Starting M1 Office Full Integration Test (M1 Final Acceptance Correction Gate) ---")

	# Set up Autoloads if missing in headless runner
	var world: WorldStateStore = root.get_node_or_null("WorldState") as WorldStateStore
	if world == null:
		world = WorldStateStore.new()
		world.name = "WorldState"
		root.add_child(world)

	var knowledge: KnowledgeStateStore = root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge == null:
		knowledge = KnowledgeStateStore.new()
		knowledge.name = "KnowledgeState"
		root.add_child(knowledge)

	# 1. Load and instantiate main production office scene
	var office_scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not assert_condition(office_scene != null, "m1_office.tscn loads"): return
	var office: M1OfficeController = office_scene.instantiate() as M1OfficeController
	if not assert_condition(office != null and office is M1OfficeController, "m1_office instantiates as M1OfficeController"): return
	root.add_child(office)

	await process_frame
	await process_frame

	# Ensure scheduler does not auto-advance in pure step test
	office.session_controller.scheduler.auto_process = false

	# This suite covers the manual key-driven session API. Shift pacing is a
	# separate layer with its own suite, so stand the director down here.
	office.shift_director.enabled = false
	office.session_controller.allow_key_start = true
	# The hand only writes from the chair. Seat the operator so the copy is
	# physical, then drive it through the paper's presentation tick.
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	var paper := office.get_node_or_null("TranscriptPaper") as TranscriptPaper
	# The intro card is a world-covering surface; this suite inspects the night
	# long after a real operator has dismissed it.
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null and intro.is_running():
		intro.skip_immediately()
	office.load_scenario_by_index(0)

	# Track cycle completion signals
	var cycle_completed_fired: Array[int] = [0]
	office.scenario_cycle_completed.connect(func(): cycle_completed_fired[0] += 1)

	var key := office.session_controller.telegraph_key
	var key_act := key.get_interactable()
	var board := office.routing_board
	var board_act := board.get_interactable()
	var paper_act := paper.get_interactable()
	var card := office.get_node_or_null("MorseReferenceCard") as MorseReferenceCard
	var card_act := card.get_interactable()
	var ledger := office.get_node_or_null("DispatchLedger") as DispatchLedger
	var ledger_act := ledger.get_interactable()
	var viewer := office.document_viewer

	# 2. DOCUMENT REPEATED OPENING TEST (No toggle desync)
	# Test MorseReferenceCard repeated open
	card_act.interact()
	if not assert_condition(viewer.is_open(), "1st interaction with MorseReferenceCard opens DocumentViewer"): return
	if not assert_condition(viewer.get_current_doc_id() == "morse_reference", "Viewer doc_id is morse_reference"): return
	if not assert_condition(viewer.body_label.text == card.get_reference_text(), "Viewer body is the real MorseReferenceCard text"): return
	if not assert_condition(["A", "C", "D", "E", "F", "G", "H", "I", "L", "N", "O", "R", "S", "T", "U", "W", "1", "7"].all(func(character: String) -> bool: return viewer.body_label.text.contains(character)), "Viewer Morse reference contains all 18 M1 characters"): return
	viewer.close_document()
	if not assert_condition(not viewer.is_open(), "DocumentViewer closes"): return
	card_act.interact()
	if not assert_condition(viewer.is_open(), "2nd interaction with MorseReferenceCard opens DocumentViewer immediately"): return
	viewer.close_document()

	# Test DispatchLedger repeated open
	ledger_act.interact()
	if not assert_condition(viewer.is_open(), "1st interaction with DispatchLedger opens DocumentViewer"): return
	if not assert_condition(viewer.get_current_doc_id() == "dispatch_ledger", "Viewer doc_id is dispatch_ledger"): return
	if not assert_condition(viewer.body_label.text.contains("NIGHT ENTRIES"), "Ledger carries the live NIGHT ENTRIES section"): return
	if not assert_condition(viewer.body_label.text.contains(DutySheet.STATUS_AWAITING), "Before any traffic the booked slots are honestly awaiting"): return
	if not assert_condition(not viewer.body_label.text.contains("COPIED"), "Before any traffic nothing claims work was done"): return
	if not assert_condition(not viewer.body_label.text.contains("UNSCHEDULED"), "Unbooked traffic stays off the paper until the night produces it"): return
	viewer.close_document()
	if not assert_condition(not viewer.is_open(), "DocumentViewer closes"): return
	ledger_act.interact()
	if not assert_condition(viewer.is_open(), "2nd interaction with DispatchLedger opens DocumentViewer immediately"): return
	viewer.close_document()

	# 3. SCENARIO 1: BASELINE (TRAIN 17 CLEAR EAST)
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	office.load_scenario_by_index(0)

	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.READY, "Scenario 1 starts in READY state"): return
	if not assert_condition(key.prompt_message == "Press Key (Answer Line)", "Key prompt is 'Press Key (Answer Line)'"): return
	if not assert_condition(key_act.is_actionable, "Key is actionable in READY state"): return

	# Start Scenario 1 transmission via key interact
	key_act.interact()
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.RECEIVING, "Transmission is RECEIVING"): return
	if not assert_condition(not key.is_enabled, "Key physically disabled while receiving"): return
	if not assert_condition(not key_act.is_actionable, "Key is not actionable while receiving (status only)"): return

	# Advance time through 13.60s (TRAIN 17 schedule duration)
	office.session_controller.scheduler.advance_time(14.0)
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.COPYING, "t0 with a live sheet lands in COPYING"): return
	_drain_paper(paper)
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.VERIFYING, "Transmission end waits for transcript verification"): return

	# Test TranscriptPaper repeated open with revealed message
	paper_act.interact()
	if not assert_condition(viewer.is_open(), "1st interaction with TranscriptPaper opens DocumentViewer"): return
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.AWAITING_ROUTE, "Transcript inspection unlocks routing"): return
	if not assert_condition(viewer.body_label.text == "TRAIN 17 CLEAR EAST", "Viewer displays 'TRAIN 17 CLEAR EAST'"): return
	viewer.close_document()
	if not assert_condition(not viewer.is_open(), "DocumentViewer closes"): return
	paper_act.interact()
	if not assert_condition(viewer.is_open(), "2nd interaction with TranscriptPaper opens DocumentViewer immediately"): return
	viewer.close_document()

	# Player opens Routing Board and sends Key 1 via InputEventKey
	board_act.interact()
	if not assert_condition(board.is_open, "Routing Board is open via interact()"): return
	if not assert_condition(board.is_awaiting_route, "Routing Board is_awaiting_route is true"): return
	var player_interaction := office.player.get_node_or_null("InteractionController") as InteractionController
	if not assert_condition(office.player.is_movement_locked and office.player.is_look_locked, "Routing Board locks player movement and look while open"): return
	if not assert_condition(player_interaction != null and player_interaction.is_ui_blocked, "Routing Board blocks world interactions while open"): return

	var ev_clear_east := InputEventKey.new()
	ev_clear_east.physical_keycode = KEY_1
	ev_clear_east.pressed = true
	ev_clear_east.echo = false
	var ev_clear_east_echo := InputEventKey.new()
	ev_clear_east_echo.physical_keycode = KEY_1
	ev_clear_east_echo.pressed = true
	ev_clear_east_echo.echo = true
	board._input(ev_clear_east_echo)
	if not assert_condition(board.is_open and not board.has_submitted_this_session, "Routing Board ignores echoed route input"): return
	board._input(ev_clear_east)

	if not assert_condition(not board.is_open, "Routing Board closed after selection"): return
	if not assert_condition(not office.player.is_look_locked and office.player.is_movement_locked, "Seated operator keeps walk lock but regains look on board close"): return
	if not assert_condition(player_interaction != null and not player_interaction.is_ui_blocked, "Closing Routing Board restores world interactions"): return
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.COMPLETE, "Routing decision 1 completes Scenario 1"): return
	# The ledger records what the operator actually sent tonight (Q6c). This
	# suite stands the director down, so the copied_ fact never lands; the
	# ledger honestly files the order without claiming the copy status.
	ledger_act.interact()
	if not assert_condition(viewer.body_label.text.contains("TRAIN 17") and viewer.body_label.text.contains("FILED    CLEAR EAST"), "Ledger night entries record the filed CLEAR EAST order"): return
	viewer.close_document()
	if not assert_condition(world.get_fact("train_17_routed_clear") == true, "WorldState recorded train_17_routed_clear = true"): return
	board_act.interact()
	if not assert_condition(not board.is_open and not office.player.is_look_locked, "Repeated routed-board interaction cannot open stale modal or lock the seated operator's look"): return

	# 4. SCENARIO 2: ATTENTION (HOLD FREIGHT UNTIL TEN + 3 Door Footsteps)
	key_act.interact()
	await process_frame

	if not assert_condition(office.get_current_scenario_index() == 1, "Current scenario index is 1 (Scenario 2)"): return
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.READY, "Scenario 2 is in READY state"): return

	key_act.interact()
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.RECEIVING, "Scenario 2 transmission starts"): return

	# Advance 4.5s -> Door footsteps trigger via hitch-proof signal
	office.session_controller.scheduler.advance_time(4.5)
	if not assert_condition(office.door_attention.is_active, "Door attention active after 4.0s"): return
	if not assert_condition(office.door_attention.steps_played == 1, "Step 1 played immediately"): return

	# Step 2 and 3
	office.door_attention._process(0.6)
	if not assert_condition(office.door_attention.steps_played == 2, "Step 2 played"): return
	office.door_attention._process(0.6)
	if not assert_condition(office.door_attention.steps_played == 3, "Exactly 3 footsteps played"): return
	if not assert_condition(not office.door_attention.is_active, "Door attention is completed and inactive"): return

	# Complete transmission (total 15.60s) - proving Morse scheduler progressed
	office.session_controller.scheduler.advance_time(12.0)
	_drain_paper(paper)
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.VERIFYING, "Scenario 2 waits for transcript verification"): return
	paper_act.interact()
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.AWAITING_ROUTE, "Scenario 2 transcript inspection unlocks routing"): return
	viewer.close_document()

	# Open board and route HOLD via InputEventKey 2
	board_act.interact()
	var ev_hold := InputEventKey.new()
	ev_hold.physical_keycode = KEY_2
	ev_hold.pressed = true
	ev_hold.echo = false
	board._input(ev_hold)

	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.COMPLETE, "Routing decision 2 completes Scenario 2"): return
	if not assert_condition(world.get_fact("freight_held_correctly") == true, "WorldState recorded freight_held_correctly = true"): return

	# 5. SCENARIO 3: CORE HOOK & GENUINE WINDOW ATTENTION
	key_act.interact()
	await process_frame

	if not assert_condition(office.get_current_scenario_index() == 2, "Current scenario index is 2 (Scenario 3)"): return
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.READY, "Scenario 3 is in READY state"): return

	# Set player facing the telegraph desk (West)
	office.player.position = Vector3(0, 0, 0)
	office.player.rotation.y = deg_to_rad(90.0) # Facing West

	office.session_controller.sounder.reset_telemetry()
	key_act.interact()
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.RECEIVING, "Scenario 3 transmission starts"): return

	# Advance 1.0s: the window figure is deferred until the consequence beat.
	office.session_controller.scheduler.advance_time(1.0)
	# The consequence figure is deliberately absent while the signal is arriving.
	if not assert_condition(not office.window_observation.is_active, "Window figure is inactive during RECEIVING"): return
	if not assert_condition(world.get_fact("window_event_occurred") != true, "Window event fact is not recorded during RECEIVING"): return

	# Complete transmission (total 3.60s), then prove stale commit input is ignored.
	office.session_controller.scheduler.advance_time(3.0)
	_drain_paper(paper)
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.VERIFYING, "Scenario 3 waits for transcript verification"): return
	if not assert_condition(not office.copy_commit_desk.is_enabled(), "Commit desk is disabled before inspection"): return
	if not assert_condition(not office.session_controller.submit_commit(&"file_water"), "Commit before inspection is ignored"): return

	# Prove layer separation: Sounder WATER (10 clicks) -> Paper WATCHER
	var scen3 := office.session_controller.get_current_scenario()
	if not assert_condition(scen3.transmission_data.true_message == "WATER", "TransmissionData true_message is WATER"): return
	if not assert_condition(scen3.transmission_data.elias_perception == "WATER", "TransmissionData elias_perception is WATER"): return
	if not assert_condition(scen3.transmission_data.written_transcript == "WATCHER", "TransmissionData written_transcript is WATCHER"): return
	if not assert_condition(office.session_controller.sounder.down_clicks_played == 10, "Sounder played exactly 10 clicks for WATER"): return

	# Inspect final transcript in viewer
	paper_act.interact()
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "Transcript inspection unlocks commit desk"): return
	if not assert_condition(office.copy_commit_desk.is_enabled(), "Commit desk is enabled after inspection"): return
	if not assert_condition(viewer.body_label.text == "WATCHER", "Transcript paper displays WATCHER"): return
	viewer.close_document()

	# Unknown input and double input cannot alter the authored commit.
	if not assert_condition(not office.session_controller.submit_commit(&"stale_action"), "Unknown commit action is ignored"): return
	if not assert_condition(office.copy_commit_desk.commit_option(&"file_watcher"), "Valid WATCHER commit is accepted"): return
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Valid commit enters CONSEQUENCE"): return
	if not assert_condition(world.get_fact("core_hook_filed_watcher") == true, "WorldState records core_hook_filed_watcher"): return
	if not assert_condition(knowledge.knows("committed_watcher_core_hook"), "KnowledgeState records committed_watcher_core_hook"): return
	if not assert_condition(not office.copy_commit_desk.commit_option(&"file_water"), "Second commit input is ignored"): return

	# The neutral figure starts only after the recovery delay and remains observable
	# for the consequence hold, independent of which copy was filed.
	office.session_controller.advance_consequence(1.0)
	if not assert_condition(office.window_observation.is_active and office.window_observation.get_visual_indicator().visible, "Window figure starts after commit recovery delay"): return
	office.player.rotation.y = deg_to_rad(0.0) # Face North
	await process_frame
	if not assert_condition(office.window_observation.is_observed, "Camera looking through window opening observes post-commit figure"): return
	if not assert_condition(knowledge.knows("saw_window_event"), "KnowledgeState records saw_window_event after post-commit figure"): return
	office.session_controller.advance_consequence(office.scenario_3.consequence_hold_seconds)
	if not assert_condition(office.session_controller.get_state() == TelegraphSessionController.State.COMPLETE, "Consequence hold is required before Scenario 3 completes"): return

	# 6. CYCLE COMPLETION
	if not assert_condition(cycle_completed_fired[0] == 1, "scenario_cycle_completed emitted exactly once"): return
	if not assert_condition(office.is_cycle_completed(), "is_cycle_completed() is true"): return
	if not assert_condition(key.prompt_message == "M1 Cycle Complete", "Key prompt indicates 'M1 Cycle Complete'"): return
	if not assert_condition(not key.is_enabled, "Key physical press is disabled after full cycle completion"): return

	# Clean up
	office.queue_free()

	print("--- All M1 Office Full Integration Tests PASSED ---")
	quit(0)

func _drain_paper(p: TranscriptPaper) -> void:
	var guard := 0
	while p.is_copy_in_progress() and guard < 400:
		p.advance_paper(0.25)
		guard += 1

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
