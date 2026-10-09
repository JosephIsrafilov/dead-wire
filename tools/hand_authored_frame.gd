extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var paper: Node3D = load("res://scenes/telegraph/transcript_paper.tscn").instantiate()
	root.add_child(paper)
	await process_frame
	var hand: Node3D = paper.get_node("WriterRig/Sleeve/Wrist/Hand")
	var pen: Node3D = hand.get_node("Pen")
	var shaft: MeshInstance3D = pen.get_node("Shaft")
	var nib: Node3D = pen.get_node("Nib")
	var to_sheet := paper.global_transform.affine_inverse()
	var tip: Vector3 = to_sheet * nib.to_global(Vector3(0, -0.011, 0))
	tip.y = 0.0006
	var origin: Vector3 = to_sheet * shaft.global_position - tip
	var axis: Vector3 = (to_sheet.basis * shaft.global_basis.y).normalized()
	var pen_pos: Vector3 = to_sheet * pen.global_position - tip
	var grip: Vector3 = pen_pos + axis * -0.043
	var up: Vector3 = (Vector3.UP - axis * axis.y).normalized()
	var left: Vector3 = axis.cross(up).normalized()
	if left.x > 0: left = -left
	var data := {"axis": [axis.x,axis.y,axis.z], "origin": [origin.x,origin.y,origin.z],
		"grip": [grip.x,grip.y,grip.z], "up": [up.x,up.y,up.z],
		"left": [left.x,left.y,left.z]}
	var f := FileAccess.open("res://assets/models/operator/hand_authored_frame.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	print(data)
	paper.queue_free()
	await process_frame
	quit(0)
