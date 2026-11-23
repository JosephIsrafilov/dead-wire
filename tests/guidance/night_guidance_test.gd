extends SceneTree

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok:
		quit(1)
	return ok

func _run() -> void:
	GameLocale.lock_language_for_test("en")
	if not check(FileAccess.file_exists("res://scripts/office/night_guidance_controller.gd"), "Guidance implementation is available"): return
	var script = load("res://scripts/office/night_guidance_controller.gd")
	if not check(script != null, "Guidance controller exists"): return
	var guidance = script.new()
	guidance.data = load("res://data/night_guidance/m1_guidance.tres")
	guidance.set_context(&"entry", false)
	guidance.advance_guidance(3.0)
	var entry_text: String = guidance.data.entry_for(&"entry").get("text", "")
	if not check(not entry_text.is_empty() and guidance.current_text == entry_text, "Entry thought appears after delay"): return
	if not check(guidance.current_text.contains("chair"), "The first thought points at the chair"): return
	# AGENT_RULES §5: a thought names the next action; it never lists the room
	# or reassures the player about it.
	if not check(guidance.current_text.split(". ").size() <= 2 and not guidance.current_text.contains("unexplained"),
			"The entry thought names the next action and does not explain the room"): return
	guidance.set_context(&"answer", false)
	if not check(guidance.current_text.is_empty(), "Completed context immediately clears its thought"): return
	guidance.advance_guidance(3.0)
	if not check(guidance.current_text.is_empty(), "Automatic thoughts respect cooldown"): return
	guidance.repeat_current()
	if not check(guidance.current_text.contains("Back to the key"), "F1 repeats current procedure despite cooldown"): return
	guidance.set_context(&"answer", true)
	if not check(guidance.current_text.is_empty(), "Protected wire or modal clears thought"): return
	guidance.repeat_current()
	if not check(guidance.current_text.is_empty(), "F1 cannot enter blocked presentation"): return
	guidance.set_context(&"open_line", false)
	guidance.advance_guidance(12.0)
	if not check(guidance.current_text.is_empty(), "Seated help does not add an automatic thought"): return
	guidance.repeat_current()
	if not check(guidance.current_text.contains("right of the writing pad"), "F1 locates the key when seated"): return
	guidance.set_context(&"read_copy", false)
	guidance.enabled = false
	guidance.advance_guidance(30.0)
	if not check(guidance.current_text.is_empty(), "Disabling automatic help suppresses thoughts"): return
	guidance.repeat_current()
	if not check(guidance.current_text.contains("read it"), "Manual help remains available when automatic help disabled"): return
	guidance.set_context(&"route", false)
	guidance.set_context(&"filing", false)
	guidance.repeat_current()
	if not check(guidance.current_text.contains("table by the stove") and not guidance.current_text.contains("wall board"), "Rapid progress never queues stale instructions"): return
	guidance.set_context(&"filing", false)
	guidance.advance_guidance(0.1)
	if not check(not guidance.current_text.is_empty(), "Repeated context does not restart or erase manual thought"): return
	guidance.advance_guidance(8.0)
	if not check(guidance.current_text.is_empty(), "Thought expires without typewriter or queue"): return
	guidance.set_context(&"route", false)
	guidance.repeat_current()
	var visible_reminder: String = guidance.current_text
	var hidden_a := WorldStateStore.new()
	var hidden_b := WorldStateStore.new()
	hidden_a.set_fact(&"freight_held_correctly", true)
	hidden_b.set_fact(&"freight_cleared_in_error", true)
	guidance.repeat_current()
	if not check(guidance.current_text == visible_reminder, "Hidden route correctness cannot change procedural thought"): return
	hidden_a.free()
	hidden_b.free()
	guidance.set_context(&"", false)
	guidance.repeat_current()
	if not check(guidance.current_text.is_empty(), "Unknown or completed steps do not retain a stale reminder"): return
	# Plan 6.6: a night speaks few lines, each naming the next action, one
	# short sentence or two. Manual help and the winding reminder do not count.
	var night_lines := 0
	for entry in guidance.data.entries:
		var text: String = entry.get("text", "")
		if entry.get("automatic", true) and entry.get("id", &"") != &"wind":
			night_lines += 1
		if not check(text.split(". ").size() <= 2 and text.length() <= 60, "Thought '%s' is one or two short sentences" % entry.get("id", &"")): return
	if not check(night_lines <= 6, "A night speaks at most six procedural lines (%d)" % night_lines): return
	guidance.free()
	quit(0)
