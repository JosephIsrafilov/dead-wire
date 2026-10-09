extends SceneTree
const OUT_BASE := "res://docs/art/state_2026-10-09/hand_authored/office/"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	var tag := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.get_node("LampLife").set_wick_immediate(1.0)
	office.shift_director.enabled = false
	office.session_controller.set_process(false)
	office.session_controller.scheduler.auto_process = false
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	await process_frame
	office.player.set_physics_process(false)
	office.player.set_process_input(false)
	office.player.camera.look_at(office.session_controller.transcript_paper.global_position)
	var paper := office.session_controller.transcript_paper
	paper.get_node("WriterRig/Sleeve/Wrist/Hand/HandMesh").mesh = load(
		"res://docs/art/state_2026-10-09/hand_authored/sources/hand_before.res" if tag == "before" else
		"res://assets/models/operator/hand_authored_v1.res")
	paper.set_process(false)
	office.load_scenario_by_index(0)
	office.session_controller.start_transmission()
	office.session_controller.scheduler.advance_time(30.0)
	while paper.get_written_glyph_count() < 5: paper.advance_paper(0.016)
	var out := OUT_BASE+tag
	if "--1080" in OS.get_cmdline_user_args(): out += "_1080p"
	DirAccess.make_dir_recursive_absolute(out)
	await _shot(out+"/01_seated_arm.png")
	var cam := office.player.camera
	cam.global_position = Vector3(-1.45,1.25,-0.65)
	cam.look_at(Vector3(-2.3,0.78,-0.7))
	await _shot(out+"/02_desk_arm.png")
	for i in 300: paper.advance_paper(0.1)
	await _shot(out+"/03_finished_sheet.png")
	paper.get_interactable().interact()
	await _shot(out+"/04_lifted_sheet.png")
	office.queue_free()
	await process_frame
	quit(0)
func _shot(path: String) -> void:
	for i in 15: await process_frame
	await RenderingServer.frame_post_draw
	print("SHOT ",path," ",root.get_texture().get_image().save_png(path))
