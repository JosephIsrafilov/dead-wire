extends SceneTree
## Deferred room foley must never bind a detached room or duplicate physical sources.
## godot --headless --audio-driver Dummy --path . --script tests/audio/foley_lifecycle_test.gd

const FOLEY = preload("res://scripts/audio/office_foley.gd")

class QuietOffice extends M1OfficeController:
	func _ready() -> void:
		pass

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Foley Lifecycle Test Suite ---")
	if not await _test_detached_before_deferred_bind(): return
	if not await _test_invalid_parent(): return
	if not await _test_unusable_components(): return
	if not await _test_queued_for_deletion(): return
	if not await _test_idempotent_bind(): return
	if not await _test_route_sound_acceptance(): return
	if not await _test_stream_injection(): return
	print("--- All Foley Lifecycle Tests PASSED ---")
	quit(0)

func _test_detached_before_deferred_bind() -> bool:
	var office := _make_office()
	var foley := office.get_node("OfficeFoley")
	root.add_child(office)
	root.remove_child(office)
	await process_frame
	var checks := [
		[foley.get_child_count() == 0, "Detached deferred bind creates no audio players"],
		[office.document_viewer.document_opened.get_connections().is_empty(), "Detached deferred bind creates no viewer connections"],
		[office.routing_board.routing_action_selected.get_connections().is_empty(), "Detached deferred bind creates no route connections"],
	]
	if not _assert_checks(checks):
		office.free()
		return false
	root.add_child(office)
	foley.call("_bind")
	var bound_count := foley.get_child_count()
	await process_frame
	var attached_checks := [
		[bound_count > 0, "An earlier detached bind does not prevent later valid binding"],
		[foley.get_child_count() == bound_count, "Reattaching after rejected binding creates sources only once"],
	]
	office.free()
	return _assert_checks(attached_checks)

func _test_invalid_parent() -> bool:
	var parent := Node3D.new()
	var foley := FOLEY.new()
	parent.add_child(foley)
	root.add_child(parent)
	await process_frame
	var empty := foley.get_child_count() == 0
	parent.free()
	return assert_condition(empty, "Non-office parent cannot create foley players")

func _test_unusable_components() -> bool:
	for label in ["viewer", "session", "transcript", "board", "desk", "door", "seat", "chair"]:
		var office := _make_office()
		var foley := office.get_node("OfficeFoley")
		match label:
			"viewer": office.document_viewer = null
			"session": office.session_controller = null
			"transcript": office.session_controller.transcript_paper = null
			"board": office.routing_board = null
			"desk": office.copy_commit_desk = null
			"door": office.office_door = null
			"seat": office.operator_seat = null
			"chair": office.get_node("Chair").free()
		root.add_child(office)
		await process_frame
		var empty := foley.get_child_count() == 0
		office.free()
		if not assert_condition(empty, "Missing %s refuses binding before any audio is created" % label): return false
	var office := _make_office()
	var foley := office.get_node("OfficeFoley")
	root.add_child(office)
	var desk := office.copy_commit_desk
	office.remove_child(desk)
	await process_frame
	var empty := foley.get_child_count() == 0
	desk.free()
	office.free()
	return assert_condition(empty, "Detached spatial component refuses binding before transforms are read")

func _test_queued_for_deletion() -> bool:
	for label in ["foley", "office", "desk"]:
		var office := _make_office()
		var foley := office.get_node("OfficeFoley")
		root.add_child(office)
		match label:
			"foley": foley.queue_free()
			"office": office.queue_free()
			"desk": office.copy_commit_desk.queue_free()
		foley.call("_bind")
		var empty := foley.get_child_count() == 0
		await process_frame
		if is_instance_valid(office): office.free()
		if not assert_condition(empty, "Queued %s refuses binding before audio creation" % label): return false
	return true

func _test_idempotent_bind() -> bool:
	var office := _make_office()
	var foley := office.get_node("OfficeFoley")
	root.add_child(office)
	await process_frame
	var first_player := foley.get_node_or_null("LeverThrow")
	var initial_count := foley.get_child_count()
	var initial_connections := office.document_viewer.document_opened.get_connections().size()
	foley.call("_bind")
	foley.call("_bind")
	var checks := [
		[first_player is AudioStreamPlayer3D, "A valid office binds its physical lever source"],
		[foley.get_child_count() == initial_count and foley.get_node_or_null("LeverThrow") == first_player, "Repeated binding keeps exactly one set of audio players"],
		[initial_connections == 1 and office.document_viewer.document_opened.get_connections().size() == 1, "Repeated binding keeps exactly one viewer connection"],
		[office.session_controller.transcript_paper.sheet_fed.get_connections().size() == 1, "Repeated binding keeps exactly one sheet-feed connection"],
		[office.copy_commit_desk.stamp_contact.get_connections().size() == 1, "Repeated binding keeps exactly one stamp-contact connection"],
		[office.office_door.door_opened.get_connections().size() == 2, "Repeated binding preserves one latch and one hinge connection"],
		[office.operator_seat.seated.get_connections().size() == 1, "Repeated binding keeps exactly one chair connection"],
	]
	root.remove_child(office)
	root.add_child(office)
	foley.call("_bind")
	checks.append([foley.get_child_count() == initial_count, "Reattaching a bound office does not duplicate players"])
	checks.append([office.document_viewer.document_opened.get_connections().size() == 1, "Reattaching a bound office does not duplicate connections"])
	office.free()
	return _assert_checks(checks)

func _test_route_sound_acceptance() -> bool:
	var office := _make_office()
	root.add_child(office)
	await process_frame
	var board := office.routing_board
	var lever := office.get_node("OfficeFoley/LeverThrow") as AudioStreamPlayer3D
	var reject := func(action: String): board.play_route_accept(action, false)
	board.routing_action_selected.connect(reject)
	board.set_awaiting_route(true)
	board.open_board()
	var result := board.select_action("CLEAR EAST")
	var rejection_checks := [
		[not result and not lever.playing, "Rejected routing intent never plays the lever throw"],
		[board.route_accepted.get_connections().size() == 1, "Lever source subscribes once to accepted acknowledgement"],
		[board.routing_action_selected.get_connections().size() == 1, "Foley adds no intent listener"],
	]
	if not _assert_checks(rejection_checks):
		office.free()
		return false
	board.routing_action_selected.disconnect(reject)
	var accept := func(action: String): board.play_route_accept(action, true)
	board.routing_action_selected.connect(accept)
	var accepted := board.select_action("HOLD")
	var acceptance_checks := [
		[accepted and lever.playing, "An accepted HOLD plays the physical lever throw"],
		[lever.bus == &"Foley" and is_equal_approx(lever.volume_db, -20.0), "Accepted-only feedback keeps the authored mix"],
	]
	lever.stop()
	office.free()
	return _assert_checks(acceptance_checks)

func _test_stream_injection() -> bool:
	var office := _make_office()
	var foley := office.get_node("OfficeFoley")
	foley.paper_stream = AudioStreamGenerator.new()
	foley.pickup_stream = AudioStreamGenerator.new()
	foley.feed_stream = AudioStreamGenerator.new()
	foley.winding_stream = AudioStreamGenerator.new()
	root.add_child(office)
	await process_frame
	var checks := [
		[foley.get_node("Paper").stream == foley.paper_stream, "Injected paper stream reaches pickup source"],
		[foley.get_node("PaperDown").stream == foley.pickup_stream, "Injected pickup stream stays distinct"],
		[foley.get_node("PaperFeed").stream == foley.feed_stream, "Injected feed stream reaches feed source"],
		[foley.get_node("RegisterWind").stream == foley.winding_stream, "Injected winding stream reaches register source"]
	]
	office.free()
	return _assert_checks(checks)

func _make_office() -> M1OfficeController:
	var office := QuietOffice.new()
	var session := TelegraphSessionController.new()
	session.name = "TelegraphSessionController"
	var transcript := TranscriptPaper.new()
	transcript.name = "TranscriptPaper"
	session.add_child(transcript)
	session.transcript_paper = transcript
	var register := TapeRegisterController.new()
	register.name = "TapeRegister"
	session.add_child(register)
	office.add_child(session)
	office.session_controller = session
	var viewer := DocumentViewer.new()
	viewer.name = "DocumentViewer"
	office.add_child(viewer)
	office.document_viewer = viewer
	var board := RoutingBoard.new()
	board.name = "RoutingBoard"
	office.add_child(board)
	office.routing_board = board
	var desk := CopyCommitDesk.new()
	desk.name = "CopyCommitDesk"
	office.add_child(desk)
	office.copy_commit_desk = desk
	var door := OfficeDoor.new()
	door.name = "OfficeDoor"
	office.add_child(door)
	office.office_door = door
	var chair := Node3D.new()
	chair.name = "Chair"
	var seat := OperatorSeat.new()
	seat.name = "OperatorSeat"
	seat.office = office
	chair.add_child(seat)
	office.add_child(chair)
	office.operator_seat = seat
	var foley := FOLEY.new()
	foley.name = "OfficeFoley"
	office.add_child(foley)
	return office

func _assert_checks(checks: Array) -> bool:
	for check in checks:
		if not assert_condition(check[0], check[1]): return false
	return true

func assert_condition(ok: bool, desc: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + desc)
	if not ok:
		quit(1)
	return ok
