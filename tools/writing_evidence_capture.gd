extends SceneTree

## Timing-fix visual evidence: the office runs live, the operator is seated,
## the baseline transmission writes itself with the fixed clock contract, and
## the writing hand is captured mid-glyph three times plus the finished sheet.
## Causality itself is proven headlessly by paper_telemetry.json
## (tools/production_evidence_capture.gd); this tool only feeds the vision
## check something to look at. Run windowed.

const OUT_DIR := "res://.dream-loop/writing_evidence"

var shots: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	var session := office.session_controller
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.stand_duration = 0.0
	office.operator_seat.sit()
	await process_frame
	await process_frame
	check(office.operator_seat.is_seated and office.operator_seat.is_settled(), "Operator seated and settled at the desk")

	session.allow_key_start = true
	office.load_scenario_by_index(0)
	check(session.start_transmission(), "Transmission starts for the writing evidence")
	var paper: TranscriptPaper = session.transcript_paper
	var rig := paper.get_writer_rig()

	# Aim the seated body at the writing zone, gameplay-style yaw/pitch.
	var paper_world: Vector3 = paper.global_position
	var player := office.player
	var flat := Vector3(paper_world.x - player.global_position.x, 0.0, paper_world.z - player.global_position.z)
	player.rotation.y = atan2(-flat.x, -flat.z)
	var to_paper: Vector3 = paper_world - player.camera.global_position
	player.head.rotation.x = clampf(atan2(to_paper.y, maxf(Vector2(to_paper.x, to_paper.z).length(), 0.001)), -0.9, 0.9)
	await process_frame
	await process_frame

	# Mid-write on the first row, hand mid-glyph.
	await _wait_for(func() -> bool:
		return paper.get_written_glyph_count() >= 4 and rig.is_motion_pending(), 4000)
	await _shot("w1_first_row_midglyph")
	# The row change itself: the second row's first glyphs under way.
	await _wait_for(func() -> bool:
		return paper.get_written_glyph_count() >= 9 and rig.is_motion_pending(), 4000)
	await _shot("w2_second_row")
	# The finished sheet, hand withdrawn or at rest.
	await _wait_for(func() -> bool: return paper.is_ready_to_inspect(), 8000)
	await _shot("w3_finished_sheet")

	print("WRITING EVIDENCE: %d screenshots" % shots)
	office.queue_free()
	quit(0)

func _wait_for(predicate: Callable, frame_budget: int) -> void:
	var guard := 0
	while not predicate.call() and guard < frame_budget:
		await process_frame
		guard += 1

func _shot(label: String) -> void:
	await create_timer(0.05).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var image := root.get_texture().get_image()
	if image != null:
		check(image.save_png(OUT_DIR.path_join(label + ".png")) == OK, "Captured " + label)
		shots += 1

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		printerr("FAIL: ", message)
