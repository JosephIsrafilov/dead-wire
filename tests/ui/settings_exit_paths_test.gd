extends SceneTree

## Every menu exit must save the latest preferences, not a stale in-memory copy.
## Runs only through tools/with_preserved_settings.py, which restores the owner's file.

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, text: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok:
		failures += 1

func chosen_survives() -> bool:
	var settings: Variant = GameSettings.load_settings()
	return settings.presentation_mode == 2 and is_equal_approx(settings.vertical_fov, 70.0) \
		and is_equal_approx(settings.text_scale, 1.4)

func _run() -> void:
	var menu: Variant = MainMenu.new()
	var pause_menu := PauseMenu.new()
	if not menu.has_method("save_preferences"):
		print("  FAIL: Every menu exit reloads the latest preferences")
		menu.free()
		pause_menu.free()
		quit(1)
		return

	var original := GameSettings.new()
	original.save()
	menu.settings = GameSettings.load_settings()
	pause_menu.settings = GameSettings.load_settings()
	var fresh: Variant = GameSettings.load_settings()
	fresh.presentation_mode = 2
	fresh.vertical_fov = 70.0
	fresh.text_scale = 1.4
	fresh.save()
	menu._on_sensitivity_changed(4.0)
	check(chosen_survives(), "Sensitivity change preserves graphics and reading choice")
	menu._on_head_bob_toggled(false)
	check(chosen_survives(), "Head bob change preserves graphics and reading choice")
	menu.quit_game()
	check(chosen_survives(), "Title Quit does not save stale preferences")
	menu.begin_watch()
	check(chosen_survives(), "Begin Watch preserves the latest preferences")
	pause_menu._on_master_changed(-7.0)
	check(chosen_survives(), "Pause volume change preserves the reading choice")
	pause_menu.is_paused = true
	pause_menu.resume()
	check(chosen_survives(), "Resume preserves all three new choices")
	pause_menu.return_to_title()
	check(chosen_survives(), "Leave Post preserves all three new choices")
	pause_menu._on_quit()
	check(chosen_survives(), "Pause Quit preserves all three new choices")
	menu.free()
	pause_menu.free()
	quit(1 if failures else 0)
