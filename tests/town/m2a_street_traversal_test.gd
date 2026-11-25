extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var town := load("res://scenes/town/black_creek_exterior.tscn").instantiate() as Node3D
	root.add_child(town)
	var player := town.get_node("Player") as PlayerController
	var sections := [
		["depot descent", Vector3(-1.6, 0.31, -5.25), Vector2(-1.6, -3.0), 0.0],
		["depot south edge", Vector3(-3.3, 0.05, -3.35), Vector2(-3.3, -5.55), 0.30],
		["depot 30 degree approach", Vector3(2.0, 0.05, -4.52), Vector2(5.62, -6.61), 0.30],
		["depot east freight ramp", Vector3(15.5, 0.05, -12.9), Vector2(12.4, -12.9), 0.30],
		["depot west end ramp", Vector3(-7.4, 0.05, -10.5), Vector2(-3.9, -10.5), 0.30],
		["depot east end outside the freight ramp", Vector3(15.1, 0.05, -6), Vector2(12.6, -6), 0.30],
		["depot north edge", Vector3(4, 0.05, -16.7), Vector2(4, -14.7), 0.30],
		["south boardwalk climb off steps", Vector3(8.0, 0.05, 29.6), Vector2(8.0, 32.0), 0.30],
		["north boardwalk climb off steps", Vector3(16.0, 0.05, 16.3), Vector2(16.0, 14.0), 0.30],
		["south walk ascent", Vector3(29.54, 0.05, 29.2), Vector2(29.54, 32.6), 0.30],
		["boarding porch ascent", Vector3(29.54, 0.31, 32.3), Vector2(29.54, 35.3), 0.46],
		["boarding porch and walk descent", Vector3(29.54, 0.47, 35.3), Vector2(29.54, 29.2), 0.0],
		["day access to quarantine gate", Vector3(21.0, 0.05, -20.5), Vector2(21.0, -24.4), 0.0],
		["bridge eastbound", Vector3(40.1, 0.03, 23), Vector2(53, 23), 0.0],
		["bridge westbound", Vector3(53, 0.03, 23), Vector2(40.1, 23), 0.0],
	]
	var failures := 0
	for section in sections:
		var start: Vector3 = section[1]
		var finish: Vector2 = section[2]
		player.global_position = start
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		player.aim_at(Vector3(finish.x, start.y + 1.56, finish.y))
		for i in 8:
			await physics_frame
		Input.action_press("move_forward")
		for i in 400:
			await physics_frame
			var p := Vector2(player.global_position.x, player.global_position.z)
			if p.distance_to(finish) < 0.09:
				break
		Input.action_release("move_forward")
		var actual := player.global_position
		var success := Vector2(actual.x, actual.z).distance_to(finish) < 0.12 and absf(actual.y - section[3]) < 0.07
		failures += int(not success)
		print("%s: %s -> %s" % ["PASS" if success else "FAIL", section[0], actual])
	town.queue_free()
	await process_frame
	var house := load("res://scenes/town/interiors/boarding_house_room.tscn").instantiate() as BoardingHouseRoomController
	house.enable_psx_rendering = false
	root.add_child(house)
	var walker := house.get_node("Player") as PlayerController
	await physics_frame
	var anchor := house.room_builder.position
	var eye := anchor + Vector3(-0.14, 1.56, 1.25)
	var aim := anchor + Vector3(0.02, 1.05, -0.94)
	var ray := PhysicsRayQueryParameters3D.create(eye, eye + (aim - eye).normalized() * 1.25, 1)
	ray.exclude = [walker.get_rid()]
	var blocked := not walker.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	failures += int(blocked)
	print("%s: Room 4 overview has a clear opening sightline" % ["FAIL" if blocked else "PASS"])
	var goals := [
		Vector3(-1.46, 0, -3.50),
		Vector3(-1.85, 0, -2.25),
		Vector3(-0.25, 0, -1.95),
		Vector3(1.25, 0, -2.10),
		Vector3(-0.25, 0, -1.65),
		Vector3(-0.25, 2.71, 3.45),
		Vector3(1.35, 2.71, 3.45),
		Vector3(1.88, 2.71, 1.79),
		Vector3(1.88, 2.71, -0.62),
		Vector3(1.88, 2.71, 1.79),
		Vector3(1.35, 2.71, 3.45),
		Vector3(-0.25, 2.71, 3.45),
		Vector3(-0.25, 0.0, -1.65),
		Vector3(-1.46, 0.0, -3.50),
	]
	var reached := true
	for waypoint: Vector3 in goals:
		var flat := Vector2(waypoint.x, waypoint.z)
		walker.aim_at(Vector3(waypoint.x, walker.global_position.y + 1.56, waypoint.z))
		Input.action_press("move_forward")
		for tick in 420:
			await physics_frame
			if Vector2(walker.global_position.x, walker.global_position.z).distance_to(flat) < 0.08:
				break
		Input.action_release("move_forward")
		if Vector2(walker.global_position.x, walker.global_position.z).distance_to(flat) >= 0.12 \
			or absf(walker.global_position.y - waypoint.y) > 0.08:
			reached = false
			break
		walker.velocity = Vector3.ZERO
	failures += int(not reached)
	print("%s: boarding entrance, staircase and upstairs room -> %s" %
		["PASS" if reached else "FAIL", walker.global_position])
	house.queue_free()
	await process_frame
	await physics_frame
	quit(int(failures > 0))
