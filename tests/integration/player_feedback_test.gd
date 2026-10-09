extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	office.session_controller.set_process(false)
	office.session_controller.scheduler.auto_process = false
	var paper := office.session_controller.transcript_paper
	var viewer := office.document_viewer
	paper.set_process(false)
	var form := paper.get_node("Sheet/FormFace") as MeshInstance3D
	var label := paper.get_label_3d()
	var widest := 0.0
	for row in paper._layout_prefix("TRAIN 17 CLEAR EAST").split("\n"):
		widest = maxf(widest, label.font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size)
	check(widest < 0.18, "Live ink rows fit the real sheet without reducing seated legibility")
	if failures: quit(1); return
	var material := form.mesh.material as StandardMaterial3D
	viewer.open_document("transcript_paper", "NIGHT COPY", "TRAIN 17 CLEAR EAST")
	var face := viewer.get_node_or_null("TranscriptSheet") as TextureRect
	check(face != null and face.texture == material.albedo_texture, "Lifted copy uses the same printed sheet texture as the desk")
	if failures: quit(1); return
	check(viewer.body_label.text == "TRAIN 17 CLEAR EAST", "Logical viewer text preserves the exact transcript")
	check(viewer.get_node("TranscriptSheet/Ink").text == paper._layout_prefix("TRAIN 17 CLEAR EAST"), "World and lifted sheet use the same line breaks")
	viewer.close_document()
	check(paper.get_node("PreviousSheet/Interactable").collision_layer == 0,
		"Invisible archive has no collider to steal the active copy ray")
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	office.load_scenario_by_index(0)
	check(office.session_controller.start_transmission(), "Start baseline in the seated office")
	office.player.camera.look_at(office.window_observation.global_position)
	office.session_controller.scheduler.advance_time(30.0)
	for i in 200: paper.advance_paper(0.25)
	check(paper.is_ready_to_inspect(), "Looking away does not stop the copy")
	office._update_transcript_prompt()
	check(paper.get_interactable().is_actionable, "Returning to the completed copy offers reading")
	paper.get_interactable().interact()
	check(viewer.is_open(), "Look-away copy can be opened")
	var ray := office.player.get_node("Head/Camera3D/InteractionRay") as RayCast3D
	office.player.camera.look_at(paper.global_position)
	await physics_frame
	ray.force_raycast_update()
	check(ray.get_collider() == paper.get_interactable(), "Real seated ray reaches active paper, not the invisible archived area")
	viewer.close_document()
	office.load_scenario_by_index(1)
	check(paper.get_display_text() == "TRAIN 17 CLEAR EAST", "Loading next order keeps the finished record")
	office.session_controller.start_transmission()
	for i in 8: paper.advance_paper(0.1)
	var archived := paper.get_node_or_null("PreviousSheet/Interactable") as Interactable
	check(archived != null, "Archived sheet has an interaction target")
	if archived != null:
		var state := office.session_controller.get_state()
		archived.interact()
		check(viewer.is_open() and viewer.get_current_doc_id() == "previous_transcript", "Old copy remains readable while the next is being written")
		check(viewer.body_label.text == "TRAIN 17 CLEAR EAST", "Archived read shows only the old visible ink")
		check(office.session_controller.get_state() == state, "Archived inspection never verifies the new telegram")
		viewer.close_document()
	office.queue_free()
	await process_frame
	quit(1 if failures else 0)
func check(ok: bool, text: String) -> void:
	if ok: print("PASS: ",text)
	else: failures += 1; printerr("FAIL: ",text)
