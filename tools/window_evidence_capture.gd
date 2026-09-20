extends SceneTree

## V2 window evidence (asset pass §5.3) — a LOGIC/VISIBILITY fixture.
##
## This drives the session by hand (director/session processing off, manual
## consequence stepping) so the window contracts are deterministic: appearance
## while unobserved, voluntary turn, deferral under a watched window, bounded
## fallback. It is NOT proof of natural input; that proof is
## tools/production_evidence_capture.gd, which runs the same room through real
## movement, mouse look and ray+E with everything processing live.
##
## 1. Commit from the real filing position.
## 2. Camera deliberately AWAY; wait for the figure to actually appear
##    (visibility_started equivalent: indicator visible while unobserved).
## 3. Turn with gameplay-style rotation, screenshot from the gameplay camera.
## 4. Seated at the desk (really seated and settled, asserted), same turn.
## 5. Pre-aimed camera: pending defers, no hang.

var shots: int = 0
var failures: int = 0
var out_dir := "res://.dream-loop/window_evidence"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	var session := office.session_controller
	var director := office.shift_director
	director.set_process(false)
	session.set_process(false)
	session.scheduler.auto_process = false
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.stand_duration = 0.0
	office.operator_seat.sit()
	var paper := session.transcript_paper

	# Drive the whole night quickly to the core-hook commit.
	office.session_controller.allow_key_start = true
	office.load_scenario_by_index(2)
	check(session.start_transmission(), "Transmission starts for the window case")
	session.scheduler.advance_time(4.0)
	_drain(paper)
	session.mark_transcript_verified()
	# Commit physically at the desk (real filing position by the door).
	await _stand_and_walk(Vector3(0.95, 0, 0.45))
	var desk_act := office.copy_commit_desk.get_node("Option1Interactable")
	check(office.copy_commit_desk.commit_option(&"file_water"), "Physical commit at the filing desk")
	check(session.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Commit enters the consequence beat")

	# 2. Look AWAY (south), let the consequence beat fire and the figure appear.
	office.player.rotation.y = deg_to_rad(180.0)
	await process_frame
	var figure := office.window_observation
	session.advance_consequence(1.05)
	check(figure.is_active, "Consequence figure is active after recovery delay")
	var guard := 0
	while not figure.get_visual_indicator().visible and guard < 40:
		session.advance_consequence(0.1)
		await process_frame
		guard += 1
	check(figure.get_visual_indicator().visible, "Figure appeared while the camera looked away (no hang)")
	check(not figure.is_observed, "Appearance is not auto-observation")

	# 3. Turn toward the window with gameplay-style rotation, capture.
	await _turn_to(figure.global_position)
	await _shot("w1_commit_turn")

	# 4. Desk position: sit for real (instant durations in this fixture), then
	# the same voluntary turn from the chair.
	await _stand_and_walk(Vector3(-1.35, 0, -0.1))
	office().operator_seat.sit()
	check(office().operator_seat.is_seated and office().operator_seat.is_settled(), "The desk shot is taken actually seated and settled")
	office().player.rotation.y = deg_to_rad(-90.0)
	await _turn_to(figure.global_position)
	await _shot("w2_seat_turn")

	# 5. Pre-aimed: reset, re-trigger, camera already on the window.
	session.set_consequence_visibility_required(true)
	session.reset_session()
	await _stand_and_walk(Vector3(-1.4, 0, -0.3))
	office.operator_seat.sit()
	check(office.operator_seat.is_settled(), "Operator settled back at the chair for the pre-aimed case")
	office.session_controller.allow_key_start = true
	office.load_scenario_by_index(2)
	check(session.start_transmission(), "Pre-aimed case transmission starts")
	session.scheduler.advance_time(4.0)
	_drain(paper)
	session.mark_transcript_verified()
	session.submit_commit(&"file_water")
	await _turn_to(figure.global_position)
	session.advance_consequence(1.05)
	check(figure.is_active and not figure.get_visual_indicator().visible, "Watched window defers the appearance (no pop-in)")
	await _shot("w3_preaimed_pending")
	var guard2 := 0
	while figure.is_active and not figure.get_visual_indicator().visible and guard2 < 80:
		session.advance_consequence(0.25)
		await process_frame
		guard2 += 1
	check(not figure.is_active or figure.get_visual_indicator().visible, "Bounded fallback resolves a fully-watched pending figure")
	await _shot("w4_preaimed_resolved")

	print("WINDOW EVIDENCE: %d failures; %d screenshots" % [failures, shots])
	office.queue_free()
	quit(1 if failures else 0)

func _drain(p: TranscriptPaper) -> void:
	var guard := 0
	while p.is_copy_in_progress() and guard < 400:
		p.advance_paper(0.25)
		guard += 1

func _stand_and_walk(pos: Vector3) -> void:
	if office_is_seated():
		office().operator_seat.stand()
	office().player.global_position = pos
	await process_frame

func office() -> M1OfficeController:
	return root.get_child(root.get_child_count() - 1) as M1OfficeController

func office_is_seated() -> bool:
	return office().operator_seat != null and office().operator_seat.is_seated

func _interact_target(target: Node3D) -> void:
	# Production commits through the interactable's own signal path.
	target.emit_signal("interacted")

func _turn_to(world_point: Vector3) -> void:
	# Gameplay-style: set yaw through the player the same way look input would.
	var player := office().player
	var flat := Vector3(world_point.x - player.global_position.x, 0, world_point.z - player.global_position.z)
	player.rotation.y = atan2(-flat.x, -flat.z)
	await process_frame
	await process_frame

func _shot(label: String) -> void:
	await create_timer(0.25).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var image := root.get_texture().get_image()
	check(image.save_png(out_dir.path_join(label + ".png")) == OK, "Captured " + label)
	shots += 1

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
