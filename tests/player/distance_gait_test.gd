extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var player: PlayerController = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.breathing_enabled = false
	await process_frame
	check(player.move_speed <= 1.5 and player.move_speed >= 1.0, "Office walking is deliberate, not a 2.35 m/s glide")
	check(player.footstep_step_distance <= 0.75, "A walking step is shorter than one metre")
	if failures: quit(1); return
	player.velocity = Vector3(player.move_speed,0,0)
	for i in 100: player.call("_update_head",0.016,0.0)
	check(player.head.position.distance_to(player.head_rest_position) < 0.001, "Velocity without floor travel causes no walking bob")
	for i in 60: player.call("_update_head",0.016,0.02)
	check(player._bob_weight > 0.9, "Real floor travel produces gait weight")
	check(absf(player.head.position.y-player.head_rest_position.y) < 0.05, "Distance-based gait stays under 5 cm")
	player.set_seated(true)
	for i in 60: player.call("_update_head",0.016,0.02)
	check(player._bob_weight < 0.001, "Seated body never walks")
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	var seat := office.operator_seat
	seat.approach_duration = 0.0
	seat.sit_duration = 0.0
	seat.sit()
	seat.stand()
	seat._apply_prompt()
	check(not seat.get_interactable().is_actionable, "Transitioning chair reports status, not an ignored E action")
	seat._advance_body(seat.stand_duration + 0.01)
	seat._apply_prompt()
	check(seat.get_interactable().is_actionable, "Chair offers sitting again when the body has finished standing")
	office.queue_free()
	player.queue_free()
	await process_frame
	quit(1 if failures else 0)
func check(ok: bool, text: String) -> void:
	if ok: print("PASS: ",text)
	else: failures += 1; printerr("FAIL: ",text)
