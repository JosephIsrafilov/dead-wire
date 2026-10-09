extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var paper := load("res://scenes/telegraph/transcript_paper.tscn").instantiate() as Node3D
	root.add_child(paper)
	await process_frame
	var parts := []
	for path in ["WriterRig/Sleeve/Wrist/Hand/HandMesh", "WriterRig/Sleeve/Wrist/WristMesh", "WriterRig/Sleeve/SleeveMesh", "WriterRig/Sleeve/Wrist/Hand/Pen/Shaft", "WriterRig/Sleeve/Wrist/Hand/Pen/Nib", "Sheet/PaperMesh"]:
		var node := paper.get_node(path) as MeshInstance3D
		for s in node.mesh.get_surface_count():
			var a := node.mesh.surface_get_arrays(s)
			var vv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var ii: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var cc: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var verts := []
			var colors := []
			var mat := node.mesh.surface_get_material(s) as StandardMaterial3D
			var col := mat.albedo_color if mat != null else Color.WHITE
			for i in (vv.size() if ii.is_empty() else ii.size()):
				var k: int = i if ii.is_empty() else ii[i]
				var v := paper.to_local(node.to_global(vv[k]))
				verts.append([v.x, v.y, v.z])
				var c := cc[k] if not cc.is_empty() else col
				colors.append([c.r, c.g, c.b])
			parts.append({"name": path + ":" + str(s), "vertices": verts, "colors": colors})
	var f := FileAccess.open("res://.dream-loop/hand_mesh.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(parts))
	f.close()
	paper.queue_free()
	await process_frame
	quit(0)
