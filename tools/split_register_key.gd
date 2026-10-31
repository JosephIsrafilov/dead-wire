extends SceneTree

## One-shot (plan 8.3): the register's winding key was baked into its static
## mesh and could never turn. This moves the key and its arbor (the brass
## faces standing proud of the right-hand side panel) into a mesh of their
## own, centred on the arbor's axis, and writes the static mesh without them.
## Nothing else in register_static.res changes.
##
##   godot --headless --path . --script tools/split_register_key.gd

const STATIC_PATH := "res://assets/models/instruments_v1/register_static.res"
const KEY_PATH := "res://assets/models/instruments_v1/register_winding_key.res"
const BRASS_SURFACE := "dw_brass"
## Register-local axis of the arbor (it runs along +X out of the side panel).
const AXIS_ORIGIN := Vector3(0.0, 0.04, -0.01)
## Face centroids inside this box belong to the key and its arbor.
const KEY_MIN := Vector3(0.084, 0.027, -0.018)
const KEY_MAX := Vector3(0.1, 0.053, -0.002)

func _initialize() -> void:
	var mesh := load(STATIC_PATH) as ArrayMesh
	if mesh == null:
		printerr("FAIL: no register mesh")
		quit(1)
		return
	var rebuilt := ArrayMesh.new()
	var key := ArrayMesh.new()
	var moved := 0
	for surface in mesh.get_surface_count():
		var tool := MeshDataTool.new()
		if tool.create_from_surface(mesh, surface) != OK:
			printerr("FAIL: surface %d cannot be read" % surface)
			quit(1)
			return
		var is_brass := mesh.surface_get_name(surface) == BRASS_SURFACE
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
			var in_key := is_brass and centre.clamp(KEY_MIN, KEY_MAX).is_equal_approx(centre)
			var target := part if in_key else keep
			for k in 3:
				var index := tool.get_face_vertex(face, k)
				target.set_normal(tool.get_vertex_normal(index))
				if has_uv:
					target.set_uv(tool.get_vertex_uv(index))
				if has_color:
					target.set_color(tool.get_vertex_color(index))
				target.add_vertex(tool.get_vertex(index) - (AXIS_ORIGIN if in_key else Vector3.ZERO))
			if in_key:
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
			part.commit(key)
			key.surface_set_material(key.get_surface_count() - 1, mesh.surface_get_material(surface))
			key.surface_set_name(key.get_surface_count() - 1, mesh.surface_get_name(surface))
			moved += parted
	print("KEY FACES %d" % moved)
	if moved == 0:
		printerr("FAIL: no key faces found (already split?)")
		quit(1)
		return
	print("SAVE STATIC ", ResourceSaver.save(rebuilt, STATIC_PATH))
	print("SAVE KEY ", ResourceSaver.save(key, KEY_PATH))
	quit(0)
