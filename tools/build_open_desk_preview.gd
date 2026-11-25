extends SceneTree
func _init() -> void:
	var source := load("res://assets/models/office_furniture_v1/desk_static.res") as ArrayMesh
	var out := ArrayMesh.new()
	var removed := 0
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size():
				indices.append(i)
		var kept := PackedInt32Array()
		for i in range(0, indices.size(), 3):
			if vertices[indices[i]].y > 0.751 or vertices[indices[i + 1]].y > 0.751 or vertices[indices[i + 2]].y > 0.751:
				removed += 1
			else:
				kept.append_array(PackedInt32Array([indices[i], indices[i + 1], indices[i + 2]]))
		if kept.is_empty():
			continue
		var compact := []
		compact.resize(Mesh.ARRAY_MAX)
		var positions := PackedVector3Array()
		var normals := PackedVector3Array()
		var tangents := PackedFloat32Array()
		var uvs := PackedVector2Array()
		var colors := PackedColorArray()
		for idx in kept:
			positions.append(arrays[Mesh.ARRAY_VERTEX][idx])
			normals.append(arrays[Mesh.ARRAY_NORMAL][idx])
			uvs.append(arrays[Mesh.ARRAY_TEX_UV][idx])
			if arrays[Mesh.ARRAY_COLOR] != null:
				colors.append(arrays[Mesh.ARRAY_COLOR][idx])
			for component in 4:
				tangents.append(arrays[Mesh.ARRAY_TANGENT][idx * 4 + component])
		compact[Mesh.ARRAY_VERTEX] = positions
		compact[Mesh.ARRAY_NORMAL] = normals
		compact[Mesh.ARRAY_TANGENT] = tangents
		compact[Mesh.ARRAY_TEX_UV] = uvs
		if not colors.is_empty():
			compact[Mesh.ARRAY_COLOR] = colors
		arrays = compact
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, source.surface_get_material(surface))
	var result := ResourceSaver.save(out, "res://assets/models/office_furniture_v1/desk_open_preview.res")
	print("removed triangles ", removed, " save ", result)
	quit(0 if result == OK else 1)
