extends SceneTree
## Actual rendered UI evidence; editor and tape are captured at production size.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	var session := office.session_controller
	session.set_process(false)
	office.load_scenario_by_index(2)
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	var out := "res://docs/research/mechanics_2026-10-10/ui_captures"
	DirAccess.make_dir_recursive_absolute(out)
	office.copy_commit_desk.select_option(0)
	for i in 15: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("01_blank_amendment.png"))
	office.amendment_editor.correction.text = "WAITER"
	office.amendment_editor.correction.text_changed.emit("WAITER")
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("02_explicit_wrong_draft.png"))
	office.amendment_editor.submit_draft()
	for i in 5: await process_frame
	office.dawn_evidence.reveal()
	office.dawn_evidence.get_interactable().interact()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("03_exact_choice_handover.png"))
	office.document_viewer.close_document()
	var tape := session.get_tape_register()
	session.scheduler.auto_process = false
	var encoder := AmericanMorseEncoder.new()
	var compiler := MorseScheduleCompiler.new()
	var schedule := compiler.compile(encoder.encode("WATER", session.alphabet), session.playback_profile)
	session.scheduler.start(schedule)
	session.scheduler.advance_time(schedule.total_duration_seconds)
	tape.get_interactable().interact()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("04_objective_tape.png"))
	print("UI captures saved: ", out)
	office.queue_free()
	await process_frame
	quit(0)
