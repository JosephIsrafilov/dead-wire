extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var p: TranscriptPaper = load("res://scenes/telegraph/transcript_paper.tscn").instantiate()
	root.add_child(p)
	p.set_process(false)
	await process_frame
	var rig := p.get_writer_rig()
	var nib := rig.get_node("Sleeve/Wrist/Hand/Pen/Nib") as Node3D
	check(nib.position.is_equal_approx(Vector3(0,-0.058,0)), "Nib keeps its authored offset, never a zeroed scene block")
	var shaft := rig.get_node("Sleeve/Wrist/Hand/Pen/Shaft") as Node3D
	check(shaft.position.is_equal_approx(Vector3(0,0.03,0)), "Shaft keeps its own authored offset")
	var upper := rig.get_node("UpperArm") as MeshInstance3D
	var elbow := rig.get_node("Sleeve/ElbowAnchor") as Node3D
	var shoulder := Vector3(0.07,0.17,0.57)
	p.begin_writing("TRAIN 17 CLEAR EAST")
	p.set_writing_progress(1.0)
	var max_len := 0.0
	var max_scale := 0.0
	var max_forearm := 0.0
	var max_tip := 0.0
	var contacts: Array[int] = []
	rig.glyph_contact.connect(func(i: int): contacts.append(i))
	for frame in 900:
		p.advance_paper(1.0/60.0)
		var e := rig.to_local(elbow.global_position)
		max_len = maxf(max_len,absf(e.distance_to(shoulder)-0.30))
		max_scale = maxf(max_scale,absf(upper.basis.z.length()-1.0))
		var cuff := rig.to_local(rig.get_node("Sleeve/Wrist/CuffAnchor").global_position)
		max_forearm = maxf(max_forearm,absf(cuff.distance_to(e)-0.27))
		if not rig.is_motion_pending() and rig.get_last_glyph_index() >= 0 and rig.is_ready_to_write():
			var target := p.to_global(p.get_glyph_contact(rig.get_last_glyph_index()))
			max_tip = maxf(max_tip,nib.to_global(Vector3(0,-0.011,0)).distance_to(target))
	check(max_len < 0.0001, "Upper bone stays 300mm throughout entry and every letter, error %.3fmm" % (max_len*1000))
	check(max_forearm < 0.0001, "Forearm stays 270mm, error %.3fmm" % (max_forearm*1000))
	check(max_scale < 0.0001, "Upper sleeve never stretches with the pen")
	check(max_tip < 0.001, "Nib contacts remain accurate, error %.3fmm" % (max_tip*1000))
	check(contacts.size() == 16, "Sixteen letters still produce sixteen contacts")
	check(upper.position.distance_to(shoulder) < 0.0001, "Shoulder matches the authored seated anatomy")
	p.queue_free()
	await process_frame
	quit(1 if failures else 0)
func check(ok: bool, text: String) -> void:
	if ok: print("PASS: ",text)
	else: failures += 1; printerr("FAIL: ",text)
