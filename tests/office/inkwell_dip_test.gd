extends SceneTree

## The visible desk geometry must leave a real opening along the dip trajectory.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	var mouth := office.get_node("InkwellMouth") as Marker3D
	var desk := office.get_node("DeskSetup") as Node3D
	# Check the tip and a small clearance circle, not just a single ray that
	# might happen to pass through a seam in the mesh.
	var bottom := mouth.global_position + Vector3.DOWN * 0.012
	for p in [Vector3.ZERO, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var offset: Vector3 = p * 0.003
		if not _check(not _desk_intersects(desk, mouth.global_position + Vector3.UP * 0.035 + offset,
				bottom + offset), "No solid desk geometry crosses the nib's path through the mouth"): return
	if not _check(_desk_intersects(desk, bottom, mouth.global_position + Vector3.DOWN * 0.045),
			"The opening leads into the inkwell, not through the desk"): return
	var paper := office.session_controller.transcript_paper
	var rig := paper.get_writer_rig()
	paper.begin_writing("A")
	paper.advance_paper(paper.feed_seconds + rig.enter_duration + 0.01)
	rig.finish_with_dip()
	if not _check(rig.is_dipping(), "The production rig starts the inkwell dip"): return
	var dip := rig._active_tween
	dip.pause()
	dip.custom_step(rig.dip_reach_seconds + rig.dip_seconds)
	var nib := rig.get_node("Sleeve/Wrist/Hand/Pen/Nib") as Node3D
	var tip := nib.to_global(Vector3(0, -0.011, 0)) - mouth.global_position
	if not _check(Vector2(tip.x, tip.z).length() < 0.004 and tip.y < -0.006 and tip.y >= -0.013,
			"The real nib tip passes below the lip of the inkwell (offset %s)" % tip): return
	var ink := desk.get_node("Inkwell/Ink") as MeshInstance3D
	var ink_surface := ink.to_global(Vector3.UP * ink.get_aabb().end.y)
	if not _check(ink.is_visible_in_tree() and nib.to_global(Vector3(0, -0.011, 0)).y < ink_surface.y
			and ink_surface.y < mouth.global_position.y, "The nib reaches the recessed ink below the open lip"): return
	office.queue_free()
	await process_frame
	quit(0)

func _desk_intersects(desk: Node3D, start: Vector3, end: Vector3) -> bool:
	for node in desk.find_children("*", "MeshInstance3D", true, false):
		var visual := node as MeshInstance3D
		if visual.name == &"Ink" or not visual.is_visible_in_tree() or visual.mesh == null:
			continue
		var a := visual.to_local(start)
		var b := visual.to_local(end)
		var vertices := visual.mesh.get_faces()
		for i in range(0, vertices.size(), 3):
			if Geometry3D.segment_intersects_triangle(a, b, vertices[i], vertices[i + 1], vertices[i + 2]) != null:
				return true
	return false

func _check(ok: bool, description: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + description)
	if not ok:
		quit(1)
	return ok
