extends SceneTree

const ROOM := preload("res://scenes/town/interiors/boarding_house_room.tscn")

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var house := ROOM.instantiate() as BoardingHouseRoomController
	house.enable_psx_rendering = false
	root.add_child(house)
	var player := house.player
	var entry := Vector3(-1.46, 0.0, -3.72)
	var kitchen := Vector3(-1.86, -0.13, 5.32)
	var routes := {
		"parlor": [entry, Vector3(-2.38, 0, -2.72), Vector3(-2.38, 0, -1.65),
			Vector3(-2.38, 0, 2.90), Vector3(-1.86, 0, 3.48), kitchen],
		"dining room": [entry, Vector3(-1.46, 0, -2.38), Vector3(0.94, 0, -2.38),
			Vector3(0.94, 0, 2.65), Vector3(0.93, 0, 3.39), Vector3(-1.86, 0, 3.39), kitchen],
	}
	for label in routes:
		player.global_position = entry + Vector3.UP * 0.035
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		await physics_frame
		await physics_frame
		await process_frame
		var route: Array = routes[label]
		var reached := await _walk(player, route)
		_check(reached, "entry to kitchen via %s" % label)
		if reached:
			route.reverse()
		_check(reached and await _walk(player, route), "kitchen to entry via %s" % label)

	var common := house.get_node("HargroveCommon") as Node3D
	var table := _find_model(common, BoardingHouseCommon.PH_TABLE_SCENE)
	var stove := _find_model(common, BoardingHouseCommon.COOKSTOVE_MODEL)
	var table_collider := _furniture_box(common, table)
	var stove_collider := _furniture_box(common, stove)
	_check(table_collider.has_volume() and stove_collider.has_volume() \
		and not table_collider.intersects(stove_collider), "kitchen table and stove colliders do not overlap")
	var table_meshes := _mesh_bounds(table)
	var stove_meshes := _mesh_bounds(stove)
	var clear := not table_meshes.is_empty() and not stove_meshes.is_empty()
	for table_mesh in table_meshes:
		clear = clear and not table_mesh.intersects(stove_collider)
		for stove_mesh in stove_meshes:
			clear = clear and not table_mesh.intersects(stove_mesh) and not table_collider.intersects(stove_mesh)
	_check(clear, "kitchen table and stove meshes clear one another and the opposing colliders")
	house.queue_free()
	await process_frame
	await physics_frame
	quit(int(_failures > 0))

func _walk(player: PlayerController, route: Array) -> bool:
	for waypoint: Vector3 in route:
		var target := Vector2(waypoint.x, waypoint.z)
		player.aim_at(Vector3(waypoint.x, player.global_position.y + 1.56, waypoint.z))
		Input.action_press("move_forward")
		for tick in 260:
			if _distance_to(player, target) < 0.045:
				break
			await physics_frame
		Input.action_release("move_forward")
		if _distance_to(player, target) >= 0.075 or absf(player.global_position.y - waypoint.y) > 0.075:
			print("    Waypoint %s, reached %s" % [waypoint, player.global_position])
			return false
		player.velocity = Vector3.ZERO
	return true

func _distance_to(player: PlayerController, point: Vector2) -> float:
	return Vector2(player.global_position.x, player.global_position.z).distance_to(point)

func _find_model(common: Node3D, scene: PackedScene) -> Node3D:
	for child in common.get_children():
		if child.scene_file_path == scene.resource_path and child.position.z > 4.30:
			return child
	return null

func _furniture_box(common: Node3D, model: Node3D) -> AABB:
	if model == null:
		return AABB()
	for child in common.get_children():
		if child is StaticBody3D and absf(child.position.x - model.position.x) < 0.01 \
			and absf(child.position.z - model.position.z) < 0.01:
			var collider := child.get_child(0) as CollisionShape3D
			var size := (collider.shape as BoxShape3D).size
			return collider.global_transform * AABB(-size / 2.0, size)
	return AABB()

func _mesh_bounds(model: Node3D) -> Array[AABB]:
	var bounds: Array[AABB] = []
	if model != null:
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			bounds.append(mesh.global_transform * mesh.get_aabb())
	return bounds

func _check(success: bool, description: String) -> void:
	print("  %s: %s" % ["PASS" if success else "FAIL", description])
	_failures += int(not success)
