extends SceneTree

## Covers the parts of "having a body" that can be asserted rather than felt.
##
## Feel itself is a playtest question. What is testable is that the camera stays
## inside comfortable bounds, that walking and looking are lockable
## independently, that the seat is required to work the key, and that a player
## who finds a hole in the world is put back rather than falling forever.

var _assertions_passed: int = 0

const COMFORT_BOB_CEILING: float = 0.05

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Player Body Test Suite ---")

	var office := _fresh_office()
	if office == null: return
	var player := office.player
	if not assert_condition(player != null, "Office exposes the player"): return

	# 1. Walking and looking lock independently. The document viewer freezes both;
	#    the chair freezes only the feet.
	player.set_movement_locked(true)
	if not assert_condition(player.is_movement_locked and player.is_look_locked, "set_movement_locked freezes walking and looking"): return
	player.set_movement_locked(false)
	player.set_walk_locked(true)
	if not assert_condition(player.is_movement_locked, "set_walk_locked freezes walking"): return
	if not assert_condition(not player.is_look_locked, "set_walk_locked leaves the head free"): return
	player.set_walk_locked(false)

	# 2. Deceleration is gradual, not a snap to zero.
	player.velocity = Vector3(player.move_speed, 0.0, 0.0)
	player._physics_process(1.0 / 60.0)
	var after_one_frame := absf(player.velocity.x)
	if not assert_condition(after_one_frame > 0.0, "Movement decays over frames rather than snapping to zero"): return
	if not assert_condition(after_one_frame < player.move_speed, "Movement actually decays"): return

	# 3. Head motion stays inside comfortable bounds. Over-large bob is the most
	#    common comfort failure in first-person horror.
	player.velocity = Vector3(player.move_speed, 0.0, 0.0)
	var peak := 0.0
	for _step in 400:
		player._update_head(1.0 / 60.0)
		peak = maxf(peak, absf(player.head.position.y - player.head_rest_position.y))
		peak = maxf(peak, absf(player.head.position.x - player.head_rest_position.x))
	if not assert_condition(peak > 0.0, "Walking moves the head at all"): return
	if not assert_condition(peak < COMFORT_BOB_CEILING, "Head travel stays under %.0f mm (peak %.1f mm)" % [COMFORT_BOB_CEILING * 1000.0, peak * 1000.0]): return

	# 4. Bob is switchable, and switching it off leaves breathing behind.
	player.head_bob_enabled = false
	player.breathing_enabled = false
	player.velocity = Vector3.ZERO
	for _step in 200:
		player._update_head(1.0 / 60.0)
	var resting := (player.head.position - player.head_rest_position).length()
	if not assert_condition(resting < 0.0005, "With bob and breathing off the head is still"): return

	player.breathing_enabled = true
	var breath_peak := 0.0
	for _step in 400:
		player._update_head(1.0 / 60.0)
		breath_peak = maxf(breath_peak, absf(player.head.position.y - player.head_rest_position.y))
	if not assert_condition(breath_peak > 0.0, "Breathing moves the head while standing still"): return
	if not assert_condition(breath_peak < COMFORT_BOB_CEILING, "Breathing stays inside comfort bounds"): return

	# 5. Urgency raises the breathing rate without raising its amplitude past
	#    comfort. The camera may report Elias is hurrying; it may not nauseate.
	player.set_urgency(1.0)
	var urgent_peak := 0.0
	for _step in 400:
		player._update_head(1.0 / 60.0)
		urgent_peak = maxf(urgent_peak, absf(player.head.position.y - player.head_rest_position.y))
	if not assert_condition(urgent_peak < COMFORT_BOB_CEILING, "Urgent breathing stays inside comfort bounds"): return
	player.set_urgency(0.0)
	player.head_bob_enabled = true

	# 6. Yaw clamping, used while seated.
	player.rotation.y = 0.0
	player.set_yaw_limit(0.0, deg_to_rad(90.0))
	player.rotation.y = deg_to_rad(200.0)
	player._apply_yaw_limit()
	if not assert_condition(absf(rad_to_deg(player.rotation.y)) <= 90.5, "Yaw clamps to the seated arc, got %.1f" % rad_to_deg(player.rotation.y)): return
	player.clear_yaw_limit()
	player.rotation.y = deg_to_rad(200.0)
	player._apply_yaw_limit()
	if not assert_condition(absf(rad_to_deg(player.rotation.y) - 200.0) < 0.5, "Clearing the limit restores free look"): return

	# 7. Falling out of the world puts the operator back instead of dropping him
	#    forever. The real fix is the door's collision; this is the backstop.
	player.global_position = Vector3(0.0, -50.0, 0.0)
	player._physics_process(1.0 / 60.0)
	if not assert_condition(player.global_position.y > -2.0, "A player below the world is recovered"): return

	# --- the chair ----------------------------------------------------------
	office = _fresh_office()
	if office == null: return
	player = office.player
	var seat := office.operator_seat
	var key := office.session_controller.telegraph_key
	if not assert_condition(seat != null, "Office exposes the operator seat"): return
	if not assert_condition(seat.get_interactable() != null, "The chair is interactable"): return
	if not assert_condition(seat.get_interactable().prompt_text == OperatorSeat.PROMPT_SIT, "Chair invites the operator to sit"): return

	# 8. The key is dead on his feet. This is what turns a prop into pressure.
	if not assert_condition(not key.is_enabled, "Key is inert while the operator stands"): return

	var standing_eye := player.head_rest_position.y
	var chair := seat.get_parent() as Node3D
	if not assert_condition(seat.sit(), "Operator sits"): return
	if not assert_condition(seat.is_seated and player.is_seated, "Both seat and player agree he is seated"): return
	if not assert_condition(player.global_position.distance_to(chair.global_position) < 0.05, "Seated operator is at the chair"): return
	if not assert_condition(key.is_enabled, "Key comes alive once seated"): return
	if not assert_condition(seat.get_interactable().prompt_text == OperatorSeat.PROMPT_STAND, "Prompt offers standing up"): return

	# 9. Seated, he can still look around — that is the whole point of turning
	#    away from the desk — but he cannot spin on the spot.
	if not assert_condition(not player.is_look_locked, "Seated operator can still look"): return
	player.rotation.y = deg_to_rad(seat.seat_facing_degrees) + deg_to_rad(179.0)
	player._apply_yaw_limit()
	var offset := absf(rad_to_deg(wrapf(player.rotation.y - deg_to_rad(seat.seat_facing_degrees), -PI, PI)))
	if not assert_condition(offset <= seat.look_half_arc_degrees + 0.5, "Seated look is clamped to the arc, got %.1f deg" % offset): return

	# 10. Standing restores everything.
	if not assert_condition(seat.stand(), "Operator stands"): return
	if not assert_condition(not seat.is_seated and not player.is_seated, "Standing clears the seated state"): return
	if not assert_condition(not player.is_movement_locked, "Standing restores walking"): return
	if not assert_condition(not key.is_enabled, "Key goes inert again once he is on his feet"): return
	seat._set_head_height(standing_eye)
	if not assert_condition(absf(player.head_rest_position.y - standing_eye) < 0.001, "Standing eye height is restored"): return

	# 11. Sitting is idempotent and standing twice is harmless.
	if not assert_condition(seat.sit(), "Can sit again"): return
	if not assert_condition(not seat.sit(), "Sitting while seated is a no-op"): return
	if not assert_condition(seat.stand(), "Can stand again"): return
	if not assert_condition(not seat.stand(), "Standing while standing is a no-op"): return

	print("--- All Player Body Tests PASSED (%d assertions) ---" % _assertions_passed)
	quit(0)

var _live: Array[Node] = []

func _fresh_office() -> M1OfficeController:
	for stale in _live:
		if is_instance_valid(stale):
			root.remove_child(stale)
			stale.queue_free()
	_live.clear()

	var world := root.get_node_or_null("WorldState") as WorldStateStore
	var knowledge := root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if world != null:
		world.reset_for_new_game()
	if knowledge != null:
		knowledge.reset_for_new_game()

	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	if not assert_condition(scene != null, "m1_office.tscn loads"): return null
	var office: M1OfficeController = scene.instantiate() as M1OfficeController
	if not assert_condition(office != null, "Office instantiates"): return null
	root.add_child(office)
	_live.append(office)
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null:
		intro.skip_immediately()
	office.session_controller.scheduler.auto_process = false
	office.shift_director.set_process(false)
	return office

func assert_condition(condition: bool, message: String) -> bool:
	if condition:
		_assertions_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
