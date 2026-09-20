extends SceneTree

## B1: the commit desk never decides the outcome. Intent goes in, the session
## answers, and only the accepted result may stamp the surface or make sound.
## Cases run against the production office wiring (desk -> office ->
## session -> commit_resolved -> desk).
##
## Input-reachability note: the desk's own _input gate requires a captured
## mouse and the interaction ray holding one of the desk's option targets, so
## this suite stages `current_target` the way a aimed ray would. The
## full unprompted key path (mouse look -> ray -> key) is proven windowed in
## tools/commit_input_route_capture.gd; this file proves the contract.

var _assertions_passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Copy Commit Desk Test Suite ---")
	var knowledge := root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	var world := root.get_node_or_null("WorldState") as WorldStateStore
	if not assert_condition(knowledge != null and world != null, "State autoloads available"): return

	# --- 1. Boundary: intent AT the expired deadline is rejected, and the
	# surface never lies about it (the B1 probe case, now asserted).
	var office := await _armed_office()
	knowledge.reset_for_new_game()
	world.reset_for_new_game()
	var session := office.session_controller
	var desk := office.copy_commit_desk
	if not assert_condition(desk.is_enabled(), "Desk is armed after verification"): return
	if not assert_condition(session.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "Session awaits the commit"): return

	# Park the clock exactly on the deadline, then express intent through the
	# desk's own API (same path _input uses) before the next process tick.
	session._post_signal_elapsed = session.commit_deadline_seconds
	var stamp_player := office.get_node("OfficeFoley/Stamp") as AudioStreamPlayer3D
	var accepted_events: Array[StringName] = []
	desk.commit_accepted.connect(func(id: StringName) -> void: accepted_events.append(id))
	var requested := desk.commit_option(&"file_water")
	if not assert_condition(requested, "The intent itself is expressed"): return
	if not assert_condition(not desk.has_committed(), "A rejected intent does not commit the desk"): return
	if not assert_condition(desk.get_result_text() == "", "No filed result text appears, got '%s'" % desk.get_result_text()): return
	if not assert_condition(not _stamp_visible(desk, 0), "No stamp is drawn on a rejected intent"): return
	if not assert_condition(not stamp_player.playing, "No stamp sound on a rejected intent"): return
	if not assert_condition(not world.get_fact("core_hook_filed_water", false), "No world fact from a rejected intent"): return

	# Timeout resolves the slot: the surface follows the authoritative lapse.
	session.advance_post_signal(0.0)
	if not assert_condition(session.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Deadline expiry resolves through the lapse path"): return
	if not assert_condition(world.get_fact("core_hook_commit_lapsed", false), "Lapse records its world fact"): return
	if not assert_condition(desk.has_committed(), "The lapse resolves the desk"): return
	if not assert_condition(desk.get_result_text() == "UNFILED", "The surface reads the honest lapse outcome, got '%s'" % desk.get_result_text()): return
	if not assert_condition(not _stamp_visible(desk, 0) and not _stamp_visible(desk, 1), "A lapse stamps neither copy as filed"): return
	if not assert_condition(accepted_events.is_empty(), "A lapse never fires the accepted contact sound"): return
	_teardown(office)

	# --- 2. Normal WATER filing through the desk's key gate.
	office = await _armed_office()
	knowledge.reset_for_new_game()
	world.reset_for_new_game()
	session = office.session_controller
	desk = office.copy_commit_desk
	stamp_player = office.get_node("OfficeFoley/Stamp") as AudioStreamPlayer3D
	accepted_events = []
	desk.commit_accepted.connect(func(id: StringName) -> void: accepted_events.append(id))

	if not assert_condition(desk._handle_key_event(_key(KEY_1)), "Key 1 passes the desk's own input gate"): return
	if not assert_condition(desk.has_committed(), "Key 1 files the first copy through the real input path"): return
	if not assert_condition(desk.get_selected_action_id() == &"file_water", "The accepted action is WATER"): return
	if not assert_condition(world.get_fact("core_hook_filed_water", false), "WATER fact recorded"): return
	if not assert_condition(knowledge.knows(&"committed_water_core_hook"), "WATER knowledge recorded"): return
	# The facts are already true while the press travels (authority first);
	# the ink and the sound land with the physical contact.
	if not assert_condition(desk.is_press_in_flight(), "The press travels after the acceptance"): return
	if not assert_condition(not _stamp_visible(desk, 0), "No ink before the press contacts the paper"): return
	if not assert_condition(await _await_press(desk), "The press lands within its duration"): return
	if not assert_condition(_stamp_visible(desk, 0) and _stamp_text(desk, 0) == "FILED", "The accepted copy is stamped FILED on contact"): return
	if not assert_condition(_stamp_visible(desk, 1) and _stamp_text(desk, 1) == "VOID", "The other copy is voided, not filed"): return
	if not assert_condition(accepted_events.size() == 1 and accepted_events[0] == &"file_water", "Exactly one accepted contact event"): return
	if not assert_condition(stamp_player.playing, "The stamp sound fires on the press contact"): return

	# Duplicate and unknown input after acceptance: exactly one outcome.
	desk._handle_key_event(_key(KEY_1))
	if not assert_condition(world.get_fact("core_hook_filed_water", false) and not world.get_fact("core_hook_filed_watcher", false), "Duplicate input records nothing further"): return
	if not assert_condition(not desk.commit_option(&"file_watcher"), "Filing the other copy after acceptance is refused"): return
	if not assert_condition(accepted_events.size() == 1, "Still exactly one accepted event"): return
	if not assert_condition(not world.get_fact("core_hook_filed_watcher", false), "WATCHER was never filed"): return
	_teardown(office)

	# --- 3. WATCHER through the second key, and unknown action ids.
	office = await _armed_office()
	knowledge.reset_for_new_game()
	world.reset_for_new_game()
	session = office.session_controller
	desk = office.copy_commit_desk
	if not assert_condition(not desk.commit_option(&"not_an_option"), "Unknown action id is refused before reaching the session"): return
	if not assert_condition(desk.is_enabled(), "Refused unknown id leaves the desk armed"): return
	if not assert_condition(desk._handle_key_event(_key(KEY_2)), "Key 2 passes the desk's input gate"): return
	if not assert_condition(desk.get_selected_action_id() == &"file_watcher", "Key 2 files the second copy"): return
	if not assert_condition(world.get_fact("core_hook_filed_watcher", false) and not world.get_fact("core_hook_filed_water", false), "WATCHER filed, WATER untouched"): return
	if not assert_condition(await _await_press(desk), "The second press lands"): return
	if not assert_condition(_stamp_visible(desk, 1) and _stamp_text(desk, 1) == "FILED", "The second copy carries FILED"): return
	if not assert_condition(_stamp_text(desk, 0) == "VOID", "The first copy is voided"): return
	_teardown(office)

	# --- 4. Commit while a document is open: the desk's own input gate.
	office = await _armed_office()
	knowledge.reset_for_new_game()
	world.reset_for_new_game()
	desk = office.copy_commit_desk
	office.document_viewer.open_document("some_doc", "TEST", "body")
	if not assert_condition(not desk._handle_key_event(_key(KEY_1)), "A keypress behind an open document is gated"): return
	if not assert_condition(not desk.has_committed() and not world.get_fact("core_hook_filed_water", false), "A keypress behind an open document files nothing"): return
	office.document_viewer.close_document()
	_teardown(office)

	# --- 5. Early intent (before the deadline) is accepted in the same frame.
	office = await _armed_office()
	knowledge.reset_for_new_game()
	world.reset_for_new_game()
	session = office.session_controller
	desk = office.copy_commit_desk
	session._post_signal_elapsed = session.commit_deadline_seconds - 0.5
	if not assert_condition(desk.commit_option(&"file_water"), "Intent before the deadline is expressed"): return
	if not assert_condition(desk.has_committed(), "An on-time intent is accepted and stamped in the same frame"): return
	if not assert_condition(world.get_fact("core_hook_filed_water", false), "On-time WATER fact recorded"): return
	_teardown(office)

	print("--- All Copy Commit Desk Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

## A production office with scenario 3 verified and awaiting the commit.
func _armed_office() -> M1OfficeController:
	var scene := ResourceLoader.load("res://scenes/office/m1_office.tscn") as PackedScene
	var office := scene.instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null:
		intro.skip_immediately()
	office.shift_director.enabled = false
	var session := office.session_controller
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
	# The desk's _input gate demands the ray holding an option target. Stage
	# exactly that (the windowed route script proves the unprompted path end
	# to end), with no frame in between: the controller's own ray re-scan
	# would otherwise clear a staged target it did not find itself.
	var controller := office.player.get_node("InteractionController") as InteractionController
	controller.current_target = office.copy_commit_desk.get_node("Option1Interactable") as Interactable
	return office

func _teardown(office: M1OfficeController) -> void:
	office.queue_free()
	await process_frame
	await process_frame

func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	return key

## Frames until the press lands (or a bounded timeout).
func _await_press(desk: CopyCommitDesk) -> bool:
	# Headless frames carry near-zero delta; drive the press clock the way
	# real frame time would. (Production advances it from _process alone.)
	var guard := 0
	while desk.is_press_in_flight() and guard < 30:
		desk._process(1.0 / 30.0)
		await process_frame
		guard += 1
	return not desk.is_press_in_flight()

func _stamp_visible(desk: CopyCommitDesk, index: int) -> bool:
	var stamp := desk.get_node_or_null(String(desk.OPTION_STAMP_NAMES[index])) as Label3D
	return stamp != null and stamp.visible

func _stamp_text(desk: CopyCommitDesk, index: int) -> String:
	var stamp := desk.get_node_or_null(String(desk.OPTION_STAMP_NAMES[index])) as Label3D
	return "" if stamp == null else stamp.text

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
