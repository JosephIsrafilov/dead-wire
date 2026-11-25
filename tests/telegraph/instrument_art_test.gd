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
			if not check(mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,
				"%s uses nearest texture filtering with mipmaps" % node.name): return
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
	if not check(absf(sounder.get_armature_strike_drop() - sounder.armature_travel) < 0.0001, "Authored armature follows MARK travel at the anvil"): return
	sounder.play_up(8)
	sounder._process(0.1)
	if not check(absf(sounder.get_armature_strike_drop()) < 0.0001 and is_equal_approx(sounder.armature.position.y, 0.065),
		"Authored armature returns to its rest on GAP"): return
	# Plan 8.1: the key lever turns on its trunnion — the knob goes down, the
	# tail comes up, the axle stays put.
	var lever := key.get_node("Lever") as Node3D
	var lever_rest := lever.transform
	key.set_press_amount(1.0)
	var knob := Vector3(0, 0, key.knob_z)
	var tail := Vector3(0, 0, -0.06)
	if not check(absf((lever_rest * knob).y - (lever.transform * knob).y - key.press_travel) < 0.0003, "The knob goes down its travel"): return
	if not check((lever.transform * tail).y > (lever_rest * tail).y + 0.003, "The tail of the lever rises as the knob goes down"): return
	if not check((lever.transform * key.lever_pivot).distance_to(lever_rest * key.lever_pivot) < 0.00001, "The key turns on its trunnion"): return
	key.set_press_amount(0.0)
	if not check(lever.transform.is_equal_approx(lever_rest), "Released, the lever is exactly at rest"): return
	# Plan 8.3: the winding key is a part of its own and turns on its arbor.
	var case_mesh: Mesh = tape.get_node("Body/AuthoredStatic").mesh
	var baked := 0
	for surface in case_mesh.get_surface_count():
		if case_mesh.surface_get_name(surface) != "dw_brass":
			continue
		var faces := MeshDataTool.new()
		faces.create_from_surface(case_mesh, surface)
		for face in faces.get_face_count():
			var centre := Vector3.ZERO
			for corner in 3:
				centre += faces.get_vertex(faces.get_face_vertex(face, corner)) / 3.0
			if centre.x > 0.084 and absf(centre.y - 0.04) < 0.013 and absf(centre.z + 0.01) < 0.008:
				baked += 1
	if not check(baked == 0, "The winding key is no longer baked into the case (%d faces)" % baked): return
	var winding_key := tape.get_node_or_null("Body/WindingKeyPivot") as Node3D
	if not check(winding_key != null and winding_key.get_node_or_null("AuthoredWindingKey") is MeshInstance3D,
		"The winding key sits on its own arbor"): return
	tape.set_process(false)
	tape.spring_tension = 0.5
	tape._spool_drive = 0.5
	tape.wind()
	var angles: Array[float] = []
	var drives: Array[float] = []
	for _step in 100:
		tape._advance_winding(0.01)
		angles.append(tape.get_key_angle())
		drives.append(tape.get_spool_drive())
	if not check(absf(angles[-1] - TAU) < 0.001, "One winding is one full turn of the key"): return
	# Between the ratchet's clicks the key rests on a quarter turn.
	var rests := 0
	for click in tape.WIND_CLICK_SECONDS:
		var resting: float = angles[int((click + 0.1) / 0.01)]
		if absf(resting - (rests + 1) * TAU / 4.0) < 0.001:
			rests += 1
	if not check(rests == 4, "It turns in four quarter turns, resting on the ratchet between them (%d)" % rests): return
	if not check(drives[9] < 0.75 and absf(drives[-1] - 1.0) < 0.001, "The spool gathers speed over the winding, not in one jump"): return
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
