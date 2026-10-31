extends SceneTree

## One-shot splits of a moving part out of an authored static mesh. The part's
## faces (by surface and by where their centres lie) go into a mesh of their
## own, centred on the part's axis; the static mesh is written without them
## and is otherwise unchanged.
##
##   godot --headless --path . --script tools/split_mesh_part.gd -- <preset>
##
## Presets:
##   register_key  (plan 8.3) the register's side winding key and its arbor.
##   lamp_wheel    (plan 8.5) the oil lamp's wick wheel on the operator's side.

const PRESETS := {
	"register_key": {
		"static": "res://assets/models/instruments_v1/register_static.res",
		"part": "res://assets/models/instruments_v1/register_winding_key.res",
		"surfaces": ["dw_brass"],
		"axis_origin": Vector3(0.0, 0.04, -0.01),
		"min": Vector3(0.084, 0.027, -0.018),
		"max": Vector3(0.1, 0.053, -0.002),
	},
	"lamp_wheel": {
		"static": "res://assets/models/office_props_v1/oil_lamp_static.res",
		"part": "res://assets/models/office_props_v1/oil_lamp_wick_wheel.res",
		"surfaces": ["dw_props_brass"],
		"axis_origin": Vector3(0.0, 0.099, 0.0),
		"min": Vector3(0.0565, 0.086, -0.012),
		"max": Vector3(0.07, 0.112, 0.012),
	},
}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not PRESETS.has(args[0]):
		printerr("FAIL: name a preset: %s" % str(PRESETS.keys()))
		quit(1)
		return
	var preset: Dictionary = PRESETS[args[0]]
	var mesh := load(preset.static) as ArrayMesh
	if mesh == null:
		printerr("FAIL: no mesh at %s" % preset.static)
		quit(1)
		return
	var rebuilt := ArrayMesh.new()
	var part_mesh := ArrayMesh.new()
	var moved := 0
	for surface in mesh.get_surface_count():
		var tool := MeshDataTool.new()
		if tool.create_from_surface(mesh, surface) != OK:
			printerr("FAIL: surface %d cannot be read" % surface)
			quit(1)
			return
		var eligible: bool = mesh.surface_get_name(surface) in preset.surfaces
		# Copy only what the surface carries: a colour channel it never had would
		# arrive black.
		var format := mesh.surface_get_format(surface)
		var has_color := format & Mesh.ARRAY_FORMAT_COLOR != 0
		var has_uv := format & Mesh.ARRAY_FORMAT_TEX_UV != 0
		var has_tangent := format & Mesh.ARRAY_FORMAT_TANGENT != 0
		var keep := SurfaceTool.new()
		var part := SurfaceTool.new()
		keep.begin(Mesh.PRIMITIVE_TRIANGLES)
		part.begin(Mesh.PRIMITIVE_TRIANGLES)
		var parted := 0
		for face in tool.get_face_count():
			var centre := Vector3.ZERO
			for k in 3:
				centre += tool.get_vertex(tool.get_face_vertex(face, k))
			centre /= 3.0
			var in_part := eligible and centre.clamp(preset.min, preset.max).is_equal_approx(centre)
			var target := part if in_part else keep
			for k in 3:
				var index := tool.get_face_vertex(face, k)
				target.set_normal(tool.get_vertex_normal(index))
				if has_uv:
					target.set_uv(tool.get_vertex_uv(index))
				if has_color:
					target.set_color(tool.get_vertex_color(index))
				target.add_vertex(tool.get_vertex(index) - (preset.axis_origin if in_part else Vector3.ZERO))
			if in_part:
				parted += 1
		keep.index()
		if has_tangent:
			keep.generate_tangents()
		keep.commit(rebuilt)
		rebuilt.surface_set_material(rebuilt.get_surface_count() - 1, mesh.surface_get_material(surface))
		rebuilt.surface_set_name(rebuilt.get_surface_count() - 1, mesh.surface_get_name(surface))
		if parted > 0:
			part.index()
			if has_tangent:
				part.generate_tangents()
			part.commit(part_mesh)
			part_mesh.surface_set_material(part_mesh.get_surface_count() - 1, mesh.surface_get_material(surface))
			part_mesh.surface_set_name(part_mesh.get_surface_count() - 1, mesh.surface_get_name(surface))
			moved += parted
	print("PART FACES %d" % moved)
	if moved == 0:
		printerr("FAIL: no part faces found (already split?)")
		quit(1)
		return
	print("SAVE STATIC ", ResourceSaver.save(rebuilt, preset.static))
	print("SAVE PART ", ResourceSaver.save(part_mesh, preset.part))
	quit(0)
