extends SceneTree
## The room answers the body: the coat swings, the floor props move.
##
## Before this pass the office had no rigid bodies at all. Every prop was a
## StaticBody3D, so Elias could walk a whole night shift shoulder-first through
## a room of statues and nothing acknowledged him. Three things had to become
## true, and each is pinned here:
##
##   1. A shove is mass-correct: the same walk moves a tin cup and a coal
##      scuttle to a similar speed, while the heavier one absorbs far more
##      energy and a genuinely heavy object barely stirs.
##   2. Loose props rest until touched and can be put back, so a cup kicked
##      under the table is not lost for the rest of the watch.
##   3. The coat is CLOTH: it holds the silhouette it was authored with, settles
##      on its own, and moves when someone walks past it.
##
##   godot --headless --audio-driver Dummy --path . --script tests/physics/cloth_and_props_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Cloth And Props Test Suite ---")
	if not _push_model(): return
	if not await _loose_props(): return
	if not await _hanging_coat(): return
	print("--- All Cloth And Props Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

## 1. The shove arithmetic.
func _push_model() -> bool:
	var walk := 1.35
	# Two props on the same walk end up at the same speed: the impulse is scaled
	# by the body's own mass, so the shove is a walk, not a launch.
	var cup := PushImpulse.resulting_speed(0.12, walk)
	var bottle := PushImpulse.resulting_speed(0.20, walk)
	if not _a(is_equal_approx(snappedf(cup, 0.001), snappedf(bottle, 0.001)),
			"Walk speed is transferred equally to light props (cup %.3f, bottle %.3f)" % [cup, bottle]): return false
	if not _a(cup > 0.5 and cup < 1.0,
			"A walked-into cup ends up at a believable speed (%.3f m/s)" % cup): return false
	# The heavy one hits the impulse ceiling and is barely stirred. 1.5 N·s on
	# 3 kg is 0.5 m/s, so it is asserted against the light props rather than
	# against zero: it moves, it just moves much less.
	var scuttle := PushImpulse.resulting_speed(3.0, walk)
	if not _a(scuttle < cup * 0.75,
			"A 3 kg scuttle takes far less speed than a cup (%.3f vs %.3f m/s)" % [scuttle, cup]): return false
	if not _a(is_equal_approx(PushImpulse.total_impulse(3.0, walk), PushImpulse.MAX_IMPULSE),
			"The impulse ceiling binds above ~1.85 kg"): return false
	# Zero cases must not produce NaN or a tiny move.
	if not _a(PushImpulse.total_impulse(0.0, walk) == 0.0, "Zero mass produces no impulse"): return false
	if not _a(PushImpulse.total_impulse(0.2, 0.0) == 0.0, "A stationary body produces no impulse"): return false
	# A contact spread over CONTACT_SECONDS integrates to exactly one shove.
	var frames := 9
	var dt := PushImpulse.CONTACT_SECONDS / float(frames)
	var integrated := 0.0
	for _i in frames:
		integrated += PushImpulse.frame_impulse(0.2, walk, dt)
	if not _a(absf(integrated - PushImpulse.total_impulse(0.2, walk)) < 0.001,
			"A nine-frame contact integrates to one shove (%.4f vs %.4f)"
				% [integrated, PushImpulse.total_impulse(0.2, walk)]): return false
	return true

## 2. Loose props: asleep at rest, restorable.
func _loose_props() -> bool:
	# The props are exercised on their own, so they need the floor the office
	# gives them. Without it they are just two bodies in free fall, which is
	# what the first run of this suite was actually measuring.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(12.0, 0.4, 12.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -0.2, 0.0)
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	var scene: PackedScene = load("res://scenes/office/loose_props.tscn")
	if not _a(scene != null, "The loose-props scene loads"): return false
	var props := scene.instantiate()
	# Plan 8.10: the props stand on the desk, not the floor. Each gets a slab
	# under its authored base before it ever enters the tree, so no physics step
	# runs without its support.
	var slabs: Array[Node] = []
	for prop in props.get_children():
		if not prop is Node3D:
			continue
		var slab := StaticBody3D.new()
		var slab_shape := CollisionShape3D.new()
		var slab_box := BoxShape3D.new()
		slab_box.size = Vector3(0.3, 0.1, 0.3)
		slab_shape.shape = slab_box
		slab.add_child(slab_shape)
		slab.position = (prop as Node3D).position + Vector3.DOWN * 0.05
		root.add_child(slab)
		slabs.append(slab)
	root.add_child(props)
	await process_frame
	var cup := props.get_node_or_null("TinCup") as LooseProp
	var bottle := props.get_node_or_null("InkBottle") as LooseProp
	if not _a(cup != null and bottle != null, "Both floor props are LooseProp rigid bodies"): return false
	if not _a(cup.mass > 0.0 and is_equal_approx(cup.mass, 0.12),
			"The cup carries its authored 120 g (%.3f kg)" % cup.mass): return false
	if not _a(bottle.mass > cup.mass, "The ink bottle is heavier than the cup"): return false
	# Never settling on load is the whole point: a prop that drifts on spawn
	# visibly twitches in a room where nothing else moves. Jolt clears the sleep
	# flag on its first step and puts the body back under once it has confirmed
	# the contact, so the assertion is that it neither moves nor stays awake.
	if not _a(cup.is_at_rest() and bottle.is_at_rest(), "Both props are authored in place"): return false
	for _i in 30:
		await physics_frame
	if not _a(cup.is_at_rest() and bottle.is_at_rest(),
			"Thirty physics frames leave both props exactly where they were placed"): return false
	if not _a(cup.sleeping and bottle.sleeping,
			"Both props park themselves again once the contact is confirmed"): return false
	# Knock one over and put it back.
	var rest := cup.global_position
	cup.global_position = rest + Vector3(0.4, 0.0, 0.25)
	await process_frame
	if not _a(not cup.is_at_rest(), "A displaced prop reports that it moved"): return false
	cup.reset_to_rest()
	if not _a(cup.is_at_rest() and cup.linear_velocity.length() < 0.001,
			"reset_to_rest puts the prop back where the room authored it"): return false
	if not _prop_shapes(cup, bottle): return false
	if not await _player_pushes_prop(cup): return false
	props.queue_free()
	floor_body.queue_free()
	for slab in slabs:
		slab.queue_free()
	await process_frame
	return true

## Plan 8.10: they are a cup and a bottle, not a cylinder and a brick.
func _prop_shapes(cup: LooseProp, bottle: LooseProp) -> bool:
	for prop: LooseProp in [cup, bottle]:
		var mesh_node := prop.get_node("Mesh") as MeshInstance3D
		var mesh := mesh_node.mesh
		var vertices := 0
		for surface in mesh.get_surface_count():
			vertices += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if not _a(mesh is ArrayMesh and mesh.resource_path.begins_with("res://assets/models/") and vertices >= 150,
			"%s is an authored model, not a primitive (%d vertices)" % [prop.name, vertices]): return false
		var dressed := mesh_node.material_override == null
		for surface in mesh.get_surface_count():
			dressed = dressed and mesh_node.get_active_material(surface) != null
		if not _a(dressed, "%s wears its own materials on every surface" % prop.name): return false
		var box := mesh.get_aabb()
		if not _a(absf(box.position.y) <= 0.001, "%s stands on its base at its own origin" % prop.name): return false
		var shapes := prop.find_children("*", "CollisionShape3D", false, false)
		var hull := AABB()
		for index in shapes.size():
			var shape := shapes[index] as CollisionShape3D
			var shape_box := _shape_aabb(shape)
			hull = shape_box if index == 0 else hull.merge(shape_box)
		var fits := shapes.size() >= 1 and shapes.size() <= 2
		for axis in 3:
			fits = fits and absf(hull.position[axis] - box.position[axis]) <= 0.006 \
				and absf(hull.end[axis] - box.end[axis]) <= 0.006
		if not _a(fits, "%s is held by one or two simple shapes that fit it (%s vs %s)" % [prop.name, str(hull), str(box)]): return false
		# Its own layer: never steals the interaction ray or the window's line of sight.
		if not _a(prop.collision_layer & 3 == 0 and prop.collision_mask & 1 != 0,
			"%s keeps out of the interaction ray and the sight lines, and still lands on the room" % prop.name): return false
	var cup_box := (cup.get_node("Mesh") as MeshInstance3D).mesh.get_aabb()
	if not _a(cup_box.size.x - cup_box.size.z > 0.015, "The cup has a handle standing out from it"): return false
	var bottle_mesh := (bottle.get_node("Mesh") as MeshInstance3D).mesh
	var bottle_box := bottle_mesh.get_aabb()
	var widest := 0.0
	var neck := 0.0
	for surface in bottle_mesh.get_surface_count():
		for vertex in bottle_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var radius := Vector2(vertex.x, vertex.z).length()
			widest = maxf(widest, radius)
			if vertex.y > bottle_box.end.y - bottle_box.size.y * 0.2:
				neck = maxf(neck, radius)
	if not _a(neck < widest * 0.5, "The bottle narrows to a neck (%.3f of %.3f m)" % [neck, widest]): return false
	return true

func _shape_aabb(node: CollisionShape3D) -> AABB:
	var size := Vector3.ZERO
	if node.shape is CylinderShape3D:
		var cylinder := node.shape as CylinderShape3D
		size = Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)
	elif node.shape is BoxShape3D:
		size = (node.shape as BoxShape3D).size
	elif node.shape is CapsuleShape3D:
		var capsule := node.shape as CapsuleShape3D
		size = Vector3(capsule.radius * 2.0, capsule.height, capsule.radius * 2.0)
	return node.transform * AABB(-size * 0.5, size)

## The end-to-end claim: a walking capsule moves a prop. The formula test above
## proves the arithmetic; this proves the wiring — that move_and_slide reports
## the contact and the player turns it into an impulse.
func _player_pushes_prop(cup: LooseProp) -> bool:
	# The cup lives on the desk now; the capsule can only meet it on the floor,
	# so it is set down on the open floor for this walk and put back after.
	cup.global_position = Vector3(0.0, 0.0, 3.0)
	cup.linear_velocity = Vector3.ZERO
	cup.angular_velocity = Vector3.ZERO
	cup.sleeping = false
	await physics_frame
	var start := cup.global_position
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	if not _a(player_scene != null, "The player scene loads"): return false
	var body := player_scene.instantiate() as PlayerController
	root.add_child(body)
	await process_frame
	# Driven by hand instead of by input: the walk direction is fixed, and
	# velocity has to stay set across move_and_slide or the capsule stalls.
	body.set_physics_process(false)
	body.global_position = start + Vector3(0.0, 0.0, -0.85)
	var direction := Vector3(0.0, 0.0, 1.0)
	for _i in 40:
		body.velocity = direction * body.move_speed
		body.move_and_slide()
		body._push_loose_bodies(1.0 / 60.0)
		await physics_frame
	var moved := cup.global_position.distance_to(start)
	if not _a(moved > 0.01,
			"Walking into a prop moves it (%.4f m after 40 frames)" % moved): return false
	cup.reset_to_rest()
	body.queue_free()
	await process_frame
	return true

## 3. The coat is cloth.
func _hanging_coat() -> bool:
	var scene: PackedScene = load("res://scenes/office/hanging_coat.tscn")
	if not _a(scene != null, "The hanging-coat scene loads"): return false
	var coat := scene.instantiate() as HangingCoat
	root.add_child(coat)
	await process_frame
	coat.set_process(false)
	if not _a(coat.get_particle_count() == coat.rings * coat.segments,
			"The coat simulates a full particle grid (%d)" % coat.get_particle_count()): return false

	if not _a(_lighting_matches_faces(coat.mesh),
			"The garment's lighting normals follow its rendered faces"): return false
	if not _a(_lighting_matches_faces(coat.mesh, -1) and _lighting_matches_faces(coat.mesh, 1),
			"Both sleeve regions have lighting normals matching their faces"): return false

	if not _sleeve_attachment_stays_put(coat): return false

	var pinned := {}
	for index in coat.get_particle_count():
		if coat._is_pinned(index):
			pinned[index] = coat.get_particle_position(index / coat.segments, index % coat.segments)
	if not _a(pinned.size() >= 1 and pinned.size() <= 4,
			"A small hanging loop, not the whole collar, supports the coat (%d pins)" % pinned.size()): return false
	var collar_only := true
	for index: int in pinned:
		collar_only = collar_only and index < coat.segments
	if not _a(collar_only, "Only the collar attaches to the hook; the body hangs freely"): return false

	# Settle it. The authored silhouette must survive the simulation: this is
	# the assertion that catches the collapse the first version had, where the
	# hem ring flattened from 0.397 m to 0.207 m while keeping its perimeter.
	for _i in 300:
		coat.step(1.0 / 60.0)
	if not _a(coat.is_settled(), "The coat comes to rest on its own"): return false

	var hem := _ring_extent(coat, coat.rings - 1)
	if not _a(absf(hem.x - 0.397) < 0.05,
			"The hem keeps the width it was authored with (%.3f m, authored 0.397)" % hem.x): return false
	if not _a(absf(hem.z - 0.178) < 0.05,
			"The hem keeps its depth (%.3f m, authored 0.178)" % hem.z): return false
	var chest := _ring_extent(coat, 2)
	if not _a(absf(chest.x - 0.366) < 0.06,
			"The chest keeps the shoulder width (%.3f m)" % chest.x): return false

	# Every attachment stays at its original position while the free collar settles.
	for _i in 120:
		coat.step(1.0 / 60.0)
	if not _a(_pins_unchanged(coat, pinned), "The hanging loop stays on the hook under gravity"): return false

	# Someone walks past: the cloth must actually move.
	var hem_before := coat.get_particle_position(coat.rings - 1, 0)
	coat.disturb(hem_before + Vector3(0.0, 0.35, -0.45), Vector3(0.0, 0.0, 1.4))
	for _i in 12:
		coat.step(1.0 / 60.0)
	var hem_after := coat.get_particle_position(coat.rings - 1, 0)
	if not _a(hem_after.distance_to(hem_before) > 0.004,
			"A body passing the coat moves the cloth (%.4f m)" % hem_after.distance_to(hem_before)): return false

	# And it settles again rather than swinging forever.
	for _i in 420:
		coat.step(1.0 / 60.0)
	if not _a(coat.is_settled(), "The coat settles again after being disturbed"): return false

	# A disturb at rest is a no-op: standing still next to the coat is not wind.
	var still := coat.get_particle_position(coat.rings - 1, 0)
	coat.disturb(still + Vector3(0.0, 0.3, -0.4), Vector3.ZERO)
	for _i in 6:
		coat.step(1.0 / 60.0)
	if not _a(coat.get_particle_position(coat.rings - 1, 0).distance_to(still) < 0.01,
			"A still body beside the coat leaves it alone"): return false

	# Sound: a real disturbance must announce itself, and it must be throttled so
	# one shove through the cloth is one rustle rather than one per frame.
	var rustles: Array[float] = []
	coat.rustled.connect(func(strength: float) -> void: rustles.append(strength))
	coat._rustle_cooldown = 0.0
	coat.disturb(coat.get_particle_position(coat.rings - 1, 0) + Vector3(0.0, 0.4, -0.5),
		Vector3(0.0, 0.0, 1.4))
	if not _a(rustles.size() == 1, "A shove through the coat emits one rustle (got %d)" % rustles.size()): return false
	if not _a(rustles[0] > 0.0 and rustles[0] <= 1.0,
			"The rustle carries a 0..1 strength (%.3f)" % rustles[0]): return false
	coat.disturb(coat.get_particle_position(coat.rings - 1, 0) + Vector3(0.0, 0.4, -0.5),
		Vector3(0.0, 0.0, 1.4))
	if not _a(rustles.size() == 1, "The cooldown swallows a second shove in the same moment"): return false

	# A draft is a real event with a cause. It moves the coat without a body.
	for _i in 240:
		coat.step(1.0 / 60.0)
	var before_draft := coat.get_particle_position(coat.rings - 1, 0)
	coat.draft(before_draft + Vector3(0.4, 0.4, -0.5), Vector3(-1.0, 0.0, 0.0), 1.2)
	for _i in 10:
		coat.step(1.0 / 60.0)
	if not _a(coat.get_particle_position(coat.rings - 1, 0).distance_to(before_draft) > 0.004,
			"A door draft moves the coat"): return false
	# And a zero-strength draft is nothing at all, so a closed door never stirs it.
	for _i in 300:
		coat.step(1.0 / 60.0)
	var settled_pose := coat.get_particle_position(coat.rings - 1, 0)
	coat.draft(settled_pose + Vector3(0.4, 0.4, -0.5), Vector3(-1.0, 0.0, 0.0), 0.0)
	for _i in 6:
		coat.step(1.0 / 60.0)
	if not _a(coat.get_particle_position(coat.rings - 1, 0).distance_to(settled_pose) < 0.01,
			"A zero-strength draft does nothing"): return false

	# The coat's own transform is identity and its particles are in world space,
	# so anything that needs "where the coat is" must not use global_position —
	# doing that put the rustle source in the middle of the floor.
	var hang := coat.get_hang_position()
	if not _a(hang.distance_to(Vector3(-0.35, 1.7, 2.2)) < 0.25,
			"get_hang_position reports where the coat actually hangs (%s)" % str(hang.snapped(Vector3.ONE * 0.01))): return false

	if not _a(_pins_unchanged(coat, pinned),
			"Walking past and a door draft cannot dislodge any attachment"): return false
	coat.queue_free()
	await process_frame
	return true

## A wider neighbouring particle must never cause an attachment to jump.
## The joined garment now blends fixed cage weights instead of following one point.
func _sleeve_attachment_stays_put(coat: HangingCoat) -> bool:
	var saved := coat._pos.duplicate()
	for side: float in [-1.0, 1.0]:
		coat._pos = coat._rest.duplicate()
		var column := 0
		for c in coat.segments:
			if coat._rest[coat.segments + c].x * side > coat._rest[coat.segments + column].x * side:
				column = c
		var anchor := coat.segments + column
		var neighbor := coat.segments + coat.segments - 1 - column
		coat._rebuild_mesh()
		var before := _rendered_points(coat.mesh)
		var old: Vector3 = coat._pos[neighbor]
		coat._pos[neighbor].x = coat._pos[anchor].x + side * 0.001
		coat._rebuild_mesh()
		var after := _rendered_points(coat.mesh)
		var jump := _largest_displacement(before, after)
		if not _a(jump <= old.distance_to(coat._pos[neighbor]) + 0.00001,
				"Sleeve %s cannot jump farther than its widening neighbour (%.4f m)" % [side, jump]): return false
		var motion := Vector3(0.0, 0.002, -0.003)
		coat._pos[anchor] += motion
		coat._rebuild_mesh()
		var followed := _largest_displacement(after, _rendered_points(coat.mesh))
		if not _a(followed > 0.0001 and followed <= motion.length() + 0.00001,
				"Sleeve %s follows its shoulder through continuous, bounded deformation" % side): return false
	coat._pos = saved
	coat._rebuild_mesh()
	return true

func _rendered_points(mesh: Mesh) -> PackedVector3Array:
	var result := PackedVector3Array()
	for surface in mesh.get_surface_count():
		result.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	return result

func _largest_displacement(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var largest := 0.0
	for i in a.size(): largest = maxf(largest, a[i].distance_to(b[i]))
	return largest

func _lighting_matches_faces(mesh: Mesh, side: int = 0) -> bool:
	var center := mesh.get_aabb().get_center().x
	var samples := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for triangle in range(0, indices.size(), 3):
			var a := indices[triangle]
			var b := indices[triangle + 1]
			var c := indices[triangle + 2]
			if side != 0 and (vertices[a].x - center) * side < 0.17: continue
			var face_normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a]).normalized()
			if face_normal.length_squared() < 0.5: continue
			if normals[a].dot(face_normal) < 0.7: return false
			samples += 1
	return samples > 10

func _pins_unchanged(coat: HangingCoat, pinned: Dictionary) -> bool:
	for index: int in pinned:
		var current := coat.get_particle_position(index / coat.segments, index % coat.segments)
		if current.distance_to(pinned[index]) > 0.0001:
			return false
	return true

func _ring_extent(coat: HangingCoat, ring: int) -> Vector3:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for c in coat.segments:
		var p := coat.get_particle_position(ring, c)
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
	return Vector3(max_x - min_x, 0.0, max_z - min_z)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
