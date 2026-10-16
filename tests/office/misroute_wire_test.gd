extends SceneTree
## A misrouted order gets an answer on the wire in the NEXT waiting stretch:
## the division asks WHERE IS 17 about the train you held, the line reports
## 71 CLEARED about the freight you released against the rule. The signal is
## armed only by the recorded world fact (a fact with a consumer), never
## lands before six seconds of the wait, never inside a hush, never on top
## of another take — and a correct route keeps the wire silent.
##   godot --headless --audio-driver Dummy --path . --script tests/office/misroute_wire_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Misroute Wire Test Suite ---")
	MainMenu.clear_state()
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	if not _a(office != null, "The office instantiates"): return
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	var director := office.shift_director
	var session := office.session_controller
	var scheduler := session.scheduler
	var unease := office.get_node("UneaseDirector") as UneaseDirector
	var world := root.get_node("WorldState") as WorldStateStore
	director.set_process(false)
	session.set_process(false)
	scheduler.auto_process = false
	office.operator_seat.sit_duration = 0
	office.operator_seat.approach_duration = 0
	office.operator_seat.sit()

	var encoder := AmericanMorseEncoder.new()
	var compiler := MorseScheduleCompiler.new()

	# --- Slot 0: hold TRAIN 17 against its order ---
	if not _a(_work_slot(session, director, scheduler, 0, "HOLD"),
		"The wrong HOLD route resolves slot 0"): return
	if not _a(director.get_slot_index() == 1 and director.get_phase() == ShiftDirector.Phase.WAITING,
		"The misrouted night moves on to the next waiting stretch"): return
	if not _a(bool(world.get_fact(&"train_17_held_in_error", false)),
		"The held train is a fact in the world"): return

	# The foreign bulletin keeps its old place at 4 s; the question waits for
	# the wire instead of cutting it.
	director.advance(5.5)
	var bulletin := _compile(director, encoder, compiler, director.foreign_traffic_text)
	if not _a(scheduler.is_playing() and bulletin != null \
			and is_equal_approx(scheduler.get_active_schedule().total_duration_seconds, bulletin.total_duration_seconds),
		"At 5.5 s the wire still carries the foreign bulletin, not the question"): return
	scheduler.advance_time(bulletin.total_duration_seconds + 0.1)
	director.advance(0.7)
	var question := _compile(director, encoder, compiler, "WHERE IS 17")
	if not _a(scheduler.is_playing() and question != null \
			and is_equal_approx(scheduler.get_active_schedule().total_duration_seconds, question.total_duration_seconds),
		"Once the wire frees up past six seconds, the division asks WHERE IS 17"): return
	_play_out(scheduler)
	director.advance(5.0)
	if not _a(not scheduler.is_playing(), "The question is asked exactly once"): return

	# --- Slot 1: release FREIGHT 71 against Rule 44 ---
	director.advance(director.wait_seconds_before_call[1] + 1.0)
	if not _a(director.get_phase() == ShiftDirector.Phase.CALLING, "Slot 1 calls"): return
	session.telegraph_key.press()
	director.advance(director.answer_beat_seconds + 0.05)
	if not _a(_receive_and_route(session, scheduler, "CLEAR EAST"),
		"The wrong CLEAR EAST route resolves slot 1"): return
	if not _a(director.get_slot_index() == 2 and director.get_phase() == ShiftDirector.Phase.WAITING,
		"The night moves on to the hook's waiting stretch"): return
	if not _a(bool(world.get_fact(&"freight_cleared_in_error", false)),
		"The released freight is a fact in the world"): return

	# --- The hush owns the wire: the report waits it out ---
	unease.is_hushed = true
	director.advance(6.5)
	if not _a(not scheduler.is_playing(), "A hush defers the misroute report"): return
	unease.is_hushed = false
	director.advance(0.1)
	var report := _compile(director, encoder, compiler, "71 CLEARED")
	if not _a(scheduler.is_playing() and report != null \
			and is_equal_approx(scheduler.get_active_schedule().total_duration_seconds, report.total_duration_seconds),
		"After the hush the line reports 71 CLEARED"): return
	_play_out(scheduler)

	# --- The answers are authored data and ride the M1 alphabet ---
	var scen1: TelegraphScenarioData = ResourceLoader.load(
		"res://data/scenarios/m1_scenario_1_baseline.tres")
	var scen2: TelegraphScenarioData = ResourceLoader.load(
		"res://data/scenarios/m1_scenario_2_attention.tres")
	if not _a(scen1.misroute_wire_signal == "WHERE IS 17" \
			and scen2.misroute_wire_signal == "71 CLEARED",
		"The misroute answers are authored in the scenarios' data"): return
	if not _a(_compile(director, encoder, compiler, scen1.misroute_wire_signal) != null \
			and _compile(director, encoder, compiler, scen2.misroute_wire_signal) != null,
		"Both misroute answers ride the M1 alphabet"): return
	if not _a(scen1.get_validation_errors().is_empty() and scen2.get_validation_errors().is_empty(),
		"The routed scenarios still validate"): return

	office.queue_free()

	# --- Control: a correct route keeps the next waiting stretch silent ---
	await process_frame
	MainMenu.clear_state()
	var quiet_office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(quiet_office)
	await process_frame
	await process_frame
	quiet_office.get_node("IntroCard").skip_immediately()
	var quiet_director := quiet_office.shift_director
	var quiet_session := quiet_office.session_controller
	var quiet_scheduler := quiet_session.scheduler
	quiet_director.set_process(false)
	quiet_session.set_process(false)
	quiet_scheduler.auto_process = false
	quiet_director.foreign_traffic_text = ""
	quiet_office.operator_seat.sit_duration = 0
	quiet_office.operator_seat.approach_duration = 0
	quiet_office.operator_seat.sit()
	if not _a(_work_slot(quiet_session, quiet_director, quiet_scheduler, 0, "CLEAR EAST"),
		"The correct CLEAR EAST route resolves slot 0"): return
	quiet_director.advance(6.5)
	if not _a(not quiet_scheduler.is_playing(),
		"A correct route sends no question on the wire"): return
	quiet_office.queue_free()
	await process_frame

	print("--- All Misroute Wire Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

## Opens the line (slot 0) or answers the call (later slots), receives the
## telegram, drains the sheet, verifies it and files the given route.
func _work_slot(
		session: TelegraphSessionController,
		director: ShiftDirector,
		scheduler: MorseRuntimeScheduler,
		slot_index: int,
		route: String) -> bool:
	if slot_index == 0:
		session.telegraph_key.press()
		director.advance(director.wait_seconds_before_call[0] + 1.0)
		session.telegraph_key.press()
		director.advance(director.answer_beat_seconds + 0.05)
	return _receive_and_route(session, scheduler, route)

func _receive_and_route(
		session: TelegraphSessionController,
		scheduler: MorseRuntimeScheduler,
		route: String) -> bool:
	scheduler.advance_time(20.0)
	var paper := session.transcript_paper
	var guard := 0
	while paper.is_copy_in_progress() and guard < 400:
		paper.advance_paper(0.25)
		guard += 1
	if session.get_state() != TelegraphSessionController.State.VERIFYING:
		return false
	if not session.mark_transcript_verified():
		return false
	return session.submit_routing_decision(route)

func _compile(
		director: ShiftDirector,
		encoder: AmericanMorseEncoder,
		compiler: MorseScheduleCompiler,
		text: String) -> MorsePlaybackScheduleData:
	var sequence := encoder.encode(text, director.alphabet)
	if sequence == null:
		return null
	return compiler.compile(sequence, director.playback_profile)

func _play_out(scheduler: MorseRuntimeScheduler) -> void:
	var active := scheduler.get_active_schedule()
	if active != null and scheduler.is_playing():
		scheduler.advance_time(active.total_duration_seconds + 0.1)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
