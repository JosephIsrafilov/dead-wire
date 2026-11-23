extends SceneTree
## The room names its tools even when idle; preparing the lamp is the operator's action.
var passed := 0
func _init() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + message)
	if not ok:
		quit(1)
	else:
		passed += 1
	return ok
func _run() -> void:
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.set_process(false)
	var lamp := office.get_node("LampLife") as LampLife
	lamp.set_process(false)
	var orders := office.get_node("DutySheet") as DutySheet
	var notice := office.get_node("OfficeStorytellingProps/NoticeCircularText") as Label3D
	var ray := office.player.get_node("Head/Camera3D/InteractionRay") as RayCast3D
	office.player.global_position = Vector3(1.62, 0.0, 1.33)
	office.player.reset_physics_interpolation()
	for i in 4:
		await physics_frame
	office.player.aim_at(orders.global_position)
	ray.force_raycast_update()
	if not check(ray.get_collider() == orders.get_interactable(), "Aiming at the posted orders finds the duty sheet"): return
	office.player.aim_at(notice.global_position)
	ray.force_raycast_update()
	if not check(ray.get_collider() != orders.get_interactable(), "Aiming at the general circular does not select the duty sheet"): return
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.sit()
	for i in 3:
		await physics_frame
		await process_frame
	var target := office.get_node("DeskSetup/OilLamp/WickInteractable") as Interactable
	var shape := target.get_node("CollisionShape3D") as CollisionShape3D
	office.player.aim_at(shape.global_position)
	ray.force_raycast_update()
	if not check(ray.get_collider() == target, "The seated camera can aim at the lamp without opening the line"): return
	target.interact()
	lamp.advance(lamp.wick_turn_seconds + 0.1)
	if not check(is_equal_approx(lamp.wick, 1.0), "Manual interaction raises the wick before the line is open"): return
	lamp.set_wick_immediate(0.3)
	office.shift_director.open_line()
	lamp.advance(lamp.wick_turn_seconds + 0.1)
	if not check(is_equal_approx(lamp.wick, 0.3), "Opening the telegraph line never moves the lamp's wick"): return
	var desk := office.copy_commit_desk
	for index in 2:
		var label := desk.get_node(String(CopyCommitDesk.OPTION_LABEL_NAMES[index])) as Label3D
		if not check(label.visible and not label.text.strip_edges().is_empty(), "An idle filing plate keeps its permanent name"): return
	desk.reset()
	for index in 2:
		var label := desk.get_node(String(CopyCommitDesk.OPTION_LABEL_NAMES[index])) as Label3D
		if not check(label.visible and not label.text.strip_edges().is_empty(), "Resetting the desk does not erase its purpose"): return
	var rules := office.get_node("RoutingBoard/SignalRules/Text") as Label3D
	var sheet := office.get_node("RoutingBoard/SignalRules/Sheet") as CSGBox3D
	var local_bounds := rules.transform * rules.get_aabb()
	if not check(local_bounds.position.x >= -sheet.size.x / 2.0 and local_bounds.end.x <= sheet.size.x / 2.0,
		"The rules text fits horizontally inside its paper"): return
	if not check(local_bounds.position.y >= -sheet.size.y / 2.0 and local_bounds.end.y <= sheet.size.y / 2.0,
		"The rules text fits vertically inside its paper"): return
	office.operator_seat.stand_duration = 0.0
	office.operator_seat.stand()
	var glass := office.get_node("NorthWindow/NightGlass") as Node3D
	office.player.global_position = Vector3(-1.5, 0.0, -1.61)
	office.player.reset_physics_interpolation()
	for i in 8:
		await physics_frame
	office.player.aim_at(glass.global_position)
	await process_frame
	ray.force_raycast_update()
	var glass_target := ray.get_collider() as Interactable
	if not check(glass_target != null and glass_target.get_parent() == glass,
		"The glass action is reachable from the room"): return
	var eye := office.player.camera.global_position
	glass_target.interact()
	await create_timer(0.55).timeout
	if not check(office.player.camera.global_position.distance_to(glass.global_position) <
		eye.distance_to(glass.global_position) - 0.12, "E moves Elias physically closer to the glass"): return
	office.player.aim_at(Vector3(-1.5, 1.55, 0.0))
	await create_timer(0.55).timeout
	if not check(is_zero_approx(office.player.get_lean_weight()), "Looking away releases the window lean"): return
	office.get_parent().queue_free()
	await process_frame
	print("--- Player Preparation: %d assertions ---" % passed)
	quit(0)
