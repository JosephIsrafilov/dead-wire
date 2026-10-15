extends SceneTree

## The stove manifest must describe the asset actually integrated in the game:
## its triangle and vertex counts come from the shipped GLB and the production
## ArrayMesh RES (surface arrays), the materials from the importer contract,
## and every unverified source-only number is labelled as such. Blender source
## rebuild parity is a separate, currently blocked gate and is NOT claimed here.
##   godot --headless --audio-driver Dummy --path . --script tests/presentation/stove_manifest_test.gd

var count := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manifest: Dictionary = _read_json("res://assets/models/stove_v1/build_manifest.json")
	if not check(not manifest.is_empty(), "The stove build manifest exists and parses"):
		quit(1)
		return
	var assembly: Dictionary = manifest.get("assemblies", {}).get("stove_static", {})

	# The shipped GLB, loaded through the engine's own glTF importer.
	var glb := load("res://assets/models/stove_v1/stove_static.glb") as PackedScene
	if not check(glb != null, "stove_static.glb loads through the engine importer"):
		quit(1)
		return
	var glb_node := glb.instantiate()
	var glb_mesh := _first_mesh(glb_node)
	if not check(glb_mesh != null and glb_mesh.get_surface_count() > 0,
			"The GLB carries a real mesh with surfaces"):
		glb_node.free()
		quit(1)
		return
	var glb_counts := _mesh_counts(glb_mesh)
	glb_node.free()

	# The production ArrayMesh RES the scene actually references.
	var res_mesh := load("res://assets/models/stove_v1/stove_static.res") as ArrayMesh
	if not check(res_mesh != null and res_mesh.get_surface_count() > 0,
			"stove_static.res is a real ArrayMesh with surfaces"):
		quit(1)
		return
	var res_counts := _mesh_counts(res_mesh)

	if not check(glb_counts.triangles == res_counts.triangles and glb_counts.triangles > 0,
			"The shipped GLB and the production RES carry the same triangle count (%d vs %d)"
				% [glb_counts.triangles, res_counts.triangles]):
		quit(1)
		return

	# The manifest must agree with the integrated asset, not with a stale build.
	if not check(int(assembly.get("triangles", -1)) == res_counts.triangles,
			"Manifest triangles match the integrated asset (manifest %d, asset %d)"
				% [int(assembly.get("triangles", -1)), res_counts.triangles]):
		quit(1)
		return
	if not check(int(manifest.get("total_triangles", -1)) == res_counts.triangles,
			"Manifest total_triangles match the integrated asset"):
		quit(1)
		return

	# Vertex representation: GLB/RES surface vertices are measured; the Blender
	# source vertex count is unverified while the source rebuild gate is closed.
	if not check(int(assembly.get("glb_vertices", -1)) == glb_counts.vertices,
			"Manifest glb_vertices match the GLB POSITION accessors (manifest %d, glb %d)"
				% [int(assembly.get("glb_vertices", -1)), glb_counts.vertices]):
		quit(1)
		return
	if not check(int(assembly.get("res_surface_vertices", -1)) == res_counts.vertices,
			"Manifest res_surface_vertices match the RES surface arrays (manifest %d, res %d)"
				% [int(assembly.get("res_surface_vertices", -1)), res_counts.vertices]):
		quit(1)
		return
	if "source_vertices" in assembly:
		if not check(bool(assembly.get("source_vertices_unverified", false)),
				"A retained Blender source vertex count is labelled unverified, not proven"):
			quit(1)
			return

	# The production scene wires the RES with the importer's material contract.
	var stove_scene := load("res://scenes/style_tests/props/corner_stove.tscn") as PackedScene
	var stove := stove_scene.instantiate()
	var authored := stove.get_node_or_null("AuthoredStove") as MeshInstance3D
	if not check(authored != null and authored.mesh == res_mesh,
			"CornerStove's AuthoredStove uses the production stove_static.res"):
		stove.free()
		quit(1)
		return
	var material_names: Array = []
	var atlas_ok := true
	var nearest_ok := true
	for index in res_mesh.get_surface_count():
		var mat := res_mesh.surface_get_material(index) as StandardMaterial3D
		if mat == null:
			atlas_ok = false
			continue
		material_names.append(mat.resource_name)
		if mat.albedo_texture == null or mat.albedo_texture.get_width() != 256:
			atlas_ok = false
		if mat.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST:
			nearest_ok = false
	if not check(material_names.size() == 6 and not material_names.has(""),
			"The RES carries six named importer materials (%s)" % str(material_names)):
		stove.free()
		quit(1)
		return
	var manifest_materials: Array = assembly.get("materials", [])
	if not check(manifest_materials.size() == material_names.size()
			and not _has_extra(manifest_materials, material_names),
			"Manifest materials match the integrated materials"):
		stove.free()
		quit(1)
		return
	if not check(atlas_ok, "Every RES material binds the 256px stove atlas"):
		stove.free()
		quit(1)
		return
	if not check(nearest_ok, "Every RES material filters the atlas NEAREST"):
		stove.free()
		quit(1)
		return
	stove.free()
	print("Stove manifest assertions: ", count)
	quit(0)

func _first_mesh(node: Node) -> ArrayMesh:
	var instances: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		instances.push_front(node)
	for child in instances:
		var mesh = child.mesh
		if mesh is ArrayMesh:
			return mesh
	return null

## Surface-level geometry counts: triangles from index arrays (or vertex
## triples when unindexed) and the summed POSITION vertex count.
func _mesh_counts(mesh: ArrayMesh) -> Dictionary:
	var triangles := 0
	var vertices := 0
	for index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(index)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		if idx.is_empty():
			triangles += verts.size() / 3
		else:
			triangles += idx.size() / 3
		vertices += verts.size()
	return {"triangles": triangles, "vertices": vertices}

func _has_extra(a: Array, b: Array) -> bool:
	for entry in a:
		if not entry in b:
			return true
	return false

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

func check(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	count += 1
	return ok
