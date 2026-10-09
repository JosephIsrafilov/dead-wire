extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var paper: TranscriptPaper = load("res://scenes/telegraph/transcript_paper.tscn").instantiate()
	root.add_child(paper)
	paper.set_process(false)
	await process_frame
	var rig := paper.get_writer_rig()
	var upper := rig.get_node_or_null("UpperArm") as MeshInstance3D
	check(upper != null, "Upper arm is separate from the moving forearm")
	if upper == null: quit(1); return
	paper.begin_writing("TRAIN 17 CLEAR EAST")
	paper.advance_paper(0.6)
	var shoulder := upper.position
	var visible_samples := 0
	var worst := 0.0
	for i in 500:
		paper.set_writing_progress(1.0)
		paper.advance_paper(0.016)
		if rig.is_ready_to_write():
			visible_samples += 1
			worst = maxf(worst,upper.position.distance_to(shoulder))
			var elbow: Vector3 = rig.get_node("Sleeve").transform * rig.get_node("Sleeve/ElbowAnchor").position
			var actual := upper.transform * Vector3(0,0,0.30)
			if actual.distance_to(elbow) > 0.001: failures += 1; break
	check(visible_samples > 20, "Shoulder sampled over writing motion")
	check(worst < 0.0001, "Glyph motion never translates the shoulder")
	check(failures == 0, "Upper arm stays connected to the moving elbow")
	check(upper.layers == 2, "Upper arm preserves layer contract")
	paper.queue_free()
	await process_frame
	quit(1 if failures else 0)
func check(ok: bool, text: String) -> void:
	if ok: print("PASS: ",text)
	else: failures += 1; printerr("FAIL: ",text)
