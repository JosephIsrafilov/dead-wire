extends SceneTree
## Import the Blender-authored DivisionMap frame mesh and bind its nearest-filtered 256px props atlas.
const OUT := "res://assets/models/office_props_v1/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var atlas := load("res://assets/textures/office_props_v1/props_atlas_256.png") as Texture2D
	if atlas == null:
		printerr("props_atlas_256.png missing")
		quit(1)
		return
	var scene := load(OUT + "division_map_frame_static.glb") as PackedScene
	if scene == null:
		printerr("division_map_frame_static.glb missing")
		quit(1)
		return
	var node := scene.instantiate()
	var instances := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		instances.push_front(node)
	if instances.size() != 1:
		printerr("Expected 1 mesh in division_map_frame_static.glb, got ", instances.size())
		quit(1)
		return
	var source := instances[0] as MeshInstance3D
	var mesh := source.mesh.duplicate() as ArrayMesh
	for index in mesh.get_surface_count():
		var imported := mesh.surface_get_material(index) as StandardMaterial3D
		var key := imported.resource_name if imported != null else "dw_props_dark_wood"
		var mat := StandardMaterial3D.new()
		mat.resource_name = key
		mat.albedo_texture = atlas
		mat.albedo_color = Color.WHITE
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		mat.roughness = 0.55 if key.contains("brass") else 0.9
		mat.metallic = 0.55 if (key.contains("iron") or key.contains("brass")) else 0.0
		mat.metallic_specular = 0.15
		mat.normal_enabled = false
		mesh.surface_set_material(index, mat)
	var err := ResourceSaver.save(mesh, OUT + "division_map_frame_static.res")
	print("IMPORT division_map_frame surfaces=", mesh.get_surface_count(), " result=", err)
	node.free()
	quit(0 if err == OK else 1)
