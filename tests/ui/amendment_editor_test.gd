extends SceneTree
var assertions := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, description: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + description)
	if not ok: quit(1); return false
	assertions += 1
	return true
func _run() -> void:
	if not check(FileAccess.file_exists("res://scenes/ui/amendment_editor.tscn"), "Paper amendment editor scene exists"): return
	var editor: Node = load("res://scenes/ui/amendment_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	if not check(not editor.call("is_open"), "Editor starts closed"): return
	editor.call("open_editor", "core_hook_water_watcher")
	if not check(editor.call("is_open"), "Explicit amendment opens editor"): return
	var input := editor.get_node("CenterContainer/Panel/Margin/VBox/Correction") as LineEdit
	if not check(input.text.is_empty() and not input.placeholder_text.contains("WATER"), "Correction starts blank without an answer hint"): return
	input.text = "waiter"
	input.text_changed.emit(input.text)
	if not check(input.text == "WAITER", "Editor visibly displays the exact uppercase submitted word"): return
	var submits: Array[String] = []
	editor.connect("correction_submitted", func(word: String): submits.append(word))
	editor.call("submit_draft")
	if not check(submits.size() == 1 and submits[0] == "WAITER", "Typed correction emits chosen word only"): return
	editor.call("reject_submission", "The sender released the line.")
	editor.call("close_editor", true)
	editor.call("open_editor", "core_hook_water_watcher")
	if not check(input.text == "WAITER", "Cancel and reopen keep the operator's draft"): return
	editor.call("close_editor", false)
	editor.call("open_editor", "another_slot")
	if not check(input.text.is_empty(), "A different scenario never receives the previous draft"): return
	input.text = "ß"
	input.text_changed.emit(input.text)
	editor.call("submit_draft")
	if not check(submits.size() == 1 and input.text == "ß", "Non-ASCII input is not silently repaired into ASCII text"): return
	input.text = "W1"
	input.text_changed.emit(input.text)
	editor.call("submit_draft")
	if not check(submits.size() == 1, "Unsupported text is rejected without filing or auto-repair"): return
	editor.queue_free()
	await process_frame
	print("Amendment editor assertions: ", assertions)
	quit(0)
