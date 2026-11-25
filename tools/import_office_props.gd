extends SceneTree
## Import the Blender-authored PSX props (oil lamp + glass chimney, depot
## chair, regulator clock) and bind the nearest-filtered 256px atlas.
##
##   godot --headless --path . --script tools/import_office_props.gd
##
## One .res per assembly in assets/models/office_props_v1/. Surfaces keep the
## authored material name (dw_props_<kind>) as resource_name so the prop scenes
## can pick a per-kind finish without a second lookup table. The lamp chimney is
## the one transparent surface in the set: it is exported apart so it can be
## blended without dragging the brass fount into the transparent queue.
const OUT := "res://assets/models/office_props_v1/"
const ATLAS := "res://assets/textures/office_props_v1/props_atlas_256.png"
const ATLAS_MATERIAL := preload("res://tools/office_atlas_material.gd")
const ASSEMBLIES := [
	"oil_lamp_static",
	"lamp_glass_static",
	"chair_static",
	"clock_static",
	"board_static",
	"window_static",
	"door_casing_static",
	"door_leaf_static",
	"door_knob_static",
	"table_static",
	"floor_wear_static",
	"wall_props_static",
	"wire_run_static",
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var atlas := load(ATLAS) as Texture2D
	if atlas == null:
		printerr("Props atlas missing: ", ATLAS)
		quit(1)
		return
	var failed := false
	var selected := OS.get_cmdline_user_args()
	for assembly in ASSEMBLIES:
		if not selected.is_empty() and assembly not in selected:
			continue
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
			var key := imported.resource_name if imported != null else "dw_props_mid_wood"
			mesh.surface_set_material(index, _build_material(key, atlas, assembly))
		var err := ResourceSaver.save(mesh, OUT + assembly + ".res")
		print("IMPORT ", assembly, " surfaces=", mesh.get_surface_count(), " aabb=", mesh.get_aabb(), " result=", err)
		if err != OK:
			failed = true
		node.free()
	quit(1 if failed else 0)

func _build_material(key: String, atlas: Texture2D, assembly: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = key
	ATLAS_MATERIAL.apply(mat, atlas, key)
	if key.contains("glass"):
		var color := Color(0.72, 0.66, 0.49, 0.24)
		if key.contains("soot"):
			color = Color(0.23, 0.19, 0.14, 0.34)
		ATLAS_MATERIAL.glass(mat, color)
	elif assembly == "oil_lamp_static" and key.contains("brass"):
		mat.albedo_color = Color(0.49, 0.38, 0.24)
	elif assembly == "floor_wear_static" and (key.contains("wood") or key.contains("rust")):
		mat.albedo_color = Color(0.57, 0.55, 0.49)
	elif key.contains("paper"):
		mat.albedo_color = Color(0.82, 0.76, 0.62)
	elif key.contains("wool") or key.contains("dust") or key.contains("slate") or key.contains("baize"):
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat
