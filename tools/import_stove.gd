extends SceneTree
## Import the Blender-authored CornerStove assembly and bind its nearest-filtered 256px atlas.
const OUT := "res://assets/models/stove_v1/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var atlas := load("res://assets/textures/stove_v1/stove_atlas_256.png") as Texture2D
	if atlas == null:
		printerr("Stove atlas missing")
		quit(1)
		return
	var scene := load(OUT + "stove_static.glb") as PackedScene
	if scene == null:
		printerr("stove_static.glb missing")
		quit(1)
		return
	var node := scene.instantiate()
	var instances := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		instances.push_front(node)
	if instances.size() != 1:
		printerr("Expected 1 mesh in stove_static.glb, got ", instances.size())
		quit(1)
		return
	var source := instances[0] as MeshInstance3D
	var mesh := source.mesh.duplicate() as ArrayMesh
	for index in mesh.get_surface_count():
		var imported := mesh.surface_get_material(index) as StandardMaterial3D
		var key := imported.resource_name if imported != null else "dw_stove_iron"
		var mat := StandardMaterial3D.new()
		mat.resource_name = key
		mat.albedo_texture = atlas
		mat.albedo_color = Color.WHITE
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		mat.roughness = 0.68 if key.contains("brass") else 0.92
		mat.metallic = 0.45 if (key.contains("iron") or key.contains("brass")) else 0.0
		mat.metallic_specular = 0.15
		mat.normal_enabled = false
		mesh.surface_set_material(index, mat)
	var err := ResourceSaver.save(mesh, OUT + "stove_static.res")
	var glb_counts := _mesh_counts(source.mesh as ArrayMesh)
	var res_counts := _mesh_counts(mesh)
	var mat_names: Array = []
	for index in mesh.get_surface_count():
		mat_names.append(mesh.surface_get_material(index).resource_name)
	var manifest := {
		"authoring": "Blender 5.2 bpy; deterministic depot potbelly stove and wall flue",
		"units": "metres",
		"atlas": "res://assets/textures/stove_v1/stove_atlas_256.png",
		"assemblies": {
			"stove_static": {
				"triangles": res_counts.triangles,
				"vertices": res_counts.vertices,
				"materials": mat_names,
				"glb_vertices": glb_counts.vertices,
				"res_surface_vertices": res_counts.vertices,
			}
		},
		"total_triangles": res_counts.triangles,
	}
	var mf := FileAccess.open(OUT + "build_manifest.json", FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify(manifest, "  ") + "\n")
		mf.close()
	print("IMPORT stove_static surfaces=", mesh.get_surface_count(),
		" tris=", res_counts.triangles, " verts=", res_counts.vertices, " result=", err)
	node.free()
	quit(0 if err == OK else 1)

func _mesh_counts(m: ArrayMesh) -> Dictionary:
	var tris := 0
	var verts := 0
	if m == null:
		return {"triangles": 0, "vertices": 0}
	for index in m.get_surface_count():
		var arrays := m.surface_get_arrays(index)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if v.is_empty():
			continue
		tris += (v.size() / 3) if idx.is_empty() else (idx.size() / 3)
		verts += v.size()
	return {"triangles": tris, "vertices": verts}
