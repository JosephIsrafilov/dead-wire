extends SceneTree
## Contract tests for the FORM 19 live 3D title screen, PSX backdrop,
## 3-tab period ledger options, and quick RU/EN switcher.
##   godot --headless --audio-driver Dummy --path . --script tests/ui/title_mood_test.gd

var _assertions: int = 0
var _tmp_settings: String = ""

func _init() -> void:
	call_deferred("_run")

func _cleanup() -> void:
	if not _tmp_settings.is_empty():
		var abs_path := ProjectSettings.globalize_path(_tmp_settings)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)
	OS.set_environment(GameSettings.PATH_OVERRIDE_ENV, "")
	GameLocale.reload()

func _run() -> void:
	_tmp_settings = "user://title_mood_test_settings.cfg"
	OS.set_environment(GameSettings.PATH_OVERRIDE_ENV, _tmp_settings)
	GameLocale.reload()

	print("--- Starting Title Mood Test Suite (FORM 19) ---")
	if not _a(MainMenu.WINDOW_TITLE == "FORM 19", "Window title is rebranded to FORM 19"): return

	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	var cal := menu.get_node_or_null("BrightnessCalibration")
	if cal != null:
		cal.queue_free()
		await process_frame

	var title_lbl := menu.get_node_or_null("CenterContainer/VBoxContainer/TitleLabel") as Label
	if not _a(title_lbl != null and title_lbl.text == "FORM 19", "Main menu displays FORM 19 title"): return

	var mood := menu.get_mood()
	if not _a(mood != null and mood.get_backdrop() != null, "Live 3D diorama texture backs the title"): return
	if not _a(mood.get_index() < menu.get_node("CenterContainer").get_index(), "The diorama sits behind the menu"): return
	if not _a(mood.mouse_filter == Control.MOUSE_FILTER_IGNORE, "TitleMood never blocks menu clicks"): return

	var backdrop := mood.get_backdrop_3d()
	if not _a(backdrop != null and backdrop.get_node_or_null("DeskLampLight") != null,
		"Live TitleBackdrop3D owns DeskLampLight and station geometry"): return
	var lamp := backdrop.get_node("DeskLampLight") as OmniLight3D
	var initial_energy := lamp.light_energy
	mood.advance_mood(0.35)
	if not _a(not is_equal_approx(lamp.light_energy, initial_energy),
		"Live kerosene lamp flickers continuously in TitleBackdrop3D"): return

	var column := menu.get_node("CenterContainer") as Control
	if not _a(is_equal_approx(column.anchor_left, 0.5), "The menu sits over the shadowed right half"): return

	var styled := menu.begin_button.get_theme_stylebox("normal") as StyleBoxFlat
	if not _a(styled != null and styled.border_width_bottom == 1, "Menu buttons use period hairline styling"): return

	menu.options_button.pressed.emit()
	await process_frame
	if not _a(menu.options_panel.visible, "Options ledger opens from the title"): return
	if not _a(menu.get_active_options_tab() == "game", "Options open on the Game tab by default"): return
	if not _a(menu.sensitivity_slider.is_visible_in_tree() and not menu.music_slider.is_visible_in_tree(),
		"Game tab shows gameplay rows and hides audio sliders"): return

	menu.select_options_tab("audio", false)
	await process_frame
	if not _a(menu.music_slider.is_visible_in_tree() and not menu.sensitivity_slider.is_visible_in_tree(),
		"Audio tab exposes music/bus sliders cleanly"): return

	menu.select_options_tab("display", false)
	await process_frame
	var read := menu.get_node_or_null("CenterContainer/VBoxContainer/OptionsPanel/OptionsBox/ReadabilityOptions") as Control
	if not _a(read != null and read.visible and not menu.music_slider.is_visible_in_tree(),
		"Display tab exposes ReadabilityOptions cleanly"): return

	var en_btn := menu.get_node_or_null("LocaleBar/EnButton") as Button
	var ru_btn := menu.get_node_or_null("LocaleBar/RuButton") as Button
	if not _a(en_btn != null and ru_btn != null, "Quick RU | EN switcher exists on the title"): return
	en_btn.pressed.emit()
	await process_frame
	if not _a(menu.begin_button.text == "Begin the Watch", "Clicking EN switches main menu live to English"): return
	ru_btn.pressed.emit()
	await process_frame
	if not _a(menu.begin_button.text == "Начать смену", "Clicking RU switches main menu live back to Russian"): return

	menu.queue_free()
	await process_frame
	_cleanup()
	print("--- All Title Mood Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	_cleanup()
	printerr("  FAIL: ", description)
	quit(1)
	return false
