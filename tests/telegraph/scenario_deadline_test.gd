extends SceneTree
## The commit deadline is authored content: each scenario owns how long the
## sender waits after t0. The session export is only the fallback for scenarios
## that do not author one. The hook must leave a novice time to verify.
##   godot --headless --audio-driver Dummy --path . --script tests/telegraph/scenario_deadline_test.gd

const HOOK_MIN_DEADLINE := 50.0

func _init() -> void:
	call_deferred("_run")

func assert_condition(ok: bool, desc: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + desc)
	if not ok:
		quit(1)
	return ok

func _run() -> void:
	var blank := TelegraphScenarioData.new()
	if not assert_condition("commit_deadline_seconds" in blank, "Scenario data carries an authored commit deadline"): return
	if not assert_condition(float(blank.get("commit_deadline_seconds")) < 0.0, "An unauthored deadline defers to the session fallback"): return

	var hook: TelegraphScenarioData = load("res://data/scenarios/m1_scenario_3_core_hook.tres")
	var authored := float(hook.get("commit_deadline_seconds"))
	if not assert_condition(authored >= HOOK_MIN_DEADLINE, "The hook authors at least %ds to verify (got %.1f)" % [HOOK_MIN_DEADLINE, authored]): return
	if not assert_condition(hook.get_validation_errors().is_empty(), "The hook scenario still validates"): return

	var broken: TelegraphScenarioData = hook.duplicate()
	broken.set("commit_deadline_seconds", INF)
	if not assert_condition(not broken.get_validation_errors().is_empty(), "A non-finite deadline is rejected by validation"): return

	var world := WorldStateStore.new()
	world.name = "WorldState"
	root.add_child(world)
	var knowledge := KnowledgeStateStore.new()
	knowledge.name = "KnowledgeState"
	root.add_child(knowledge)

	var controller := TelegraphSessionController.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	var key := TelegraphKey.new()
	var paper := TranscriptPaper.new()
	for node in [controller, scheduler, key, paper]:
		root.add_child(node)
	controller.world_state = world
	controller.scheduler = scheduler
	controller.telegraph_key = key
	controller.transcript_paper = paper
	controller._bind_components()
	controller.commit_deadline_seconds = 30.0

	if not assert_condition(controller.has_method("get_commit_deadline_seconds"), "The session exposes its effective deadline"): return
	controller.load_scenario(hook)
	if not assert_condition(is_equal_approx(controller.get_commit_deadline_seconds(), authored), "The loaded hook's authored deadline wins over the session fallback"): return

	key.press()
	scheduler.advance_time(4.0)
	var guard := 0
	while paper.is_copy_in_progress() and guard < 400:
		paper.advance_paper(0.25)
		guard += 1
	controller.mark_transcript_verified()
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "The hook reaches AWAITING_COMMIT"): return
	controller.advance_post_signal(31.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "The old 30 s fallback no longer releases the line"): return
	controller.advance_post_signal(authored - 31.0 + 0.1)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "The authored deadline itself lapses the commit"): return

	var plain: TelegraphScenarioData = load("res://data/scenarios/m1_scenario_1_baseline.tres")
	controller.load_scenario(plain)
	if not assert_condition(is_equal_approx(controller.get_commit_deadline_seconds(), 30.0), "An unauthored scenario uses the session fallback"): return

	for node in [controller, scheduler, key, paper, world, knowledge]:
		node.free()
	quit(0)
