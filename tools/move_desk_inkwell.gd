extends SceneTree

## One-shot (plan 5.8): moves the baked inkwell of the authored desk from the
## far left of the blotter to just right of the copy board, where the writing
## hand can reach it. Only the inkwell's own vertices move; nothing else in
## desk_static.res changes. tools/build_office_furniture_blender.py carries
## the same new position, so a future rebuild agrees with this file.
##
##   godot --headless --path . --script tools/move_desk_inkwell.gd

const MESH_PATH := "res://assets/models/office_furniture_v1/desk_static.res"
## Desk-local footprint of the inkwell (cylinder r 0.026, collar r 0.027).
const OLD_CENTRE := Vector2(0.52, -0.08)
const NEW_CENTRE := Vector2(-0.32, -0.20)
const RADIUS := 0.034
const MIN_Y := 0.751
const MAX_Y := 0.82

func _initialize() -> void:
	var mesh := load(MESH_PATH) as ArrayMesh
	if mesh == null:
		printerr("FAIL: no desk mesh")
		quit(1)
		return
	var delta := Vector3(NEW_CENTRE.x - OLD_CENTRE.x, 0.0, NEW_CENTRE.y - OLD_CENTRE.y)
	var rebuilt := ArrayMesh.new()
	var moved := 0
	var low := Vector3.INF
	var high := -Vector3.INF
	for surface in mesh.get_surface_count():
		var tool := MeshDataTool.new()
		if tool.create_from_surface(mesh, surface) != OK:
			printerr("FAIL: surface %d cannot be edited" % surface)
			quit(1)
			return
		for index in tool.get_vertex_count():
			var v := tool.get_vertex(index)
			if Vector2(v.x, v.z).distance_to(OLD_CENTRE) <= RADIUS and v.y >= MIN_Y and v.y <= MAX_Y:
				tool.set_vertex(index, v + delta)
				moved += 1
				low = low.min(v)
				high = high.max(v)
		tool.commit_to_surface(rebuilt)
		rebuilt.surface_set_material(rebuilt.get_surface_count() - 1, mesh.surface_get_material(surface))
		rebuilt.surface_set_name(rebuilt.get_surface_count() - 1, mesh.surface_get_name(surface))
	print("MOVED %d vertices, old bounds %s .. %s" % [moved, low, high])
	if moved == 0:
		printerr("FAIL: no inkwell vertices found (already moved?)")
		quit(1)
		return
	print("SAVE ", ResourceSaver.save(rebuilt, MESH_PATH))
	quit(0)
