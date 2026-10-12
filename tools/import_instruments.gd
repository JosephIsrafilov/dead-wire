extends SceneTree
## Import the Blender-authored assemblies; preserve materials as local nearest atlas.
const NAMES := ["key_static", "key_lever", "sounder_static", "sounder_armature", "register_static", "register_spool", "register_stylus"]
const OUT := "res://assets/models/instruments_v1/"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var atlas := load("res://assets/textures/instruments_v1/instrument_atlas_256.png") as Texture2D
	if atlas == null:
		printerr("Instrument atlas missing")
		quit(1)
		return
	var materials := {}
	for name in NAMES:
		var scene := load(OUT + name + ".glb") as PackedScene
		if scene == null:
			quit(1)
			return
		var node := scene.instantiate()
		var instances := node.find_children("*", "MeshInstance3D", true, false)
		if node is MeshInstance3D:
			instances.push_front(node)
		if instances.size() != 1:
			printerr("Expected exactly one authored mesh: ", name, " ", instances.size())
			quit(1)
			return
		var source := instances[0] as MeshInstance3D
		var mesh := source.mesh.duplicate() as ArrayMesh
		for index in mesh.get_surface_count():
			var imported := mesh.surface_get_material(index) as StandardMaterial3D
			var key := imported.resource_name
			if not materials.has(key):
				var mat := imported.duplicate() as StandardMaterial3D
				mat.albedo_texture = atlas
				mat.albedo_color = Color.WHITE
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat.roughness = 0.65 if key.contains("brass") else 0.88
				mat.metallic = 0.5 if key.contains("brass") or key.contains("iron") else 0.0
				mat.metallic_specular = 0.3
				mat.normal_enabled = false
				mat.orm_texture = null
				materials[key] = mat
			mesh.surface_set_material(index, materials[key])
		var error := ResourceSaver.save(mesh, OUT + name + ".res")
		print("IMPORT ", name, " surfaces ", mesh.get_surface_count(), " aabb ", mesh.get_aabb(), " result ", error)
		node.free()
		if error != OK:
			quit(1)
			return
	quit(0)
