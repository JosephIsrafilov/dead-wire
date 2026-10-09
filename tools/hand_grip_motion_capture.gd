extends SceneTree

## Windowed real office, production scheduler and presentation clocks.
## Only the setup is staged (intro skipped, already seated, director disabled).
## Use --write-movie .dream-loop/hand_grip_movie/frame.png --fixed-fps 30.
var office: M1OfficeController
var elapsed := 0.0
var active := false
var started := false
var completed := false
var tail := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	office = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.get_node("LampLife").set_wick_immediate(1.0)
	office.shift_director.enabled = false
	office.shift_director.set_process(false)
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	await process_frame
	office.player.set_physics_process(false)
	office.player.set_process_input(false)
	office.player.camera.look_at(office.session_controller.transcript_paper.global_position)
	office.load_scenario_by_index(0)
	active = true

func _process(delta: float) -> bool:
	if not active:
		return false
	elapsed += delta
	if not started and elapsed >= 1.0:
		started = true
		office.session_controller.start_transmission()
		print("MOTION: live transmission started")
	var paper := office.session_controller.transcript_paper
	if started and not completed and paper.paper_state == TranscriptPaper.PaperState.READY_TO_INSPECT:
		completed = true
		print("MOTION: %d glyphs, copy complete; withdrawal" % paper.get_written_glyph_count())
	if completed:
		tail += delta
	if tail >= 1.0 or elapsed > 30.0:
		print("MOTION: done, elapsed %.2f s" % elapsed)
		quit(0 if completed else 1)
	return false
