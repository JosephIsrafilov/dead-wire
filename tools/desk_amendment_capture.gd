extends SceneTree

## Plan 6.3: the correction written by hand on the copy, from the chair —
## mid-word and finished. Windowed only. Writes .dream-loop/desk_amendment/.
##
##   godot --path . --resolution 1920x1080 --script tools/desk_amendment_capture.gd

const OUT_DIR := "res://.dream-loop/desk_amendment"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 4:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	(office.get_node("LampLife") as LampLife).set_wick_immediate(1.0)
	var session := office.session_controller
	session.set_process(false)
	var paper := session.transcript_paper
	office.load_scenario_by_index(2)
	paper.set_transcript_text("WATCHER")
	paper.reveal_transcript()
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	await process_frame
	var player := office.player
	var flat := Vector3(paper.global_position.x - player.global_position.x, 0.0, paper.global_position.z - player.global_position.z)
	player.rotation.y = atan2(-flat.x, -flat.z)
	var to_paper: Vector3 = paper.global_position - player.camera.global_position
	player.head.rotation.x = clampf(atan2(to_paper.y, Vector2(to_paper.x, to_paper.z).length()), -0.9, 0.9)
	for _i in 10:
		await process_frame
	await _shot("0_aimed")
	var desk := office.get_node("DeskAmendment") as DeskAmendment
	desk.begin()
	for letter in "WATER":
		var event := InputEventKey.new()
		event.keycode = OS.find_keycode_from_string(letter)
		event.pressed = true
		desk._input(event)
	await create_timer(0.5).timeout
	await _shot("1_writing")
	await create_timer(1.5).timeout
	desk.finish()
	await create_timer(1.6).timeout
	await _shot("2_written")
	quit(0)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	print("SHOT ", label, " ", root.get_texture().get_image().save_png(OUT_DIR.path_join(label + ".png")))
