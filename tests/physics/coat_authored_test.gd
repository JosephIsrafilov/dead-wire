extends SceneTree
## The chosen Blender garment is the live cloth, not a static overlay or loose sleeves.

var _assertions := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var coat = load("res://scenes/office/hanging_coat.tscn").instantiate()
	root.add_child(coat)
	coat.set_process(false)
	if not _a(coat.mesh.get_surface_count() > 1 and not coat.has_node("SleeveLeft"),
		"The production coat renders the authored garment, without detached sleeve nodes"): return
	var binding = coat.get("_binding")
	if not _a(binding != null, "The authored garment is bound to the cloth simulation"): return
	var rest: PackedVector3Array = coat._pos.duplicate()
	var before: Array = _vertices(coat.mesh)
	var offset := Vector3(0.007, -0.003, -0.012)
	for i in coat._pos.size(): coat._pos[i] += offset
	coat._rebuild_mesh()
	var moved: Array = _vertices(coat.mesh)
	var largest_error := 0.0
	for s in before.size():
		for i in before[s].size():
			largest_error = maxf(largest_error, moved[s][i].distance_to(before[s][i] + offset))
	if not _a(largest_error < 0.00001, "Every surface follows a uniform cloth displacement exactly"): return
	coat._pos = rest.duplicate()
	coat._rebuild_mesh()
	if not _a(_mesh_error(before, _vertices(coat.mesh)) < 0.00001,
		"Returning the particles restores the authored garment without drift"): return
	var original_materials: Array = []
	for s in coat.mesh.get_surface_count(): original_materials.append(coat.mesh.surface_get_material(s))
	var hem: Vector3 = coat.get_particle_position(coat.rings - 1, 0)
	coat.disturb(hem + Vector3(0, 0.35, -0.45), Vector3(0, 0, 1.4))
	for i in 18: coat.step(1.0 / 120.0)
	var deformed: Array = _vertices(coat.mesh)
	if not _a(_mesh_error(before, deformed) > 0.001, "A passing player moves the visible mesh, not only hidden particles"): return
	if not _a(_seams_match(before, deformed), "Shared sleeve/body vertices stay welded during a real shove"): return
	var kept_materials := true
	for s in coat.mesh.get_surface_count(): kept_materials = kept_materials and original_materials[s] == coat.mesh.surface_get_material(s)
	if not _a(kept_materials, "Rebuilding cloth preserves wool, lining and button materials"): return
	for i in 600: coat.step(1.0 / 120.0)
	if not _a(coat._frozen, "The authored coat sleeps after the existing solver settles"): return
	if not _a(_mesh_error(before, _vertices(coat.mesh)) < 0.004, "The rendered garment returns near its initial drape"): return
	var parked_mesh: Mesh = coat.mesh
	coat.step(1.0)
	if not _a(coat.mesh == parked_mesh, "Sleeping cloth keeps the existing mesh resource"): return
	coat.free()
	print("--- Authored Coat: %d assertions PASSED ---" % _assertions)
	quit(0)

func _vertices(mesh: Mesh) -> Array:
	var result: Array = []
	for s in mesh.get_surface_count(): result.append(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return result

func _mesh_error(a: Array, b: Array) -> float:
	var result := 0.0
	for s in a.size():
		for i in a[s].size(): result = maxf(result, a[s][i].distance_to(b[s][i]))
	return result

func _seams_match(before: Array, after: Array) -> bool:
	var shared := {}
	var duplicates := 0
	for s in before.size():
		for i in before[s].size():
			var key: Vector3 = before[s][i].snapped(Vector3.ONE * 0.000001)
			if shared.has(key):
				duplicates += 1
				if shared[key].distance_to(after[s][i]) > 0.000002: return false
			else: shared[key] = after[s][i]
	return duplicates > 100

func _a(ok: bool, desc: String) -> bool:
	if ok:
		_assertions += 1
		print("  PASS: ", desc)
	else:
		printerr("  FAIL: ", desc)
		quit(1)
	return ok
