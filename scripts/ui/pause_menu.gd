class_name PauseMenu
extends CanvasLayer

## Escape used to do nothing but drop the mouse cursor, leaving the game running
## behind an uncaptured pointer with no way back except clicking. This owns the
## key instead: it stops the shift, shows the options that have to be a player's
## choice rather than a designer's, and writes them to disk.

signal paused()
signal resumed()

const TITLE_SCENE: String = "res://scenes/ui/main_menu.tscn"
const READABILITY_PATH: String = \
	"CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OptionsBox/ReadabilityOptions"
const DEBUG_FOCUS_LOGS: bool = false
const SFX_PAPER_TURN := preload("res://audio/sfx/foley/paper_turn.wav")
const SFX_KEY_CLICK := preload("res://audio/sfx/foley/key_click.wav")

@export var player: PlayerController = null
@export var document_viewer: DocumentViewer = null

var settings: GameSettings = null

var is_paused: bool = false
var _paused_for_focus: bool = false
var _reacquire_on_walk_input: bool = false

var sensitivity_slider: HSlider = null
var head_bob_check: CheckButton = null
var master_slider: HSlider = null
var ambience_slider: HSlider = null
var telegraph_slider: HSlider = null
var foley_slider: HSlider = null
var music_slider: HSlider = null
var contextual_thoughts_check: CheckButton = null
var resume_button: Button = null
var title_button: Button = null
var quit_button: Button = null

var _tab_game: Button = null
var _tab_audio: Button = null
var _tab_display: Button = null
var _ru_button: Button = null
var _en_button: Button = null
var _active_tab: String = "game"
var _ui_fx_player: AudioStreamPlayer = null

const LEAVE_CONFIRM_TEXT := "Leave? The night is lost — press again"
const LEAVE_CONFIRM_MSEC := 4000
var _leave_armed_at: int = -1
var _leave_caption: String = ""

static func _leave_confirm_text() -> String:
	return GameLocale.pick(
		"Выйти? Смена пропадёт — нажмите ещё раз",
		"Leave? The night is lost — press again"
	)

func _enter_tree() -> void:
	_bind_window_focus()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_find_nodes()
	_resolve_targets()

	settings = GameSettings.load_settings()
	settings.apply(player)
	_push_settings_to_controls()
	_connect_controls()
	_bind_window_focus()
	_apply_period_styles()
	select_options_tab("game", false)
	refresh_locale()

func _apply_period_styles() -> void:
	var panel := get_node_or_null("CenterContainer/PanelContainer") as PanelContainer
	PeriodUIStyle.style_options_ledger(panel)
	PeriodUIStyle.style_menu_button(resume_button, true)
	PeriodUIStyle.style_menu_button(title_button, false)
	PeriodUIStyle.style_menu_button(quit_button, false)
	var options := get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OptionsBox")
	if options != null:
		PeriodUIStyle.style_controls_recursive(options)
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
	var options := "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OptionsBox/"
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
	var read := get_node_or_null(READABILITY_PATH) as ReadabilityOptions
	if read != null:
		read.apply_tab_filter(tab_id)
	_refresh_tab_styles()
	if with_sound:
		_play_ui_fx(SFX_PAPER_TURN, -14.0)

func _on_locale_pill_pressed(code: String) -> void:
	var read := get_node_or_null(READABILITY_PATH) as ReadabilityOptions
	if read != null:
		read.select_language_code(code)
	else:
		var s := GameSettings.load_settings()
		s.language = code
		s.save()
		GameLocale.set_language(code)
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_method("refresh_locale"):
		parent_node.call("refresh_locale")
	else:
		refresh_locale()
	_play_ui_fx(SFX_KEY_CLICK, -16.0)

func _play_ui_fx(stream: AudioStream, db: float) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree() or stream == null:
		return
	if _ui_fx_player == null:
		_ui_fx_player = AudioStreamPlayer.new()
		_ui_fx_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_ui_fx_player.bus = &"Foley" if AudioServer.get_bus_index(&"Foley") >= 0 else &"Master"
		add_child(_ui_fx_player)
	_ui_fx_player.stream = stream
	_ui_fx_player.volume_db = db
	_ui_fx_player.play()

func refresh_locale() -> void:
	var box := "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/"
	var options := box + "OptionsBox/"
	var title := get_node_or_null(box + "HeaderRow/TitleBox/TitleLabel") as Label
	if title != null:
		title.text = GameLocale.pick("ЛИНИЯ НА УДЕРЖАНИИ", "LINE HELD")
	var subtitle := get_node_or_null(box + "HeaderRow/TitleBox/SubtitleLabel") as Label
	if subtitle != null:
		var in_office := get_parent() is M1OfficeController
		subtitle.text = GameLocale.pick(
			"Станция Блэк-Крик — Ночная смена" if in_office else "Блэк-Крик — Апрель 1890",
			"Black Creek Station — Night Watch" if in_office else "Black Creek — April 1890"
		)
	if _tab_game != null:
		_tab_game.text = GameLocale.pick("Игра", "Game")
	if _tab_audio != null:
		_tab_audio.text = GameLocale.pick("Звук", "Audio")
	if _tab_display != null:
		_tab_display.text = GameLocale.pick("Экран", "Display")
	var row_labels := {
		options + "MasterRow/Label": ["Общая громкость", "Master volume"],
		options + "AmbienceRow/Label": ["Шум комнаты", "Room ambience"],
		options + "TelegraphRow/Label": ["Телеграф", "Telegraph"],
		options + "FoleyRow/Label": ["Звуки предметов", "Foley"],
		options + "MusicRow/Label": ["Музыка", "Music"],
		options + "SensitivityRow/Label": ["Чувствительность мыши", "Mouse sensitivity"],
	}
	for path in row_labels:
		var lbl := get_node_or_null(path) as Label
		if lbl != null:
			var pair: Array = row_labels[path]
			lbl.text = GameLocale.pick(pair[0], pair[1])
	_refresh_locale_pills()
	if head_bob_check != null:
		head_bob_check.text = GameLocale.pick("Покачивание головы", "Head movement while walking")
	if contextual_thoughts_check != null:
		contextual_thoughts_check.text = GameLocale.pick("Мысли оператора", "Contextual thoughts")
	if resume_button != null:
		resume_button.text = GameLocale.pick("Продолжить", "Return to the Wire")
	if title_button != null:
		var base_leave := GameLocale.pick("В главное меню", "Leave the Post")
		_leave_caption = base_leave
		title_button.text = _leave_confirm_text() if is_leave_armed() else base_leave
	if quit_button != null:
		quit_button.text = GameLocale.pick("Выйти из игры", "Quit to Desktop")
	var hint := get_node_or_null(box + "HintLabel") as Label
	if hint != null:
		if get_parent() is M1OfficeController:
			hint.text = GameLocale.pick(
				"A / W / D / S  обзор      ЛКМ  действие      ПКМ  прильнуть      Колесо  лампа      Пробел  ключ",
				"W A S D  look      LMB  act      RMB  lean      Wheel  lamp      Space  key"
			)
		else:
			hint.text = GameLocale.pick(
				"WASD  ходьба      Shift  быстрый шаг      E  действие      Esc  пауза",
				"W A S D  walk      Shift  brisk stride      E  act      Esc  pause"
			)

func _bind_window_focus() -> void:
	if not is_inside_tree():
		return
	var root_win := get_tree().root
	if root_win == null:
		return
	if not root_win.focus_entered.is_connected(_on_window_focus_entered):
		root_win.focus_entered.connect(_on_window_focus_entered)
	if not root_win.focus_exited.is_connected(_on_window_focus_exited):
		root_win.focus_exited.connect(_on_window_focus_exited)

func _unbind_window_focus() -> void:
	if not is_inside_tree():
		return
	var root_win := get_tree().root
	if root_win == null:
		return
	if root_win.focus_entered.is_connected(_on_window_focus_entered):
		root_win.focus_entered.disconnect(_on_window_focus_entered)
	if root_win.focus_exited.is_connected(_on_window_focus_exited):
		root_win.focus_exited.disconnect(_on_window_focus_exited)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_on_window_focus_exited()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_on_window_focus_entered()

func _exit_tree() -> void:
	_unbind_window_focus()
	_release_focus_pause()

func _log_focus(msg: String) -> void:
	if DEBUG_FOCUS_LOGS and DisplayServer.get_name() != "headless":
		print("[Focus] " + msg)

func _on_window_focus_exited() -> void:
	var paused_now := get_tree().paused if is_inside_tree() else false
	_log_focus("window focus_exited paused_now=%s paused_for_focus=%s" % [paused_now, _paused_for_focus])
	if is_inside_tree() and not get_tree().paused:
		# Hold the wire and the shift clocks without taking over the active UI.
		_paused_for_focus = true
		_reacquire_on_walk_input = true
		get_tree().paused = true

func _on_window_focus_entered() -> void:
	_log_focus("window focus_entered paused_for_focus=%s is_paused=%s mouse=%d" % [
		_paused_for_focus, is_paused, Input.mouse_mode
	])
	_release_focus_pause()
	_restore_mouse_mode(true)
	_restore_mouse_mode.call_deferred(true)

func _release_focus_pause() -> void:
	if _paused_for_focus:
		_paused_for_focus = false
		if is_inside_tree():
			get_tree().paused = false

func _restore_mouse_mode(force_reacquire: bool = false) -> void:
	var tree_paused := is_inside_tree() and get_tree().paused
	if is_paused or tree_paused:
		_log_focus("restore skipped: is_paused=%s tree_paused=%s" % [is_paused, tree_paused])
		return
	var parent_node := get_parent()
	var blocked := parent_node != null and parent_node.has_method("is_world_view_blocked") \
		and bool(parent_node.call("is_world_view_blocked"))
	if blocked:
		_log_focus("restore skipped: world_view_blocked=true")
		return
	if is_inside_tree() and get_viewport() != null:
		get_viewport().gui_release_focus()
		if get_tree().root != null:
			get_tree().root.gui_release_focus()
	var seated_mode := player != null and player.seated_station_mode
	if not seated_mode and force_reacquire and DisplayServer.get_name() != "headless" \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Toggle through VISIBLE so Windows DisplayServer re-acquires OS ClipCursor.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if seated_mode else Input.MOUSE_MODE_CAPTURED
	_log_focus("restored mouse_mode=%d seated=%s force=%s" % [Input.mouse_mode, seated_mode, force_reacquire])
	if player != null:
		var interaction := player.get_node_or_null("InteractionController") as InteractionController
		if interaction != null:
			interaction.refresh_prompt()

func _find_nodes() -> void:
	var box := "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/"
	var options := box + "OptionsBox/"
	_tab_game = get_node_or_null(box + "TabBarRow/TabGame") as Button
	_tab_audio = get_node_or_null(box + "TabBarRow/TabAudio") as Button
	_tab_display = get_node_or_null(box + "TabBarRow/TabDisplay") as Button
	_ru_button = get_node_or_null(box + "HeaderRow/LocaleBar/RuButton") as Button
	_en_button = get_node_or_null(box + "HeaderRow/LocaleBar/EnButton") as Button
	if sensitivity_slider == null:
		sensitivity_slider = get_node_or_null(options + "SensitivityRow/SensitivitySlider") as HSlider
	if head_bob_check == null:
		head_bob_check = get_node_or_null(options + "HeadBobCheck") as CheckButton
	if master_slider == null:
		master_slider = get_node_or_null(options + "MasterRow/MasterSlider") as HSlider
	if ambience_slider == null:
		ambience_slider = get_node_or_null(options + "AmbienceRow/AmbienceSlider") as HSlider
	if telegraph_slider == null:
		telegraph_slider = get_node_or_null(options + "TelegraphRow/TelegraphSlider") as HSlider
	if foley_slider == null:
		foley_slider = get_node_or_null(options + "FoleyRow/FoleySlider") as HSlider
	if music_slider == null:
		music_slider = get_node_or_null(options + "MusicRow/MusicSlider") as HSlider
	if contextual_thoughts_check == null:
		contextual_thoughts_check = get_node_or_null(options + "ContextualThoughtsCheck") as CheckButton
	if resume_button == null:
		resume_button = get_node_or_null(box + "ButtonRow/ResumeButton") as Button
	if title_button == null:
		title_button = get_node_or_null(box + "ButtonRow/TitleButton") as Button
	if quit_button == null:
		quit_button = get_node_or_null(box + "ButtonRow/QuitButton") as Button

func _resolve_targets() -> void:
	var office := get_parent()
	if office == null:
		return
	if player == null:
		player = office.get_node_or_null("Player") as PlayerController
	if document_viewer == null:
		document_viewer = office.get_node_or_null("DocumentViewer") as DocumentViewer

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
	if sensitivity_slider != null and not sensitivity_slider.value_changed.is_connected(_on_sensitivity_changed):
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	if head_bob_check != null and not head_bob_check.toggled.is_connected(_on_head_bob_toggled):
		head_bob_check.toggled.connect(_on_head_bob_toggled)
	if master_slider != null and not master_slider.value_changed.is_connected(_on_master_changed):
		master_slider.value_changed.connect(_on_master_changed)
	if ambience_slider != null and not ambience_slider.value_changed.is_connected(_on_ambience_changed):
		ambience_slider.value_changed.connect(_on_ambience_changed)
	if telegraph_slider != null and not telegraph_slider.value_changed.is_connected(_on_telegraph_changed):
		telegraph_slider.value_changed.connect(_on_telegraph_changed)
	if foley_slider != null and not foley_slider.value_changed.is_connected(_on_foley_changed):
		foley_slider.value_changed.connect(_on_foley_changed)
	if music_slider != null and not music_slider.value_changed.is_connected(_on_music_changed):
		music_slider.value_changed.connect(_on_music_changed)
	if contextual_thoughts_check != null and not contextual_thoughts_check.toggled.is_connected(
			_on_contextual_thoughts_toggled):
		contextual_thoughts_check.toggled.connect(_on_contextual_thoughts_toggled)
	if resume_button != null and not resume_button.pressed.is_connected(resume):
		resume_button.pressed.connect(resume)
	if title_button != null and not title_button.pressed.is_connected(_on_leave_pressed):
		title_button.pressed.connect(_on_leave_pressed)
	if quit_button != null and not quit_button.pressed.is_connected(_on_quit):
		quit_button.pressed.connect(_on_quit)
	if _tab_game != null and not _tab_game.pressed.is_connected(select_options_tab.bind("game", true)):
		_tab_game.pressed.connect(select_options_tab.bind("game", true))
	if _tab_audio != null and not _tab_audio.pressed.is_connected(select_options_tab.bind("audio", true)):
		_tab_audio.pressed.connect(select_options_tab.bind("audio", true))
	if _tab_display != null and not _tab_display.pressed.is_connected(select_options_tab.bind("display", true)):
		_tab_display.pressed.connect(select_options_tab.bind("display", true))
	if _ru_button != null and not _ru_button.pressed.is_connected(_on_locale_pill_pressed.bind(GameLocale.LANG_RU)):
		_ru_button.pressed.connect(_on_locale_pill_pressed.bind(GameLocale.LANG_RU))
	if _en_button != null and not _en_button.pressed.is_connected(_on_locale_pill_pressed.bind(GameLocale.LANG_EN)):
		_en_button.pressed.connect(_on_locale_pill_pressed.bind(GameLocale.LANG_EN))

func _input(event: InputEvent) -> void:
	if _reacquire_on_walk_input and player != null and not event.is_echo() and event.is_pressed():
		var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
		var walk_key := event.is_action_pressed("interact") or event.is_action_pressed("move_forward") \
			or event.is_action_pressed("move_backward") or event.is_action_pressed("move_left") \
			or event.is_action_pressed("move_right")
		if (click or walk_key) and player.restore_walk_mouse_capture(true):
			_reacquire_on_walk_input = false
	if event.is_echo() or not event.is_action_pressed("ui_cancel"):
		return
	var office := get_parent() as M1OfficeController
	var editor := office.get_node_or_null("AmendmentEditor") as AmendmentEditor if office != null else null
	if editor != null and (editor.is_open() or editor.owns_transition_frame()):
		return
	# The pen on the paper takes Escape: it takes the correction back (6.3).
	var desk := get_tree().get_first_node_in_group(DeskAmendment.GROUP) as DeskAmendment
	if desk != null and desk.writing:
		return
	# A document in hand takes the key first: Escape should put the paper down
	# before it stops the shift. Input is left unhandled so the viewer consumes it.
	if not is_paused and document_viewer != null and document_viewer.is_open():
		return
	# When toggle() declines because an active surface owns the key, the event
	# must reach that surface: Escape closes the board instead of vanishing.
	if toggle():
		get_viewport().set_input_as_handled()

func toggle() -> bool:
	if is_paused:
		return resume()
	return pause()

func pause() -> bool:
	if is_paused or _paused_for_focus:
		return false
	var office := get_parent() as M1OfficeController
	if office != null:
		var editor := office.get_node_or_null("AmendmentEditor") as AmendmentEditor
		if editor != null and (editor.is_open() or editor.owns_transition_frame()):
			return false
		if office.routing_board != null and office.routing_board.is_open:
			return false
		var intro := office.get_node_or_null("IntroCard") as IntroCard
		if (intro != null and intro.visible) or (office.shift_end_card != null and office.shift_end_card.is_running()):
			return false
	is_paused = true
	if player != null:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
	visible = true
	var readability := get_node_or_null(READABILITY_PATH)
	if readability != null and readability.has_method("refresh"):
		readability.refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_inside_tree():
		get_tree().paused = true
	if resume_button != null:
		resume_button.grab_focus()
	paused.emit()
	return true

func resume() -> bool:
	if not is_paused:
		return false
	is_paused = false
	visible = false
	_disarm_leave()
	if is_inside_tree():
		get_tree().paused = false
		if get_viewport() != null:
			get_viewport().gui_release_focus()
		if get_tree().root != null:
			get_tree().root.gui_release_focus()
	_restore_mouse_mode()
	_restore_mouse_mode.call_deferred()
	_save()
	resumed.emit()
	return true

func _on_sensitivity_changed(value: float) -> void:
	# The slider works in thousandths so it has a usable range on screen.
	settings = GameSettings.load_settings()
	settings.mouse_sensitivity = maxf(0.0002, value / 1000.0)
	settings.apply(player)
	settings.save()

func _on_head_bob_toggled(pressed: bool) -> void:
	settings = GameSettings.load_settings()
	settings.head_bob_enabled = pressed
	settings.apply(player)
	settings.save()

func _on_master_changed(value: float) -> void:
	settings = GameSettings.load_settings()
	settings.master_volume_db = value
	settings.apply(player)
	settings.save()

func _on_ambience_changed(value: float) -> void:
	settings = GameSettings.load_settings()
	settings.ambience_volume_db = value
	settings.apply(player)
	settings.save()

func _on_telegraph_changed(value: float) -> void:
	settings = GameSettings.load_settings()
	settings.telegraph_volume_db = value
	settings.apply(player)
	settings.save()

func _on_foley_changed(value: float) -> void:
	settings = GameSettings.load_settings()
	settings.foley_volume_db = value
	settings.apply(player)
	settings.save()

func _on_music_changed(value: float) -> void:
	settings = GameSettings.load_settings()
	settings.music_volume_db = value
	settings.apply(player)
	settings.save()

func _on_contextual_thoughts_toggled(pressed: bool) -> void:
	settings = GameSettings.load_settings()
	settings.contextual_thoughts_enabled = pressed
	settings.apply(player)
	settings.save()

func _save() -> void:
	settings = GameSettings.load_settings()
	settings.save()

## Leaving the post loses the night (plan 6.8), so the button asks once: the
## first press says what it costs, a second press within a few seconds leaves.
func _on_leave_pressed() -> void:
	if is_leave_armed():
		_leave_armed_at = -1
		return_to_title()
		return
	_leave_armed_at = Time.get_ticks_msec()
	if title_button != null:
		if _leave_caption.is_empty():
			_leave_caption = title_button.text
		title_button.text = _leave_confirm_text()

func is_leave_armed() -> bool:
	return _leave_armed_at >= 0 and Time.get_ticks_msec() - _leave_armed_at <= LEAVE_CONFIRM_MSEC

func _disarm_leave() -> void:
	_leave_armed_at = -1
	if title_button != null and not _leave_caption.is_empty():
		title_button.text = _leave_caption

func _process(_delta: float) -> void:
	if _paused_for_focus and is_inside_tree():
		var root_win := get_tree().root
		if (root_win != null and root_win.has_focus()) or DisplayServer.window_is_focused():
			_on_window_focus_entered()
	if _leave_armed_at >= 0 and not is_leave_armed():
		_disarm_leave()

## Abandoning a watch clears it. There is no resuming a half-finished night.
func return_to_title() -> bool:
	_save()
	MainMenu.clear_state()
	if not is_inside_tree():
		return false
	var tree := get_tree()
	if tree == null:
		return false
	is_paused = false
	visible = false
	tree.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return SceneTransitionManager.go(tree, TITLE_SCENE)

func _on_quit() -> void:
	_save()
	if is_inside_tree():
		get_tree().paused = false
		get_tree().quit()
