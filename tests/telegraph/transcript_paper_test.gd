extends SceneTree

func _init() -> void:
	print("--- Starting Transcript Paper Test Suite (Gate 11) ---")

	var paper_scene: PackedScene = ResourceLoader.load("res://scenes/telegraph/transcript_paper.tscn")
	if not assert_condition(paper_scene != null, "transcript_paper.tscn loads"): return
	var paper_node: TranscriptPaper = paper_scene.instantiate() as TranscriptPaper
	if not assert_condition(paper_node != null and paper_node is TranscriptPaper, "instantiates as TranscriptPaper"): return
	root.add_child(paper_node)

	var act: Interactable = paper_node.get_interactable()
	if not assert_condition(act != null, "paper has Interactable component"): return
	if not assert_condition(act.prompt_text == "Read Telegram Transcript", "prompt text matches"): return

	var lbl: Label3D = paper_node.get_label_3d()
	if not assert_condition(lbl != null, "paper has Label3D"): return

	# 1. Initial blank state
	if not assert_condition(paper_node.get_transcript_text().is_empty(), "Initial transcript text is empty"): return
	if not assert_condition(not paper_node.is_revealed(), "Initial state is unrevealed"): return
	if not assert_condition(lbl.text == "[BLANK TELEGRAM PAD]", "Label shows placeholder initially"): return

	# 2. Set text without revealing
	paper_node.set_transcript_text("WATCHER")
	if not assert_condition(paper_node.get_transcript_text() == "WATCHER", "Transcript text set to WATCHER"): return
	if not assert_condition(lbl.text == "[BLANK TELEGRAM PAD]", "Label remains placeholder before reveal"): return

	# 3. Reveal transcript
	paper_node.reveal_transcript()
	if not assert_condition(paper_node.is_revealed(), "is_revealed() is true"): return
	if not assert_condition(lbl.text == "WATCHER", "Label displays WATCHER upon reveal"): return

	# 4. Reliable inspection emissions (every interaction emits inspected text, no toggle desync)
	var inspected_text: Array[String] = []
	paper_node.transcript_inspected.connect(func(t: String): inspected_text.append(t))

	paper_node._on_interacted()
	if not assert_condition(inspected_text.size() == 1 and inspected_text[0] == "WATCHER", "First interaction emits transcript_inspected with text"): return

	paper_node._on_interacted()
	if not assert_condition(inspected_text.size() == 2 and inspected_text[1] == "WATCHER", "Second interaction also emits transcript_inspected with text"): return

	# 5. Clear transcript
	paper_node.clear_transcript()
	if not assert_condition(paper_node.get_transcript_text().is_empty(), "Cleared transcript text is empty"): return
	if not assert_condition(not paper_node.is_revealed(), "Cleared state is unrevealed"): return
	if not assert_condition(lbl.text == "[BLANK TELEGRAM PAD]", "Label resets to placeholder"): return

	# Clean up
	paper_node.queue_free()

	print("--- All Transcript Paper Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
