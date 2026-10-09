extends SceneTree

## Import explicit connected authored patch data. Does not edit pen/cloth transforms.
const SOURCE := "res://assets/models/operator/hand_authored_v1.json"
const OUT := "res://assets/models/operator/hand_authored_v1.res"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var paper: Node3D = load("res://scenes/telegraph/transcript_paper.tscn").instantiate()
	root.add_child(paper)
	await process_frame
	var hand: Node3D = paper.get_node("WriterRig/Sleeve/Wrist/Hand")
	var nib: Node3D = hand.get_node("Pen/Nib")
	var to_sheet := paper.global_transform.affine_inverse()
	var tip: Vector3 = to_sheet * nib.to_global(Vector3(0,-0.011,0))
	tip.y = 0.0006
	var to_hand := (to_sheet * hand.global_transform).affine_inverse()
	var mesh := ArrayMesh.new()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for part in 6:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(material)
		for f in data.faces.size():
			if int(data.groups[f]) != part: continue
			# Godot front face is clockwise; authored normals remain outward.
			for corner in [0,2,1]:
				var i := int(data.faces[f][corner])
				var v: Array = data.vertices[i]
				var n: Array = data.normals[i]
				var normal := Vector3(n[0],n[1],n[2])
				var color := Color(0.46,0.37,0.32).lerp(Color(0.49,0.38,0.33),clampf(normal.y,0,1))
				if f in data.nail_faces: color = Color(0.57,0.48,0.42)
				st.set_color(color)
				st.set_normal(to_hand.basis * normal)
				st.add_vertex(to_hand * (tip + Vector3(v[0],v[1],v[2])))
		mesh = st.commit(mesh)
		mesh.surface_set_name(part,data.parts[part])
	var err := ResourceSaver.save(mesh, OUT)
	print("AUTHORED hand surfaces=",mesh.get_surface_count()," saved=",err)
	paper.queue_free()
	await process_frame
	quit(err)
