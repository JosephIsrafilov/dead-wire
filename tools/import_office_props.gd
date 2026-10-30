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
	mat.albedo_texture = atlas
	mat.albedo_color = Color.WHITE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.normal_enabled = false
	mat.metallic_specular = 0.12
	# The lamp's own housing stands 6 cm from its 2.6-energy light. No atlas
	# value survives that: the fount and the foot clip to flat white and the
	# silhouette collapses into a pale blob. This one assembly gets a housing
	# albedo dark enough that the near light brings it up to brass rather than
	# past it. Brass elsewhere in the room (the board's lever base, the clock's
	# bezel) is far from the lamp and keeps the atlas value.
	if assembly == "oil_lamp_static" and (key.contains("brass") or key.contains("iron")):
		mat.albedo_color = Color(0.30, 0.25, 0.16)
	# Worn boards laid over the floor have to sit in the floor's own value range,
	# or they read as new timber dropped on an old floor. The floor material
	# multiplies its texture by (0.72, 0.6, 0.46); this matches it.
	if assembly == "floor_wear_static" and (key.contains("wood") or key.contains("rust")):
		mat.albedo_color = Color(0.52, 0.43, 0.33)
	# The service hatch sill sits inside the stove ember light's reach, and at
	# full atlas albedo it clipped to a flat orange slab. Dimming only this
	# assembly's timber keeps the hatch reading as wood under a fire's glow.
	if assembly == "wall_props_static" and (key.contains("wood") or key.contains("rust")):
		mat.albedo_color = Color(0.74, 0.70, 0.64)
	# Wool in this assembly is only the felt hat now (the coat is simulated
	# cloth, see scripts/office/hanging_coat.gd). It has to match the coat's own
	# material or the two read as different garments draped over each other:
	# the atlas wool tile is mixed for the desk lamp and renders as a black mass
	# on the south wall, so both are lifted by the same factor.
	if assembly == "wall_props_static" and key.contains("wool"):
		mat.albedo_color = Color(1.85, 1.80, 1.70)
	# The coat hangs in the ember light's reach, and at the atlas wool value it
	# came up to the same brightness as the lit boards behind it: the garment had
	# no value separation and its silhouette dissolved into the wall. Only a mild
	# dim — the hue already separates it, and taking it too dark (0.62 was tried)
	# turned the coat into a black mass with no placket, buttons or wear left.
	if assembly == "wall_props_static" and key.contains("wool"):
		mat.albedo_color = Color(0.82, 0.80, 0.76)
	if key.contains("glass"):
		# Old chimney glass. Two things are deliberate here: the blend is MIX
		# rather than ADD (additive stacked to pure white against the night
		# window), and the alpha is low because the tube has no caps, so the
		# near and far wall both draw and a higher alpha doubles into a dark
		# cone. 0.16 reads as a warm tint over the pigeonholes, and the flame
		# stays visible through it.
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.92, 0.66, 0.34, 0.16)
		mat.roughness = 1.0
		mat.metallic = 0.0
		mat.metallic_specular = 0.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mat.disable_receive_shadows = true
	elif key.contains("brass") or key.contains("iron"):
		# No metal on these props. A metallic surface with no reflection probe
		# goes black in this room — the old CSG lamp's brass fount rendered as a
		# black bulb — and the PSX language has no metal shading to lose. The
		# atlas already carries the brass and iron colours.
		mat.roughness = 0.82
		mat.metallic = 0.0
		mat.metallic_specular = 0.28
	elif key.contains("paper") or key.contains("enamel"):
		mat.roughness = 0.95
		mat.metallic = 0.0
	elif key.contains("wool") or key.contains("dust"):
		# Greasy wool and dust: fully matte, no specular at all. A coat that
		# catches a highlight reads as painted cardboard.
		mat.roughness = 1.0
		mat.metallic = 0.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	elif key.contains("slate") or key.contains("baize"):
		# Slate and baize are matte by nature: no specular at all, or the board
		# catches the desk lamp as a grey mirror and stops reading as slate.
		mat.roughness = 1.0
		mat.metallic = 0.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	elif key.contains("leather"):
		mat.roughness = 1.0
		mat.metallic = 0.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	else:
		mat.roughness = 0.9
		mat.metallic = 0.0
	return mat
