extends SceneTree
## Import the Blender-authored M1 furniture (desk, record bookcase, pigeonhole
## cabinet) and bind the nearest-filtered 256px atlas to every surface.
##
##   godot --headless --path . --script tools/import_office_furniture.gd
##
## One .res per assembly in assets/models/office_furniture_v1/. Surfaces keep
## the authored material name (dw_furniture_<kind>) as resource_name so the
## prop scenes can pick a per-kind roughness without a second lookup table.
const OUT := "res://assets/models/office_furniture_v1/"
const ATLAS := "res://assets/textures/office_furniture_v1/furniture_atlas_256.png"
const ASSEMBLIES := ["desk_static", "bookcase_static", "cabinet_static"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var atlas := load(ATLAS) as Texture2D
	if atlas == null:
		printerr("Furniture atlas missing: ", ATLAS)
		quit(1)
		return
	var failed := false
	for assembly in ASSEMBLIES:
		var scene := load(OUT + assembly + ".glb") as PackedScene
		if scene == null:
			printerr(assembly, ".glb missing")
			failed = true
			continue
		var node := scene.instantiate()
		var instances := node.find_children("*", "MeshInstance3D", true, false)
		if node is MeshInstance3D:
			instances.push_front(node)
		if instances.size() != 1:
			printerr(assembly, ": expected 1 mesh, got ", instances.size())
			node.free()
			failed = true
			continue
		var source := instances[0] as MeshInstance3D
		var mesh := source.mesh.duplicate() as ArrayMesh
		for index in mesh.get_surface_count():
			var imported := mesh.surface_get_material(index) as StandardMaterial3D
			var key := imported.resource_name if imported != null else "dw_furniture_mid_wood"
			mesh.surface_set_material(index, _build_material(key, atlas))
		var err := ResourceSaver.save(mesh, OUT + assembly + ".res")
		print("IMPORT ", assembly, " surfaces=", mesh.get_surface_count(), " aabb=", mesh.get_aabb(), " result=", err)
		if err != OK:
			failed = true
		node.free()
	quit(1 if failed else 0)

func _build_material(key: String, atlas: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = key
	mat.albedo_texture = atlas
	mat.albedo_color = Color.WHITE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.normal_enabled = false
	mat.metallic_specular = 0.12
	if key.contains("paper"):
		# The pigeonhole forms stand 0.3 m from a 2.6-energy desk lamp and clip to
		# a flat white wedge, losing every facet. A dimmer albedo keeps them
		# inside the lamp's range so the paper still reads as paper.
		mat.albedo_color = Color(0.42, 0.40, 0.34)
		mat.roughness = 0.95
		mat.metallic = 0.0
	elif key.contains("brass"):
		mat.roughness = 0.55
		mat.metallic = 0.6
	elif key.contains("iron"):
		mat.roughness = 0.62
		mat.metallic = 0.5
	elif key.contains("baize") or key.contains("leather"):
		mat.roughness = 1.0
		mat.metallic = 0.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	else:
		mat.roughness = 0.9
		mat.metallic = 0.0
	return mat
