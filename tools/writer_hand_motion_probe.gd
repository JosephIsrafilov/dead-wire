extends SceneTree
## Production timing/pose evidence only; deliberately NOT a visual acceptance tool.
## godot --headless --audio-driver Dummy --fixed-fps 60 --path . --script tools/writer_hand_motion_probe.gd

const OUT := "res://.dream-loop/hand_motion.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	await process_frame
	var session := office.session_controller
	session.allow_key_start = true
	office.load_scenario_by_index(0)
	var paper := session.transcript_paper
	var rig := paper.get_writer_rig()
	var contacts := []
	rig.glyph_contact.connect(func(index: int):
		var nib := paper.get_node("WriterRig/Sleeve/Wrist/Hand/Pen/Nib") as Node3D
		var actual := nib.to_global(Vector3(0, -0.011, 0))
		var expected := paper.to_global(paper.get_glyph_contact(index))
		contacts.append({"glyph": index, "error_m": actual.distance_to(expected)})
	)
	if not session.start_transmission():
		printerr("FAIL: production transmission did not start")
		quit(1)
		return
	var states := {}
	var samples := []
	var timed_out := true
	for frame in 12000:
		await process_frame
		var state: int = rig.get_presentation_state()
		states[state] = true
		if frame % 6 == 0:
			var nib := paper.get_node("WriterRig/Sleeve/Wrist/Hand/Pen/Nib") as Node3D
			var p := paper.to_local(nib.to_global(Vector3(0, -0.011, 0)))
			samples.append({"frame": frame, "state": state, "glyphs": paper.get_written_glyph_count(),
				"nib": [p.x, p.y, p.z]})
		if paper.is_ready_to_inspect() and state == WriterRig.PresentationState.WITHDRAWN:
			timed_out = false
			break
	var max_error := 0.0
	for contact in contacts:
		max_error = maxf(max_error, contact.error_m)
	var ok := not timed_out and contacts.size() > 9 and max_error < 0.0001
	ok = ok and states.has(WriterRig.PresentationState.ENTER)
	ok = ok and states.has(WriterRig.PresentationState.WRITING)
	ok = ok and states.has(WriterRig.PresentationState.FINISH)
	ok = ok and states.has(WriterRig.PresentationState.WITHDRAWN)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"visual_acceptance": false, "passed": ok,
		"timed_out": timed_out, "max_contact_error_m": max_error,
		"contacts": contacts, "samples": samples}, "	"))
	f.close()
	print(("PASS: " if ok else "FAIL: ") + "Production hand motion: %d contacts, max error %.6f m, states %s" % [
		contacts.size(), max_error, states.keys()])
	office.queue_free()
	await process_frame
	quit(0 if ok else 1)
