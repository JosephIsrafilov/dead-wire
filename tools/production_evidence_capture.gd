extends SceneTree

## H2 production acceptance: one natural route through real input only.
##
## What makes this production evidence rather than a fixture:
## - Movement is movement actions (WASD) going through PlayerController's own
##   physics: real acceleration, real move_and_slide, real collision. The
##   script never writes the player's transform.
## - Looking is synthetic mouse motion parsed through Input and handled by the
##   player's own _input — including the seated yaw clamp.
## - Every E is the interaction ray finding the target under the crosshair and
##   the "interact" action firing, exactly as a keypress would.
## - Director, session, scheduler and paper all process live on their own
##   clocks.
## - Seated shots assert is_seated AND is_settled, plus camera height.
##
## Headless cannot capture the mouse, which the look path requires; run this
## without --headless. Failure to capture is a failure of the run, not a pass.

const OUT_DIR := "res://.dream-loop/production_evidence"
const WALK_STEP_LIMIT: float = 0.2

var office: M1OfficeController
var player: PlayerController
var interaction: InteractionController
var shots: int = 0
var failures: int = 0

## Paper causality telemetry (timing-fix acceptance): every sheet_fed,
## glyph_contact and copy_finished is timestamped with the full cursor state,
## so the writing's physical causality can be verified without vision.
var _paper_events: Array = []
var _paper_samples: Array = []
var _transmission_finished: Array = []
var _paper_root0: Vector3 = Vector3.ZERO
var _telemetry_paper: TranscriptPaper = null
var _telemetry_tape: TapeRegisterController = null

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("PRODUCTION EVIDENCE: real mouse capture needs a window; run without --headless")
		quit(2)
		return

	office = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	player = office.player
	interaction = player.get_node("InteractionController") as InteractionController
	var session := office.session_controller
	var director := office.shift_director
	_begin_paper_telemetry(session)

	# Everything runs live: director pacing, session processing, scheduler.
	check(director.enabled, "Shift director runs live")
	check(session.get_process_mode() != Node.PROCESS_MODE_DISABLED, "Session processing is live")
	check(session.scheduler.auto_process, "Scheduler auto-processes")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Mouse is captured the way the game captures it")

	# 1. Cross the room to the chair on movement input alone.
	var start := player.global_position
	var walk := await _walk_to(Vector3(-1.05, 0, 0.4), 0.3)
	check(walk.reached, "The operator reached the chair area on movement input")
	check(walk.teleports == 0, "Every frame of the walk was a physics step, not a teleport (%d unexplained, %.3f m max frame)" % [walk.teleports, walk.max_step])
	check(walk.path_length > 0.8, "The operator actually crossed distance on his own legs (%.2f m)" % walk.path_length)
	check(not office.operator_seat.is_seated, "Still standing after the walk")

	# 2. Sit through ray + E, and wait for the body to finish arriving.
	check(await _interact_with(office.get_node("Chair/Interactable") as Interactable, "the chair"), "Sitting was a real ray + E")
	await _wait_until(func() -> bool: return office.operator_seat.is_settled(), 900)
	check(office.operator_seat.is_seated and office.operator_seat.is_settled(), "The sit transition physically finished")
	check(absf(player.camera.global_position.y - office.operator_seat.seat_eye_height) < 0.05, "Seated camera height is the seat's own")

	# 3. Open the line; answer the call with the same key.
	var key := session.telegraph_key.get_interactable()
	check(await _interact_with(key, "the telegraph key"), "The line was opened through ray + E")
	check(director.get_phase() == ShiftDirector.Phase.WAITING, "Seated key press opens the line")
	await _wait_until(func() -> bool: return director.get_phase() == ShiftDirector.Phase.CALLING, 4000)
	check(director.get_phase() == ShiftDirector.Phase.CALLING, "The wire called on its own clock")
	check(await _interact_with(key, "the telegraph key"), "The call was answered through ray + E")
	check(session.get_state() == TelegraphSessionController.State.RECEIVING, "Key press answered the call")
	await _shot("p1_seated_receiving")
	check(office.operator_seat.is_seated and office.operator_seat.is_settled(), "p1 was captured seated and settled")

	# 4. Seated look sweep toward the window, through the yaw clamp.
	await _aim_at(Vector3(-1.0, 1.45, -2.4))
	await _shot("p2_seated_window_look")
	# Prove the clamp ran through the mouse path: try to over-rotate far past
	# the seated arc and confirm the body stops at its limit.
	var centre: float = office.operator_seat.seat_facing_degrees
	for i in 120:
		_send_mouse(60.0, 0.0)
		await process_frame
	var over: float = absf(rad_to_deg(wrapf(player.rotation.y - deg_to_rad(centre), -PI, PI)))
	check(over <= office.operator_seat.look_half_arc_degrees + 1.0, "Seated look cannot spin past the yaw clamp (%.1f° of ±%.0f°)" % [over, office.operator_seat.look_half_arc_degrees])

	# 5. Pause during the receive: Esc freezes the world; Esc resumes it.
	var ambience := office.get_node("OfficeAmbience") as OfficeAmbience
	var ticks_before_pause: int = ambience.ticks_played
	_press_action("ui_cancel")
	await _wait_until(func() -> bool: return paused, 120)
	check(paused, "Esc pauses the whole simulation")
	for i in 45:
		await process_frame
	check(ambience.ticks_played == ticks_before_pause, "The simulation is frozen while paused (no ticks advanced)")
	_press_action("ui_cancel")
	await _wait_until(func() -> bool: return not paused, 120)
	check(not paused, "Esc resumes the simulation")

	# 6. Stand by movement input (the seat's own rule), step away, come back.
	Input.action_press("move_forward")
	await _wait_until(func() -> bool: return not office.operator_seat.is_seated, 400)
	Input.action_release("move_forward")
	check(not office.operator_seat.is_seated, "Movement input stands the operator (seat rule)")
	await _wait_until(func() -> bool: return absf(player.camera.global_position.y - 1.65) < 0.05, 400)
	check(absf(player.camera.global_position.y - 1.65) < 0.05, "Standing camera height is the standing body's")
	var away := await _walk_to(Vector3(-0.65, 0, 0.45))
	check(away.reached and away.teleports == 0, "A step away from the desk on real legs")
	check(not office.operator_seat.is_seated, "Still standing away from the chair")
	check(await _interact_with(office.get_node("Chair/Interactable") as Interactable, "the chair"), "Returning to the chair was ray + E")
	await _wait_until(func() -> bool: return office.operator_seat.is_settled(), 900)
	check(office.operator_seat.is_settled(), "Returned and settled — the hand can resume the copy")

	# 7. Let the live copy finish; read the finished sheet from the chair.
	await _wait_until(func() -> bool: return session.get_state() == TelegraphSessionController.State.VERIFYING, 6000)
	check(session.get_state() == TelegraphSessionController.State.VERIFYING, "The copy finished on the live clock")
	_check_paper_invariants()
	var paper := office._get_transcript_paper()
	check(await _interact_with(paper.get_interactable(), "the finished copy"), "Reading the copy was ray + E")
	await _wait_until(func() -> bool: return office.document_viewer.is_open(), 120)
	check(office.document_viewer.is_open(), "The document viewer opened from the chair")
	await _shot("p3_seated_read")
	_press_action("interact")
	await _wait_until(func() -> bool: return not office.document_viewer.is_open(), 120)
	check(not office.document_viewer.is_open(), "The document went down on E")

	# 8. Stand and walk to the board: no teleports between shots.
	Input.action_press("move_backward")
	await _wait_until(func() -> bool: return not office.operator_seat.is_seated, 400)
	Input.action_release("move_backward")
	var to_board := await _walk_to(Vector3(0.7, 0, -0.35), 0.3)
	if not (to_board.reached and to_board.teleports == 0):
		print("  [walk east] ", to_board, " pos=", player.global_position)
	check(to_board.reached and to_board.teleports == 0, "Walked the open floor toward the east wall")
	var at_board := await _walk_to(Vector3(2.05, 0, -0.85), 0.3)
	check(at_board.reached and at_board.teleports == 0, "Reached the routing board on movement input")
	check(await _interact_with(office.routing_board.get_interactable(), "the routing board"), "The board opened through ray + E")
	check(office.routing_board.is_open, "Routing board opened from a real standing position")
	await _shot("p4_board_standing")

	# 9. Route through the InputMap action, not a method call.
	_press_action("route_clear_east")
	await _wait_until(func() -> bool:
		var knowledge := _knowledge()
		return knowledge != null and knowledge.knows(&"filed_baseline_train_17"), 300)
	# (H5) The per-slot submit flag resets when the slot advances; the retained
	# physical record is the honest proof the route went out through the board.
	check(office.routing_board._last_route_action == "CLEAR EAST", "The route went out through the board's own key")
	check(_knowledge().knows(&"filed_baseline_train_17"), "Elias knows the message was filed")
	await _shot("p5_route_result")

	# 10. The natural route ends at the door, still on real legs.
	var door_root := office.get_node("SouthDoor") as Node3D
	for waypoint in [Vector3(0.7, 0, 0.35), Vector3(-0.7, 0, 1.1)]:
		var leg := await _walk_to(waypoint, 0.45)
		check(leg.reached and leg.teleports == 0, "Walked toward the door without teleporting")
	var to_door := await _walk_to(Vector3(door_root.global_position.x, 0, door_root.global_position.z - 0.95), 0.45)
	check(to_door.reached and to_door.teleports == 0, "The route key → board → door was walked, not teleported")
	await _aim_at(door_root.global_position)
	await _shot("p6_door_route")

	print("PRODUCTION EVIDENCE: %d failures; %d screenshots" % [failures, shots])
	_dump_paper_telemetry()
	office.queue_free()
	quit(1 if failures else 0)

# --- paper causality telemetry ----------------------------------------------

## Hooks every event that decides the writing's physical causality, plus the
## session's own transmission_finished, so the two can never be confused.
func _begin_paper_telemetry(session: TelegraphSessionController) -> void:
	var paper := session.transcript_paper
	if paper == null:
		check(false, "Telemetry found the transcript paper")
		return
	_telemetry_paper = paper
	_paper_root0 = paper.position
	_telemetry_tape = session.get_tape_register()
	paper.sheet_fed.connect(func(): _record_paper_event("sheet_fed", {}))
	paper.copy_finished.connect(func(scenario_id: String):
		_record_paper_event("copy_finished", {"scenario_id": scenario_id}))
	session.transmission_finished.connect(func(scenario: TelegraphScenarioData):
		_transmission_finished.append({
			"scenario_id": scenario.scenario_id if scenario != null else "",
			"t_ms": Time.get_ticks_msec(),
		}))
	var rig := paper.get_writer_rig()
	if rig != null:
		rig.glyph_contact.connect(func(glyph_index: int):
			_record_paper_event("glyph_contact", {"glyph_index": glyph_index}))
	_record_paper_event("telemetry_attached", {})

func _paper_snapshot() -> Dictionary:
	var paper := _telemetry_paper
	var rig := paper.get_writer_rig()
	var sheet := paper.get_sheet_node()
	return {
		"t_ms": Time.get_ticks_msec(),
		"paper_state": TranscriptPaper.PaperState.keys()[paper.get_state()],
		"feed_elapsed": paper._feed_elapsed,
		"writer_state": WriterRig.PresentationState.keys()[rig.get_presentation_state()],
		"written_glyph_count": paper.get_written_glyph_count(),
		"available_glyph_count": paper.get_available_glyph_count(),
		"last_glyph_index": rig.get_last_glyph_index(),
		"motion_pending": rig.is_motion_pending(),
		"sheet_position": [sheet.position.x, sheet.position.y, sheet.position.z],
		"paper_root_position": [paper.position.x, paper.position.y, paper.position.z],
		"tape_event_count": _telemetry_tape.get_record().size() if _telemetry_tape != null else -1,
	}

func _record_paper_event(kind: String, payload: Dictionary) -> void:
	var entry := {"event": kind}
	entry.merge(payload, true)
	entry.merge(_paper_snapshot(), false)
	_paper_events.append(entry)
	_paper_samples.append(entry.duplicate(true))

## The invariants a vision-less reader needs: the root never moves, the
## cursors stay ordered and monotonic, one contact writes at most one glyph,
## terminal state accepts nothing, and copy_finished is exactly once and
## distinct from the session's transmission_finished.
func _check_paper_invariants() -> void:
	if _telemetry_paper == null:
		return
	var paper := _telemetry_paper
	var total := paper.get_transcript_text().length()
	check(paper.position.is_equal_approx(_paper_root0), "Telemetry: the paper root never moved")
	var contacts: Array = _paper_events.filter(func(e): return e["event"] == "glyph_contact")
	var feds: Array = _paper_events.filter(func(e): return e["event"] == "sheet_fed")
	var finished: Array = _paper_events.filter(func(e): return e["event"] == "copy_finished")
	check(feds.size() >= 1, "Telemetry: sheet_fed fired at least once")
	check(finished.size() == 1, "Telemetry: copy_finished fired exactly once, got %d" % finished.size())
	check(_transmission_finished.size() >= 1, "Telemetry: transmission_finished fired and is not replaced by copy_finished")
	if not finished.is_empty() and not _transmission_finished.is_empty():
		# The paper's own completion and the session's signal-end are two
		# distinct events; neither may stand in for the other.
		check(finished[0]["scenario_id"] == _transmission_finished[0]["scenario_id"],
			"Telemetry: copy_finished and transmission_finished name the same scenario, not a substitution")
	# Connection order makes the completing contact's copy_finished row land
	# before that contact's own row, so ink truth comes from the cursors, not
	# from row order: after N contacts exactly N glyphs must be written —
	# which also proves a terminal sheet accepts no further contacts.
	var written := 0
	var monotonic := true
	var ordered := true
	for sample in _paper_samples:
		var w: int = sample["written_glyph_count"]
		var a: int = sample["available_glyph_count"]
		if w < written:
			monotonic = false
		if w > a or a > total:
			ordered = false
		written = w
	var contact_ordinal := 0
	var one_contact_one_glyph := true
	for s in _paper_samples:
		if s["event"] == "glyph_contact":
			contact_ordinal += 1
			if int(s["written_glyph_count"]) != contact_ordinal:
				one_contact_one_glyph = false
	check(monotonic, "Telemetry: written glyphs are monotonic")
	check(ordered, "Telemetry: written <= available <= total at every event")
	check(one_contact_one_glyph, "Telemetry: every contact writes exactly one glyph, so terminal state accepts none")
	check(contacts.size() == int(paper.get_written_glyph_count()), "Telemetry: one contact event per written glyph (%d vs %d)" % [contacts.size(), paper.get_written_glyph_count()])
	var tape_events := 0
	var tape_monotonic := true
	var tape_inked_on_copy := false
	for s in _paper_samples:
		var tape_count: int = s["tape_event_count"]
		if tape_count < 0:
			continue
		if tape_count < tape_events:
			tape_monotonic = false
		tape_events = tape_count
		if s["event"] == "copy_finished" and tape_count > 0:
			tape_inked_on_copy = true
	check(tape_monotonic, "Telemetry: the tape's ink only ever grows")
	check(tape_inked_on_copy, "Telemetry: the tape inked the same transmission the hand transcribed")

func _dump_paper_telemetry() -> void:
	if _telemetry_paper == null:
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var data := {
		"paper_root_position": [_paper_root0.x, _paper_root0.y, _paper_root0.z],
		"transmission_finished": _transmission_finished,
		"events": _paper_events,
	}
	var file := FileAccess.open(OUT_DIR.path_join("paper_telemetry.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
		print("PRODUCTION EVIDENCE: paper telemetry written to %s/paper_telemetry.json" % OUT_DIR)

# --- real-input helpers -----------------------------------------------------

## A short tap of an InputMap action, dispatched through the real input
## pipeline so _input/_unhandled_input handlers see it exactly as a keypress.
func _press_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)

## Synthetic mouse motion through Input: the player's own _input consumes it,
## yaw clamp and pitch clamp included.
func _send_mouse(dx: float, dy: float = 0.0) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, dy)
	Input.parse_input_event(ev)

## Turn the body and tilt the head until the camera looks at a world point.
func _aim_at(world_point: Vector3) -> void:
	var flat := Vector3(world_point.x - player.global_position.x, 0.0, world_point.z - player.global_position.z)
	var desired_yaw := atan2(-flat.x, -flat.z)
	var desired_pitch := atan2(world_point.y - player.camera.global_position.y, maxf(flat.length(), 0.001))
	for i in 120:
		var yaw_err: float = wrapf(desired_yaw - player.rotation.y, -PI, PI)
		var pitch_err: float = desired_pitch - player.head.rotation.x
		if absf(yaw_err) < 0.004 and absf(pitch_err) < 0.004:
			return
		_send_mouse(
			clampf(-yaw_err / player.mouse_sensitivity, -60.0, 60.0),
			clampf(-pitch_err / player.mouse_sensitivity, -60.0, 60.0))
		await process_frame

## Aim, wait for the interaction ray to actually hold the target, then E.
## The aim point is the interactable's collision shape centre — the shape, not
## the node origin, is what the ray must find.
func _interact_with(target: Interactable, label: String) -> bool:
	if target == null:
		return _fail("no interactable for %s" % label)
	await _aim_at(_aim_point(target))
	var guard := 0
	while interaction.current_target != target and guard < 180:
		await process_frame
		guard += 1
	if interaction.current_target != target:
		return _fail("%s never came under the crosshair" % label)
	_press_action("interact")
	await process_frame
	await process_frame
	return true

func _aim_point(target: Node3D) -> Vector3:
	var shape := target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null:
		return shape.global_position
	return target.global_position

## Walk to a point on movement input only. Returns whether the point was
## reached, the largest per-frame step (no teleports) and the total path
## length actually travelled (the body really moved).
func _walk_to(target: Vector3, tolerance: float = 0.4) -> Dictionary:
	var max_step := 0.0
	var path_length := 0.0
	var teleports := 0
	var previous := player.global_position
	var guard := 0
	var stuck := 0
	var last_ms := Time.get_ticks_msec()
	Input.action_press("move_forward")
	while player.global_position.distance_to(Vector3(target.x, player.global_position.y, target.z)) > tolerance and guard < 2400:
		guard += 1
		await process_frame
		var step := player.global_position.distance_to(previous)
		max_step = maxf(max_step, step)
		path_length += step
		# A long frame legitimately covers more ground at walking speed; only a
		# step that walking speed cannot explain in the time the frame took is
		# a teleport.
		var elapsed := maxf(float(Time.get_ticks_msec() - last_ms) / 1000.0, 1.0 / 240.0)
		if step > player.move_speed * elapsed + 0.12:
			teleports += 1
		last_ms = Time.get_ticks_msec()
		if step < 0.0005:
			stuck += 1
			if stuck > 90:
				break
		else:
			stuck = 0
		previous = player.global_position
		await _aim_at(target)
	Input.action_release("move_forward")
	return {"reached": player.global_position.distance_to(Vector3(target.x, player.global_position.y, target.z)) <= tolerance + 0.05, "max_step": max_step, "path_length": path_length, "teleports": teleports}

func _wait_until(predicate: Callable, frame_budget: int) -> void:
	var guard := 0
	while not predicate.call() and guard < frame_budget:
		await process_frame
		guard += 1

func _knowledge() -> KnowledgeStateStore:
	return root.get_node_or_null("KnowledgeState") as KnowledgeStateStore

func _fail(message: String) -> bool:
	failures += 1
	printerr("FAIL: ", message)
	return false

func _shot(label: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var image := root.get_texture().get_image()
	if image != null:
		check(image.save_png(OUT_DIR.path_join(label + ".png")) == OK, "Captured " + label)
		shots += 1

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
