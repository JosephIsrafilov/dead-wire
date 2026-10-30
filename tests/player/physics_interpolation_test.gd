extends SceneTree

var passed := 0

func _init() -> void:
	_run.call_deferred()

func require(ok: bool, message: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + message)
	if not ok:
		quit(1)
		return false
	passed += 1
	return true

func _run() -> void:
	if not require(is_physics_interpolation_enabled(), "Production enables physics interpolation between ticks"): return
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	root.add_child(player)
	player.set_physics_process(false)
	var spawn := player.global_transform
	player.get_global_transform_interpolated()
	for i in 3:
		await physics_frame
		await process_frame
	player.global_position = Vector3(20.0, -10.0, 20.0)
	for i in 3:
		await physics_frame
		await process_frame
		player.get_global_transform_interpolated()
	if not require(player.get_global_transform_interpolated().origin.distance_to(spawn.origin) > 10.0,
			"The rendered body has reached the fall position before recovery"): return
	player.velocity = Vector3(3.0, -8.0, 1.0)
	player._recover_from_fall()
	await process_frame
	if not require(player.global_transform.is_equal_approx(spawn), "Recovery returns the body to its spawn"): return
	if not require(player.get_global_transform_interpolated().origin.distance_to(spawn.origin) < 0.001,
			"Recovery clears the old render pose instead of flying through the floor"): return
	if not require(player.velocity == Vector3.ZERO, "Recovery cannot carry the fall velocity into the next tick"): return
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	for i in 3:
		await physics_frame
		await process_frame
		player.camera.get_camera_transform()
	player._apply_mouse_look(Vector2(20.0, -10.0))
	var rendered := player.camera.get_camera_transform()
	if not require(rendered.basis.is_equal_approx(player.head.global_basis),
			"Rendered mouse yaw and pitch respond before another physics tick"): return
	if not require(is_equal_approx(player.rotation.y, -0.06), "Movement facing follows the immediate yaw"): return
	if not require(is_equal_approx(player.head.rotation.x, 0.03), "Immediate pitch preserves sensitivity"): return
	var facing := player.rotation.y
	player._physics_process(0.0)
	if not require(is_equal_approx(player.rotation.y, facing), "Physics does not apply the mouse motion twice"): return
	player.queue_free()
	await process_frame
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	office.player.set_physics_process(false)
	var seat := office.operator_seat
	seat.approach_duration = 0.0
	seat.sit_duration = 0.0
	seat.stand_duration = 0.1
	seat.sit()
	seat._process(0.0)
	if not require(office.player.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,
			"The seated frame-driven posture is not interpolated a second time"): return
	seat.stand()
	seat._process(0.0)
	if not require(office.player.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,
			"The stand glide retains its frame-driven pose"): return
	seat._process(0.2)
	seat._process(0.0)
	if not require(office.player.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_INHERIT,
			"Walking regains physics interpolation after the glide"): return
	office.queue_free()
	await process_frame
	print("Physics interpolation assertions: ", passed)
	quit(0)
