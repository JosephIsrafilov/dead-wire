extends SceneTree
## A service signal never cuts a live telegram: while the wire carries the
## session's own schedule, the director's wire play is refused (0.0, nothing
## cancelled, the tape keeps its take whole). And when a telegram really is
## cancelled, the session ends it honestly: t0 starts, the unfinished sheet
## keeps its partial ink, and the whisper never speaks letters the wire did
## not finish.
##   godot --headless --audio-driver Dummy --path . --script tests/office/wire_guard_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Wire Guard Test Suite ---")
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

	var scen3: TelegraphScenarioData = ResourceLoader.load(
		"res://data/scenarios/m1_scenario_3_core_hook.tres")

	var t0_events: Array[TelegraphScenarioData] = []
	session.transmission_finished.connect(func(scenario: TelegraphScenarioData) -> void:
		t0_events.append(scenario))
	var whispered: Array[String] = []
	session.perception_glyph.connect(func(_id: String, _index: int, glyph: String) -> void:
		whispered.append(glyph))

	# --- 1. A service signal mid-telegram is refused and cuts nothing ---
	if not _a(session.load_scenario(scen3), "The hook scenario loads"): return
	if not _a(session.start_transmission(), "The telegram takes the wire"): return
	scheduler.advance_time(1.5)
	var telegram_schedule := scheduler.get_active_schedule()
	if not _a(telegram_schedule != null and scheduler.is_playing(),
		"Mid-copy the wire carries the telegram's own schedule"): return
	var t0_before := t0_events.size()

	var played := director._play_on_wire("CR CR")
	if not _a(played == 0.0,
		"A service signal during RECEIVING is refused, got duration %f" % played): return
	if not _a(scheduler.is_playing() and scheduler.get_active_schedule() == telegram_schedule,
		"The refused signal leaves the telegram on the wire"): return
	if not _a(session.get_state() == TelegraphSessionController.State.RECEIVING,
		"The session keeps receiving its own telegram"): return
	if not _a(t0_events.size() == t0_before,
		"A refused signal is not the telegram's t0"): return

	scheduler.advance_time(3.6 - scheduler.get_elapsed_seconds() + 0.05)
	if not _a(t0_events.size() == t0_before + 1,
		"The telegram then reaches its own t0, exactly once"): return
	var interrupted := 0
	for snapshot in tape.get_segment_snapshots():
		if snapshot.get("interrupted", false):
			interrupted += 1
	if not _a(interrupted == 0,
		"The tape carries no BROKEN OFF take, got %d" % interrupted): return

	# --- 2. A truly cancelled telegram ends honestly instead of stranding ---
	if not _a(session.load_scenario(scen3), "The hook reloads for the cancel case"): return
	whispered.clear()
	if not _a(session.start_transmission(), "The second telegram takes the wire"): return
	scheduler.advance_time(2.5)
	var glyphs_at_cancel := whispered.size()
	if not _a(glyphs_at_cancel > 0 and glyphs_at_cancel < 5,
		"Mid-copy the whisper has spoken some but not all letters, got %d" % glyphs_at_cancel): return
	t0_before = t0_events.size()

	scheduler.cancel()
	if not _a(t0_events.size() == t0_before + 1,
		"A cancelled telegram still reaches t0 — the sender's clock starts"): return
	if not _a(session.get_state() == TelegraphSessionController.State.COPYING,
		"The unfinished sheet stays open in COPYING with its partial ink"): return
	if not _a(whispered.size() == glyphs_at_cancel,
		"The whisper never speaks letters the wire did not finish"): return
	var broken := 0
	for snapshot in tape.get_segment_snapshots():
		if snapshot.get("interrupted", false):
			broken += 1
	if not _a(broken == 1,
		"The tape honestly records exactly one BROKEN OFF take, got %d" % broken): return

	session.queue_free()
	director.queue_free()
	print("--- All Wire Guard Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
