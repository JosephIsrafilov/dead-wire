extends SceneTree

## Windowed acceptance for the direct lever stops: E must reach the physical
## stop through the real interaction ray, from the standing position the
## production route walks to. Movement is movement actions, looking is
## synthetic mouse motion through the player's own _input, and E is the
## "interact" action through the real input pipeline — no stop.interact() or
## throw_direct_route calls anywhere. The AWAITING_ROUTE state itself is a
## controlled fixture (deadline parked at zero) so the window run stays short.
## Headless cannot capture the mouse; run without --headless (refuses, exit 2).
##   godot --path . --script tools/routing_stop_input_capture.gd

const OUT_DIR := "res://.dream-loop/routing_stop_evidence"

var office: M1OfficeController
var player: PlayerController
var interaction: InteractionController
var board: RoutingBoard
var failures: int = 0
var shots: int = 0
var accepted_routes: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("ROUTING STOP INPUT: real mouse capture needs a window; run without --headless")
		quit(2)
		return
	office = load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	player = office.player
	interaction = player.get_node("InteractionController") as InteractionController
	board = office.routing_board
	board.route_accepted.connect(func(action: String): accepted_routes.append(action))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Mouse is captured the way the game captures it")

	var walk := await _walk_to(Vector3(2.05, 0, -0.85), 0.3)
	check(walk.reached and walk.teleports == 0,
		"Walked to the production standing position on movement input (%d unexplained steps)"
			% walk.teleports)

	if not await _throw_stop_via_e("ClearStopInteractable", "CLEAR EAST", "clear"):
		_finish()
		return
	if not await _throw_stop_via_e("HoldStopInteractable", "HOLD", "hold"):
		_finish()
		return
	if not await _modal_path_via_e():
		_finish()
		return
	check(accepted_routes == ["CLEAR EAST", "HOLD"],
		"Both stops resolved through the session authority in order")
	_finish()

func _prepare_awaiting_route() -> void:
	var director := office.shift_director
	var session := office.session_controller
	director.set_process(false)
	session.set_process(false)
	office.load_scenario_by_index(accepted_routes.size())
	session._state = TelegraphSessionController.State.AWAITING_ROUTE
	session._post_signal_elapsed = 0.0
	director._slot_index = accepted_routes.size()
	director._phase = ShiftDirector.Phase.AWAITING_ROUTE
	board.set_awaiting_route(true)

func _throw_stop_via_e(stop_name: String, action: String, label: String) -> bool:
	_prepare_awaiting_route()
	var stop := board.get_node(stop_name) as Interactable
	if stop == null:
		return _fail("%s missing" % stop_name)
	var shape := stop.get_node("CollisionShape3D") as CollisionShape3D
	await _aim_at(shape.global_position if shape != null else stop.global_position)
	var guard := 0
	while interaction.current_target != stop and guard < 240:
		await process_frame
		guard += 1
	if not check(interaction.current_target == stop,
			"%s came under the crosshair through the real interaction ray" % stop_name):
		return false
	await _shot("routing_stop_%s_target" % label)
	await _press_action("interact")
	await process_frame
	await process_frame
	if not check(board._last_route_action == action,
			"E on %s threw the lever for %s through the session authority" % [stop_name, action]):
		return false
	if not check(not board.is_open, "The direct E never opened the modal (%s)" % stop_name):
		return false
	if not check(not stop.can_interact(), "The stop disabled itself after the accepted throw"):
		return false
	await _shot("routing_stop_%s_thrown" % label)
	return true

func _modal_path_via_e() -> bool:
	_prepare_awaiting_route()
	var inter := board.get_interactable()
	var shape := inter.get_node("CollisionShape3D") as CollisionShape3D
	await _aim_at(shape.global_position if shape != null else inter.global_position)
	var guard := 0
	while interaction.current_target != inter and guard < 240:
		await process_frame
		guard += 1
	if not check(interaction.current_target == inter,
			"The ordinary board surface still comes under the crosshair"):
		return false
	await _press_action("interact")
	guard = 0
	while not board.is_open and guard < 120:
		await process_frame
		guard += 1
	if not check(board.is_open, "The board modal still opens through ray + E"):
		return false
	await _shot("routing_modal_open")
	await _press_action("ui_cancel")
	guard = 0
	while board.is_open and guard < 120:
		await process_frame
		guard += 1
	if not check(not board.is_open, "The modal still closes on Esc"):
		return false
	return true

func _finish() -> void:
	print("ROUTING STOP INPUT: %d failures; %d screenshots" % [failures, shots])
	office.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)

# --- real-input helpers (same contracts as production_evidence_capture.gd) --

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

func _send_mouse(dx: float, dy: float = 0.0) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, dy)
	Input.parse_input_event(ev)

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

func _walk_to(target: Vector3, tolerance: float = 0.4) -> Dictionary:
	var max_step := 0.0
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
	return {"reached": player.global_position.distance_to(Vector3(target.x, player.global_position.y, target.z)) <= tolerance + 0.05, "teleports": teleports, "max_step": max_step}

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

func check(condition: bool, message: String) -> bool:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
	return condition
