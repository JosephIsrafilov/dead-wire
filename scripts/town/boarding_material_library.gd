class_name BoardingMaterialLibrary
extends RefCounted

## Maps flat Blender placeholder materials inside the Hargrove boarding house
## and Room 4 onto textured PBR StandardMaterial3D surfaces built from existing
## office and town texture sets. Keeps custom shader/print overrides untouched.

const TEX_OFFICE := "res://assets/textures/office_surfaces/"
const TEX_WEAR := "res://assets/textures/office_wear/"
const TEX_TOWN1 := "res://assets/textures/town_v1/"
const TEX_TOWN2 := "res://assets/textures/town_v2/"

const PALETTE: Dictionary = {
	"Fir": {
		"alb": TEX_OFFICE + "floor_albedo.png",
		"nrm": TEX_OFFICE + "floor_normal.png",
		"rgh": TEX_OFFICE + "floor_roughness.png",
		"col": Color("c9ae8b"), "uv": Vector3(1.8, 1.8, 1.8), "rough": 0.86, "nrm_s": 0.80,
	},
	"FirD": {
		"alb": TEX_OFFICE + "floor_albedo.png",
		"nrm": TEX_OFFICE + "floor_normal.png",
		"rgh": TEX_OFFICE + "floor_roughness.png",
		"col": Color("9f8364"), "uv": Vector3(1.8, 1.8, 1.8), "rough": 0.88, "nrm_s": 0.80,
	},
	"FirL": {
		"alb": TEX_OFFICE + "floor_albedo.png",
		"nrm": TEX_OFFICE + "floor_normal.png",
		"rgh": TEX_OFFICE + "floor_roughness.png",
		"col": Color("dbc3a1"), "uv": Vector3(1.8, 1.8, 1.8), "rough": 0.85, "nrm_s": 0.78,
	},
	"Wain": {
		"alb": TEX_OFFICE + "beadboard_albedo.png",
		"nrm": TEX_OFFICE + "beadboard_normal.png",
		"rgh": TEX_OFFICE + "beadboard_roughness.png",
		"col": Color("b39472"), "uv": Vector3(1.25, 0.85, 1.25), "rough": 0.78, "nrm_s": 0.75,
	},
	"WainDark": {
		"alb": TEX_OFFICE + "beadboard_albedo.png",
		"nrm": TEX_OFFICE + "beadboard_normal.png",
		"rgh": TEX_OFFICE + "beadboard_roughness.png",
		"col": Color("8d7154"), "uv": Vector3(1.25, 0.85, 1.25), "rough": 0.80, "nrm_s": 0.75,
	},
	"ChairRail": {
		"alb": TEX_OFFICE + "beadboard_albedo.png",
		"nrm": TEX_OFFICE + "beadboard_normal.png",
		"rgh": TEX_OFFICE + "beadboard_roughness.png",
		"col": Color("9e7e5c"), "uv": Vector3(1.25, 0.85, 1.25), "rough": 0.76, "nrm_s": 0.72,
	},
	"HallPlaster": {
		"alb": TEX_TOWN1 + "boarding_wallpaper_128.png",
		"nrm": TEX_TOWN2 + "plaster_normal.png",
		"rgh": TEX_TOWN2 + "plaster_roughness.png",
		"col": Color("d8cdb4"), "uv": Vector3(1.4, 1.4, 1.4), "rough": 0.92, "nrm_s": 0.42,
	},
	"PaperFaded": {
		"alb": TEX_WEAR + "wallpaper_b.png",
		"nrm": TEX_TOWN2 + "plaster_normal.png",
		"rgh": TEX_TOWN2 + "plaster_roughness.png",
		"col": Color("d8d0be"), "uv": Vector3(1.5, 1.5, 1.5), "rough": 0.92, "nrm_s": 0.40,
	},
	"PaperStripe": {
		"alb": TEX_WEAR + "wallpaper_b.png",
		"nrm": TEX_TOWN2 + "plaster_normal.png",
		"rgh": TEX_TOWN2 + "plaster_roughness.png",
		"col": Color("c3ba9f"), "uv": Vector3(1.5, 1.5, 1.5), "rough": 0.92, "nrm_s": 0.40,
	},
	"Plaster": {
		"alb": TEX_TOWN2 + "plaster_albedo.png",
		"nrm": TEX_TOWN2 + "plaster_normal.png",
		"rgh": TEX_TOWN2 + "plaster_roughness.png",
		"col": Color("dcd2bd"), "uv": Vector3(0.85, 0.85, 0.85), "rough": 0.95, "nrm_s": 0.45,
	},
	"Desk": {
		"alb": TEX_TOWN2 + "mahogany_albedo.png",
		"nrm": TEX_TOWN2 + "mahogany_normal.png",
		"rgh": TEX_TOWN2 + "mahogany_roughness.png",
		"col": Color("b48763"), "uv": Vector3(1.6, 1.6, 1.6), "rough": 0.62, "nrm_s": 0.65,
	},
	"DeskD": {
		"alb": TEX_TOWN2 + "mahogany_albedo.png",
		"nrm": TEX_TOWN2 + "mahogany_normal.png",
		"rgh": TEX_TOWN2 + "mahogany_roughness.png",
		"col": Color("7a553c"), "uv": Vector3(1.6, 1.6, 1.6), "rough": 0.64, "nrm_s": 0.65,
	},
	"Apron": {
		"alb": TEX_TOWN2 + "mahogany_albedo.png",
		"nrm": TEX_TOWN2 + "mahogany_normal.png",
		"rgh": TEX_TOWN2 + "mahogany_roughness.png",
		"col": Color("c8b392"), "uv": Vector3(1.6, 1.6, 1.6), "rough": 0.68, "nrm_s": 0.60,
	},
	"Oak": {
		"alb": TEX_TOWN2 + "mahogany_albedo.png",
		"nrm": TEX_TOWN2 + "mahogany_normal.png",
		"rgh": TEX_TOWN2 + "mahogany_roughness.png",
		"col": Color("b9916a"), "uv": Vector3(1.6, 1.6, 1.6), "rough": 0.62, "nrm_s": 0.65,
	},
	"OakDark": {
		"alb": TEX_TOWN2 + "mahogany_albedo.png",
		"nrm": TEX_TOWN2 + "mahogany_normal.png",
		"rgh": TEX_TOWN2 + "mahogany_roughness.png",
		"col": Color("7f5d42"), "uv": Vector3(1.6, 1.6, 1.6), "rough": 0.66, "nrm_s": 0.65,
	},
	"Shadow": {
		"alb": TEX_TOWN2 + "mahogany_albedo.png",
		"nrm": TEX_TOWN2 + "mahogany_normal.png",
		"rgh": TEX_TOWN2 + "mahogany_roughness.png",
		"col": Color("543e2d"), "uv": Vector3(1.6, 1.6, 1.6), "rough": 0.72, "nrm_s": 0.60,
	},
	"OldWhite": {
		"alb": TEX_TOWN2 + "mahogany_albedo.png",
		"nrm": TEX_TOWN2 + "mahogany_normal.png",
		"rgh": TEX_TOWN2 + "mahogany_roughness.png",
		"col": Color("dfd4be"), "uv": Vector3(1.6, 1.6, 1.6), "rough": 0.70, "nrm_s": 0.50,
	},
	"Brick": {
		"alb": TEX_TOWN2 + "brick_albedo.png",
		"nrm": TEX_TOWN2 + "brick_normal.png",
		"rgh": TEX_TOWN2 + "brick_roughness.png",
		"col": Color("be7563"), "uv": Vector3(1.45, 1.45, 1.45), "rough": 0.90, "nrm_s": 0.95,
	},
	"BrickD": {
		"alb": TEX_TOWN2 + "brick_albedo.png",
		"nrm": TEX_TOWN2 + "brick_normal.png",
		"rgh": TEX_TOWN2 + "brick_roughness.png",
		"col": Color("66443b"), "uv": Vector3(1.45, 1.45, 1.45), "rough": 0.92, "nrm_s": 0.95,
	},
	"Stone": {
		"alb": TEX_TOWN2 + "stone_albedo.png",
		"nrm": TEX_TOWN2 + "stone_normal.png",
		"rgh": TEX_TOWN2 + "stone_roughness.png",
		"col": Color("a79f92"), "uv": Vector3(1.3, 1.3, 1.3), "rough": 0.92, "nrm_s": 0.85,
	},
	"StoneD": {
		"alb": TEX_TOWN2 + "stone_albedo.png",
		"nrm": TEX_TOWN2 + "stone_normal.png",
		"rgh": TEX_TOWN2 + "stone_roughness.png",
		"col": Color("7d766b"), "uv": Vector3(1.3, 1.3, 1.3), "rough": 0.92, "nrm_s": 0.85,
	},
	"IronTrim": {
		"alb": TEX_TOWN2 + "iron_albedo.png",
		"nrm": TEX_TOWN2 + "iron_normal.png",
		"rgh": TEX_TOWN2 + "iron_roughness.png",
		"col": Color("585450"), "uv": Vector3(2.2, 2.2, 2.2), "rough": 0.62, "metal": 0.52, "nrm_s": 0.60,
	},
	"Iron": {
		"alb": TEX_TOWN2 + "iron_albedo.png",
		"nrm": TEX_TOWN2 + "iron_normal.png",
		"rgh": TEX_TOWN2 + "iron_roughness.png",
		"col": Color("464340"), "uv": Vector3(2.2, 2.2, 2.2), "rough": 0.64, "metal": 0.52, "nrm_s": 0.60,
	},
	"Soot": {
		"alb": TEX_TOWN2 + "iron_albedo.png",
		"nrm": TEX_TOWN2 + "iron_normal.png",
		"rgh": TEX_TOWN2 + "iron_roughness.png",
		"col": Color("302b27"), "uv": Vector3(2.2, 2.2, 2.2), "rough": 0.72, "metal": 0.42, "nrm_s": 0.60,
	},
	"Tin": {
		"alb": TEX_TOWN2 + "iron_albedo.png",
		"nrm": TEX_TOWN2 + "iron_normal.png",
		"rgh": TEX_TOWN2 + "iron_roughness.png",
		"col": Color("a9a497"), "uv": Vector3(2.2, 2.2, 2.2), "rough": 0.42, "metal": 0.68, "nrm_s": 0.50,
	},
	"BrassAged": {
		"nrm": TEX_TOWN2 + "iron_normal.png",
		"col": Color("c79c56"), "uv": Vector3(2.4, 2.4, 2.4), "rough": 0.36, "metal": 0.78, "nrm_s": 0.25,
	},
	"Brass": {
		"nrm": TEX_TOWN2 + "iron_normal.png",
		"col": Color("c79c56"), "uv": Vector3(2.4, 2.4, 2.4), "rough": 0.36, "metal": 0.78, "nrm_s": 0.25,
	},
	"KeroseneWornBrass": {
		"nrm": TEX_TOWN2 + "iron_normal.png",
		"col": Color("c79c56"), "uv": Vector3(2.4, 2.4, 2.4), "rough": 0.36, "metal": 0.78, "nrm_s": 0.25,
	},
	"Copper": {
		"nrm": TEX_TOWN2 + "iron_normal.png",
		"col": Color("c87446"), "uv": Vector3(2.4, 2.4, 2.4), "rough": 0.32, "metal": 0.82, "nrm_s": 0.25,
	},
	"ParlorRug": {
		"alb": TEX_TOWN1 + "rag_rug_128.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"rgh": TEX_OFFICE + "wool_roughness.png",
		"col": Color("9e483c"), "uv": Vector3(1.8, 1.8, 1.8), "rough": 0.96, "nrm_s": 0.60,
	},
	"TrunkCanvas": {
		"alb": TEX_OFFICE + "wool_albedo.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"rgh": TEX_OFFICE + "wool_roughness.png",
		"col": Color("9c896c"), "uv": Vector3(2.2, 2.2, 2.2), "rough": 0.94, "nrm_s": 0.50,
	},
	"Indigo": {
		"alb": TEX_TOWN1 + "rag_rug_128.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"rgh": TEX_OFFICE + "wool_roughness.png",
		"col": Color("667085"), "uv": Vector3(1.8, 1.8, 1.8), "rough": 0.96, "nrm_s": 0.55,
	},
	"Canvas": {
		"alb": TEX_TOWN1 + "rag_rug_128.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"rgh": TEX_OFFICE + "wool_roughness.png",
		"col": Color("b0987c"), "uv": Vector3(1.8, 1.8, 1.8), "rough": 0.96, "nrm_s": 0.55,
	},
	"Velvet": {
		"alb": TEX_OFFICE + "wool_albedo.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"rgh": TEX_OFFICE + "wool_roughness.png",
		"col": Color("6c2320"), "uv": Vector3(2.8, 2.8, 2.8), "rough": 0.88, "nrm_s": 0.65,
	},
	"LinenCloth": {
		"alb": TEX_OFFICE + "wool_albedo.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"rgh": TEX_OFFICE + "wool_roughness.png",
		"col": Color("ddd2bc"), "uv": Vector3(2.5, 2.5, 2.5), "rough": 0.94, "nrm_s": 0.45,
	},
	"Ticking": {
		"alb": TEX_OFFICE + "wool_albedo.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"rgh": TEX_OFFICE + "wool_roughness.png",
		"col": Color("cfc2ab"), "uv": Vector3(2.5, 2.5, 2.5), "rough": 0.94, "nrm_s": 0.45,
	},
	"Linen": {
		"alb": TEX_OFFICE + "wool_albedo.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"rgh": TEX_OFFICE + "wool_roughness.png",
		"col": Color("e8dfc9"), "uv": Vector3(2.5, 2.5, 2.5), "rough": 0.94, "nrm_s": 0.45,
	},
	"Pillow": {
		"alb": TEX_OFFICE + "wool_albedo.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"rgh": TEX_OFFICE + "wool_roughness.png",
		"col": Color("dfd3c2"), "uv": Vector3(2.5, 2.5, 2.5), "rough": 0.94, "nrm_s": 0.45,
	},
	"Paper": {
		"alb": TEX_OFFICE + "wool_albedo.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"rgh": TEX_OFFICE + "wool_roughness.png",
		"col": Color("d9ccb0"), "uv": Vector3(2.5, 2.5, 2.5), "rough": 0.94, "nrm_s": 0.40,
	},
	"QuiltRed": {
		"alb": TEX_TOWN1 + "patchwork_quilt_128.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"col": Color("b57e78"), "uv": Vector3(1.6, 1.6, 1.6), "rough": 0.94, "nrm_s": 0.55,
	},
	"QuiltBlue": {
		"alb": TEX_TOWN1 + "patchwork_quilt_128.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"col": Color("8fa2b0"), "uv": Vector3(1.6, 1.6, 1.6), "rough": 0.94, "nrm_s": 0.55,
	},
	"QuiltOchre": {
		"alb": TEX_TOWN1 + "patchwork_quilt_128.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"col": Color("c9ab78"), "uv": Vector3(1.6, 1.6, 1.6), "rough": 0.94, "nrm_s": 0.55,
	},
	"QuiltCream": {
		"alb": TEX_TOWN1 + "patchwork_quilt_128.png",
		"nrm": TEX_OFFICE + "wool_normal.png",
		"col": Color("dcd0b4"), "uv": Vector3(1.6, 1.6, 1.6), "rough": 0.94, "nrm_s": 0.55,
	},
	"LeatherTrim": {
		"nrm": TEX_TOWN2 + "clay_normal.png",
		"col": Color("4c2e1e"), "uv": Vector3(2.2, 2.2, 2.2), "rough": 0.56, "spec": 0.35, "nrm_s": 0.45,
	},
	"Ceramic": {
		"col": Color("dcd5c5"), "rough": 0.24, "spec": 0.45,
	},
	"Glaze": {
		"col": Color("48637a"), "rough": 0.22, "spec": 0.50,
	},
	"Water": {
		"col": Color("557a82"), "rough": 0.15, "spec": 0.55,
	},
	"Mirror": {
		"col": Color("8ea0a0"), "rough": 0.20, "metal": 0.65, "spec": 0.78,
	},
	"Ember": {
		"alb": TEX_OFFICE + "ember_coals.png",
		"emit_tex": TEX_OFFICE + "ember_coals.png",
		"emit_col": Color(1.0, 0.36, 0.06), "emit_e": 2.4,
		"col": Color(0.45, 0.22, 0.14), "uv": Vector3(2.8, 2.8, 2.8), "rough": 0.85,
	},
	"Bread": {
		"alb": TEX_TOWN2 + "clay_albedo.png",
		"nrm": TEX_TOWN2 + "clay_normal.png",
		"col": Color("ba8548"), "uv": Vector3(2.4, 2.4, 2.4), "rough": 0.88, "nrm_s": 0.65,
	},
}

static var _cache: Dictionary = {}
static var _tex_cache: Dictionary = {}

static func apply_recursive(root: Node) -> void:
	if root == null:
		return
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var cur := queue.pop_back() as Node
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.material_override == null and mi.mesh != null:
				_apply_mesh(mi)
		for child in cur.get_children():
			queue.push_back(child)

static func _apply_mesh(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	var count := mesh.get_surface_count()
	for s in count:
		if mi.get_surface_override_material(s) != null:
			continue
		var src := mesh.surface_get_material(s)
		if src == null:
			continue
		var raw_name: String = src.resource_name
		var dot_idx: int = raw_name.find(".")
		var key: String = raw_name.substr(0, dot_idx) if dot_idx > 0 else raw_name
		if not PALETTE.has(key):
			continue
		var fmt: int = mesh.surface_get_format(s)
		var has_vcol: bool = (fmt & Mesh.ARRAY_FORMAT_COLOR) != 0
		mi.set_surface_override_material(s, _material_for(key, has_vcol))

static func _material_for(key: String, has_vcol: bool) -> StandardMaterial3D:
	var cache_key := "%s|%s" % [key, "vc" if has_vcol else "flat"]
	if _cache.has(cache_key):
		return _cache[cache_key] as StandardMaterial3D
	var spec: Dictionary = PALETTE[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = "BoardingPBR_" + key
	mat.albedo_color = spec.get("col", Color.WHITE)
	mat.roughness = float(spec.get("rough", 0.85))
	mat.metallic = float(spec.get("metal", 0.0))
	if spec.has("spec"):
		mat.metallic_specular = float(spec["spec"])
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.vertex_color_use_as_albedo = has_vcol
	if spec.has("uv"):
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = spec["uv"]
	if spec.has("alb"):
		mat.albedo_texture = _load_tex(String(spec["alb"]))
	if spec.has("nrm"):
		mat.normal_enabled = true
		mat.normal_scale = float(spec.get("nrm_s", 0.6))
		mat.normal_texture = _load_tex(String(spec["nrm"]))
	if spec.has("rgh"):
		mat.roughness_texture = _load_tex(String(spec["rgh"]))
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if spec.has("emit_tex"):
		mat.emission_enabled = true
		mat.emission = spec.get("emit_col", Color(1.0, 0.36, 0.06))
		mat.emission_energy_multiplier = float(spec.get("emit_e", 2.0))
		mat.emission_texture = _load_tex(String(spec["emit_tex"]))
	_cache[cache_key] = mat
	return mat

static func _load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	var tex := load(path) as Texture2D
	_tex_cache[path] = tex
	return tex
