extends SceneTree
## Protects the RU/EN localization contract, Cyrillic font safety, and anti-slop
## / spoiler-free HUD invariants from Phase 1.
##   godot --headless --audio-driver Dummy --path . --script tests/ui/localization_test.gd

var _tmp_settings: String = ""

func _init() -> void:
	call_deferred("_run")

func assert_condition(ok: bool, desc: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + desc)
	if not ok:
		_cleanup()
		quit(1)
	return ok

func _cleanup() -> void:
	if not _tmp_settings.is_empty():
		var abs_path := ProjectSettings.globalize_path(_tmp_settings)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)
	OS.set_environment(GameSettings.PATH_OVERRIDE_ENV, "")
	GameLocale.reload()

func _run() -> void:
	_tmp_settings = "user://localization_test_settings.cfg"
	OS.set_environment(GameSettings.PATH_OVERRIDE_ENV, _tmp_settings)
	var abs_path := ProjectSettings.globalize_path(_tmp_settings)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)
	GameLocale.reload()

	print("--- Starting Localization & Anti-Slop Test Suite ---")

	# 1. GameSettings default language & sanitization
	var defaults := GameSettings.load_settings()
	if not assert_condition(defaults.language == "ru", "GameSettings defaults language to 'ru'"):
		return
	defaults.language = "en"
	defaults.save()
	var reloaded := GameSettings.load_settings()
	if not assert_condition(reloaded.language == "en", "GameSettings saves and loads 'en'"):
		return
	reloaded.language = "fr_invalid"
	reloaded.sanitize()
	if not assert_condition(reloaded.language == "ru", "GameSettings sanitizes invalid language to 'ru'"):
		return
	reloaded.language = "ru"
	reloaded.save()

	# 2. GameLocale.pick follows set_language
	GameLocale.set_language("ru")
	if not assert_condition(GameLocale.pick("Русский", "English") == "Русский", "GameLocale.pick returns Russian in 'ru'"):
		return
	GameLocale.set_language("en")
	if not assert_condition(GameLocale.pick("Русский", "English") == "English", "GameLocale.pick returns English in 'en'"):
		return
	GameLocale.set_language("ru")

	# 3. MainMenu Russian default + live switch to English
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	var cal := menu.get_node_or_null("BrightnessCalibration")
	if cal != null:
		cal.queue_free()
		await process_frame
	if not assert_condition(
		menu.begin_button.text == "Начать смену"
		and menu.options_button.text == "Настройки"
		and menu.quit_button.text == "Выход",
		"MainMenu renders Russian buttons by default"
	):
		return
	var opt_box := menu.get_node_or_null("CenterContainer/VBoxContainer/OptionsPanel/OptionsBox/ReadabilityOptions") as ReadabilityOptions
	if not assert_condition(opt_box != null and opt_box.has_method("select_language_code"), "ReadabilityOptions exposes language selector"):
		return
	opt_box.select_language_code("en")
	await process_frame
	if not assert_condition(
		menu.begin_button.text == "Begin the Watch"
		and menu.options_button.text == "Options"
		and menu.quit_button.text == "Quit",
		"MainMenu switches live to English when language changes"
	):
		return
	opt_box.select_language_code("ru")
	await process_frame
	menu.queue_free()
	await process_frame

	# 4. IntroCard RU and EN
	GameLocale.set_language("ru")
	var intro_ru := load("res://scenes/ui/intro_card.tscn").instantiate() as IntroCard
	root.add_child(intro_ru)
	await process_frame
	var place_ru: String = (intro_ru.get_node("CenterContainer/VBoxContainer/PlaceLabel") as Label).text
	var order_ru: String = (intro_ru.get_node("CenterContainer/VBoxContainer/OrderLabel") as RichTextLabel).text
	if not assert_condition(place_ru.contains("БЛЭК-КРИК") and order_ru.contains("ПРИКАЗ"), "IntroCard renders Russian text in 'ru'"):
		return
	intro_ru.queue_free()
	await process_frame

	GameLocale.set_language("en")
	var intro_en := load("res://scenes/ui/intro_card.tscn").instantiate() as IntroCard
	root.add_child(intro_en)
	await process_frame
	var place_en: String = (intro_en.get_node("CenterContainer/VBoxContainer/PlaceLabel") as Label).text
	var order_en: String = (intro_en.get_node("CenterContainer/VBoxContainer/OrderLabel") as RichTextLabel).text
	if not assert_condition(place_en.contains("BLACK CREEK") and order_en.contains("ORDER 41"), "IntroCard renders English text in 'en'"):
		return
	intro_en.queue_free()
	await process_frame
	GameLocale.set_language("ru")

	# 5 & 6 & 7 & 8. Office scene checks: anti-slop, no hook spoiler, Cyrillic fonts, Murmur gloss
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null:
		intro.skip_immediately()
	await process_frame

	# DutySheet has no outdated room directions
	var duty := office.get_node("DutySheet") as DutySheet
	var duty_text := duty.get_sheet_text()
	if not assert_condition(
		not duty_text.contains("east wall") and not duty_text.contains("table by the stove")
		and not duty_text.contains("восточной стене") and not duty_text.contains("у печки"),
		"DutySheet contains no outdated room directions"
	):
		return

	# Cyrillic font safety on SoundCaptions, MurmurCaption, ServiceShutterEvent, DocumentViewer
	var sc := office.get_node("SoundCaptions") as SoundCaptions
	var sc_label := sc.get_child(0) as Label
	var sc_font: Font = sc_label.get_theme_font("font")
	if not assert_condition(sc_font != null and sc_font.resource_path.contains("OldStandardTT"), "SoundCaptions uses Cyrillic-capable OldStandardTT font"):
		return

	var murmur := office.get_node("MurmurCaption") as MurmurCaption
	var m_label := murmur.get_child(0) as RichTextLabel
	var m_font: Font = m_label.get_theme_font("normal_font")
	if not assert_condition(m_font != null and m_font.resource_path.contains("OldStandardTT"), "MurmurCaption uses Cyrillic-capable OldStandardTT font"):
		return

	var shutter := office.get_node("ServiceShutterEvent") as ServiceShutterEvent
	var b_label := shutter.get_node("DoorVoiceLayer/DoorVoiceBanner").get_child(0) as Label
	var b_font: Font = b_label.get_theme_font("font")
	if not assert_condition(b_font != null and b_font.resource_path.contains("OldStandardTT"), "ServiceShutterEvent voice banner uses OldStandardTT font"):
		return

	var timetable := office.get_node("TimetableCard") as TimetableCard
	timetable.get_interactable().interact()
	await process_frame
	var viewer := office.document_viewer
	var doc_font: Font = viewer.body_label.get_theme_font("normal_font")
	if not assert_condition(doc_font != null and doc_font.resource_path.contains("OldStandardTT"), "DocumentViewer uses OldStandardTT on timetable_card in RU"):
		return
	viewer.close_document()
	await process_frame

	# Anti-slop / Spoiler-free DutyStrip on core_hook_water_watcher
	office.load_scenario_by_index(2)
	var session := office.session_controller
	var scen3 := session.get_current_scenario()
	session.start_transmission()
	session.scheduler.advance_time(60.0)
	var paper := session.transcript_paper
	paper.advance_paper(60.0)
	paper._on_interacted()
	await process_frame
	if viewer.is_open():
		viewer.close_document()
	await process_frame
	var station := office.get_node("SeatedStationController") as SeatedStationController
	var texts: Dictionary = station._duty_texts()
	var combined := ("%s %s" % [texts.get("primary", ""), texts.get("sub", "")]).to_upper()
	if not assert_condition(
		not combined.contains("DIFFERENT")
		and not combined.contains("ДРУГОЕ")
		and not combined.contains("WATCHER")
		and not combined.contains("WATER")
		and not combined.contains("ВОДА")
		and not combined.contains("СМОТРЯЩИЙ")
		and not combined.contains("НАБЛЮДАТЕЛЬ"),
		"DutyStrip during core_hook_water_watcher contains zero hook spoilers"
	):
		return

	# MurmurCaption in RU shows Russian gloss for MJ WATER without leaking WATCHER
	murmur._on_transmission_started(scen3)
	for g in scen3.transmission_data.elias_perception.replace(" ", "").length():
		murmur._on_perception_glyph(scen3.scenario_id, g, "")
	murmur._on_transmission_finished(scen3)
	await process_frame
	var m_full := m_label.get_parsed_text()
	if not assert_condition(
		m_full.contains("ВОДА") and not m_full.to_upper().contains("WATCHER") and not m_full.to_upper().contains("СМОТРЯЩИЙ"),
		"MurmurCaption in RU shows Russian meaning gloss ('ВОДА') without leaking WATCHER"
	):
		return

	office.queue_free()
	await process_frame
	_cleanup()
	print("--- Localization & Anti-Slop Test Suite PASSED ---")
	quit(0)
