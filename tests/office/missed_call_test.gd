extends SceneTree
## A missed call is not silence: the sender surrenders on the wire with a
## short LINE CLOSED, Elias's ledger grows a NO COPY row from KnowledgeState,
## and the night moves on. But the critical copy cannot be missed at all —
## its sender keeps calling on a tightening interval until answered.
##   godot --headless --audio-driver Dummy --path . --script tests/office/missed_call_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Missed Call Test Suite ---")
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
	var world := root.get_node("WorldState") as WorldStateStore
	director.set_process(false)
	session.set_process(false)
	scheduler.auto_process = false
	office.operator_seat.sit_duration = 0
	office.operator_seat.approach_duration = 0
	office.operator_seat.sit()

	var encoder := AmericanMorseEncoder.new()
	var compiler := MorseScheduleCompiler.new()
	var missed: Array[String] = []
	director.traffic_missed.connect(func(_slot: int, scenario: TelegraphScenarioData) -> void:
		missed.append(scenario.scenario_id))

	# --- 1. An ordinary call, ignored: the sender surrenders on the wire ---
	session.telegraph_key.press()
	director.advance(director.wait_seconds_before_call[0] + 1.0)
	if not _a(director.get_phase() == ShiftDirector.Phase.CALLING, "Slot 0 calls"): return
	director.advance(40.0)
	if not _a(missed.size() == 1 and missed[0] == "baseline_train_17",
		"The ignored call is missed traffic"): return
	if not _a(director.get_slot_index() == 1 and director.get_phase() == ShiftDirector.Phase.WAITING,
		"The night moves on after the miss"): return
	if not _a(bool(world.get_fact(&"telegram_missed_baseline_train_17", false)),
		"The miss is a fact in the world"): return
	var surrender := compiler.compile(
		encoder.encode("LINE CLOSED", director.alphabet), director.playback_profile)
	if not _a(surrender != null, "The surrender text rides the M1 alphabet"): return
	if not _a(scheduler.is_playing() and surrender != null \
			and is_equal_approx(scheduler.get_active_schedule().total_duration_seconds, surrender.total_duration_seconds),
		"The sender surrenders with a short LINE CLOSED on the wire, not with silence"): return

	# --- 2. The ledger row grows from KnowledgeState ---
	if not _a(director.missed_call_sign == "LINE CLOSED",
		"The surrender sign is authored data on the director"): return
	var ledger := office.get_node("DispatchLedger") as DispatchLedger
	if not _a(ledger != null, "The office carries the dispatch ledger"): return
	var ledger_text := ledger.get_ledger_text()
	if not _a(ledger_text.contains("TRAIN 17") and ledger_text.contains("NO COPY"),
		"The ledger writes the missed train as NO COPY from knowledge"): return

	# --- 3. The critical call cannot be missed: it escalates until answered ---
	scheduler.advance_time(surrender.total_duration_seconds + 0.1)
	director._advance_to_slot(2)
	# Forcing a slot directly from WAITING keeps the old phase timer (the
	# director never does this in the real flow — transitions come from other
	# phases); the fixture resets it like a fresh slot would.
	director._phase_timer = 0.0
	if not _a(director.get_slot_index() == 2 and director.get_phase() == ShiftDirector.Phase.WAITING,
		"The hook slot waits for its call"): return
	director.advance(director.wait_seconds_before_call[2] + 1.0)
	if not _a(director.get_phase() == ShiftDirector.Phase.CALLING, "The hook calls"): return
	var calls: Array[int] = []
	director.call_started.connect(func(_slot: int, number: int) -> void: calls.append(number))
	var window_at_third := -1.0
	var window_at_fourth := -1.0
	var guard := 0
	while calls.size() < 6 and guard < 400:
		director.advance(0.25)
		guard += 1
		if calls.size() >= 3 and window_at_third < 0.0:
			window_at_third = director._call_window_seconds
		if calls.size() >= 4 and window_at_fourth < 0.0:
			window_at_fourth = director._call_window_seconds
	if not _a(calls.size() >= 6, "The sender keeps calling past the old limit, got %d" % calls.size()): return
	if not _a(director.get_phase() == ShiftDirector.Phase.CALLING,
		"The critical slot is never skipped: the phase is still CALLING"): return
	if not _a(not bool(world.get_fact(&"telegram_missed_core_hook_water_watcher", false)) \
			and missed.size() == 1,
		"The critical call records no miss"): return
	if not _a(window_at_third > 0.0 and window_at_fourth > 0.0 and window_at_fourth < window_at_third - 0.5,
		"The interval escalates: window %.2fs -> %.2fs" % [window_at_third, window_at_fourth]): return

	# Answering still works after the escalation.
	session.telegraph_key.press()
	# The office answers on the wire first; the message follows the answer and
	# the sender's breath, both of which the director times.
	director.advance(director.get_answer_total_seconds() + 0.05)
	if not _a(session.get_state() == TelegraphSessionController.State.RECEIVING,
		"The escalated call is answered like any other"): return

	office.queue_free()
	await process_frame
	print("--- All Missed Call Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
