extends SceneTree

## Targeted windowed frames for the point fixes (plan, final verification 7):
## - two tape inspections of the same finished take at different spring
##   tensions (the visible tail must be stable), and
## - a previous-copy read and close while the next blank is feeding.
## Fixture-driven capture with minimal assertions; the full contracts live in
## tests/telegraph/tape_feed_monotonicity_test.gd and
## tests/integration/previous_copy_close_feed_test.gd.
##   godot --path . --script res://tools/targeted_fix_frames_capture.gd

const OUT_DIR := "res://.dream-loop/targeted_fix_frames"

var failures := 0
var shots := 0
var office: M1OfficeController

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("TARGETED FRAMES: real framebuffer needed; run without --headless")
		quit(2)
		return
	# --- Phase 1: the tape tail under a weakening spring --------------------
	office = await _make_office()
	var register := office.session_controller.get_tape_register()
	_drive_transmission()
	var act := register.get_interactable()
	act.interact()
	await _frames(3)
	var body_strong: String = office.document_viewer.body_label.text
	if not check(office.document_viewer.is_open()
		and office.document_viewer.get_current_doc_id() == "tape_register",
		"First tape inspection opened the station register"):
		_finish()
		return
	await _shot("p_tape_read_strong_tension")
	office.document_viewer.close_document()
	await _frames(2)
	register.spring_tension = 0.35
	register._process(1.0 / 60.0)
	act.interact()
	await _frames(3)
	var body_weak: String = office.document_viewer.body_label.text
	await _shot("p_tape_read_weak_tension")
	office.document_viewer.close_document()
	if not check(body_weak == body_strong,
			"The visible tape tail is identical after the spring runs down"):
		_finish()
		return
	office.queue_free()
	await _frames(2)

	# --- Phase 2: previous copy read + close during the new feed -----------
	office = await _make_office()
	var paper := office.session_controller.transcript_paper
	var sheet := paper.get_sheet_node()
	sheet.position = Vector3(0.04, 0.021, 0.015)
	paper._sheet_rest_position = sheet.position
	paper._sheet_rest_captured = true
	paper.begin_writing("TRAIN 17 CLEAR EAST")
	await _frames(20)
	paper.reveal_transcript()
	paper.begin_writing("WATCHER")
	await _frames(4)
	var previous_act := paper.get_node("PreviousSheet/Interactable") as Interactable
	previous_act.interact()
	await _frames(20)
	if not check(office.document_viewer.is_open()
		and office.document_viewer.get_current_doc_id() == "previous_transcript",
		"Previous copy opened during the new feed"):
		_finish()
		return
	await _shot("p_previous_lift_during_feed")
	office.document_viewer.close_document()
	await _frames(40)
	if not check(paper._previous_lift <= 0.0001,
			"The archived sheet returned after the close (lift %.4f)" % paper._previous_lift):
		_finish()
		return
	await _frames(20)
	await _shot("p_previous_returned_feed_continues")
	if not check(paper.get_state() == TranscriptPaper.PaperState.COPYING
		and paper.get_sheet_node().position == paper._sheet_rest_position,
			"The new blank finished feeding at its rest after the read"):
		_finish()
		return
	_finish()

func _make_office() -> M1OfficeController:
	var scene := load("res://scenes/office/m1_office.tscn") as PackedScene
	var node := scene.instantiate() as M1OfficeController
	root.add_child(node)
	await _frames(2)
	node.get_node("IntroCard").skip_immediately()
	node.shift_director.set_process(false)
	node.session_controller.set_process(false)
	node.session_controller.scheduler.auto_process = false
	root.size = Vector2i(1280, 720)
	await _frames(2)
	return node

func _drive_transmission() -> void:
	var session := office.session_controller
	var director := office.shift_director
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	director.open_line()
	director.advance(director.wait_seconds_before_call[0] + 0.5)
	session.telegraph_key.press()
	director.advance(director.answer_beat_seconds + 0.05)
	var scheduler := session.scheduler
	scheduler.advance_time(scheduler.get_total_duration_seconds() + 1.0)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _finish() -> void:
	print("TARGETED FRAMES: %d failures; %d screenshots" % [failures, shots])
	if office != null and is_instance_valid(office):
		office.queue_free()
		await _frames(2)
	quit(1 if failures else 0)

func _shot(label: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var image := root.get_texture().get_image()
	if image != null:
		check(image.save_png(OUT_DIR.path_join(label + ".png")) == OK, "Captured " + label)
		shots += 1

func check(condition: bool, message: String) -> bool:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
	return condition
