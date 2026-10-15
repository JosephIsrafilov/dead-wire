extends SceneTree

## The direct lever stops are real physics: from the standing position the
## production route walks to, the nearest collider under the interaction ray
## must be the stop itself, and a direct throw must keep the modal lifecycle
## honest (no fake board_opened/board_closed, no is_open, no mouse-mode grab).
##   godot --headless --audio-driver Dummy --path . --script tests/integration/routing_stop_ray_test.gd

var count := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not await _test_stop_ray_identity(): return
	if not await _test_modal_surface_stays(): return
	if not await _test_direct_lifecycle_is_honest(): return
	if not await _test_direct_deadline_boundaries(): return
	print("Routing stop ray assertions: ", count)
	quit(0)

func _make_office() -> M1OfficeController:
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	var director := office.shift_director
	var session := office.session_controller
	director.set_process(false)
	session.set_process(false)
	office.load_scenario_by_index(0)
	session._state = TelegraphSessionController.State.AWAITING_ROUTE
	session._post_signal_elapsed = 0.0
	director._slot_index = 0
	director._phase = ShiftDirector.Phase.AWAITING_ROUTE
	var board := office.routing_board
	board.set_awaiting_route(true)
	await physics_frame
	await physics_frame
	return office

## The production route stands here before pressing E on the board
## (tools/production_evidence_capture.gd walks to (2.05, 0, -0.85) on movement
## input only); the eye rests at the player camera height 1.56.
const STANDING_ORIGIN := Vector3(2.05, 1.56, -0.85)

func _ray_hit(office: M1OfficeController, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	# Exactly the production InteractionRay: layers 1+2, areas and bodies.
	query.collision_mask = 3
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return office.get_world_3d().direct_space_state.intersect_ray(query)

func _test_stop_ray_identity() -> bool:
	var office := await _make_office()
	var board := office.routing_board
	var origin := STANDING_ORIGIN
	var inter_shape := board.get_node("Interactable/CollisionShape3D") as CollisionShape3D
	if not check(origin.distance_to(inter_shape.global_position) > 0.4,
			"Standing origin is outside the board interaction volume, %.2f m away" % origin.distance_to(inter_shape.global_position)):
		return false
	for stop_name in ["ClearStopInteractable", "HoldStopInteractable"]:
		var stop := board.get_node_or_null(stop_name) as Interactable
		if not check(stop != null and stop.can_interact(),
				"%s exists and is direct-eligible in the AWAITING_ROUTE fixture" % stop_name):
			return false
		var hit := _ray_hit(office, origin, stop.global_position)
		var hit_ok: bool = not hit.is_empty() and hit.collider is Interactable \
			and hit.collider.name == stop_name
		if not check(hit_ok,
				"Nearest collider from the standing position at %s is %s" % [stop_name,
					str(hit.collider.name) if not hit.is_empty() else "nothing"]):
			return false
	var board_origin: Vector3 = board.global_position
	print("  [geometry] board=", board_origin, " clear=", board.get_node("ClearStopInteractable").global_position,
		" hold=", board.get_node("HoldStopInteractable").global_position)
	office.queue_free()
	await process_frame
	return true

func _test_modal_surface_stays() -> bool:
	var office := await _make_office()
	var board := office.routing_board
	var inter := board.get_interactable()
	# Aim at the readable slate face above the lever — covered by the modal
	# surface both before and after the stop split.
	var slate_point := board.global_position + board.global_transform.basis.y * 0.95 - board.global_transform.basis.z * 0.15
	var hit := _ray_hit(office, STANDING_ORIGIN, slate_point)
	if not check(not hit.is_empty() and hit.collider == inter,
			"The ordinary board surface still answers the ray with the board Interactable"):
		return false
	var opened: Array = []
	var closed: Array = []
	board.board_opened.connect(func(): opened.append(1))
	board.board_closed.connect(func(): closed.append(1))
	board.open_board()
	if not check(board.is_open and opened.size() == 1, "The modal opens once through the board surface path"):
		return false
	board.close_board()
	if not check(not board.is_open and closed.size() == 1, "The modal closes once"):
		return false
	office.queue_free()
	await process_frame
	return true

func _test_direct_lifecycle_is_honest() -> bool:
	var office := await _make_office()
	var board := office.routing_board
	var opened: Array = []
	var closed: Array = []
	var accepted: Array = []
	board.board_opened.connect(func(): opened.append(1))
	board.board_closed.connect(func(): closed.append(1))
	board.route_accepted.connect(func(action): accepted.append(action))
	var mouse_before: Input.MouseMode = Input.mouse_mode
	# Direct is forbidden while the modal is open: the modal owns the decision.
	board.open_board()
	var blocked_result := board.throw_direct_route("HOLD")
	if not check(not blocked_result and accepted.is_empty(),
			"A direct throw is forbidden while the modal is open"):
		return false
	if not check(board.is_open, "The blocked direct throw leaves the modal open"):
		return false
	board.close_board()
	# The blocked-modal exercise above legitimately opened and closed once;
	# the direct-throw phase below starts from clean lifecycle counters.
	opened.clear()
	closed.clear()
	var result := board.throw_direct_route("CLEAR EAST")
	if not check(result and accepted == ["CLEAR EAST"],
			"A direct throw at an open decision is accepted by the session authority"):
		return false
	if not check(opened.is_empty(),
			"A direct throw never fakes a board_opened lifecycle (got %d)" % opened.size()):
		return false
	if not check(closed.is_empty(),
			"A direct throw never emits board_closed for a modal it never opened (got %d)" % closed.size()):
		return false
	if not check(not board.is_open, "A direct throw leaves the modal closed"):
		return false
	if not check(Input.mouse_mode == mouse_before, "A direct throw never grabs the mouse"):
		return false
	if not check(board._last_route_action == "CLEAR EAST", "The accepted direct route is on the lever record"):
		return false
	# The ordinary modal path keeps its symmetric 1/1 lifecycle.
	var modal_opened: Array = []
	var modal_closed: Array = []
	board.board_opened.connect(func(): modal_opened.append(1))
	board.board_closed.connect(func(): modal_closed.append(1))
	board.reset_for_new_transmission()
	var session := office.session_controller
	office.load_scenario_by_index(1)
	session._state = TelegraphSessionController.State.AWAITING_ROUTE
	session._post_signal_elapsed = 0.0
	board.set_awaiting_route(true)
	board.open_board()
	var modal_result := board.select_action("HOLD")
	if not check(modal_result and modal_opened.size() == 1 and modal_closed.size() == 1,
			"The modal path still opens and closes exactly once per accepted order"):
		return false
	office.queue_free()
	await process_frame
	return true

func _test_direct_deadline_boundaries() -> bool:
	for offset in [-0.001, 0.0, 0.001]:
		var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
		root.add_child(office)
		await process_frame
		await process_frame
		office.get_node("IntroCard").skip_immediately()
		var director := office.shift_director
		var session := office.session_controller
		director.set_process(false)
		session.set_process(false)
		office.load_scenario_by_index(0)
		session._state = TelegraphSessionController.State.AWAITING_ROUTE
		session._post_signal_elapsed = director.route_deadline_seconds + offset
		director._slot_index = 0
		director._phase = ShiftDirector.Phase.AWAITING_ROUTE
		var board := office.routing_board
		board.set_awaiting_route(true)
		var accepted: Array = []
		board.route_accepted.connect(func(action): accepted.append(action))
		var before := board._last_route_action
		var result := board.throw_direct_route("HOLD")
		var lever := office.get_node("OfficeFoley/LeverThrow") as AudioStreamPlayer3D
		if offset < 0.0:
			if not check(result and accepted == ["HOLD"],
					"Direct throw before the deadline is accepted once"):
				return false
		else:
			if not check(not result and accepted.is_empty(),
					"Direct throw at/after the exact deadline is rejected by the authority"):
				return false
			if not check(board._last_route_action == before,
					"Late direct rejection does not invent route memory"):
				return false
			if not check(lever != null and not lever.playing,
					"Late direct rejection creates no physical lever sound"):
				return false
		office.queue_free()
		await process_frame
	return true

func check(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok:
		quit(1)
		return false
	count += 1
	return true
