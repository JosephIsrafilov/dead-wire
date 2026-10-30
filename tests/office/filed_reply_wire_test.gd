extends SceneTree
## Plan 4.4: a routed copy filed with a correction is answered on the wire
## (SAID WHAT) before the next traffic, and only then does the night move on.
## A copy filed as copied keeps the wire silent.
##   godot --headless --audio-driver Dummy --path . --script tests/office/filed_reply_wire_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Filed Reply Wire Test Suite ---")
	MainMenu.clear_state()
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	var director := office.shift_director
	var session := office.session_controller
	var scheduler := session.scheduler
	director.set_process(false)
	session.set_process(false)
	scheduler.auto_process = false
	director.foreign_traffic_text = ""
	office.operator_seat.sit_duration = 0
	office.operator_seat.approach_duration = 0
	office.operator_seat.sit()

	session.telegraph_key.press()
	director.advance(director.wait_seconds_before_call[0] + 1.0)
	session.telegraph_key.press()
	director.advance(director.get_answer_total_seconds() + 0.05)
	scheduler.advance_time(20.0)
	var guard := 0
	while session.transcript_paper.is_copy_in_progress() and guard < 400:
		session.transcript_paper.advance_paper(0.25)
		guard += 1
	session.mark_transcript_verified()
	if not _a(session.submit_routing_decision("CLEAR EAST"), "The order goes out"): return
	if not _a(session.submit_amendment("TRAIN"), "The routed copy is filed with a correction"): return
	session.advance_consequence(5.0)
	var reply := MorseScheduleCompiler.new().compile(
		AmericanMorseEncoder.new().encode("SAID WHAT", director.alphabet), director.playback_profile)
	if not _a(scheduler.is_playing() and reply != null
		and is_equal_approx(scheduler.get_active_schedule().total_duration_seconds, reply.total_duration_seconds),
		"The sender answers the correction on the wire: SAID WHAT"): return
	if not _a(director.get_slot_index() == 0, "The next traffic waits for the answer"): return
	scheduler.advance_time(reply.total_duration_seconds + 0.1)
	director.advance(reply.total_duration_seconds + director.answer_beat_seconds + 0.1)
	if not _a(director.get_slot_index() == 1 and director.get_phase() == ShiftDirector.Phase.WAITING,
		"After the answer the night moves on"): return

	# Slot 1 filed as copied: nothing on the wire, the night moves straight on.
	director.advance(director.wait_seconds_before_call[1] + 1.0)
	session.telegraph_key.press()
	director.advance(director.get_answer_total_seconds() + 0.05)
	scheduler.advance_time(20.0)
	guard = 0
	while session.transcript_paper.is_copy_in_progress() and guard < 400:
		session.transcript_paper.advance_paper(0.25)
		guard += 1
	session.mark_transcript_verified()
	session.submit_routing_decision("HOLD")
	if not _a(session.submit_commit(&"file_as_copied"), "The second copy is filed as copied"): return
	session.advance_consequence(5.0)
	if not _a(director.get_slot_index() == 2 and not scheduler.is_playing(),
		"A plain filing gets no answer and the night moves on at once"): return

	office.queue_free()
	for _frame in 5:
		await process_frame
	print("--- All Filed Reply Wire Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
