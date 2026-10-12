extends SceneTree
## Production instrument mesh/material integration, not artistic acceptance.
var passed := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, description: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + description)
	if not ok:
		quit(1)
		return false
	passed += 1
	return true
func _run() -> void:
	var key: TelegraphKey = load("res://scenes/telegraph/telegraph_key.tscn").instantiate()
	var sounder: SounderController = load("res://scenes/telegraph/sounder.tscn").instantiate()
	var tape: TapeRegisterController = load("res://scenes/telegraph/tape_register.tscn").instantiate()
	root.add_child(key)
	root.add_child(sounder)
	root.add_child(tape)
	await process_frame
	if not check(key.get_node_or_null("AuthoredStatic") is MeshInstance3D, "Key uses authored instrument assembly"): return
	if not check(sounder.get_node_or_null("AuthoredStatic") is MeshInstance3D, "Sounder uses authored instrument assembly"): return
	if not check(tape.get_node_or_null("Body/AuthoredStatic") is MeshInstance3D, "Register uses authored instrument assembly"): return
	var paths := [key.get_node("AuthoredStatic"), key.get_node("Lever/AuthoredLever"),
		sounder.get_node("AuthoredStatic"), sounder.get_node("ArmatureBar/AuthoredArmature"),
		tape.get_node("Body/AuthoredStatic"), tape.get_node("Body/Spool/AuthoredSpool"),
		tape.get_node("Body/StylusPivot/AuthoredStylus")]
	var triangles := 0
	for node in paths:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if not check(mesh is ArrayMesh and mesh.get_surface_count() > 0, "%s has imported mesh surfaces" % node.name): return
		var box := mesh.get_aabb()
		if not check(box.size.length() > 0.001 and box.size.length() < 0.4, "%s remains metre-scale desk geometry" % node.name): return
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface) as StandardMaterial3D
			if not check(mat != null and mat.albedo_texture != null, "%s surface has authored texture" % node.name): return
			if not check(mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "%s uses nearest texture filtering" % node.name): return
			var arrays := mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += indices.size() / 3
	if not check(triangles > 500 and triangles < 16000, "All three desk instruments stay inside triangle budget"): return
	if not check(key.get_node("Lever").position.is_equal_approx(Vector3(0, 0.022, 0)), "Key keeps existing moving pivot"): return
	var shape := key.get_node("Interactable/CollisionShape3D").shape as BoxShape3D
	if not check(shape.size.is_equal_approx(Vector3(0.12, 0.08, 0.22)), "Key interaction volume unchanged"): return
	if not check(sounder.armature != null and is_equal_approx(sounder.armature.position.y, 0.065), "Sounder captures original armature rest"): return
	sounder.set_process(false)
	sounder.play_down(7)
	sounder._process(0.1)
	if not check(is_equal_approx(sounder.armature.position.y, 0.065 - sounder.armature_travel), "Authored armature follows MARK travel"): return
	sounder.play_up(8)
	sounder._process(0.1)
	if not check(is_equal_approx(sounder.armature.position.y, 0.065), "Authored armature returns on GAP"): return
	if not check(tape.get_node("Body/Spool").position.is_equal_approx(Vector3(0, 0.105, -0.025)), "Register keeps original spool pivot"): return
	if not check(tape.get_node("Body/StylusPivot").position.is_equal_approx(Vector3(0, 0.081, 0.03)), "Register keeps original stylus pivot"): return
	if not check(tape.get_node("Body/TapeTop").visible and tape.get_node("Body/PaperStrip").visible, "Objective tape paper surfaces remain present"): return
	var sounder_mesh: Mesh = sounder.get_node("AuthoredStatic").mesh
	var coil_top := -INF
	for surface in sounder_mesh.get_surface_count():
		var material := sounder_mesh.surface_get_material(surface)
		if material.resource_name.contains("coil"):
			var vertices: PackedVector3Array = sounder_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				coil_top = maxf(coil_top, vertex.y)
	if not check(coil_top > 0.0 and coil_top < 0.052, "Wound coils clear the armature at full MARK travel"): return
	if not check(not key.get_node("WoodBase").visible and not sounder.get_node("BaseMesh").visible and not tape.get_node("Body/Cabinet").visible, "Old blockouts do not double-render over authored meshes"): return
	key.queue_free()
	sounder.queue_free()
	tape.queue_free()
	await process_frame
	print("Instrument art assertions: ", passed, " triangles: ", triangles)
	quit(0)
