class_name MainMenu
extends Control

## Title screen for FORM 19, and the only place a watch is actually started.
##
## WorldState and KnowledgeState are autoloads and outlive a scene change. Every
## route into a new watch goes through `begin_watch()` so state clears cleanly.

signal watch_started()

const OFFICE_SCENE: String = "res://scenes/office/m1_office.tscn"
const WINDOW_TITLE: String = "FORM 19"

const SFX_KEY_CLICK := preload("res://audio/sfx/foley/key_click.wav")
const SFX_PAPER_TURN := preload("res://audio/sfx/foley/paper_turn.wav")
const SFX_SOUNDER_DOWN := preload("res://audio/sfx/telegraph/sounder_down.wav")
const SFX_SOUNDER_UP := preload("res://audio/sfx/telegraph/sounder_up.wav")
const SFX_WIND := preload("res://audio/sfx/ambience/wind_window.wav")
const SFX_ROOM_TONE := preload("res://audio/sfx/ambience/room_tone.wav")
const MUSIC_DRONE := preload("res://audio/music/menu_dread_ambient.wav")

@export var office_scene_path: String = OFFICE_SCENE

var settings: GameSettings = null

var continue_button: Button = null
var begin_button: Button = null
var options_panel: Control = null
var options_button: Button = null
var quit_button: Button = null
var sensitivity_slider: HSlider = null
var head_bob_check: CheckButton = null
var master_slider: HSlider = null
var ambience_slider: HSlider = null
var telegraph_slider: HSlider = null
var foley_slider: HSlider = null
var music_slider: HSlider = null
var contextual_thoughts_check: CheckButton = null
var build_footer: Label = null

var _tab_game: Button = null
var _tab_audio: Button = null
var _tab_display: Button = null
var _ru_button: Button = null
var _en_button: Button = null
var _active_tab: String = "game"
var _is_starting: bool = false

var _ui_fx_player: AudioStreamPlayer = null
var _wire_pulse_player: AudioStreamPlayer = null
var _wind_player: AudioStreamPlayer = null
var _room_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null

func _ready() -> void:
	_find_nodes()
	get_window().title = WINDOW_TITLE
	settings = GameSettings.load_settings()
	settings.apply(null)
	_push_settings_to_controls()
	_connect_controls()
	_setup_continue_button()
	_build_mood()
	_setup_audio()
	_apply_period_styles()
	select_options_tab("game", false)
	refresh_locale()
	if build_footer != null:
		build_footer.visible = OS.is_debug_build()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if options_panel != null:
		options_panel.visible = false
	if continue_button != null:
		continue_button.grab_focus()
	elif begin_button != null:
		begin_button.grab_focus()
	if BrightnessCalibration.needed():
		var calibration := BrightnessCalibration.new()
		calibration.name = "BrightnessCalibration"
		add_child(calibration)
		calibration.tree_exited.connect(func() -> void:
			if is_instance_valid(begin_button) and begin_button.is_inside_tree():
				begin_button.grab_focus())

func _find_nodes() -> void:
	var box := "CenterContainer/VBoxContainer/"
	build_footer = get_node_or_null(box + "FooterLabel") as Label
	begin_button = get_node_or_null(box + "BeginButton") as Button
	options_button = get_node_or_null(box + "OptionsButton") as Button
	quit_button = get_node_or_null(box + "QuitButton") as Button
	options_panel = get_node_or_null(box + "OptionsPanel") as Control

	var options := box + "OptionsPanel/OptionsBox/"
	_tab_game = get_node_or_null(options + "TabBarRow/TabGame") as Button
	_tab_audio = get_node_or_null(options + "TabBarRow/TabAudio") as Button
	_tab_display = get_node_or_null(options + "TabBarRow/TabDisplay") as Button
	sensitivity_slider = get_node_or_null(options + "SensitivityRow/SensitivitySlider") as HSlider
	head_bob_check = get_node_or_null(options + "HeadBobCheck") as CheckButton
	master_slider = get_node_or_null(options + "MasterRow/MasterSlider") as HSlider
	ambience_slider = get_node_or_null(options + "AmbienceRow/AmbienceSlider") as HSlider
	telegraph_slider = get_node_or_null(options + "TelegraphRow/TelegraphSlider") as HSlider
	foley_slider = get_node_or_null(options + "FoleyRow/FoleySlider") as HSlider
	music_slider = get_node_or_null(options + "MusicRow/MusicSlider") as HSlider
	contextual_thoughts_check = get_node_or_null(options + "ContextualThoughtsCheck") as CheckButton

	_ru_button = get_node_or_null("LocaleBar/RuButton") as Button
	_en_button = get_node_or_null("LocaleBar/EnButton") as Button

func _push_settings_to_controls() -> void:
	if settings == null:
		return
	if sensitivity_slider != null:
		sensitivity_slider.set_value_no_signal(settings.mouse_sensitivity * 1000.0)
	if head_bob_check != null:
		head_bob_check.set_pressed_no_signal(settings.head_bob_enabled)
	if master_slider != null:
		master_slider.set_value_no_signal(settings.master_volume_db)
	if ambience_slider != null:
		ambience_slider.set_value_no_signal(settings.ambience_volume_db)
	if telegraph_slider != null:
		telegraph_slider.set_value_no_signal(settings.telegraph_volume_db)
	if foley_slider != null:
		foley_slider.set_value_no_signal(settings.foley_volume_db)
	if music_slider != null:
		music_slider.set_value_no_signal(settings.music_volume_db)
	if contextual_thoughts_check != null:
		contextual_thoughts_check.set_pressed_no_signal(settings.contextual_thoughts_enabled)

func _connect_controls() -> void:
	ReadabilityOptions.attach_readout(sensitivity_slider, "%.1f")
	for slider in [master_slider, ambience_slider, telegraph_slider, foley_slider, music_slider]:
		ReadabilityOptions.attach_readout(slider, "%d dB")
	if begin_button != null and not begin_button.pressed.is_connected(_on_begin_pressed):
		begin_button.pressed.connect(_on_begin_pressed)
	if options_button != null and not options_button.pressed.is_connected(toggle_options):
		options_button.pressed.connect(toggle_options)
	if quit_button != null and not quit_button.pressed.is_connected(quit_game):
		quit_button.pressed.connect(quit_game)

	if _tab_game != null:
		_tab_game.pressed.connect(select_options_tab.bind("game", true))
	if _tab_audio != null:
		_tab_audio.pressed.connect(select_options_tab.bind("audio", true))
	if _tab_display != null:
		_tab_display.pressed.connect(select_options_tab.bind("display", true))
	if _ru_button != null:
		_ru_button.pressed.connect(_on_locale_pill_pressed.bind(GameLocale.LANG_RU))
	if _en_button != null:
		_en_button.pressed.connect(_on_locale_pill_pressed.bind(GameLocale.LANG_EN))

	for btn in [begin_button, options_button, quit_button]:
		if btn != null:
			btn.mouse_entered.connect(_play_ui_fx.bind(SFX_KEY_CLICK, -18.0))

	if sensitivity_slider != null:
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	if head_bob_check != null:
		head_bob_check.toggled.connect(_on_head_bob_toggled)
	if master_slider != null:
		master_slider.value_changed.connect(_on_master_changed)
	if ambience_slider != null:
		ambience_slider.value_changed.connect(_on_ambience_changed)
	if telegraph_slider != null:
		telegraph_slider.value_changed.connect(_on_telegraph_changed)
	if foley_slider != null:
		foley_slider.value_changed.connect(_on_foley_changed)
	if music_slider != null:
		music_slider.value_changed.connect(_on_music_changed)
	if contextual_thoughts_check != null:
		contextual_thoughts_check.toggled.connect(_on_contextual_thoughts_toggled)

func refresh_locale() -> void:
	var box := "CenterContainer/VBoxContainer/"
	var dept := get_node_or_null(box + "DeptStampLabel") as Label
	if dept != null:
		dept.text = GameLocale.pick(
			"ЖЕЛ. ДОР. БЛЭК-КРИК  ·  ТЕЛЕГРАФНАЯ СТАНЦИЯ",
			"B.C. & W. R.R.  ·  TELEGRAPH DEPT."
		)
	var station := get_node_or_null(box + "StationLabel") as Label
	if station != null:
		station.text = GameLocale.pick(
			"РАЗЪЕЗД БЛЭК-КРИК  ·  АПРЕЛЬ 1890 ГОДА",
			"BLACK CREEK STATION  ·  APRIL 1890"
		)
	var corner_stamp := get_node_or_null("CornerStamp") as Label
	if corner_stamp != null:
		corner_stamp.text = GameLocale.pick(
			"БЛЭК-КРИК, КОЛОРАДО  ·  ФОРМА № 19",
			"BLACK CREEK, COLORADO  ·  FORM NO. 19"
		)
	if begin_button != null:
		begin_button.text = GameLocale.pick("Начать смену", "Begin the Watch")
	if continue_button != null:
		continue_button.text = GameLocale.pick("Продолжить путь (Блэк-Крик)", "Continue (Black Creek)")
	if options_button != null:
		options_button.text = GameLocale.pick("Настройки", "Options")
	if quit_button != null:
		quit_button.text = GameLocale.pick("Выход", "Quit")
	if build_footer != null:
		build_footer.text = GameLocale.pick("Сборка смены M1", "M1 watch build")
	if _tab_game != null:
		_tab_game.text = GameLocale.pick("Игра", "Game")
	if _tab_audio != null:
		_tab_audio.text = GameLocale.pick("Звук", "Audio")
	if _tab_display != null:
		_tab_display.text = GameLocale.pick("Экран", "Display")

	var options := box + "OptionsPanel/OptionsBox/"
	var row_labels := {
		"SensitivityRow/Label": ["Чувствительность мыши", "Mouse sensitivity"],
		"MasterRow/Label": ["Общая громкость", "Master volume"],
		"AmbienceRow/Label": ["Шум комнаты", "Room ambience"],
		"TelegraphRow/Label": ["Телеграф", "Telegraph"],
		"FoleyRow/Label": ["Звуки предметов", "Foley"],
		"MusicRow/Label": ["Музыка", "Music"],
	}
	for path in row_labels:
		var lbl := get_node_or_null(options + path) as Label
		if lbl != null:
			var pair: Array = row_labels[path]
			lbl.text = GameLocale.pick(pair[0], pair[1])
	if head_bob_check != null:
		head_bob_check.text = GameLocale.pick("Покачивание головы", "Head movement while walking")
	if contextual_thoughts_check != null:
		contextual_thoughts_check.text = GameLocale.pick("Мысли оператора", "Contextual thoughts")
	_refresh_locale_pills()

func _build_mood() -> void:
	if get_node_or_null("TitleMood") != null:
		return
	var mood := TitleMood.new()
	mood.name = "TitleMood"
	add_child(mood)
	move_child(mood, mini(1, get_child_count() - 1))
	mood.sounder_pulse.connect(_play_background_wire_pulse)

func _apply_period_styles() -> void:
	PeriodUIStyle.style_menu_button(continue_button, true)
	PeriodUIStyle.style_menu_button(begin_button, continue_button == null)
	PeriodUIStyle.style_menu_button(options_button, false)
	PeriodUIStyle.style_menu_button(quit_button, false)
	PeriodUIStyle.style_options_ledger(options_panel as PanelContainer)
	if options_panel != null:
		PeriodUIStyle.style_controls_recursive(options_panel)
		options_panel.custom_minimum_size.y = 0.0
	_refresh_tab_styles()
	_refresh_locale_pills()

func _refresh_tab_styles() -> void:
	PeriodUIStyle.style_tab_button(_tab_game, _active_tab == "game")
	PeriodUIStyle.style_tab_button(_tab_audio, _active_tab == "audio")
	PeriodUIStyle.style_tab_button(_tab_display, _active_tab == "display")

func _refresh_locale_pills() -> void:
	var is_ru := GameLocale.is_ru()
	PeriodUIStyle.style_locale_pill(_ru_button, is_ru)
	PeriodUIStyle.style_locale_pill(_en_button, not is_ru)

func select_options_tab(tab_id: String, with_sound: bool = true) -> void:
	_active_tab = tab_id
	var options := "CenterContainer/VBoxContainer/OptionsPanel/OptionsBox/"
	var game_nodes := [
		get_node_or_null(options + "SensitivityRow"),
		head_bob_check,
		contextual_thoughts_check,
	]
	var audio_nodes := [
		get_node_or_null(options + "MasterRow"),
		get_node_or_null(options + "AmbienceRow"),
		get_node_or_null(options + "TelegraphRow"),
		get_node_or_null(options + "FoleyRow"),
		get_node_or_null(options + "MusicRow"),
	]
	for node in game_nodes:
		if node is Control:
			(node as Control).visible = (tab_id == "game")
	for node in audio_nodes:
		if node is Control:
			(node as Control).visible = (tab_id == "audio")
	var read := get_node_or_null(options + "ReadabilityOptions") as ReadabilityOptions
	if read != null:
		read.apply_tab_filter(tab_id)
	_refresh_tab_styles()
	if with_sound:
		_play_ui_fx(SFX_PAPER_TURN, -14.0)

func _on_locale_pill_pressed(code: String) -> void:
	var read := get_node_or_null(
		"CenterContainer/VBoxContainer/OptionsPanel/OptionsBox/ReadabilityOptions"
	) as ReadabilityOptions
	if read != null:
		read.select_language_code(code)
	else:
		var s := GameSettings.load_settings()
		s.language = code
		s.save()
		GameLocale.set_language(code)
		refresh_locale()
	_play_ui_fx(SFX_KEY_CLICK, -16.0)

func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_ui_fx_player = AudioStreamPlayer.new()
	_ui_fx_player.bus = &"Foley" if AudioServer.get_bus_index(&"Foley") >= 0 else &"Master"
	add_child(_ui_fx_player)

	_wire_pulse_player = AudioStreamPlayer.new()
	_wire_pulse_player.bus = &"Telegraph" if AudioServer.get_bus_index(&"Telegraph") >= 0 else &"Master"
	add_child(_wire_pulse_player)

	_wind_player = _make_loop_player(SFX_WIND, &"Ambience", -27.0)
	_room_player = _make_loop_player(SFX_ROOM_TONE, &"Ambience", -31.0)
	_music_player = _make_loop_player(MUSIC_DRONE, &"Music", -34.0)
	if _music_player != null:
		create_tween().tween_property(_music_player, "volume_db", -9.0, 2.8).set_trans(Tween.TRANS_SINE)

func _make_loop_player(stream: AudioStream, bus_name: StringName, db: float) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus_name if AudioServer.get_bus_index(bus_name) >= 0 else &"Master"
	player.volume_db = db
	player.finished.connect(player.play)
	add_child(player)
	player.play()
	return player

func _play_ui_fx(stream: AudioStream, db: float) -> void:
	if _ui_fx_player == null or stream == null:
		return
	_ui_fx_player.stream = stream
	_ui_fx_player.volume_db = db
	_ui_fx_player.play()

func _play_background_wire_pulse() -> void:
	if _wire_pulse_player == null or not is_inside_tree():
		return
	_wire_pulse_player.volume_db = -21.0
	_wire_pulse_player.stream = SFX_SOUNDER_DOWN
	_wire_pulse_player.play()
	await get_tree().create_timer(0.14).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_wire_pulse_player.stream = SFX_SOUNDER_UP
	_wire_pulse_player.play()
	await get_tree().create_timer(0.24).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_wire_pulse_player.stream = SFX_SOUNDER_DOWN
	_wire_pulse_player.play()

func get_mood() -> TitleMood:
	return get_node_or_null("TitleMood") as TitleMood

func get_active_options_tab() -> String:
	return _active_tab

func toggle_options() -> void:
	if options_panel == null:
		return
	options_panel.visible = not options_panel.visible
	var spacer := get_node_or_null("CenterContainer/VBoxContainer/Spacer") as Control
	if spacer != null:
		spacer.custom_minimum_size.y = 4.0 if options_panel.visible else 18.0
	var mood := get_mood()
	if mood != null:
		mood.set_options_open(options_panel.visible)
	if options_panel.visible:
		select_options_tab(_active_tab, false)
		var readability := options_panel.get_node_or_null("OptionsBox/ReadabilityOptions")
		if readability != null and readability.has_method("refresh"):
			readability.refresh()
	_play_ui_fx(SFX_PAPER_TURN, -14.0)

func open_options() -> void:
	if options_panel != null and not options_panel.visible:
		toggle_options()

func _setup_continue_button() -> void:
	if not CampaignStateStore.has_saved_campaign():
		return
	var box := get_node_or_null("CenterContainer/VBoxContainer") as VBoxContainer
	if box == null or begin_button == null:
		return
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.custom_minimum_size = begin_button.custom_minimum_size
	continue_button.add_theme_font_size_override("font_size", 18)
	continue_button.pressed.connect(continue_campaign)
	continue_button.mouse_entered.connect(_play_ui_fx.bind(SFX_KEY_CLICK, -18.0))
	box.add_child(continue_button)
	box.move_child(continue_button, begin_button.get_index())

func continue_campaign() -> bool:
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false
	var world := tree.root.get_node_or_null("WorldState") as WorldStateStore
	var knowledge := tree.root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	var campaign := tree.root.get_node_or_null("CampaignState") as CampaignStateStore
	if campaign == null or not campaign.load_from_disk(world, knowledge):
		return false
	save_preferences()
	tree.paused = false
	var target := "res://scenes/town/black_creek_exterior.tscn"
	if campaign.phase == CampaignStateStore.PHASE_NIGHT:
		target = office_scene_path
	return SceneTransitionManager.go(tree, target)

func _on_begin_pressed() -> void:
	if _is_starting:
		return
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		begin_watch()
		return
	_is_starting = true
	if begin_button != null:
		begin_button.disabled = true
	_play_ui_fx(SFX_SOUNDER_DOWN, -11.0)
	var mood := get_mood()
	if mood != null:
		mood.play_enter_transition(0.36)
	var timer := get_tree().create_timer(0.36)
	timer.timeout.connect(begin_night_approach, CONNECT_ONE_SHOT)

## Starts a new watch via the foggy night approach outside Black Creek Depot.
func begin_night_approach() -> bool:
	clear_state()
	DispatchLedger.reset_watch_count()
	PlaytestTelemetry.arm()
	save_preferences()
	watch_started.emit()

	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false
	var campaign := tree.root.get_node_or_null("CampaignState") as CampaignStateStore
	if campaign != null:
		campaign.phase = CampaignStateStore.PHASE_NIGHT_APPROACH
		campaign.pending_spawn_point = &"night_arrival"
	tree.paused = false
	return SceneTransitionManager.go(tree, "res://scenes/town/black_creek_exterior.tscn")

## Clears all state stores and opens the office. Everything that starts a watch
## synchronously must come through here.
func begin_watch() -> bool:
	clear_state()
	DispatchLedger.reset_watch_count()
	PlaytestTelemetry.arm()
	save_preferences()
	watch_started.emit()

	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	tree.paused = false
	return SceneTransitionManager.go(tree, office_scene_path)

## Both stores reset independently, exactly as the state contract requires.
static func clear_state() -> void:
	var loop := Engine.get_main_loop()
	var tree := loop as SceneTree
	if tree == null or tree.root == null:
		return
	var world := tree.root.get_node_or_null("WorldState") as WorldStateStore
	if world != null:
		world.reset_for_new_game()
	var knowledge := tree.root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge != null:
		knowledge.reset_for_new_game()
	var campaign := tree.root.get_node_or_null("CampaignState") as CampaignStateStore
	if campaign != null:
		campaign.reset_for_new_game()

func save_preferences() -> Error:
	settings = GameSettings.load_settings()
	return settings.save()

func quit_game() -> void:
	save_preferences()
	if is_inside_tree() and get_tree() != null:
		get_tree().quit()

func _on_sensitivity_changed(value: float) -> void:
	settings = GameSettings.load_settings()
	settings.mouse_sensitivity = maxf(0.0002, value / 1000.0)
	settings.apply(null)
	settings.save()

func _on_head_bob_toggled(pressed: bool) -> void:
	settings = GameSettings.load_settings()
	settings.head_bob_enabled = pressed
	settings.apply(null)
	settings.save()

func _on_master_changed(value: float) -> void:
	settings = GameSettings.load_settings()
	settings.master_volume_db = value
	settings.apply(null)
	settings.save()

func _on_ambience_changed(value: float) -> void:
	settings = GameSettings.load_settings()
	settings.ambience_volume_db = value
	settings.apply(null)
	settings.save()

func _on_telegraph_changed(value: float) -> void:
	settings = GameSettings.load_settings()
	settings.telegraph_volume_db = value
	settings.apply(null)
	settings.save()

func _on_foley_changed(value: float) -> void:
	settings = GameSettings.load_settings()
	settings.foley_volume_db = value
	settings.apply(null)
	settings.save()

func _on_music_changed(value: float) -> void:
	settings = GameSettings.load_settings()
	settings.music_volume_db = value
	settings.apply(null)
	settings.save()

func _on_contextual_thoughts_toggled(pressed: bool) -> void:
	settings = GameSettings.load_settings()
	settings.contextual_thoughts_enabled = pressed
	settings.save()
