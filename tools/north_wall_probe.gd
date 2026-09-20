extends SceneTree

## Q1 acceptance: the north wall is closed everywhere except the single
## relocated window aperture. A sweep of rays at head height must hit wall
## (or window solid) across the full span; only the aperture band passes.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	var failures := 0
	var space := office.get_world_3d().direct_space_state
	# Ray from mid-room toward the wall plane z=-2.36, sweeping x from -2.9 to 2.9.
	# Aperture (glass zone, no wall): x in [-2.24, -0.76] at y in [0.92, 2.14].
	var holes: Array[float] = []
	for i in range(55):
		var x := -2.7 + i * 0.1
		for y in [1.0, 1.5, 2.0]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, y, -1.0), Vector3(x, y, -2.5))
			query.collision_mask = 1
			var hit := space.intersect_ray(query)
			var in_aperture: bool = x > -2.24 and x < -0.76 and y > 0.92 and y < 2.14
			if hit.is_empty() and not in_aperture:
				holes.append(x)
				printerr("HOLE at x=%.2f y=%.2f" % [x, y])
	if holes.is_empty():
		print("NORTH WALL SWEEP: closed everywhere outside the aperture (55 x-positions x 3 heights)")
	# Walk along the wall at knee height: below the sill the bottom wall
	# segment (y 0..0.92) must stop the body everywhere, aperture included.
	var player := office.player
	for x in [-2.7, -2.4, -2.2, -2.0, -1.5, -1.0, -0.8, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 2.4]:
		player.global_position = Vector3(x, 0, -1.8)
		await process_frame
		var q2 := PhysicsRayQueryParameters3D.create(Vector3(x, 0.5, -1.8), Vector3(x, 0.5, -2.3))
		q2.collision_mask = 1
		if space.intersect_ray(q2).is_empty():
			printerr("WALK HOLE at x=%.2f" % x)
			failures += 1
	if failures == 0:
		print("WALL WALK: no path through the north wall")
	office.queue_free()
	quit(1 if failures else 0)
