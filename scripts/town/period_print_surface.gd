extends RefCounted
## Printed surfaces with a small physical curl, not text floating over a box.

static func place(parent: Node3D, title: String, pos: Vector3, size: Vector2,
		texture: Texture2D, rotation_deg := Vector3.ZERO, curl := 0.0) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 5:
		for col in 6:
			var a := Vector2(col / 6.0, row / 5.0)
			var b := a + Vector2(1.0 / 6, 0)
			var c := a + Vector2(0, 1.0 / 5)
			var d := b + c - a
			for uv: Vector2 in [a, c, b, b, c, d]:
				surface.set_uv(Vector2(uv.x, 1.0 - uv.y))
				var lift := curl * (pow(absf(uv.x - 0.5) * 2, 3) + pow(uv.x * (1 - uv.y), 7))
				surface.add_vertex(Vector3((uv.x - 0.5) * size.x, (uv.y - 0.5) * size.y, lift))
	surface.generate_normals()
	var sheet := MeshInstance3D.new()
	sheet.name = title
	sheet.position = pos
	sheet.rotation_degrees = rotation_deg
	sheet.mesh = surface.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.92
	sheet.material_override = mat
	parent.add_child(sheet)
	return sheet
