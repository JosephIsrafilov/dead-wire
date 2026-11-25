class_name ReadabilityOptions
extends VBoxContainer

## Shared image, reading, language and display options for both the title and
## pause menus. Each change is written to disk at once, so no exit path can drop it.

var _language: OptionButton
var _title: Label
var _mode: OptionButton
var _fov: HSlider
var _text: HSlider
var _brightness: HSlider
var _window: OptionButton
var _vsync: CheckBox
var _fps: OptionButton
var _invert: CheckBox
var _defaults: Button
var _captions: CheckBox
var _quality: OptionButton
var _playtest_log: CheckBox
var _display_row: HBoxContainer
var _toggle_row: HBoxContainer
var _slider_labels: Dictionary = {}
var _slider_rows: Dictionary = {}
## Each slider's printed value, so a setting is a number and not a guess.
var _readouts: Dictionary = {}
var _active_tab: String = "all"

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_title = Label.new()
	add_child(_title)

	_language = OptionButton.new()
	_language.add_item("Язык: Русский", 0)
	_language.add_item("Language: English", 1)
	add_child(_language)

	_mode = OptionButton.new()
	_mode.add_item("", ReadabilityPolicy.Mode.READABLE)
	_mode.add_item("", ReadabilityPolicy.Mode.CLEAN)
	add_child(_mode)
	_fov = _slider("", 55.0, 85.0, 1.0, "%d°")
	_text = _slider("", 1.0, 1.5, 0.1, "×%.1f")
	_brightness = _slider("", 0.6, 1.8, 0.05, "×%.2f")

	_display_row = HBoxContainer.new()
	_display_row.add_theme_constant_override("separation", 4)
	add_child(_display_row)
	_window = OptionButton.new()
	_window.add_item("", 0)
	_window.add_item("", 1)
	_display_row.add_child(_window)
	_fps = OptionButton.new()
	for limit in GameSettings.FPS_LIMITS:
		_fps.add_item("", limit)
	_display_row.add_child(_fps)
	_quality = OptionButton.new()
	for index in GameSettings.QUALITY_NAMES.size():
		_quality.add_item("", index)
	_display_row.add_child(_quality)

	_toggle_row = HBoxContainer.new()
	_toggle_row.add_theme_constant_override("separation", 4)
	add_child(_toggle_row)
	_vsync = CheckBox.new()
	_toggle_row.add_child(_vsync)
	_invert = CheckBox.new()
	_toggle_row.add_child(_invert)
	_captions = CheckBox.new()
	_toggle_row.add_child(_captions)
	_playtest_log = CheckBox.new()
	_toggle_row.add_child(_playtest_log)
	_defaults = Button.new()
	_toggle_row.add_child(_defaults)
	for compact in [_window, _fps, _quality, _vsync, _invert, _captions, _playtest_log, _defaults]:
		(compact as Control).add_theme_font_size_override("font_size", 13)

	_apply_locale()
	refresh()
	_language.item_selected.connect(_on_language)
	_mode.item_selected.connect(_on_mode)
	_fov.value_changed.connect(_on_fov)
	_text.value_changed.connect(_on_text)
	_brightness.value_changed.connect(_on_brightness)
	_window.item_selected.connect(_on_window)
	_vsync.toggled.connect(_on_vsync)
	_fps.item_selected.connect(_on_fps)
	_quality.item_selected.connect(_on_quality)
	_invert.toggled.connect(_on_invert)
	_captions.toggled.connect(_on_captions)
	_playtest_log.toggled.connect(_on_playtest_log)
	_defaults.pressed.connect(_on_defaults)
	visibility_changed.connect(refresh)

func select_language_code(code: String) -> void:
	var idx := 1 if code == GameLocale.LANG_EN else 0
	if _language != null:
		_language.select(idx)
	_on_language(idx)

func _apply_locale() -> void:
	if _title != null:
		_title.text = GameLocale.pick("ИЗОБРАЖЕНИЕ И ЧТЕНИЕ", "IMAGE / READING")
	if _mode != null:
		_mode.set_item_text(0, GameLocale.pick("540 — ночь как задумано", "540 — the night as drawn"))
		_mode.set_item_text(1, GameLocale.pick("CLEAN — полное разрешение", "CLEAN — full resolution"))
	if _slider_labels.has(_fov):
		(_slider_labels[_fov] as Label).text = GameLocale.pick(
			"Угол обзора (55–85°)", "Vertical field of view (55–85 degrees)"
		)
	if _slider_labels.has(_text):
		(_slider_labels[_text] as Label).text = GameLocale.pick(
			"Размер текста — документы и листы", "Reading size — documents and lifted sheets"
		)
	if _slider_labels.has(_brightness):
		(_slider_labels[_brightness] as Label).text = GameLocale.pick(
			"Яркость — комната, не бумага", "Brightness — the room, not the page"
		)
	if _window != null:
		_window.set_item_text(0, GameLocale.pick("В окне", "Windowed"))
		_window.set_item_text(1, GameLocale.pick("Полный экран", "Full screen"))
	if _fps != null:
		for i in GameSettings.FPS_LIMITS.size():
			var limit: int = GameSettings.FPS_LIMITS[i]
			_fps.set_item_text(
				i,
				GameLocale.pick("Без лимита FPS", "No frame limit") if limit == 0
				else GameLocale.pick("%d кадр/с" % limit, "%d frames" % limit)
			)
	if _quality != null:
		var ru_qual: Array[String] = ["Низкое", "Среднее", "Высокое"]
		for index in GameSettings.QUALITY_NAMES.size():
			var qname: String = ru_qual[index] if GameLocale.is_ru() else GameSettings.QUALITY_NAMES[index]
			_quality.set_item_text(index, GameLocale.pick("Качество: ", "Quality: ") + qname)
	if _vsync != null:
		_vsync.text = GameLocale.pick("Верт. синхр.", "VSync")
	if _invert != null:
		_invert.text = GameLocale.pick("Инверсия Y", "Invert Y")
	if _captions != null:
		_captions.text = GameLocale.pick("Субтитры", "Captions")
	if _playtest_log != null:
		_playtest_log.text = GameLocale.pick("Лог теста", "Playtest log")
	if _defaults != null:
		_defaults.text = GameLocale.pick("Сброс", "Default")

## A labelled slider with its value printed beside it.
func _slider(caption: String, low: float, high: float, step: float, format: String) -> HSlider:
	var label := Label.new()
	label.text = caption
	add_child(label)
	var row := HBoxContainer.new()
	add_child(row)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(56, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	_slider_labels[slider] = label
	_slider_rows[slider] = row
	_readouts[slider] = [readout, format]
	slider.value_changed.connect(func(_value: float) -> void: _print_value(slider))
	return slider

func apply_tab_filter(tab_id: String) -> void:
	_active_tab = tab_id
	if tab_id == "audio":
		visible = false
		return
	visible = true
	var show_all := tab_id == "all"
	var show_game := show_all or tab_id == "game"
	var show_display := show_all or tab_id == "display"
	if _title != null:
		_title.visible = show_all
	if _language != null:
		_language.visible = show_game
	if _mode != null:
		_mode.visible = show_display
	for s in [_fov, _text, _brightness]:
		if s != null:
			if _slider_labels.has(s):
				(_slider_labels[s] as Control).visible = show_display
			if _slider_rows.has(s):
				(_slider_rows[s] as Control).visible = show_display
	if _display_row != null:
		_display_row.visible = show_display
	if _toggle_row != null:
		_toggle_row.visible = show_game or show_display
	if _vsync != null:
		_vsync.visible = show_display
	for ctrl in [_invert, _captions, _playtest_log, _defaults]:
		if ctrl != null:
			(ctrl as Control).visible = show_game

func _print_value(slider: HSlider) -> void:
	var entry: Array = _readouts.get(slider, [])
	if entry.is_empty():
		return
	(entry[0] as Label).text = (entry[1] as String) % slider.value

func get_readout_text(slider: HSlider) -> String:
	var entry: Array = _readouts.get(slider, [])
	return (entry[0] as Label).text if not entry.is_empty() else ""

func refresh() -> void:
	if _mode == null or _fov == null or _text == null:
		return
	var settings := GameSettings.load_settings()
	GameLocale.set_language(settings.language)
	_apply_locale()
	if _language != null:
		_language.select(1 if settings.language == GameLocale.LANG_EN else 0)
	var clean := settings.presentation_mode == ReadabilityPolicy.Mode.CLEAN
	_mode.select(_mode.get_item_index(ReadabilityPolicy.Mode.CLEAN if clean else ReadabilityPolicy.Mode.READABLE))
	_fov.set_value_no_signal(settings.vertical_fov)
	_text.set_value_no_signal(settings.text_scale)
	if _brightness != null:
		_brightness.set_value_no_signal(settings.brightness)
	for slider in _readouts:
		_print_value(slider)
	if _window != null:
		_window.select(_window.get_item_index(1 if settings.fullscreen else 0))
		_vsync.set_pressed_no_signal(settings.vsync)
		_fps.select(_fps.get_item_index(settings.max_fps))
		_invert.set_pressed_no_signal(settings.invert_y)
		_captions.set_pressed_no_signal(settings.sound_captions)
		_quality.select(_quality.get_item_index(settings.quality))
		_playtest_log.set_pressed_no_signal(settings.playtest_telemetry_enabled)

func _on_language(index: int) -> void:
	var settings := GameSettings.load_settings()
	settings.language = GameLocale.LANG_EN if _language.get_item_id(index) == 1 else GameLocale.LANG_RU
	GameLocale.set_language(settings.language)
	_commit(settings)
	_apply_locale()
	_notify_ancestors_locale()

func _notify_ancestors_locale() -> void:
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor.has_method("refresh_locale"):
			ancestor.refresh_locale()
		ancestor = ancestor.get_parent()

func _on_mode(index: int) -> void:
	var settings := GameSettings.load_settings()
	settings.presentation_mode = _mode.get_item_id(index)
	_commit(settings)

func _on_fov(value: float) -> void:
	var settings := GameSettings.load_settings()
	settings.vertical_fov = value
	_commit(settings)

func _on_text(value: float) -> void:
	var settings := GameSettings.load_settings()
	settings.text_scale = value
	_commit(settings)

func _on_brightness(value: float) -> void:
	var settings := GameSettings.load_settings()
	settings.brightness = value
	settings.brightness_calibrated = true
	_commit(settings)

func _on_window(index: int) -> void:
	var settings := GameSettings.load_settings()
	settings.fullscreen = _window.get_item_id(index) == 1
	_commit(settings)

func _on_vsync(pressed: bool) -> void:
	var settings := GameSettings.load_settings()
	settings.vsync = pressed
	_commit(settings)

func _on_fps(index: int) -> void:
	var settings := GameSettings.load_settings()
	settings.max_fps = _fps.get_item_id(index)
	_commit(settings)

func _on_playtest_log(pressed: bool) -> void:
	var settings := GameSettings.load_settings()
	settings.playtest_telemetry_enabled = pressed
	_commit(settings)

func _on_quality(index: int) -> void:
	var settings := GameSettings.load_settings()
	settings.quality = _quality.get_item_id(index)
	_commit(settings)

func _on_invert(pressed: bool) -> void:
	var settings := GameSettings.load_settings()
	settings.invert_y = pressed
	_commit(settings)

func _on_captions(pressed: bool) -> void:
	var settings := GameSettings.load_settings()
	settings.sound_captions = pressed
	_commit(settings)

## Back to how the night is meant to look; the first-launch brightness stays
## calibrated (the player has seen the marks once).
func _on_defaults() -> void:
	var settings := GameSettings.load_settings()
	settings.restore_defaults()
	_commit(settings)
	refresh()

func _commit(settings: GameSettings) -> void:
	settings.save()
	var ancestor: Node = self
	var host: PSXPresentationHost
	while ancestor != null and not (ancestor is M1OfficeController):
		host = ancestor.get_node_or_null("PSXPresentationHost") as PSXPresentationHost
		if host != null:
			break
		ancestor = ancestor.get_parent()
	var office := ancestor as M1OfficeController
	settings.apply(office.player if office != null else null)
	if office != null:
		office.apply_presentation_mode(settings.presentation_mode)
		if office.document_viewer != null and office.document_viewer.has_method("set_text_scale"):
			office.document_viewer.set_text_scale(settings.text_scale)
	elif host != null:
		host.apply_presentation_mode(settings.presentation_mode)

## The older sound/control rows share the same numeric feedback in both menus.
static func attach_readout(slider: HSlider, format: String) -> void:
	if slider == null or slider.get_parent().has_node("Value"):
		return
	var value := Label.new()
	value.name = "Value"
	value.custom_minimum_size.x = 52.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 13)
	slider.get_parent().add_child(value)
	value.text = format % slider.value
	slider.value_changed.connect(func(number: float) -> void: value.text = format % number)
