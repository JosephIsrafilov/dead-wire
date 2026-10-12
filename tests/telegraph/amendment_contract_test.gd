extends SceneTree
## Honest filing starts with neutral actions and rejects an untyped amendment.
var assertions := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, description: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + description)
	if not ok:
		quit(1)
		return false
	assertions += 1
	return true
func _run() -> void:
	var scenario := load("res://data/scenarios/m1_scenario_3_core_hook.tres") as TelegraphScenarioData
	if not check(scenario.get_validation_errors().is_empty(), "Hook scenario remains valid"): return
	for option in scenario.commit_options:
		if not check(not option.display_label.contains("WATER") and not option.display_label.contains("WATCHER"), "Pre-decision label supplies no answer"): return
	var session := TelegraphSessionController.new()
	root.add_child(session)
	if not check(session.load_scenario(scenario), "Session loads neutral hook scenario"): return
	session._state = TelegraphSessionController.State.VERIFYING
	if not check(session.mark_transcript_verified(), "Inspection enters filing gate"): return
	if not check(not session.submit_commit(&"amend_copy"), "Bare amendment cannot silently file WATER"): return
	if not check(session.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "Untyped amendment leaves decision pending"): return
	if not check(session.has_method("submit_amendment"), "Session owns typed amendment validation and acceptance"): return
	var world := root.get_node("WorldState") as WorldStateStore
	var knowledge := root.get_node("KnowledgeState") as KnowledgeStateStore
	for invalid in ["", "water", " WATER", "WATER ", "WÄTER", "1", "A".repeat(25)]:
		var world_before := world.snapshot()
		var knowledge_before := knowledge.snapshot()
		if not check(not session.call("submit_amendment", invalid), "Authority rejects noncanonical correction '%s'" % invalid): return
		if not check(world.snapshot() == world_before and knowledge.snapshot() == knowledge_before, "Rejected text changes neither independent store"): return
	if not check(session.call("submit_amendment", "WAITER"), "A valid wrong amendment is a real accepted choice"): return
	if not check(world.get_fact(&"core_hook_amended_wrong", false), "Wrong amendment has a distinct objective outcome"): return
	if not check(world.get_fact(&"core_hook_filed_word", "") == "WAITER", "Objective filed word remains exactly WAITER"): return
	if not check(knowledge.has_method("recall_value"), "Knowledge has its own chosen-word record"): return
	if not check(knowledge.call("recall_value", &"filed_word_core_hook", "") == "WAITER", "Operator remembers chosen word, not an automatic WATER answer"): return
	if not check(knowledge.knows(&"amendment_entered_core_hook") and not knowledge.knows(&"committed_water_core_hook"), "Knowledge confirms amendment only, never correctness"): return
	if not check(not session.call("submit_amendment", "WATER"), "Duplicate typed amendment cannot replace the first choice"): return
	session.reset_session()
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	session.load_scenario(scenario)
	session._state = TelegraphSessionController.State.VERIFYING
	session._post_signal_elapsed = 0.0
	session.mark_transcript_verified()
	var records: Array = []
	session.commit_recorded.connect(func(id: String, action: StringName, word: String):
		records.append([id, action, word])
		session.reset_session()
		session.submit_amendment("OTHER"))
	if not check(session.submit_amendment("WATER"), "Correct explicit amendment is accepted"): return
	if not check(world.get_fact(&"core_hook_filed_water", false) and records.size() == 1, "Reentrant callbacks cannot double-file or erase accepted outcome"): return
	if not check(records[0] == [scenario.scenario_id, &"amend_copy", "WATER"], "Resolution carries captured old-slot and exact word"): return
	if not check(knowledge.recall_value(&"filed_word_core_hook") == "WATER" and not knowledge.knows(&"committed_water_core_hook"), "Correct amendment still does not reveal grading in knowledge"): return
	session.reset_session()
	session.load_scenario(scenario)
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	session._post_signal_elapsed = session.commit_deadline_seconds
	var facts_before := world.snapshot()
	if not check(not session.submit_amendment("WAITER") and world.snapshot() == facts_before, "Correction at exact original deadline changes no facts"): return
	for word in ["A", "A".repeat(24), "WATCHER", "UNLISTED"]:
		session.reset_session()
		world.reset_for_new_game()
		knowledge.reset_for_new_game()
		session.load_scenario(scenario)
		session._state = TelegraphSessionController.State.VERIFYING
		session.mark_transcript_verified()
		if not check(session.submit_amendment(word), "Authority accepts canonical length/word '%s'" % word): return
		if not check(world.get_fact(&"core_hook_filed_word") == word and knowledge.recall_value(&"filed_word_core_hook") == word, "Valid words are never silently replaced by a candidate answer"): return
	session.queue_free()
	await process_frame
	print("Amendment contract assertions: ", assertions)
	quit(0)
