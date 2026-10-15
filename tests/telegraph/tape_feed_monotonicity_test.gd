extends SceneTree

## The register strip is a physical feed: availability of the objective ink is
## monotonic. A weakening spring can only hold back ink that was laid down
## while it was slack; marks already fed out past the rollers never retract.
##   godot --headless --audio-driver Dummy --path . --script tests/telegraph/tape_feed_monotonicity_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Tape Feed Monotonicity Test Suite ---")
	if not _test_weakening_spring_never_retracts_visible_ink(): return
	if not _test_full_take_stays_full_while_the_watch_runs_down(): return
	if not _test_wind_releases_the_whole_backlog_once(): return
	if not _test_new_take_keeps_history_and_reset_clears_the_feed(): return
	if not await _test_office_viewer_keeps_timing_columns(): return
	print("--- All Tape Feed Monotonicity Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

## Contract 1 (P1): between two reads of the same finished take, with no new
## scheduler events, the second read contains the first read's ink as an exact
## prefix. GAP whitespace included, no normalization.
func _test_weakening_spring_never_retracts_visible_ink() -> bool:
	var tape := _make_register()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	root.add_child(scheduler)
	tape.connect_scheduler(scheduler)
	var schedule := _schedule([1, 2, 1, 3, 1, 2, 1, 3, 1])
	if not _a(scheduler.start(schedule), "Monotonicity fixture schedule starts"): return false
	scheduler.advance_time(schedule.total_duration_seconds + 1.0)
	var snap := tape.get_segment_snapshots()
	if not _a(snap.size() == 1 and snap[0].complete and snap[0].events.size() == 9,
		"The fixture take completes with nine alternating MARK/GAP events"): return false
	var weak := _parse_takes(_inspect(tape, 0.54))
	if not _a(weak.size() == 1 and weak[0]["header"].contains("COMPLETE"),
		"A first read at 0.54 still labels the finished take COMPLETE"): return false
	# The spring clock keeps running while no new wire events arrive.
	for _step in 120:
		tape._process(1.0 / 60.0)
	var weaker := _parse_takes(_inspect(tape, 0.35))
	if not _a(weaker.size() == 1 and weaker[0]["header"].contains("COMPLETE"),
		"The later read keeps the COMPLETE boundary metadata"): return false
	if not _a(weaker[0]["ink"].begins_with(weak[0]["ink"]) and weak[0]["ink"].length() > 0,
		"Ink already fed out survives a weakening spring: first read is an exact prefix of the second ('%s' then '%s')"
			% [weak[0]["ink"], weaker[0]["ink"]]): return false
	if not _a(weaker[0]["ink"] == "·  ·   ·  ·   ·",
		"Every timing column of the finished take, GAP whitespace included, survives the second read"): return false
	if not _a(tape.get_record().size() == 9, "The objective record never loses events while the strip is read"): return false
	_cleanup(tape, scheduler)
	return true

## Contract 2: a take read in full at a healthy tension stays in full as the
## spring runs down; snapshots and the source schedule stay untouched.
func _test_full_take_stays_full_while_the_watch_runs_down() -> bool:
	var tape := _make_register()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	root.add_child(scheduler)
	tape.connect_scheduler(scheduler)
	var schedule := _schedule([1, 2, 1, 3, 1, 2, 1, 3, 1])
	scheduler.start(schedule)
	scheduler.advance_time(schedule.total_duration_seconds + 1.0)
	var planned_units: Array[int] = []
	for event in schedule.events:
		planned_units.append(event.duration_units)
	var full := _parse_takes(_inspect(tape, 1.0))
	if not _a(full.size() == 1 and full[0]["ink"] == "·  ·   ·  ·   ·" and not full[0]["slack"],
		"A healthy spring shows the whole finished take, GAP columns exact"): return false
	var half := _parse_takes(_inspect(tape, 0.54))
	if not _a(half[0]["ink"] == full[0]["ink"] and not half[0]["slack"],
		"A take read in full stays full at 0.54"): return false
	for _step in 120:
		tape._process(1.0 / 60.0)
	var low := _parse_takes(_inspect(tape, 0.35))
	if not _a(low[0]["ink"] == full[0]["ink"] and not low[0]["slack"] and low[0]["header"].contains("COMPLETE"),
		"A take read in full stays full at 0.35 with no new wire events"): return false
	var after := tape.get_segment_snapshots()
	var snapshots_match: bool = after.size() == 1 and after[0].complete and after[0].events.size() == 9
	var source_match := true
	for i in range(planned_units.size()):
		var ink: TapeInkEvent = after[0].events[i]
		source_match = source_match and ink.kind == schedule.events[i].kind \
			and is_equal_approx(ink.duration_units, float(planned_units[i])) \
			and is_equal_approx(ink.duration_seconds, schedule.events[i].duration_seconds)
	if not _a(snapshots_match and source_match,
		"Rundown and reads leave durations, kinds and completion status unchanged"): return false
	_cleanup(tape, scheduler)
	return true

## Contract 3: winding feeds the held backlog out exactly once; repeated reads
## are idempotent and a second rundown does not retract released evidence.
func _test_wind_releases_the_whole_backlog_once() -> bool:
	var tape := _make_register()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	root.add_child(scheduler)
	tape.connect_scheduler(scheduler)
	# Every mark of this take is inked while the feed lags under the rollers.
	tape.spring_tension = 0.35
	var schedule := _schedule([1, 2, 1, 3, 1, 2, 1, 3, 1])
	scheduler.start(schedule)
	scheduler.advance_time(schedule.total_duration_seconds + 1.0)
	var held := _parse_takes(_inspect(tape, 0.35))
	if not _a(held.size() == 1 and held[0]["ink"] == "" and held[0]["slack"],
		"A take inked entirely on a slack spring is held with an honest boundary, not deleted"): return false
	if not _a(tape.get_record().size() == 9,
		"The objective record already holds all nine events under the rollers"): return false
	tape.wind()
	var wound := _parse_takes(_inspect(tape, 1.0))
	if not _a(wound[0]["ink"] == "·  ·   ·  ·   ·" and not wound[0]["slack"],
		"Winding feeds the whole held backlog out once"): return false
	var again := _parse_takes(_inspect(tape, 1.0))
	if not _a(again[0]["ink"] == wound[0]["ink"],
		"Reading the wound strip again is idempotent"): return false
	tape.spring_tension = 0.35
	for _step in 120:
		tape._process(1.0 / 60.0)
	var run_down := _parse_takes(_inspect(tape, 0.35))
	if not _a(run_down[0]["ink"] == "·  ·   ·  ·   ·",
		"Once fed out, the strip stays readable while the spring runs down again"): return false
	if not _a(tape.get_record().size() == 9, "Winding and reading never touch the record"): return false
	_cleanup(tape, scheduler)
	return true

## Contract 4: a new take never hides an older one; interruption keeps its
## exact fractional snapshot and the '?' ink; reset is the only cursor reset.
func _test_new_take_keeps_history_and_reset_clears_the_feed() -> bool:
	var tape := _make_register()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	root.add_child(scheduler)
	tape.connect_scheduler(scheduler)
	var first := _schedule([1, 2, 1, 3, 1])
	scheduler.start(first)
	scheduler.advance_time(first.total_duration_seconds + 1.0)
	# A second, weak take: MARK, GAP, then a long MARK interrupted mid-ink.
	tape.spring_tension = 0.35
	var second := _schedule([1, 2, 6])
	scheduler.start(second)
	scheduler.advance_time(0.35)
	scheduler.cancel()
	var read := _parse_takes(_inspect(tape, 0.35))
	if not _a(read.size() == 2 and read[0]["ink"] == "·  ·   ·" and not read[0]["slack"],
		"A new take never hides the older take's fed-out ink"): return false
	if not _a(read[1]["header"].contains("INTERRUPTED") and read[1]["slack"],
		"The weak take is held under the rollers with its honest interrupted boundary"): return false
	var snaps := tape.get_segment_snapshots()
	var interrupted_ink: TapeInkEvent = snaps[1].events[2]
	if not _a(snaps[1].interrupted and snaps[1].events.size() == 3
		and is_equal_approx(interrupted_ink.duration_seconds, 0.05)
		and interrupted_ink.interrupted and not interrupted_ink.is_complete,
		"Interruption keeps the exact fractional snapshot of the held event"): return false
	tape.wind()
	var wound := _parse_takes(_inspect(tape, 1.0))
	if not _a(wound[0]["ink"] == "·  ·   ·",
		"Winding preserves the older take's ink exactly"): return false
	if not _a(wound[1]["ink"] == "·  ?",
		"Releasing the weak take keeps the interrupted '?' ink verbatim"): return false
	# reset() is the one watch reset that clears the feed history.
	tape.reset()
	tape.spring_tension = 0.35
	var third := _schedule([1, 2, 1])
	scheduler.start(third)
	scheduler.advance_time(third.total_duration_seconds + 1.0)
	var after_reset := _parse_takes(_inspect(tape, 0.35))
	if not _a(after_reset.size() == 1 and after_reset[0]["ink"] == "" and after_reset[0]["slack"],
		"reset() clears the feed history: a fresh weak take is held again, no stale cursor"): return false
	if not _a(tape.get_record().size() == 3, "reset() leaves only the new take's record"): return false
	_cleanup(tape, scheduler)
	return true

## Contract 5: the real office path (Interactable -> tape_inspected ->
## DocumentViewer) shows the same timing columns on a run-down spring.
func _test_office_viewer_keeps_timing_columns() -> bool:
	var world := root.get_node_or_null("WorldState") as WorldStateStore
	if world == null:
		world = WorldStateStore.new()
		world.name = "WorldState"
		root.add_child(world)
	var knowledge := root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge == null:
		knowledge = KnowledgeStateStore.new()
		knowledge.name = "KnowledgeState"
		root.add_child(knowledge)
	var scene: PackedScene = ResourceLoader.load("res://scenes/office/m1_office.tscn")
	var office := scene.instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null and intro.is_running():
		intro.skip_immediately()
	office.session_controller.scheduler.auto_process = false
	office.shift_director.set_process(false)
	if not _a(office.shift_director.open_line(), "Office fixture: the watch opens"): return false
	office.operator_seat.sit_duration = 0.0
	office.operator_seat.approach_duration = 0.0
	office.operator_seat.sit()
	var director := office.shift_director
	director.advance(director.wait_seconds_before_call[0] + 0.5)
	if not _a(director.get_phase() == ShiftDirector.Phase.CALLING,
		"Office fixture: the first call arrives"): return false
	office.session_controller.telegraph_key.press()
	director.advance(director.answer_beat_seconds + 0.05)
	var scheduler := office.session_controller.scheduler
	var total := scheduler.get_total_duration_seconds()
	if not _a(total > 0.0, "Office fixture: the first telegram is on the wire"): return false
	scheduler.advance_time(total + 1.0)
	var register := office.session_controller.get_tape_register()
	var raw: Array[String] = []
	var listener := func(text: String): raw.append(text)
	register.tape_inspected.connect(listener)
	var act := register.get_interactable()
	act.interact()
	await process_frame
	if not _a(office.document_viewer.is_open()
		and office.document_viewer.get_current_doc_id() == "tape_register",
		"Reading the office register opens the station register in the real viewer"): return false
	var body_first: String = office.document_viewer.body_label.text
	if not _a(body_first == M1OfficeController._wrap_tape_text(raw[0]),
		"The viewer body is the lossless layout wrap of the real signal body"): return false
	var record := register.get_record()
	if not _a(raw[0].ends_with(_tail_glyph(record[record.size() - 1])),
		"Trailing timing columns survive into the signal body, trailing GAP whitespace included"): return false
	office.document_viewer.close_document()
	await process_frame
	act.interact()
	await process_frame
	var body_second: String = office.document_viewer.body_label.text
	if not _a(body_second == body_first, "A second read of the same strip is idempotent"): return false
	office.document_viewer.close_document()
	await process_frame
	# The spring runs down with no new wire events between the reads.
	register.spring_tension = 0.35
	act.interact()
	await process_frame
	var body_weak: String = office.document_viewer.body_label.text
	office.document_viewer.close_document()
	register.tape_inspected.disconnect(listener)
	if not _a(body_weak == body_first,
		"A run-down spring never retracts already-read evidence in the real viewer path"): return false
	office.queue_free()
	return true

func _make_register() -> TapeRegisterController:
	var scene: PackedScene = load("res://scenes/telegraph/tape_register.tscn")
	var tape := scene.instantiate() as TapeRegisterController
	root.add_child(tape)
	return tape

## Reads the strip the way the player does: the register's own Interactable
## and tape_inspected signal, at a given spring tension.
func _inspect(tape: TapeRegisterController, tension: float) -> String:
	tape.spring_tension = tension
	var act := tape.get_interactable()
	var captured: Array[String] = []
	var listener := func(text: String): captured.append(text)
	tape.tape_inspected.connect(listener)
	act.interact()
	tape.tape_inspected.disconnect(listener)
	return captured[0] if captured.size() > 0 else ""

func _parse_takes(text: String) -> Array[Dictionary]:
	var takes: Array[Dictionary] = []
	var lines: PackedStringArray = text.split("\n")
	var header := ""
	var ink := ""
	var slack := false
	for line in lines:
		if line.begins_with("[WIRE TAKE"):
			if not header.is_empty():
				takes.append({"header": header, "ink": ink, "slack": slack})
			header = line
			ink = ""
			slack = false
		elif line.begins_with("[SPRING SLACK"):
			slack = true
		else:
			ink += line
	if not header.is_empty():
		takes.append({"header": header, "ink": ink, "slack": slack})
	return takes

## Rendered form of a single record event, mirroring the strip renderer, used
## to prove the last timing column (often a trailing GAP) survives the path.
func _tail_glyph(ink: TapeInkEvent) -> String:
	if ink.kind == MorseTimingEvent.Kind.MARK:
		if not ink.is_complete or ink.interrupted:
			return "?"
		if ink.duration_units >= 6.0:
			return "———"
		return "·" if ink.duration_units <= 2.0 else "—"
	return " ".repeat(maxi(int(floor(ink.duration_units)), 0))

func _schedule(units: Array) -> MorsePlaybackScheduleData:
	var schedule := MorsePlaybackScheduleData.new()
	var elapsed := 0.0
	for i in range(units.size()):
		var event := MorseScheduledEvent.new()
		event.event_index = i
		event.kind = MorseTimingEvent.Kind.MARK if i % 2 == 0 else MorseTimingEvent.Kind.GAP
		event.duration_units = units[i]
		event.duration_seconds = units[i] * 0.1
		event.start_seconds = elapsed
		event.end_seconds = elapsed + event.duration_seconds
		elapsed = event.end_seconds
		schedule.events.append(event)
	schedule.total_duration_seconds = elapsed
	return schedule

func _cleanup(tape: TapeRegisterController, scheduler: MorseRuntimeScheduler) -> void:
	tape.disconnect_scheduler()
	tape.queue_free()
	scheduler.queue_free()

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
