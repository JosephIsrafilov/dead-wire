extends SceneTree
var assertions := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, description: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + description)
	if not ok: quit(1); return false
	assertions += 1
	return true
func _run() -> void:
	var world := root.get_node("WorldState") as WorldStateStore
	var knowledge := root.get_node("KnowledgeState") as KnowledgeStateStore
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	var session := TelegraphSessionController.new()
	root.add_child(session)
	var scenario := load("res://data/scenarios/m1_scenario_3_core_hook.tres") as TelegraphScenarioData
	session.load_scenario(scenario)
	session._state = TelegraphSessionController.State.VERIFYING
	session.mark_transcript_verified()
	if not check(session.submit_amendment("WAITER"), "Wrong correction is accepted without changing it"): return
	var dawn := load("res://scenes/office/dawn_evidence.tscn").instantiate() as DawnEvidence
	root.add_child(dawn)
	dawn.reveal()
	if not check(dawn.get_document_text().contains("WAITER"), "Dawn preserves the actual entered word"): return
	if not check(not dawn.get_document_text().contains("WATER\n"), "Dawn does not substitute the correct answer"): return
	var status := DutySheet.core_hook_outcome(knowledge)
	if not check(status == "AMENDED COPY SEALED", "Operator journal acknowledges amendment without grading it"): return
	if not check(not knowledge.knows(&"amended_wrong_core_hook"), "Knowledge never learns objective wrongness by filing"): return
	world.set_fact(&"core_hook_filed_word", "CHANGED")
	if not check(knowledge.recall_value(&"filed_word_core_hook") == "WAITER", "Objective mutation cannot rewrite the independent chosen-word memory"): return
	var snap := knowledge.value_snapshot()
	snap[&"filed_word_core_hook"] = "OTHER"
	if not check(knowledge.recall_value(&"filed_word_core_hook") == "WAITER", "Chosen-word snapshots cannot mutate knowledge"): return
	knowledge.reset_for_new_game()
	if not check(knowledge.value_snapshot().is_empty(), "New watch clears entered-word memory"): return
	dawn.queue_free()
	session.queue_free()
	await process_frame
	print("Amendment record assertions: ", assertions)
	quit(0)
