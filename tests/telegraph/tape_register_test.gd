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
