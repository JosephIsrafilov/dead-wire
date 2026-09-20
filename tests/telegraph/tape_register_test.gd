extends SceneTree

## Tape register contract (design doc §4): the tape is a second renderer of
## the SAME scheduler timeline the sounder plays. It records every MARK/GAP
## event verbatim and has no access to message text at all.

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Tape Register Test Suite ---")
	# 1. Instantiates and starts empty.
	var tape: TapeRegisterController = load("res://scripts/telegraph/hardware/tape_register_controller.gd").new()
	root.add_child(tape)
	await process_frame
	if not _a(tape.get_record().is_empty(), "Tape starts empty"): return

	# 2. Records MARK/GAP verbatim from scheduler events.
	var ev_mark := MorseScheduledEvent.new()
	ev_mark.kind = MorseTimingEvent.Kind.MARK
	ev_mark.duration_units = 1
	var ev_gap := MorseScheduledEvent.new()
	ev_gap.kind = MorseTimingEvent.Kind.GAP
	ev_gap.duration_units = 3
	tape._on_timing_event_started(ev_mark)
	tape._on_timing_event_started(ev_gap)
	if not _a(tape.get_record().size() == 2, "Two events recorded verbatim"): return
	if not _a(tape.get_record()[0].kind == MorseTimingEvent.Kind.MARK
		and tape.get_record()[1].kind == MorseTimingEvent.Kind.GAP,
		"Kinds preserved in order"): return

	# 3. connect/disconnect follows the sounder pattern.
	var sched: MorseRuntimeScheduler = MorseRuntimeScheduler.new()
	root.add_child(sched)
	tape.connect_scheduler(sched)
	if not _a(sched.timing_event_started.is_connected(tape._on_timing_event_started),
		"connect_scheduler hooks timing_event_started"): return
	tape.disconnect_scheduler()
	if not _a(not sched.timing_event_started.is_connected(tape._on_timing_event_started),
		"disconnect_scheduler unhooks cleanly"): return

	# 4. reset clears the record but not the subscription lifecycle.
	tape.reset()
	if not _a(tape.get_record().is_empty(), "reset clears the tape"): return

	# 5. Tape rendering: MARK units -> dot/dash, GAP -> space per unit.
	var t2: TapeRegisterController = load("res://scripts/telegraph/hardware/tape_register_controller.gd").new()
	root.add_child(t2)
	await process_frame
	t2._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 1))
	t2._on_timing_event_started(_ev(MorseTimingEvent.Kind.GAP, 1))
	t2._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 3))
	t2._on_timing_event_started(_ev(MorseTimingEvent.Kind.GAP, 3))
	if not _a(t2.get_tape_text() == "· —   ", "Mark/GAP render to dot/dash/spaces verbatim, got '%s'" % t2.get_tape_text()): return
	# Word gap: long GAP renders as more spaces.
	t2._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 2))
	if not _a(t2.get_tape_text() == "· —   ·", "A 2-unit MARK is still a dot; gaps scale, got '%s'" % t2.get_tape_text()): return
	t2.queue_free()

	tape.queue_free()
	sched.queue_free()

	# 6. LIVE session wiring: a real transmission inks the tape verbatim.
	var controller := TelegraphSessionController.new()
	var live_sched := MorseRuntimeScheduler.new()
	live_sched.auto_process = false
	var live_tape: TapeRegisterController = load("res://scripts/telegraph/hardware/tape_register_controller.gd").new()
	live_tape.name = "TapeRegister"
	root.add_child(controller)
	root.add_child(live_sched)
	controller.scheduler = live_sched
	controller.add_child(live_tape)
	var scen: TelegraphScenarioData = load("res://data/scenarios/m1_scenario_1_baseline.tres")
	if not _a(controller.load_scenario(scen), "Session loads the scenario with the tape attached"): return
	if not _a(controller.start_transmission(), "Live transmission starts"): return
	var sched_data: MorsePlaybackScheduleData = live_sched.get_active_schedule()
	var expected_events: int = sched_data.events.size()
	live_sched.advance_time(live_sched.get_total_duration_seconds() + 1.0)
	var record := live_tape.get_record()
	if not _a(record.size() > 0, "A real transmission inked the tape"): return
	if not _a(record.size() == expected_events + 1,
		"Tape count equals the schedule's events plus the between-transmissions gap (%d vs %d)" % [record.size(), expected_events]): return
	var kinds_ok := true
	for i in range(expected_events):
		if record[i].kind != sched_data.events[i].kind:
			kinds_ok = false
			break
	if not _a(kinds_ok, "Recorded MARK/GAP kinds match the schedule verbatim"): return
	var last_ev: MorseScheduledEvent = record[record.size() - 1]
	if not _a(last_ev.kind == MorseTimingEvent.Kind.GAP
		and last_ev.duration_units == live_tape.BETWEEN_TRANSMISSIONS_GAP_UNITS,
		"Completed transmission ends with the 12-unit between-gap"): return
	var has_mark := false
	var has_gap := false
	for ev in record:
		if ev.kind == MorseTimingEvent.Kind.MARK:
			has_mark = true
		else:
			has_gap = true
	if not _a(has_mark and has_gap, "Record contains at least one MARK and one GAP"): return
	var tape_text := live_tape.get_tape_text()
	if not _a(tape_text.contains("\u00b7"), "Tape text contains a dot"): return
	var latin := RegEx.new()
	latin.compile("[A-Za-z]")
	if not _a(latin.search(tape_text) == null, "Tape text contains no Latin letters"): return

	controller.queue_free()

	# 7. Inspection contract: the strip lifts to the lamp through the viewer.
	var t3: TapeRegisterController = load("res://scripts/telegraph/hardware/tape_register_controller.gd").new()
	root.add_child(t3)
	await process_frame
	var inspected: Array[String] = []
	t3.tape_inspected.connect(func(text: String): inspected.append(text))
	t3._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 1))
	t3._on_interacted()
	if not _a(inspected.size() == 1 and inspected[0] == "\u00b7",
		"Interaction emits tape_inspected with the inked tape text"): return
	if not _a(t3.get_interactable() == null,
		"get_interactable is null on a pure-code instance without crashing"): return
	t3.queue_free()

	# A blank machine is honest: the empty strip still lifts to the lamp.
	var t4: TapeRegisterController = load("res://scripts/telegraph/hardware/tape_register_controller.gd").new()
	root.add_child(t4)
	await process_frame
	var blank: Array[String] = []
	t4.tape_inspected.connect(func(text: String): blank.append(text))
	t4._on_interacted()
	if not _a(blank.size() == 1 and blank[0] == "",
		"Empty tape still emits an honest empty body"): return
	t4.queue_free()

	# 8. LIVE office wiring: reading the register opens the existing viewer.
	var world: WorldStateStore = root.get_node_or_null("WorldState") as WorldStateStore
	if world == null:
		world = WorldStateStore.new()
		world.name = "WorldState"
		root.add_child(world)
	var knowledge: KnowledgeStateStore = root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge == null:
		knowledge = KnowledgeStateStore.new()
		knowledge.name = "KnowledgeState"
		root.add_child(knowledge)
	var office_scene := ResourceLoader.load("res://scenes/office/m1_office.tscn") as PackedScene
	var office := office_scene.instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null and intro.is_running():
		intro.skip_immediately()
	var office_tape := office.session_controller.get_tape_register()
	if not _a(office_tape != null,
		"Office exposes the tape register through the session controller"): return
	var tape_act: Interactable = office_tape.get_interactable()
	if not _a(tape_act != null and tape_act.prompt_text == "Read Tape Register",
		"Scene tape register carries an Interactable with the read prompt"): return
	tape_act.interact()
	await process_frame
	if not _a(office.document_viewer.is_open(),
		"Reading the tape opens the existing DocumentViewer"): return
	if not _a(office.document_viewer.get_current_doc_id() == "tape_register",
		"Viewer doc_id is tape_register"): return
	if not _a(office.document_viewer.title_label != null
		and office.document_viewer.title_label.text == "STATION REGISTER",
		"Viewer title is STATION REGISTER"): return
	office.document_viewer.close_document()
	if not _a(not office.document_viewer.is_open(),
		"Viewer closes after the tape read"): return
	office.queue_free()
	await process_frame
	await process_frame

	# 9. Between-transmissions gap (design doc §4): completion inks a pause
	# longer than any word gap, so the strip shows where a transmission ends.
	var t5: TapeRegisterController = load("res://scripts/telegraph/hardware/tape_register_controller.gd").new()
	root.add_child(t5)
	var sched5: MorseRuntimeScheduler = MorseRuntimeScheduler.new()
	root.add_child(sched5)
	t5.connect_scheduler(sched5)
	if not _a(sched5.timing_event_started.is_connected(t5._on_timing_event_started)
		and sched5.playback_completed.is_connected(t5._on_playback_completed)
		and sched5.playback_cancelled.is_connected(t5._on_playback_cancelled),
		"connect_scheduler hooks all three signals"): return
	t5._on_playback_completed(MorsePlaybackScheduleData.new())
	var rec5 := t5.get_record()
	if not _a(rec5.size() == 1 and rec5[0].kind == MorseTimingEvent.Kind.GAP
		and rec5[0].duration_units == 12,
		"Completion appends a synthetic 12-unit between-transmissions GAP"): return
	sched5.playback_completed.emit(MorsePlaybackScheduleData.new())
	if not _a(t5.get_record().size() == 2
		and t5.get_record()[1].duration_units == 12,
		"Signal path appends the between-gap too"): return
	t5.disconnect_scheduler()
	if not _a(not sched5.timing_event_started.is_connected(t5._on_timing_event_started)
		and not sched5.playback_completed.is_connected(t5._on_playback_completed)
		and not sched5.playback_cancelled.is_connected(t5._on_playback_cancelled),
		"disconnect_scheduler unhooks all three signals"): return
	t5.queue_free()
	sched5.queue_free()

	# 10. Rendering: a dot then the between-gap -> dot followed by 12 spaces.
	var t6: TapeRegisterController = load("res://scripts/telegraph/hardware/tape_register_controller.gd").new()
	root.add_child(t6)
	t6._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 1))
	t6._on_playback_completed(MorsePlaybackScheduleData.new())
	if not _a(t6.get_tape_text() == "\u00b7" + " ".repeat(12),
		"MARK(1) + completion renders dot then 12 spaces, got '%s'" % t6.get_tape_text()): return
	t6.queue_free()

	# 11. Two transmissions: the between-gap (12) outgrows the word gap (3).
	var t7: TapeRegisterController = load("res://scripts/telegraph/hardware/tape_register_controller.gd").new()
	root.add_child(t7)
	t7._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 1))
	t7._on_timing_event_started(_ev(MorseTimingEvent.Kind.GAP, 3))
	t7._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 1))
	t7._on_playback_completed(MorsePlaybackScheduleData.new())
	t7._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 2))
	var two_text := t7.get_tape_text()
	if not _a(_longest_space_run(two_text) == 12,
		"Longest space run is the 12-unit between-gap"): return
	if not _a(two_text.find(" ".repeat(12)) > 0,
		"Between-gap sits between transmissions, not at index 0"): return
	t7.queue_free()

	# 12. Cancellation: no between-gap, partial ink stays (honest break).
	var t8: TapeRegisterController = load("res://scripts/telegraph/hardware/tape_register_controller.gd").new()
	root.add_child(t8)
	t8._on_timing_event_started(_ev(MorseTimingEvent.Kind.MARK, 1))
	t8._on_timing_event_started(_ev(MorseTimingEvent.Kind.GAP, 3))
	var before_cancel := t8.get_tape_text()
	t8._on_playback_cancelled(MorsePlaybackScheduleData.new(), 0.5)
	if not _a(t8.get_record().size() == 2,
		"Cancellation appends no between-gap"): return
	if not _a(t8.get_tape_text() == before_cancel,
		"Cancelled transmission's partial ink stays unchanged"): return
	t8.queue_free()


	print("--- All Tape Register Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false


func _ev(kind: MorseTimingEvent.Kind, units: int) -> MorseScheduledEvent:
	var e := MorseScheduledEvent.new()
	e.kind = kind
	e.duration_units = units
	return e


func _longest_space_run(text: String) -> int:
	var longest := 0
	var run := 0
	for ch in text:
		if ch == " ":
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
	return longest
