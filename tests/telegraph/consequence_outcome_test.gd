extends SceneTree
## The hook's consequence is chosen by how the decision resolved, from data:
## filing as copied, amending with another word and lapsing send the figure to
## the window; amending with the TRUE word sends only a cloud across the moon
## (G4: every branch must not look the same). The mapping lives in the
## scenario .tres, never in code.
##   godot --headless --audio-driver Dummy --path . --script tests/telegraph/consequence_outcome_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Consequence Outcome Test Suite ---")
	var world := WorldStateStore.new()
	world.name = "WorldState"
	var knowledge := KnowledgeStateStore.new()
	knowledge.name = "KnowledgeState"
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	var key := TelegraphKey.new()
	var paper := TranscriptPaper.new()
	var session := TelegraphSessionController.new()
	root.add_child(world)
	root.add_child(knowledge)
	root.add_child(scheduler)
	root.add_child(paper)
	root.add_child(key)
	root.add_child(session)
	session.world_state = world
	session.scheduler = scheduler
	session.telegraph_key = key
	session.transcript_paper = paper
	session._bind_components()

	var scen3: TelegraphScenarioData = ResourceLoader.load(
		"res://data/scenarios/m1_scenario_3_core_hook.tres")

	var events: Array[String] = []
	var holds: Array[float] = []
	session.consequence_started.connect(func(event_id: String, hold_seconds: float) -> void:
		events.append(event_id)
		holds.append(hold_seconds))

	# --- 1. Amending with the TRUE word: only a cloud crosses the moon ---
	if not _a(_drive_to_commit(session, scheduler, paper, scen3),
		"The hook reaches its filing decision"): return
	if not _a(session.submit_amendment("WATER"), "Amending with the true word is accepted"): return
	session.advance_consequence(scen3.consequence_delay_seconds + 0.1)
	if not _a(events.size() == 1, "The consequence beats exactly once, got %d" % events.size()): return
	if not _a(events[0] == "moon_cloud",
		"Amending WATER sends a cloud shadow, not the figure, got '%s'" % events[0]): return
	if not _a(is_equal_approx(holds[0], scen3.consequence_hold_seconds),
		"The authored hold travels with the event"): return
	if not _a(session.get_resolved_outcome() == TelegraphScenarioData.OUTCOME_AMENDED_TRUE,
		"The session names the outcome it resolved to"): return

	# --- 2. Amending with another word: the figure keeps its appointment ---
	events.clear()
	if not _a(_drive_to_commit(session, scheduler, paper, scen3),
		"The hook reloads for the wrong-word case"): return
	if not _a(session.submit_amendment("WAITER"), "Amending with another word is accepted"): return
	session.advance_consequence(scen3.consequence_delay_seconds + 0.1)
	if not _a(events.size() == 1 and events[0] == "window_figure",
		"A wrong amendment still brings the figure, got '%s'" % (events[0] if events.size() == 1 else "<none>")): return
	if not _a(session.get_resolved_outcome() == TelegraphScenarioData.OUTCOME_AMENDED_OTHER,
		"A wrong word resolves to amended_other"): return

	# --- 3. Filing as copied: the figure keeps its appointment ---
	events.clear()
	if not _a(_drive_to_commit(session, scheduler, paper, scen3),
		"The hook reloads for the file-as-copied case"): return
	if not _a(session.submit_commit(&"file_watcher"), "Filing as copied is accepted"): return
	session.advance_consequence(scen3.consequence_delay_seconds + 0.1)
	if not _a(events.size() == 1 and events[0] == "window_figure",
		"Filing the watched word still brings the figure, got '%s'" % (events[0] if events.size() == 1 else "<none>")): return
	if not _a(session.get_resolved_outcome() == TelegraphScenarioData.OUTCOME_FILED_AS_COPIED,
		"Filing as copied resolves to filed_as_copied"): return

	# --- 4. Lapsing: the figure keeps its appointment ---
	events.clear()
	if not _a(_drive_to_commit(session, scheduler, paper, scen3),
		"The hook reloads for the lapse case"): return
	if not _a(session.lapse_commit(), "Letting the deadline lapse is accepted"): return
	session.advance_consequence(scen3.consequence_delay_seconds + 0.1)
	if not _a(events.size() == 1 and events[0] == "window_figure",
		"A lapsed filing still brings the figure, got '%s'" % (events[0] if events.size() == 1 else "<none>")): return
	if not _a(session.get_resolved_outcome() == TelegraphScenarioData.OUTCOME_LAPSED,
		"A lapse resolves to lapsed"): return

	# --- 5. The mapping is data, and the data validates ---
	if not _a(scen3.get_validation_errors().is_empty(),
		"The authored hook scenario passes validation"): return
	var outcome_map := scen3.consequence_events_by_outcome
	if not _a(outcome_map.size() == 4,
		"The hook authors all four outcomes, got %d" % outcome_map.size()): return
	var keys_known := true
	for outcome_key in outcome_map.keys():
		if StringName(str(outcome_key)) not in TelegraphScenarioData.OUTCOME_IDS:
			keys_known = false
	if not _a(keys_known, "Every authored outcome key is a registered outcome id"): return
	if not _a(str(outcome_map.get("amended_true", "")) == "moon_cloud" \
			and str(outcome_map.get("filed_as_copied", "")) == "window_figure" \
			and str(outcome_map.get("amended_other", "")) == "window_figure" \
			and str(outcome_map.get("lapsed", "")) == "window_figure",
		"Only the true amendment maps to the cloud; every other outcome keeps the figure"): return

	var broken: TelegraphScenarioData = scen3.duplicate()
	broken.consequence_events_by_outcome = {"not_an_outcome": "window_figure", "lapsed": ""}
	if not _a(broken.get_validation_errors().size() >= 2,
		"Unknown outcomes and empty event ids fail validation, got %d errors" \
			% broken.get_validation_errors().size()): return

	session.queue_free()
	print("--- All Consequence Outcome Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _drive_to_commit(
		session: TelegraphSessionController,
		scheduler: MorseRuntimeScheduler,
		paper: TranscriptPaper,
		scenario: TelegraphScenarioData) -> bool:
	if not session.load_scenario(scenario):
		return false
	if not session.start_transmission():
		return false
	# The hook's WATER signal runs 3.6 s on the M1 profile (same constant the
	# whisper and wire-guard suites drive it by).
	scheduler.advance_time(3.7)
	var guard := 0
	while paper.is_copy_in_progress() and guard < 400:
		paper.advance_paper(0.25)
		guard += 1
	if session.get_state() != TelegraphSessionController.State.VERIFYING:
		return false
	return session.mark_transcript_verified() \
		and session.get_state() == TelegraphSessionController.State.AWAITING_COMMIT

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
