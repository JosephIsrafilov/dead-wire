extends RefCounted

static func apply(mat: StandardMaterial3D, atlas: Texture2D, kind: String) -> void:
	var stem := atlas.resource_path.get_basename()
	mat.albedo_texture = atlas
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.vertex_color_use_as_albedo = true
	mat.normal_enabled = true
	mat.normal_texture = load(stem + "_normal.png") as Texture2D
	mat.roughness_texture = load(stem + "_roughness.png") as Texture2D
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 1.0
	mat.normal_scale = 0.57
	mat.metallic = 0.0
	mat.metallic_specular = 0.22
	if kind.contains("brass"):
		mat.metallic = 0.89
		mat.metallic_specular = 0.5
	elif kind.contains("iron"):
		mat.metallic = 0.72
		mat.normal_scale = 0.85

static func glass(mat: StandardMaterial3D, tint: Color) -> void:
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	mat.normal_enabled = false
	mat.metallic = 0.0
	mat.disable_receive_shadows = true
