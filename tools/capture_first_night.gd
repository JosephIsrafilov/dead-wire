extends SceneTree

var office: M1OfficeController
var folder := "res://.dream-loop/review"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	office = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	office.session_controller.scheduler.auto_process = false
	office.session_controller.set_process(false)
	await _shot("entry")
	office.operator_seat.sit()
	await create_timer(1.0).timeout
	await _shot("seated")
	office.load_scenario_by_index(2)
	office.session_controller.start_transmission()
	for ratio in [0.25, 0.5, 0.75]:
		office.session_controller.scheduler.advance_time(0.9)
		await _shot("writing_%d" % int(ratio * 100))
	office.session_controller.scheduler.advance_time(1.0)
	await _shot("written")
	office.player.camera.fov = 48.0
	var sound_direction := office.session_controller.sounder.global_position + Vector3(0, 0.05, 0) - office.player.camera.global_position
	office.player.rotation.y = atan2(-sound_direction.x, -sound_direction.z)
	office.player.head.rotation.x = atan2(sound_direction.y, Vector2(sound_direction.x, sound_direction.z).length())
	await _shot("hardware")
	office.player.camera.fov = 78.0
	office.session_controller.mark_transcript_verified()
	office.operator_seat.stand()
	await create_timer(0.8).timeout
	_view(Vector3(0.95, 0, 0.45), Vector3(0.95, 0.84, 1.35))
	await _shot("filing_ready")
	office.copy_commit_desk.select_option(0)
	await _shot("filing_water")
	office.session_controller.advance_consequence(1.0)
	await process_frame
	_view(Vector3(0.45, 0, -1.1), Vector3(0.72, 1.5, -2.85))
	await _shot("figure")
	office.load_scenario_by_index(2)
	office.session_controller.start_transmission()
	office.session_controller.scheduler.advance_time(4.0)
	office.session_controller.mark_transcript_verified()
	office.copy_commit_desk.select_option(1)
	_view(Vector3(0.95, 0, 0.45), Vector3(0.95, 0.84, 1.35))
	await _shot("filing_watcher")
	office.load_scenario_by_index(2)
	office.session_controller.start_transmission()
	office.session_controller.scheduler.advance_time(4.0)
	office.session_controller.lapse_commit()
	await _shot("filing_lapsed")
	_view(Vector3(-0.15, 0, 1.05), Vector3(-1.6, 1.0, 2.30))
	await _shot("door_zone")
	office.shift_end_card.play("END OF WATCH", office.get_node("DutySheet").get_watch_record())
	await create_timer(3.3).timeout
	await _shot("ending")
	quit()

func _view(position: Vector3, target: Vector3) -> void:
	office.player.global_position = position
	var direction := target - office.player.camera.global_position
	office.player.rotation.y = atan2(-direction.x, -direction.z)
	office.player.head.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())

func _shot(label: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png(folder.path_join(label + ".png"))
	print("CAPTURE: ", label, " ", picture.get_size(), " fps=", Engine.get_frames_per_second())
