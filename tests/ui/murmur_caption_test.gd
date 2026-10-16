extends SceneTree
## The perception layer speaks: during a copy Elias whispers, letter by
## letter, what he HEARS on the wire — so on the hook the whisper says
## W-A-T-E-R while the sheet fills with WATCHER.
##   godot --headless --audio-driver Dummy --path . --script tests/ui/murmur_caption_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Murmur Caption Test Suite ---")
	var controller := TelegraphSessionController.new()
	var scheduler := MorseRuntimeScheduler.new()
	scheduler.auto_process = false
	var key := TelegraphKey.new()
	var paper := TranscriptPaper.new()
	var world := WorldStateStore.new()
	world.name = "WorldState"
	var knowledge := KnowledgeStateStore.new()
	knowledge.name = "KnowledgeState"
	root.add_child(world)
	root.add_child(knowledge)
	root.add_child(scheduler)
	root.add_child(paper)
	root.add_child(key)
	root.add_child(controller)
	controller.world_state = world
	controller.scheduler = scheduler
	controller.telegraph_key = key
	controller.transcript_paper = paper
	controller._bind_components()

	var alphabet: AmericanMorseAlphabetData = ResourceLoader.load(
		"res://data/morse/m1_american_morse_alphabet.tres")
	var scen1: TelegraphScenarioData = ResourceLoader.load(
		"res://data/scenarios/m1_scenario_1_baseline.tres")
	var scen3: TelegraphScenarioData = ResourceLoader.load(
		"res://data/scenarios/m1_scenario_3_core_hook.tres")

	var glyphs: Array[String] = []
	var indices: Array[int] = []
	var times: Array[float] = []
	controller.perception_glyph.connect(func(_id: String, index: int, glyph: String) -> void:
		glyphs.append(glyph)
		indices.append(index)
		times.append(scheduler.get_elapsed_seconds()))

	# --- 1. The hook: the whisper says exactly WATER, not the sheet's word ---
	controller.load_scenario(scen3)
	key.press()
	if not _a(controller.get_state() == TelegraphSessionController.State.RECEIVING, "The hook transmission is receiving"): return
	var step := 0.05
	while scheduler.get_elapsed_seconds() < 3.5:
		scheduler.advance_time(step)
	# Land inside the scheduler's completion epsilon so the last letter can
	# only arrive through the pre-t0 flush, not through a time tick.
	scheduler.advance_time(3.6 - 0.000005 - scheduler.get_elapsed_seconds())
	if not _a(scheduler.get_playback_state() == MorseRuntimeScheduler.State.COMPLETED, "The hook signal ended"): return
	if not _a(glyphs.size() == 5 and indices == [0, 1, 2, 3, 4],
		"The hook whisper carries exactly the five heard letters, not the sheet's seven"): return
	if not _a(glyphs[0] == "W" and glyphs[1] == "A" and glyphs[2] == "T" and glyphs[3] == "E" and glyphs[4] == "R",
		"The heard letters spell WATER"): return
	var water_ends := MorseLetterTiming.letter_end_fractions("WATER", alphabet)
	var total := 3.6
	var monotone := true
	for i in range(times.size()):
		if times[i] < water_ends[i] * total - 0.0001:
			monotone = false
		if i > 0 and times[i] < times[i - 1]:
			monotone = false
	if not _a(monotone, "Each letter is whispered no earlier than its own end on the wire, in order"): return

	# --- 2. A cancelled telegram never finishes its whisper ---
	var cancelled_glyphs: Array[String] = []
	controller.perception_glyph.connect(func(_id: String, _index: int, glyph: String) -> void:
		cancelled_glyphs.append(glyph))
	controller.load_scenario(scen3)
	key.press()
	while scheduler.get_elapsed_seconds() < 2.5:
		scheduler.advance_time(step)
	if not _a(cancelled_glyphs.size() == 3 and cancelled_glyphs[2] == "T",
		"A cancelled hook whisper stops at the last crossed letter"): return
	scheduler.cancel()
	scheduler.advance_time(5.0)
	if not _a(cancelled_glyphs.size() == 3, "Cancel does not flush the unwhispered tail"): return

	# --- 3. Every message gets its whisper: the fair copy is heard in full ---
	controller.load_scenario(scen1)
	key.press()
	scheduler.advance_time(14.0)
	if not _a(glyphs.size() == 5 + 3 + 16, "The fair copy whisper restarts on its own scenario"): return
	var fair_first := glyphs.size() - 16
	if not _a(indices[fair_first] == 0 and indices[indices.size() - 1] == 15,
		"The fair copy whispers all sixteen of its letters, once each"): return
	if not _a(glyphs[fair_first] == "T" and glyphs[fair_first + 4] == "N" and glyphs[glyphs.size() - 1] == "T",
		"The fair whisper follows its own message, not the sheet"): return

	# --- 4. The caption node shows the whisper and holds it past the wire ---
	var caption := MurmurCaption.new()
	caption.session = controller
	root.add_child(caption)
	controller.load_scenario(scen3)
	key.press()
	if not _a(caption.get_display_text().is_empty(), "A fresh scenario starts the whisper blank"): return
	scheduler.advance_time(2.35)
	if not _a(caption.get_display_text() == "w · a · t", "The whisper builds letter by letter, lowercase and spaced"): return
	scheduler.advance_time(3.6 - scheduler.get_elapsed_seconds() + 1.0)
	_drain_paper(paper)
	if not _a(paper.get_display_text() == "WATCHER", "The sheet holds the written word WATCHER"): return
	if not _a(caption.get_display_text() == "w · a · t · e · r", "The finished whisper says water while the sheet says WATCHER"): return
	if not _a(caption.is_holding(), "The whisper holds after the wire falls silent"): return
	caption._process(3.9)
	if not _a(caption.is_holding() and caption.get_display_text() == "w · a · t · e · r",
		"The whisper is still readable at the end of its hold"): return
	caption._process(0.2)
	if not _a(caption.is_fading() and not caption.get_display_text().is_empty(),
		"The whisper fades out slowly after its hold"): return
	caption._process(2.0)
	if not _a(not caption.is_visible_on_screen(), "The whisper is gone after the fade"): return

	# --- 5. Word gaps read wider than letter gaps ---
	controller.load_scenario(scen1)
	key.press()
	if not _a(caption.get_display_text().is_empty(), "The next scenario clears the whisper"): return
	scheduler.advance_time(6.6)
	var shown := caption.get_display_text()
	if not _a(shown.begins_with("t · r · a · i · n"), "The fair whisper spells its first word"): return
	if not _a(shown.contains("1 · 7"), "The fair whisper spells its second word"): return
	var between := shown.trim_prefix("t · r · a · i · n").trim_suffix("1 · 7")
	if not _a(between.length() > 3, "A word gap is wider than a letter gap, got '%s'" % between): return
	if not _a(not between.contains("·") and between.strip_edges(false, true).is_empty(),
		"A word gap is pure space without a dot, got '%s'" % between): return

	# --- 6. Layer contract: the whisper node never reads the other two layers ---
	var source := FileAccess.get_file_as_string("res://scripts/ui/murmur_caption.gd")
	if not _a(source.length() > 0, "The whisper source file is readable"): return
	if not _a(not source.contains("true_message") and not source.contains("written_transcript"),
		"The whisper source never mentions the true message or the written transcript"): return
	if not _a(not source.contains("M1OfficeController"), "The whisper node stays decoupled from the office controller"): return
	if not _a(caption.process_mode == Node.PROCESS_MODE_INHERIT,
		"The whisper keeps the default process mode, so pausing the night pauses it"): return

	# --- 7. The whisper is no cheat sheet: reading the sheet dismisses it fast ---
	scheduler.cancel()
	controller.load_scenario(scen3)
	key.press()
	scheduler.advance_time(3.7)
	if not _a(caption.get_display_text() == "w · a · t · e · r",
		"The finished hook whisper is holding before the sheet is read"): return
	paper._on_interacted()
	if not _a(caption.is_dismissing(), "Reading the sheet starts the dismissal"): return
	caption._process(0.3)
	if not _a(not caption.get_display_text().is_empty(),
		"Halfway through the dismissal the whisper is still legible"): return
	caption._process(0.35)
	if not _a(caption.get_display_text().is_empty(),
		"Reading the sheet empties the whisper within 0.6 s"): return

	# --- 8. Standing up mid-copy silences the whisper too ---
	var stood_events: Array[int] = []
	controller.operator_stood.connect(func() -> void: stood_events.append(1))
	controller.load_scenario(scen3)
	key.press()
	scheduler.advance_time(2.35)
	if not _a(caption.get_display_text() == "w · a · t",
		"The whisper is mid-copy before the operator stands"): return
	controller.notify_operator_stood()
	if not _a(stood_events.size() == 1,
		"Standing up is announced on the session's operator_stood signal"): return
	if not _a(caption.is_dismissing(), "Standing up starts the dismissal"): return
	caption._process(0.65)
	if not _a(caption.get_display_text().is_empty(),
		"Standing up empties the whisper within 0.6 s"): return

	controller.queue_free()
	caption.queue_free()
	print("--- All Murmur Caption Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _drain_paper(p: TranscriptPaper) -> void:
	var guard := 0
	while p.is_copy_in_progress() and guard < 400:
		p.advance_paper(0.25)
		guard += 1

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
