extends SceneTree
## Plan 8.10: the cup and the ink bottle are set down where a man would set
## them — on the desk, by his hands, clear of the instruments, the pen's path
## and every walking line in the room — and they rest there.
##   godot --headless --audio-driver Dummy --path . --script tests/office/loose_prop_placement_test.gd

const PLAYER_RADIUS := 0.35
const CORRIDOR_HALF_WIDTH := PLAYER_RADIUS + 0.15
## The routes the operator actually walks, on the floor plane (x, z).
const CORRIDORS := [
	[Vector2(0.0, 1.05), Vector2(-0.65, -0.6)],
	[Vector2(-0.65, -0.6), Vector2(1.92, -0.85)],
	[Vector2(-0.65, -0.6), Vector2(0.62, -1.5)],
	[Vector2(-0.65, -0.6), Vector2(-1.5, -1.7)],
	[Vector2(-0.65, -0.6), Vector2(0.0, 0.2)],
	[Vector2(0.0, 0.2), Vector2(-1.6, 1.5)],
	[Vector2(-1.6, 1.5), Vector2(0.45, 1.2)],
	[Vector2(0.45, 1.2), Vector2(1.45, 1.2)],
	[Vector2(1.92, -0.85), Vector2(0.45, 1.2)],
	[Vector2(1.92, -0.85), Vector2(2.0, 0.45)],
	[Vector2(-1.6, 1.5), Vector2(-1.9, 1.38)],
]
const INSTRUMENTS := ["TelegraphStation", "TelegraphSessionController/TapeRegister", "TranscriptPaper",
	"DispatchLedger", "DeskSetup/OilLamp"]

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Loose Prop Placement Test Suite ---")
	MainMenu.clear_state()
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _frame in 3:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	var props: Array[LooseProp] = []
	for child in office.get_node("LooseProps").get_children():
		if child is LooseProp:
			props.append(child)
	if not _a(props.size() == 2, "The room keeps its two loose objects"): return
	var desk_solid := office.get_node("DeskSetup/DeskSolid") as StaticBody3D
	var desk_shape := desk_solid.get_node("CollisionShape3D") as CollisionShape3D
	var desk_box := desk_shape.shape as BoxShape3D
	var desk_top := desk_shape.global_position.y + desk_box.size.y * 0.5
	var station_y := (office.get_node("TelegraphStation") as Node3D).global_position.y
	if not _a(absf(desk_top - station_y) <= 0.003,
		"The desk's solid top is the dressed top the instruments stand on (%.3f vs %.3f)" % [desk_top, station_y]): return
	var space := office.get_world_3d().direct_space_state
	var inkwell := (office.get_node("InkwellMouth") as Node3D).global_position
	for prop in props:
		var mesh := prop.get_node("Mesh") as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		var name := String(prop.name)
		# Resting on furniture, not on the floor and not in the air.
		var query := PhysicsRayQueryParameters3D.create(prop.global_position + Vector3.UP * 0.05,
			prop.global_position + Vector3.DOWN * 0.5)
		query.exclude = [prop.get_rid()]
		var hit := space.intersect_ray(query)
		if not _a(not hit.is_empty() and hit.collider == desk_solid and absf(box.position.y - hit.position.y) <= 0.003,
			"%s stands on the desk (%s)" % [name, str(hit.get("position", "nothing"))]): return
		# Well inside the top, so a nudge does not tip it off the edge.
		var footprint := _flat(box).grow(0.03)
		var desk_flat := _flat(desk_shape.global_transform * AABB(-desk_box.size * 0.5, desk_box.size))
		var inside := footprint.position.x >= desk_flat.position.x and footprint.end.x <= desk_flat.end.x \
			and footprint.position.z >= desk_flat.position.z and footprint.end.z <= desk_flat.end.z
		if not _a(inside, "%s sits at least 3 cm inside the desk top (%s in %s)" % [name, str(footprint), str(desk_flat)]): return
		# Nothing baked into the desk under it (the pen tray, the pens).
		if not _a(not _desk_has_relief(office, _flat(box).grow(0.005)), "%s does not stand on the pen tray or the pens" % name): return
		# Clear of the instruments, the copy and the pen's way to the inkwell.
		for path in INSTRUMENTS:
			var other := _visual_aabb(office.get_node(path))
			if not _a(not box.grow(0.01).intersects(other), "%s keeps clear of %s" % [name, path]): return
		if not _a(Vector2(box.get_center().x - inkwell.x, box.get_center().z - inkwell.z).length() >= 0.12,
			"%s leaves the pen's way to the inkwell free" % name): return
		# Never on a line the operator walks.
		var spot := Vector2(prop.global_position.x, prop.global_position.z)
		for corridor in CORRIDORS:
			var nearest := Geometry2D.get_closest_point_to_segment(spot, corridor[0], corridor[1])
			if not _a(spot.distance_to(nearest) > CORRIDOR_HALF_WIDTH,
				"%s is off the walk %s-%s" % [name, str(corridor[0]), str(corridor[1])]): return
	for _step in 60:
		await physics_frame
	for prop in props:
		if not _a(prop.is_at_rest(), "%s lies still where it was set down" % prop.name): return
	# A fresh watch puts a knocked cup back.
	var cup := office.get_node("LooseProps/TinCup") as LooseProp
	cup.global_position += Vector3(0.0, 0.0, 0.3)
	office.load_scenario_by_index(0)
	if not _a(cup.is_at_rest(), "A fresh watch puts the cup back where it belongs"): return
	# Each object still sounds like itself, from where it stands.
	var foley := office.get_node("OfficeFoley")
	for pair in [["TinCup", "cup_stream", "cup_variants"], ["InkBottle", "bottle_stream", "bottle_variants"]]:
		var source := foley.get_node_or_null(String(pair[0]) + "Impact") as AudioStreamPlayer3D
		var pool: Array = [foley.get(pair[1])]
		pool.append_array(foley.get(pair[2]))
		var prop := office.get_node("LooseProps/" + String(pair[0])) as Node3D
		if not _a(source != null and source.stream in pool and source.global_position.distance_to(prop.global_position) < 0.01,
			"%s knocks with its own sound, heard where it stands" % pair[0]): return
	office.queue_free()
	for _frame in 3:
		await process_frame
	print("--- All Loose Prop Placement Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _flat(box: AABB) -> AABB:
	return AABB(Vector3(box.position.x, -1.0, box.position.z), Vector3(box.size.x, 2.0, box.size.z))

## World AABB of everything visible under a node.
func _visual_aabb(node: Node) -> AABB:
	var merged := AABB()
	var first := true
	for child in [node] + node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null or not visual.is_visible_in_tree():
			continue
		var box := visual.global_transform * visual.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	return merged

## True if the authored desk has geometry standing proud of its top inside a
## footprint (the baked pen tray and pens sit at y 0.758..0.775).
func _desk_has_relief(office: Node, footprint: AABB) -> bool:
	var desk := office.get_node("DeskSetup/AuthoredDesk") as MeshInstance3D
	for surface in desk.mesh.get_surface_count():
		for vertex in desk.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var world: Vector3 = desk.global_transform * vertex
			if world.y > 0.757 and world.y < 0.9 and footprint.has_point(Vector3(world.x, 0.0, world.z)):
				return true
	return false

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
