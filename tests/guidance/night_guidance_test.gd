extends SceneTree

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var guide := NightGuidanceController.new()
	for locale in ["ru", "en"]:
		GameLocale.lock_language_for_test(locale)
		guide.set_context(&"", false)
		guide._shown.clear()
		guide.set_context(&"entry", false)
		guide.advance_guidance(1.0)
		_check(guide.current_text.contains(GameLocale.pick("с азов", "from the basics")),
			"Entry explains starting from the basics in " + locale)
		for phase in [&"open_line", &"answer", &"read_copy", &"route", &"filing"]:
			guide.set_context(phase, false)
			_check(guide.current_text.is_empty(), "Changing the task clears the prior thought")
			guide.advance_guidance(0.8)
			var entry := guide.data.entry_for(phase)
			_check(guide.current_text == GameLocale.pick(entry.text_ru, entry.text),
				"First-slot instruction arrives without the general cooldown: " + String(phase))
		guide.set_context(&"answer_late", false)
		guide.advance_guidance(6.5)
		guide.repeat_current()
		_check(guide.current_text.is_empty(), "A second call stays quiet during the first seconds")
		guide.advance_guidance(0.6)
		_check(not guide.current_text.is_empty(), "A delayed second call gives a single nudge")
		guide.advance_guidance(6.0)
		_check(guide.current_text.is_empty(), "The second call nudge expires and does not repeat")
		guide.set_context(&"compare", false)
		guide.advance_guidance(1.0)
		_check(not guide.current_text.is_empty() and not guide.current_text.contains("WATCHER")
			and not guide.current_text.contains("WATER"), "Third-slot thought names tools and keeps the wire private")
	guide.set_context(&"read_copy", true)
	guide.repeat_current()
	_check(guide.current_text.is_empty(), "Manual guidance cannot speak during protected work")
	guide.enabled = false
	guide.set_context(&"route", false)
	guide.advance_guidance(12.0)
	_check(guide.current_text.is_empty(), "Disabling automatic guidance stops the next thought")
	guide.repeat_current()
	_check(guide.current_text.contains("[A]"), "Manual guidance still names the next action")
	guide.set_context(&"filing", false)
	guide.repeat_current()
	_check(guide.current_text.contains("[D]") and not guide.current_text.contains("[A]"),
		"Rapid progress replaces stale directions")
	guide.advance_guidance(8.0)
	_check(guide.current_text.is_empty(), "Thought expires after its hold time")
	for entry in guide.data.entries:
		_check(not String(entry.text).is_empty() and not String(entry.text_ru).is_empty(),
			"English and Russian strings exist for " + str(entry.id))
	GameLocale.clear_test_override()
	guide.free()
	quit(int(_failed))

func _check(ok: bool, description: String) -> void:
	_failed = _failed or not ok
	print("  %s: %s" % ["PASS" if ok else "FAIL", description])
