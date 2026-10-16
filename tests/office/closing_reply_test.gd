extends SceneTree
## The sender answers the filed word before good night: the closing wire
## carries ONE schedule, "<reply> <closing sign>", and the reply is chosen by
## how the hook's filing resolved, from the scenario's data. The reply rides
## the tape as an ordinary take, and no closing wire may ever cut a live
## critical copy.
##   godot --headless --audio-driver Dummy --path . --script tests/office/closing_reply_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Closing Reply Test Suite ---")
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
	var encoder := AmericanMorseEncoder.new()
	var compiler := MorseScheduleCompiler.new()

	# --- 1. Each outcome rides out as one "<reply> <sign>" schedule ---
	if not _a(_resolve_hook(session, scheduler, paper, scen3, "WATER"),
		"The true-word amendment resolves the hook"): return
	if not _a(_closing_rides(director, scheduler, encoder, compiler, "WATER TO HAND GN"),
		"Amending WATER gets the sender's 'WATER TO HAND GN' as one schedule"): return
	_play_out(scheduler)

	if not _a(_resolve_hook(session, scheduler, paper, scen3, "WAITER"),
		"The wrong-word amendment resolves the hook"): return
	if not _a(_closing_rides(director, scheduler, encoder, compiler, "SAID WHAT GN"),
		"A wrong word gets 'SAID WHAT GN'"): return
	_play_out(scheduler)

	if not _a(_resolve_hook(session, scheduler, paper, scen3, ""),
		"Filing as copied resolves the hook"): return
	if not _a(_closing_rides(director, scheduler, encoder, compiler, "WHAT IS WATCHER GN"),
		"Filing the watched word gets 'WHAT IS WATCHER GN'"): return
	_play_out(scheduler)

	if not _a(_resolve_hook(session, scheduler, paper, scen3, "<lapsed>"),
		"The lapse resolves the hook"): return
	if not _a(_closing_rides(director, scheduler, encoder, compiler, "LINE CLOSED GN"),
		"A lapse gets 'LINE CLOSED GN'"): return
	_play_out(scheduler)
	if not _a(session.get_filed_word().is_empty(), "A lapse files no word"): return

	# --- 2. The reply is an ordinary take: the tape stays whole ---
	var interrupted := 0
	var complete := 0
	for snapshot in tape.get_segment_snapshots():
		if snapshot.get("interrupted", false):
			interrupted += 1
		if snapshot.get("complete", false):
			complete += 1
	if not _a(interrupted == 0, "No reply take is broken off on the tape, got %d" % interrupted): return
	if not _a(complete >= 8,
		"Telegram and reply takes all complete on the tape, got %d" % complete): return

	# --- 3. The replies are data: validated, sendable, template with fallback ---
	if not _a(scen3.get_validation_errors().is_empty(),
		"The authored hook scenario still validates"): return
	var replies := scen3.wire_reply_by_outcome
	if not _a(replies.size() == 4,
		"The hook authors a reply for all four outcomes, got %d" % replies.size()): return
	var all_sendable := true
	for outcome_key in replies.keys():
		if StringName(str(outcome_key)) not in TelegraphScenarioData.OUTCOME_IDS:
			all_sendable = false
		if encoder.encode(str(replies[outcome_key]), director.alphabet) == null:
			all_sendable = false
	if not _a(all_sendable, "Every authored reply rides the M1 alphabet"): return
	if not _a(encoder.encode(scen3.wire_reply_fallback, director.alphabet) != null,
		"The fallback reply rides the M1 alphabet too"): return

	var templated: TelegraphScenarioData = scen3.duplicate()
	templated.wire_reply_by_outcome = {"amended_other": "SAID {word}"}
	templated.wire_reply_fallback = "SAID WHAT"
	if not _a(templated.get_validation_errors().is_empty(), "The templated copy validates"): return
	if not _a(_resolve_hook(session, scheduler, paper, templated, "WAITER"),
		"The templated hook resolves with an encodable word"): return
	if not _a(_closing_rides(director, scheduler, encoder, compiler, "SAID WAITER GN"),
		"An encodable {word} substitution rides the wire"): return
	_play_out(scheduler)
	if not _a(session.get_filed_word() == "WAITER", "The session remembers the filed word"): return

	if not _a(_resolve_hook(session, scheduler, paper, templated, "QUIT"),
		"The templated hook resolves with an unencodable word"): return
	if not _a(_closing_rides(director, scheduler, encoder, compiler, "SAID WHAT GN"),
		"An unencodable {word} falls back to the authored plain reply"): return
	_play_out(scheduler)

	# --- 4. Fairness: a closing wire never cuts a live critical copy ---
	if not _a(session.load_scenario(scen3), "The hook reloads for the fairness case"): return
	if not _a(session.start_transmission(), "The critical copy takes the wire"): return
	scheduler.advance_time(1.0)
	var telegram_schedule := scheduler.get_active_schedule()
	director._begin_closing()
	if not _a(scheduler.is_playing() and scheduler.get_active_schedule() == telegram_schedule,
		"The closing reply is refused while the critical copy is live"): return
	scheduler.cancel()

	session.queue_free()
	director.queue_free()
	print("--- All Closing Reply Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

## Drives the hook through the desk to a resolved filing.
## `word` is the amendment word; "" files as copied; "<lapsed>" lets the
## deadline run out. Completes the consequence beat so the director closes.
func _resolve_hook(
		session: TelegraphSessionController,
		scheduler: MorseRuntimeScheduler,
		paper: TranscriptPaper,
		scenario: TelegraphScenarioData,
		word: String) -> bool:
	if not session.load_scenario(scenario):
		return false
	if not session.start_transmission():
		return false
	scheduler.advance_time(3.7)
	var guard := 0
	while paper.is_copy_in_progress() and guard < 400:
		paper.advance_paper(0.25)
		guard += 1
	if session.get_state() != TelegraphSessionController.State.VERIFYING:
		return false
	if not session.mark_transcript_verified():
		return false
	var resolved := false
	if word == "<lapsed>":
		resolved = session.lapse_commit()
	elif word.is_empty():
		resolved = session.submit_commit(&"file_watcher")
	else:
		resolved = session.submit_amendment(word)
	if not resolved:
		return false
	# delay 1.0 + hold 6.0 without a visibility requirement completes the beat
	# and hands the night to the director's closing.
	session.advance_consequence(7.2)
	return session.get_state() == TelegraphSessionController.State.COMPLETE

## True when the wire right now carries exactly the compiled `expected_text`.
func _closing_rides(
		director: ShiftDirector,
		scheduler: MorseRuntimeScheduler,
		encoder: AmericanMorseEncoder,
		compiler: MorseScheduleCompiler,
		expected_text: String) -> bool:
	var active := scheduler.get_active_schedule()
	if active == null:
		return _a(false, "The closing wire is silent — expected '%s'" % expected_text)
	var sequence := encoder.encode(expected_text, director.alphabet)
	if sequence == null:
		return _a(false, "Expected closing text is not encodable: '%s'" % expected_text)
	var expected := compiler.compile(sequence, director.playback_profile)
	if expected == null:
		return _a(false, "Expected closing text does not compile: '%s'" % expected_text)
	return _a(is_equal_approx(active.total_duration_seconds, expected.total_duration_seconds),
		"The closing schedule is '%s' (%.2fs), got %.2fs" % [
			expected_text, expected.total_duration_seconds, active.total_duration_seconds])

func _play_out(scheduler: MorseRuntimeScheduler) -> void:
	var active := scheduler.get_active_schedule()
	if active != null and scheduler.is_playing():
		scheduler.advance_time(active.total_duration_seconds + 0.1)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
