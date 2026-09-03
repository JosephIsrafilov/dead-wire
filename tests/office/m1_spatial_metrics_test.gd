extends SceneTree

const ROOM_X_MIN := -2.9
const ROOM_X_MAX := 2.9
const ROOM_Z_MIN := -2.3
const ROOM_Z_MAX := 2.3
const PLAYER_RADIUS := 0.35

var office_scene := preload("res://scenes/office/m1_office.tscn")
var office_node: M1OfficeController
var failures := 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("--- Starting M1 Spatial Metrics Test Suite (physical layout gate) ---")
	office_node = office_scene.instantiate() as M1OfficeController
	_assert(office_node != null, "production office instantiates")
	if office_node == null:
		quit(1)
		return
	root.add_child(office_node)
	await physics_frame
	await physics_frame

	var desk := office_node.get_node_or_null("DeskSetup") as Node3D
	var chair := office_node.get_node_or_null("Chair") as Node3D
	var cabinet := office_node.get_node_or_null("StorageCabinet") as Node3D
	var bookcase := office_node.get_node_or_null("Bookcase") as Node3D
	var stove := office_node.get_node_or_null("CornerStove") as Node3D
	var board := office_node.get_node_or_null("RoutingBoard") as RoutingBoard
	var window := office_node.get_node_or_null("NorthWindow") as Node3D
	var door := office_node.get_node_or_null("SouthDoor") as Node3D
	var player := office_node.get_node_or_null("Player") as CharacterBody3D

	_assert(desk != null and desk.get_node_or_null("Chair") == null, "1. Chair is not a DeskSetup descendant")
	_assert(chair != null and chair.get_parent() == office_node, "2. Chair exists as a separate production-scene object")
	_assert(chair != null and chair.scale.x > 0.0 and chair.scale.y > 0.0 and chair.scale.z > 0.0, "3. Chair has positive scale")
	_assert(chair != null and chair.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.99, "4. Chair global up is upright")
	var chair_box := _combined_aabb(chair)
	var desk_box := _combined_aabb(desk)
	_assert(_touches_floor(chair_box), "5. Chair feet contact floor")
	var chair_to_desk := (desk.global_position - chair.global_position).normalized() if chair != null and desk != null else Vector3.ZERO
	_assert(chair != null and chair.global_transform.basis.z.normalized().dot(chair_to_desk) > 0.8, "6. Chair faces the desk working surface")
	_assert(not chair_box.intersects(desk_box), "7. Chair AABB does not intersect desk solid geometry")
	var seat := chair.get_node_or_null("Seat") if chair != null else null
	var tabletop := desk.get_node_or_null("DeskTop") if desk != null else null
	_assert(seat != null and tabletop != null and not _combined_aabb(seat).intersects(_combined_aabb(tabletop)), "8. Seat is not embedded in tabletop")
	_assert(_touches_floor(desk_box), "9. Desk contacts floor")
	_assert(_inside_room(_combined_aabb(cabinet)), "10. Cabinet does not intersect a room wall")
	_assert(_inside_room(_combined_aabb(bookcase)), "11. Bookcase does not intersect a room wall")
	_assert(_inside_room(_combined_aabb(stove)) and not _combined_aabb(stove).intersects(_combined_aabb(cabinet)) and not _combined_aabb(stove).intersects(_combined_aabb(bookcase)), "12. Stove avoids wall and furniture overlap")
	_assert(stove != null and stove.get_node_or_null("SideTable") == null, "13. Stove contains no SideTable")
	_assert(_has_collider(desk) and _has_collider(chair) and _has_collider(cabinet) and _has_collider(bookcase) and _has_collider(stove) and _has_collider(board), "14. Large furniture and board have collision shapes")
	_assert(_passage_width_is_at_least(0.65), "15. Main crossing uses a 0.70m player capsule clearance")
	var desk_access := Vector3(-0.65, 0.0, -0.6)
	_assert(_capsule_path_is_clear(player, Vector3(0.0, 0.0, 0.0), desk_access), "16. Player capsule passes spawn to desk")
	_assert(_capsule_path_is_clear(player, desk_access, Vector3(1.92, 0.0, -0.85)), "17. Player capsule passes desk to Routing Board")
	_assert(_capsule_path_is_clear(player, desk_access, Vector3(0.62, 0.0, -1.5)), "18. Player capsule passes desk to window")
	_assert(_capsule_path_is_clear(player, desk_access, Vector3(0.0, 0.0, 0.2)) and _capsule_path_is_clear(player, Vector3(0.0, 0.0, 0.2), Vector3(-1.6, 0.0, 1.5)), "19. Player capsule passes desk to door")
	_assert(_interaction_rays_hit_expected(), "20. Interaction rays hit expected telegraph, documents, and Routing Board")
	var paper := office_node.get_node_or_null("TranscriptPaper") as Node3D
	var card := office_node.get_node_or_null("MorseReferenceCard") as Node3D
	var ledger := office_node.get_node_or_null("DispatchLedger") as Node3D
	_assert(not _combined_aabb(paper).intersects(_combined_aabb(card)) and not _combined_aabb(paper).intersects(_combined_aabb(ledger)) and not _combined_aabb(card).intersects(_combined_aabb(ledger)), "21. Gameplay documents have non-overlapping AABBs")
	_assert(desk != null and desk.find_child("TelegramLog", true, false) == null and desk.find_child("TelegramSheet2", true, false) == null, "22. Decorative duplicate documents are absent")
	var inward := (Vector3.ZERO - board.global_position).normalized() if board != null else Vector3.ZERO
	_assert(board != null and (-board.global_transform.basis.z).normalized().dot(inward) > 0.75, "23. Routing Board basis faces into room")
	_assert(board != null and board.global_transform.basis.determinant() > 0.99, "24. Routing Board basis is not mirrored")
	_assert(_window_line_of_sight_is_honest(), "25-26. Wall blocks outside aperture and LoS passes window aperture")
	_assert(_attention_directions_are_separate(desk_access, window.global_position, door.global_position), "27. Door and Window are different attention directions")
	_assert(_cannot_see_all_attention_zones(desk_access, desk.global_position, window.global_position, door.global_position, board.global_position), "28. Desk, Window, Door, and Board exceed central FOV")
	_assert(_inside_room(_combined_aabb(desk)) and _inside_room(chair_box) and _inside_room(_combined_aabb(cabinet)) and _inside_room(_combined_aabb(bookcase)) and _inside_room(_combined_aabb(stove)) and _inside_room(_combined_aabb(board)), "29. All major props are inside room bounds")
	_assert(_no_rejected_runtime_assets(office_node), "30. Runtime scene contains no third-party high-poly reference assets")

	office_node.queue_free()
	if failures == 0:
		print("--- All M1 Spatial Metrics Tests PASSED ---")
		quit(0)
	else:
		printerr("--- M1 Spatial Metrics Tests FAILED: %d ---" % failures)
		quit(1)

func _assert(condition: bool, description: String) -> void:
	if condition:
		print("  PASS: ", description)
	else:
		failures += 1
		printerr("  FAIL: ", description)

func _combined_aabb(node: Node) -> AABB:
	return _combined_aabb_fixed(node)

func _geometry_aabbs(node: Node, output: Array[AABB]) -> void:
	if node is MeshInstance3D or node is CSGShape3D:
		var instance := node as VisualInstance3D
		var local_box := instance.get_aabb()
		if local_box.size.length() > 0.0001:
			output.append(instance.global_transform * local_box)
	for child in node.get_children():
		_geometry_aabbs(child, output)

func _combined_aabb_fixed(node: Node) -> AABB:
	var boxes: Array[AABB] = []
	_geometry_aabbs(node, boxes)
	if boxes.is_empty():
		return AABB(Vector3.ZERO, Vector3.ZERO)
	var merged := boxes[0]
	for index in range(1, boxes.size()):
		merged = merged.merge(boxes[index])
	return merged

func _touches_floor(box: AABB) -> bool:
	return box.position.y <= 0.025 and box.end.y >= -0.005

func _inside_room(box: AABB) -> bool:
	return box.position.x >= ROOM_X_MIN + 0.04 and box.end.x <= ROOM_X_MAX - 0.04 and box.position.z >= ROOM_Z_MIN + 0.04 and box.end.z <= ROOM_Z_MAX - 0.04 and box.position.y >= -0.01 and box.end.y <= 2.88

func _has_collider(node: Node) -> bool:
	if node == null:
		return false
	for child in node.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
			return true
		if _has_collider(child):
			return true
	return false

func _passage_width_is_at_least(required_width: float) -> bool:
	return PLAYER_RADIUS * 2.0 >= required_width and _capsule_path_is_clear(office_node.get_node_or_null("Player") as CharacterBody3D, Vector3(-0.65, 0.0, -0.6), Vector3(1.82, 0.0, -0.85))

func _capsule_path_is_clear(player: CharacterBody3D, from: Vector3, to: Vector3) -> bool:
	if player == null:
		return false
	var player_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if player_shape == null or player_shape.shape == null:
		return false
	var space := office_node.get_world_3d().direct_space_state
	var steps := maxi(2, ceili(from.distance_to(to) / 0.08))
	for index in range(steps + 1):
		var point := from.lerp(to, float(index) / float(steps))
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = player_shape.shape
		# Raise the probe above the floor contact plane so this verifies horizontal
		# player clearance against walls and furniture, not intentional floor support.
		query.transform = Transform3D(Basis.IDENTITY, point + Vector3(0, 1.15, 0))
		query.collision_mask = 1
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = [player.get_rid()]
		query.margin = 0.001
		var hits := space.intersect_shape(query, 1)
		if not hits.is_empty():
			var collider := hits[0].get("collider") as Node
			printerr("Capsule path blocked at %s by %s" % [point, collider.get_path() if collider != null else "<unknown>"])
			return false
	return true

func _interaction_rays_hit_expected() -> bool:
	var board_area := office_node.get_node_or_null("RoutingBoard/Interactable") as Area3D
	var key_area := office_node.get_node_or_null("TelegraphStation/TelegraphKey/Interactable") as Area3D
	var paper_area := office_node.get_node_or_null("TranscriptPaper/Interactable") as Area3D
	var ledger_area := office_node.get_node_or_null("DispatchLedger/Interactable") as Area3D
	return _ray_hits_area(Vector3(1.65, 1.45, -0.85), board_area) and _ray_hits_area(Vector3(-0.95, 1.1, -0.92), key_area) and _ray_hits_area(Vector3(-0.95, 1.1, -0.72), paper_area) and _ray_hits_area(Vector3(-0.95, 1.1, -0.42), ledger_area)

func _ray_hits_area(from: Vector3, expected: Area3D) -> bool:
	if expected == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, expected.global_position)
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := office_node.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == expected

func _window_line_of_sight_is_honest() -> bool:
	var space := office_node.get_world_3d().direct_space_state
	var open_query := PhysicsRayQueryParameters3D.create(Vector3(0.0, 1.5, -1.0), Vector3(1.05, 1.45, -2.85))
	open_query.collision_mask = 1
	var closed_query := PhysicsRayQueryParameters3D.create(Vector3(0.0, 1.5, -1.0), Vector3(-1.45, 1.5, -2.85))
	closed_query.collision_mask = 1
	return space.intersect_ray(open_query).is_empty() and not space.intersect_ray(closed_query).is_empty()

func _attention_directions_are_separate(origin: Vector3, window_pos: Vector3, door_pos: Vector3) -> bool:
	var to_window := Vector3(window_pos.x - origin.x, 0, window_pos.z - origin.z).normalized()
	var to_door := Vector3(door_pos.x - origin.x, 0, door_pos.z - origin.z).normalized()
	return rad_to_deg(to_window.angle_to(to_door)) > 75.0

func _cannot_see_all_attention_zones(origin: Vector3, desk_pos: Vector3, window_pos: Vector3, door_pos: Vector3, board_pos: Vector3) -> bool:
	var angles: Array[float] = []
	for target in [desk_pos, window_pos, door_pos, board_pos]:
		var direction: Vector3 = target - origin
		angles.append(wrapf(atan2(direction.x, direction.z), 0.0, TAU))
	angles.sort()
	var largest_gap := 0.0
	for index in angles.size():
		var next := angles[(index + 1) % angles.size()]
		var gap := next - angles[index]
		if index == angles.size() - 1:
			gap += TAU
		largest_gap = maxf(largest_gap, gap)
	return rad_to_deg(TAU - largest_gap) > 75.0

func _no_rejected_runtime_assets(node: Node) -> bool:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null and mesh.resource_path.contains("models/third_party"):
			return false
	for child in node.get_children():
		if not _no_rejected_runtime_assets(child):
			return false
	return true
