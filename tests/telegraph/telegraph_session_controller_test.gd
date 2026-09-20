extends SceneTree

func _init() -> void:
	print("--- Starting Telegraph Session Controller Test Suite (Gate 12 / F2 contract) ---")

	# Set up WorldState singleton node on root
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

	# Set up components
	var controller := TelegraphSessionController.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	var sounder := SounderController.new()
	var key := TelegraphKey.new()
	var paper := TranscriptPaper.new()

	root.add_child(controller)
	root.add_child(scheduler)
	root.add_child(sounder)
	root.add_child(key)
	root.add_child(paper)

	controller.world_state = world
	controller.scheduler = scheduler
	controller.sounder = sounder
	controller.telegraph_key = key
	controller.transcript_paper = paper
	controller._bind_components()

	# Load scenario fixtures
	var scen1: TelegraphScenarioData = ResourceLoader.load("res://data/scenarios/m1_scenario_1_baseline.tres")
	var scen2: TelegraphScenarioData = ResourceLoader.load("res://data/scenarios/m1_scenario_2_attention.tres")
	var scen3: TelegraphScenarioData = ResourceLoader.load("res://data/scenarios/m1_scenario_3_core_hook.tres")

	# Track the three distinct completion events across the whole suite.
	var copy_finished_ids: Array[String] = []
	controller.copy_finished.connect(func(id: String): copy_finished_ids.append(id))
	var warnings: Array[StringName] = []
	controller.deadline_warning.connect(func(kind: StringName): warnings.append(kind))

	# 1. Flow Test: Scenario 1 with Correct Routing
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	controller.load_scenario(scen1)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.READY, "Scenario 1 loaded -> state READY"): return

	# Press key to answer line and start transmission
	key.press()
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.RECEIVING, "Key press transitions to RECEIVING"): return

	# Advance time through 13.60s (TRAIN 17 schedule duration). The synchronous
	# jump authorizes every cue at once, so the sheet legitimately lands in
	# COPYING with a backlog rather than being instantly complete.
	scheduler.advance_time(14.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COPYING, "t0 with unfinished sheet enters COPYING"): return
	_drain_paper(paper)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.VERIFYING, "Finished copy transitions to VERIFYING"): return
	if not assert_condition(copy_finished_ids.size() == 1 and copy_finished_ids[0] == "baseline_train_17", "copy_finished fired exactly once for the physical sheet"): return
	if not assert_condition(paper.get_transcript_text() == "TRAIN 17 CLEAR EAST", "Paper text set to written_transcript"): return
	if not assert_condition(paper.is_ready_to_inspect(), "Paper is physically complete"): return
	if not assert_condition(controller.mark_transcript_verified(), "Transcript verification unlocks routing"): return
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.AWAITING_ROUTE, "Verified transcript transitions to AWAITING_ROUTE"): return
	if not assert_condition(not controller.mark_transcript_verified(), "Transcript verification is exactly once"): return

	# Submit correct decision
	var route_ok := controller.submit_routing_decision("CLEAR EAST")
	if not assert_condition(route_ok, "Routing decision submitted"): return
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COMPLETE, "State is COMPLETE after routing"): return
	if not assert_condition(world.has_fact("train_17_routed_clear") and world.get_fact("train_17_routed_clear") == true, "WorldState recorded correct fact"): return
	if not assert_condition(not world.has_fact("train_17_held_in_error"), "Incorrect fact is NOT set"): return
	if not assert_condition(world.has_fact("train_17_no_order_sent") == false, "Lapse fact is NOT set on a correct route"): return
	if not assert_condition(knowledge.knows("route_clear_east_baseline_train_17"), "Accepted route records the route_clear_east knowledge fact"): return
	if not assert_condition(knowledge.knows("filed_baseline_train_17"), "Accepted route records filed_ knowledge fact"): return
	if not assert_condition(not knowledge.knows("lapsed_baseline_train_17"), "Correct route records no lapse fact"): return

	# 2. Consequence Test: Scenario 1 with Wrong Routing (no reload)
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	controller.load_scenario(scen1)
	key.press()
	scheduler.advance_time(14.0)
	_drain_paper(paper)
	controller.mark_transcript_verified()
	controller.submit_routing_decision("HOLD")
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COMPLETE, "State is COMPLETE after incorrect routing"): return
	if not assert_condition(world.has_fact("train_17_held_in_error") and world.get_fact("train_17_held_in_error") == true, "WorldState recorded incorrect consequence"): return
	if not assert_condition(not world.has_fact("train_17_routed_clear"), "Correct fact is NOT set on mistake"): return
	if not assert_condition(not world.has_fact("train_17_no_order_sent"), "A wrong order is not a lapse"): return
	if not assert_condition(knowledge.knows("route_hold_baseline_train_17"), "Accepted wrong route still records the action actually sent"): return

	# 3. Flow Test: Scenario 2 (Attention event at 4.0s)
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	var attention_fired: Array[String] = []
	controller.attention_event_triggered.connect(func(id: String): attention_fired.append(id))

	controller.load_scenario(scen2)
	key.press()
	if not assert_condition(attention_fired.is_empty(), "Attention event not fired before 4.0s"): return

	# Advance 4.5s
	scheduler.advance_time(4.5)
	if not assert_condition(attention_fired.size() == 1 and attention_fired[0] == "door_footsteps", "Attention event 'door_footsteps' triggered at 4.0s"): return

	# Complete transmission (total 15.60s)
	scheduler.advance_time(12.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COPYING, "Scenario 2 reaches COPYING at t0"): return
	_drain_paper(paper)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.VERIFYING, "Scenario 2 reaches VERIFYING"): return
	controller.mark_transcript_verified()
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.AWAITING_ROUTE, "Scenario 2 reaches AWAITING_ROUTE after inspection"): return
	controller.submit_routing_decision("HOLD")
	if not assert_condition(world.has_fact("freight_held_correctly") and world.get_fact("freight_held_correctly") == true, "Scenario 2 correct routing recorded"): return

	# 3b. W08: a service signal ending on the same scheduler is not t0.
	controller.load_scenario(scen2)
	key.press()
	scheduler.advance_time(16.5)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COPYING, "Scenario 2b in COPYING at t0"): return
	var nag_seq: MorseSequenceData = AmericanMorseEncoder.new().encode("E", controller.alphabet)
	var nag_sched: MorsePlaybackScheduleData = MorseScheduleCompiler.new().compile(nag_seq, controller.playback_profile)
	scheduler.start(nag_sched)
	scheduler.advance_time(nag_sched.total_duration_seconds + 0.1)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COPYING, "Service signal completion is not the telegram's t0"): return
	if not assert_condition(paper.get_available_glyph_count() == paper.get_written_glyph_count() or paper.is_copy_in_progress(), "Nag does not change the sheet's target"): return

	# 4. Flow Test: Scenario 3 (Core Hook: Sounder WATER, Paper WATCHER)
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	sounder.reset_telemetry()
	controller.load_scenario(scen3)
	key.press()

	# Run transmission (3.60s)
	scheduler.advance_time(4.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COPYING, "Scenario 3 reaches COPYING at t0"): return
	_drain_paper(paper)

	if not assert_condition(controller.get_state() == TelegraphSessionController.State.VERIFYING, "Scenario 3 reaches VERIFYING"): return
	if not assert_condition(paper.get_transcript_text() == "WATCHER", "Paper displays WATCHER"): return
	if not assert_condition(sounder.down_clicks_played > 0, "Sounder played clicks during transmission"): return
	if not assert_condition(not controller.submit_commit(&"file_water"), "Commit before inspection is a no-op"): return
	controller.mark_transcript_verified()
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "Scenario 3 awaits commit after inspection"): return
	if not assert_condition(controller.submit_commit(&"file_water"), "Scenario 3 accepts authored commit"): return
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Commit starts consequence state"): return
	if not assert_condition(not controller.submit_commit(&"file_watcher"), "Second commit is a no-op"): return
	# A world-space figure can remain pending while the camera watches it. The
	# session must not complete the observable hold before the figure appears.
	controller.set_consequence_visibility_required(true)
	controller.advance_consequence(2.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Pending consequence does not complete before figure visibility"): return
	controller.notify_consequence_visible()
	controller.advance_consequence(0.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Late appearance starts a fresh observable hold"): return
	controller.advance_consequence(scen3.consequence_hold_seconds - 0.1)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Full visible hold cannot be consumed while pending"): return
	controller.advance_consequence(0.1)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COMPLETE, "Visible consequence hold completes session"): return
	if not assert_condition(world.has_fact("core_hook_filed_water") and world.get_fact("core_hook_filed_water") == true, "Scenario 3 water fact recorded"): return
	if not assert_condition(world.has_fact("water_watcher_transmission_received"), "Scenario 3 completion fact recorded"): return

	# 5. Automatic deadline covers COPYING, VERIFYING and AWAITING_COMMIT without
	# silently choosing either copy. The clock starts at t0.
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	controller.commit_deadline_seconds = 0.5
	controller.load_scenario(scen3)
	key.press()
	scheduler.advance_time(4.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COPYING, "Automatic timeout branch starts in COPYING"): return
	controller._process(0.6)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Commit deadline lapses from COPYING"): return
	if not assert_condition(world.has_fact("core_hook_commit_lapsed") and knowledge.knows("core_hook_commit_lapsed"), "Automatic timeout records dedicated lapse facts"): return
	if not assert_condition(not world.has_fact("core_hook_filed_water") and not world.has_fact("core_hook_filed_watcher"), "Automatic timeout does not select either authored copy"): return
	if not assert_condition(paper.is_incomplete_closed(), "Lapsed copy closes as terminal partial"): return
	if not assert_condition(knowledge.knows("incomplete_copy_core_hook_water_watcher"), "incomplete_copy fact recorded for the lapsed sheet"): return
	controller.advance_consequence(scen3.consequence_delay_seconds + scen3.consequence_hold_seconds)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COMPLETE, "Automatic timeout consequence completes the session"): return

	# 6. Explicit timeout path remains available for UI/deadline owners.
	controller.commit_deadline_seconds = 30.0
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	controller.load_scenario(scen3)
	key.press()
	scheduler.advance_time(4.0)
	_drain_paper(paper)
	controller.mark_transcript_verified()
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.AWAITING_COMMIT, "Timeout branch reaches AWAITING_COMMIT"): return
	if not assert_condition(controller.lapse_commit(), "Timeout branch accepts an explicit lapse"): return
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Lapse enters the neutral consequence state"): return
	if not assert_condition(world.has_fact("core_hook_commit_lapsed"), "Lapse records the dedicated world fact"): return
	if not assert_condition(knowledge.knows("core_hook_commit_lapsed"), "Lapse records the dedicated knowledge fact"): return
	if not assert_condition(not world.has_fact("core_hook_filed_water") and not world.has_fact("core_hook_filed_watcher"), "Lapse does not select either authored copy"): return
	controller.advance_consequence(scen3.consequence_delay_seconds + scen3.consequence_hold_seconds)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COMPLETE, "Lapse consequence still completes the session"): return

	# 6b. O04: input arriving after the deadline is rejected at the door and
	# never produces a stamp or a fact.
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	controller.load_scenario(scen3)
	key.press()
	scheduler.advance_time(4.0)
	_drain_paper(paper)
	controller.mark_transcript_verified()
	controller.advance_post_signal(controller.commit_deadline_seconds + 0.1)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Expired deadline resolved the slot"): return
	if not assert_condition(not controller.submit_commit(&"file_water"), "Late input cannot file after the deadline"): return
	if not assert_condition(not world.has_fact("core_hook_filed_water"), "Rejected late input leaves no fact"): return

	# 7. Unread order lapses without pretending it was verified.
	controller.load_scenario(scen1)
	controller.start_transmission()
	scheduler.advance_time(14.0)
	_drain_paper(paper)
	if not assert_condition(not controller.submit_routing_decision("CLEAR EAST"), "Unread order still rejects player routing"): return
	if not assert_condition(controller.lapse_routing(), "Unread order can lapse without verification"): return
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COMPLETE, "Unread lapse completes rather than stranding the night"): return
	if not assert_condition(not controller.lapse_routing(), "Lapse is terminal exactly once"): return

	# 8. W02/W03: stand mid-signal, return; the signal never restarts and no
	# deadline resets.
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	controller.load_scenario(scen1)
	key.press()
	scheduler.advance_time(4.0)
	paper.advance_paper(0.6)
	var prefix := paper.get_written_glyph_count()
	if not assert_condition(prefix > 0, "Seated operator's hand has written ink"): return
	controller.notify_operator_stood()
	if not assert_condition(paper.is_copy_paused(), "Standing suspends the live sheet"): return
	scheduler.advance_time(4.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.RECEIVING, "Signal survives the operator leaving"): return
	if not assert_condition(paper.get_written_glyph_count() == prefix, "No ink appears while standing"): return
	controller.notify_operator_seated()
	if not assert_condition(paper.is_writing(), "Returning resumes the sheet without resetting it"): return
	scheduler.advance_time(6.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COPYING, "t0 lands in COPYING after the return"): return
	if not assert_condition(controller.get_post_signal_elapsed() == 0.0, "t0 starts the post-signal clock at zero"): return
	_drain_paper(paper)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.VERIFYING, "Returned copy completes into VERIFYING"): return
	if not assert_condition(controller.mark_transcript_verified(), "Verification unlocks routing after the round trip"): return
	controller.submit_routing_decision("CLEAR EAST")
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COMPLETE, "Round-trip session completes"): return

	# 9. W04/W05: grace closes an unfinished sheet; returning after grace
	# reopens nothing.
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	warnings.clear()
	controller.unfinished_copy_grace_seconds = 2.0
	controller.commit_deadline_seconds = 30.0
	controller.load_scenario(scen1)
	key.press()
	controller.notify_operator_stood()
	scheduler.advance_time(14.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COPYING, "Sheet unfinished at t0 (operator away)"): return
	controller._process(2.1)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COMPLETE, "Grace lapse completes the session"): return
	if not assert_condition(paper.is_incomplete_closed(), "Sheet closed as terminal partial"): return
	if not assert_condition(knowledge.knows("incomplete_copy_baseline_train_17"), "incomplete_copy fact recorded"): return
	if not assert_condition(knowledge.knows("lapsed_baseline_train_17"), "Routing lapse knowledge fact recorded"): return
	if not assert_condition(world.has_fact("train_17_no_order_sent"), "Routing lapse world fact recorded"): return
	if not assert_condition(not world.has_fact("train_17_held_in_error"), "Lapse is not an incorrect order"): return
	if not assert_condition(not knowledge.knows("copied_baseline_train_17"), "No copied_ fact for a never-finished sheet"): return
	if not assert_condition(warnings.has(TelegraphSessionController.WARNING_COPY_GRACE), "Grace warning fired before expiry"): return
	controller.notify_operator_seated()
	if not assert_condition(not paper.is_copy_in_progress(), "Returning after grace does not reopen the sheet"): return
	controller.unfinished_copy_grace_seconds = 20.0

	# 10. A finished old sheet does not verify the next scenario's session (O05).
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	controller.load_scenario(scen1)
	key.press()
	scheduler.advance_time(14.0)
	_drain_paper(paper)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.VERIFYING, "Scenario 1 waits for inspection"): return
	controller.load_scenario(scen2)
	if not assert_condition(paper.is_ready_to_inspect() and paper.get_paper_scenario_id() == "baseline_train_17", "Terminal sheet survives the slot change"): return
	key.press()
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.RECEIVING, "Scenario 2 is receiving"): return
	paper._on_interacted()
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.RECEIVING, "Reading the old sheet verifies nothing of the new session"): return
	if not assert_condition(not controller.mark_transcript_verified(), "Old sheet cannot pass the verification gate"): return

	# 11. Commit warning fires once, after t0, only on the live deadline.
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	warnings.clear()
	controller.commit_warning_seconds = 10.0
	controller.load_scenario(scen3)
	key.press()
	scheduler.advance_time(4.0)
	_drain_paper(paper)
	controller.mark_transcript_verified()
	controller.advance_post_signal(controller.commit_deadline_seconds - controller.commit_warning_seconds + 0.1)
	if not assert_condition(warnings.count(TelegraphSessionController.WARNING_COMMIT) == 1, "Commit warning fires exactly once"): return
	controller.advance_post_signal(controller.commit_warning_seconds)
	if not assert_condition(warnings.count(TelegraphSessionController.WARNING_COMMIT) == 1, "Warning is not repeated on later ticks"): return
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "Deadline then lapses the commit"): return

	# 11b. One warning per scenario (R8): a grace warning that already spoke
	# silences the later commit warning, even after the copy completes.
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	warnings.clear()
	controller.commit_warning_seconds = 10.0
	controller.load_scenario(scen3)
	key.press()
	# The operator is away: the sheet stays open at t0 and the grace runs.
	controller.notify_operator_stood()
	scheduler.advance_time(4.0)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.COPYING, "Away operator leaves the copy open at t0"): return
	controller.advance_post_signal(controller.unfinished_copy_grace_seconds - controller.copy_grace_warning_seconds + 0.1)
	if not assert_condition(warnings.count(TelegraphSessionController.WARNING_COPY_GRACE) == 1, "Grace warning fires at its threshold"): return
	# He returns and the sheet physically completes after the warning.
	controller.notify_operator_seated()
	_drain_paper(paper)
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.VERIFYING, "Returned copy completes into VERIFYING"): return
	if not assert_condition(controller._grace_active == false, "Completing the copy cancels the grace"): return
	# Past the commit-warning threshold: the scenario already had its warning.
	# The clock is cumulative — advance only the remaining distance.
	var commit_warn_at: float = controller.commit_deadline_seconds - controller.commit_warning_seconds + 0.1
	controller.advance_post_signal(maxf(commit_warn_at - controller.get_post_signal_elapsed(), 0.0))
	if not assert_condition(warnings.size() == 1, "The commit warning stays silent after the grace warning (one per scenario)"): return
	if not assert_condition(controller.get_deadline_warning_text().begins_with("The sender is about to release the line"), "The live status names the deadline that still runs"): return
	var commit_expire_at: float = controller.commit_deadline_seconds + 0.1
	controller.advance_post_signal(maxf(commit_expire_at - controller.get_post_signal_elapsed(), 0.0))
	if not assert_condition(controller.get_state() == TelegraphSessionController.State.CONSEQUENCE, "The commit deadline itself still runs and lapses"): return

	# Clean up
	controller.queue_free()
	scheduler.queue_free()
	sounder.queue_free()
	key.queue_free()
	paper.queue_free()

	print("--- All Telegraph Session Controller Tests PASSED ---")
	quit(0)

func _drain_paper(p: TranscriptPaper) -> void:
	var guard := 0
	while p.is_copy_in_progress() and guard < 400:
		p.advance_paper(0.25)
		guard += 1

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
