extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func angle(a: Basis,b: Basis) -> float:
	return rad_to_deg(a.orthonormalized().get_rotation_quaternion().angle_to(b.orthonormalized().get_rotation_quaternion()))
func _run() -> void:
	root.size=Vector2i(1280,720)
	var ps: Array[TranscriptPaper]=[]
	var rests: Array[Transform3D]=[]
	for i in 2:
		var p: TranscriptPaper=load("res://scenes/telegraph/transcript_paper.tscn").instantiate()
		p.position=Vector3.ZERO if i==0 else Vector3(3,1,-2)
		p.rotation.y=0.0 if i==0 else PI/2.0
		root.add_child(p)
		p.set_process(false)
		p.feed_seconds=0.0
		var rig=p.get_writer_rig()
		rig.enter_duration=0.0
		ps.append(p)
		rests.append(rig.get_node("Sleeve").transform)
	await process_frame
	for i in 2:
		var p=ps[i]
		var rig=p.get_writer_rig()
		p.begin_writing("WATCHER",PackedFloat32Array(),"probe")
		for glyph in 5:
			rig.set_writing_progress(0.8,"WATCHER",glyph)
		var sleeve=rig.get_node("Sleeve") as Node3D
		print("REVIEW rig variant=",i,"local rotation drift=",angle(rests[i].basis,sleeve.basis),"local position=",sleeve.position)
		rig.reset()
		print("REVIEW after reset variant=",i,"remaining rotation error=",angle(rests[i].basis,sleeve.basis))
	for p in ps: p.queue_free()
	var office: M1OfficeController=load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.operator_seat.approach_duration=0.0
	office.operator_seat.sit_duration=0.0
	office.operator_seat.sit()
	var p=office.session_controller.transcript_paper
	var lbl=p.get_label_3d()
	var font=lbl.font if lbl.font!=null else ThemeDB.fallback_font
	var cam=office.player.camera
	var a=cam.unproject_position(lbl.to_global(Vector3.ZERO))
	var b=cam.unproject_position(lbl.to_global(Vector3(0,-font.get_height(lbl.font_size)*lbl.pixel_size,0)))
	print("REVIEW writing full-font-height screen pixels=",a.distance_to(b),"output viewport=",cam.get_viewport().get_visible_rect().size,"render_scale=",office.render_scale)
	var session=office.session_controller
	office.shift_director.set_process(false)
	session.set_process(false)
	session.scheduler.auto_process=false
	office.load_scenario_by_index(2)
	session.start_transmission()
	session.scheduler.advance_time(4.0)
	for i in 300: p.advance_paper(0.02)
	session.mark_transcript_verified()
	# Emulate input at the boundary before the next process tick resolves timeout.
	session._post_signal_elapsed=session.commit_deadline_seconds
	var chosen=office.copy_commit_desk.commit_option(&"file_water")
	print("REVIEW late commit accepted_by_surface=",chosen,"surface=",office.copy_commit_desk.get_result_text(),"session_state=",session.get_state(),"world_water=",root.get_node("WorldState").get_fact(&"core_hook_filed_water",false),"world_lapsed=",root.get_node("WorldState").get_fact(&"core_hook_commit_lapsed",false))
	session.advance_post_signal(0.0)
	print("REVIEW after timeout resolution: surface=",office.copy_commit_desk.get_result_text(),"world_water=",root.get_node("WorldState").get_fact(&"core_hook_filed_water",false),"world_lapsed=",root.get_node("WorldState").get_fact(&"core_hook_commit_lapsed",false))
	session.reset_session()
	office.queue_free()
	await process_frame
	await process_frame
	quit()
