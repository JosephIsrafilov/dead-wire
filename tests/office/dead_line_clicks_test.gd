extends SceneTree

## The dead line clicks (plan 4.10): once in each of the first two silences the
## sounder drops a single stray mark. It is real traffic on the wire, so the
## register inks it - the register records every MARK and knows no text. It is
## never a call, never in silence 3, never over a live telegram, and never
## twice in the same silence.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Dead Line Clicks Test Suite ---")
	var script: Variant = load("res://scripts/office/dead_line_clicks.gd")
	if not _check(script != null, "The dead line has a script"): return

	var world := WorldStateStore.new()
	world.name = "WorldState"
	var knowledge := KnowledgeStateStore.new()
	knowledge.name = "KnowledgeState"
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	var key := TelegraphKey.new()
	var paper := TranscriptPaper.new()
	var tape := TapeRegisterController.new()
	tape.name = "TapeRegister"
	var session := TelegraphSessionController.new()
	root.add_child(world)
	root.add_child(knowledge)
	root.add_child(scheduler)
	root.add_child(paper)
	root.add_child(key)
	root.add_child(session)
	session.add_child(tape)
	session.world_state = world
	session.scheduler = scheduler
	session.telegraph_key = key
	session.transcript_paper = paper
	session._bind_components()
	var director := ShiftDirector.new()
	director.session = session
	root.add_child(director)
	director.set_process(false)

	var clicks: Node = script.new()
	clicks.director = director
	root.add_child(clicks)
	clicks.set_process(false)

	var marks_before := _marks(tape)
	if not _check(not clicks.update(2, 40.0), "Silence 3 has no stray click"): return
	if not _check(not clicks.update(0, 1.0), "Nothing clicks at the start of a silence"): return
	if not _check(clicks.update(0, clicks.click_after_seconds[0] + 0.1), "In silence 1 the dead line clicks"): return
	if not _check(scheduler.is_playing(), "The click is real traffic on the wire"): return
	scheduler.advance_time(2.0)
	if not _check(_marks(tape) == marks_before + 1, "The register inks exactly one mark for it"): return
	if not _check(not clicks.update(0, clicks.click_after_seconds[0] + 5.0), "It clicks once per silence"): return

	# A live wire refuses the stray click; it never cuts through traffic.
	var scen: TelegraphScenarioData = ResourceLoader.load("res://data/scenarios/m1_scenario_1_baseline.tres")
	if scen != null and session.load_scenario(scen) and session.start_transmission():
		scheduler.advance_time(0.5)
		if not _check(not clicks.update(1, clicks.click_after_seconds[1] + 0.1), "A live telegram refuses the stray click"): return
		scheduler.cancel()
	else:
		if not _check(false, "Fixture: the first scenario loads and transmits"): return
	if not _check(clicks.update(1, clicks.click_after_seconds[1] + 0.2), "Once the wire is quiet, silence 2 gets its click"): return

	session.queue_free()
	director.queue_free()
	clicks.queue_free()
	for _frame in 3:
		await process_frame
	print("--- All Dead Line Clicks Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _marks(tape: TapeRegisterController) -> int:
	var count := 0
	for event in tape.get_record():
		if event.kind == MorseTimingEvent.Kind.MARK:
			count += 1
	return count

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
