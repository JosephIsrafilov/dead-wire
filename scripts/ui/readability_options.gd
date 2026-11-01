class_name ReadabilityOptions
extends VBoxContainer

## Shared image, reading and display options for both the title and pause
## menus. Each change is written to disk at once, so no exit path can drop it.

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
## Each slider's printed value, so a setting is a number and not a guess.
var _readouts: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "IMAGE / READING"
	add_child(title)
	# CLASSIC and READABLE draw on the same 540-line grid since plan 1.1, so the
	# player is offered the picture as drawn or the accessibility option. A saved
	# CLASSIC still loads and simply shows as 540.
	_mode = OptionButton.new()
	_mode.add_item("540 — the night as drawn", ReadabilityPolicy.Mode.READABLE)
	_mode.add_item("CLEAN — full resolution", ReadabilityPolicy.Mode.CLEAN)
	add_child(_mode)
	_fov = _slider("Vertical field of view (55–85 degrees)", 55.0, 85.0, 1.0, "%d°")
	_text = _slider("Reading size — documents and lifted sheets", 1.0, 1.5, 0.1, "×%.1f")
	_brightness = _slider("Brightness — the room, not the page", 0.6, 1.8, 0.05, "×%.2f")
	# Display and controls: two compact rows, so both menus still fit the frame.
	var display_row := HBoxContainer.new()
	add_child(display_row)
	_window = OptionButton.new()
	_window.add_item("Windowed", 0)
	_window.add_item("Full screen", 1)
	display_row.add_child(_window)
	_fps = OptionButton.new()
	for limit in GameSettings.FPS_LIMITS:
		_fps.add_item("No frame limit" if limit == 0 else "%d frames" % limit, limit)
	display_row.add_child(_fps)
	# Plan 10.3: what the machine spends on the air and the shadows.
	_quality = OptionButton.new()
	for index in GameSettings.QUALITY_NAMES.size():
		_quality.add_item("Quality: " + GameSettings.QUALITY_NAMES[index], index)
	display_row.add_child(_quality)
	var toggle_row := HBoxContainer.new()
	add_child(toggle_row)
	_vsync = CheckBox.new()
	_vsync.text = "VSync"
	toggle_row.add_child(_vsync)
	_invert = CheckBox.new()
	_invert.text = "Invert Y"
	toggle_row.add_child(_invert)
	_captions = CheckBox.new()
	_captions.text = "Captions"
	toggle_row.add_child(_captions)
	_defaults = Button.new()
	_defaults.text = "Default"
	toggle_row.add_child(_defaults)
	refresh()
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
	_defaults.pressed.connect(_on_defaults)
	visibility_changed.connect(refresh)

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
	_readouts[slider] = [readout, format]
	slider.value_changed.connect(func(_value: float) -> void: _print_value(slider))
	return slider

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
	while ancestor != null and not (ancestor is M1OfficeController):
		ancestor = ancestor.get_parent()
	var office := ancestor as M1OfficeController
	settings.apply(office.player if office != null else null)
	if office != null:
		office.apply_presentation_mode(settings.presentation_mode)
		if office.document_viewer != null and office.document_viewer.has_method("set_text_scale"):
			office.document_viewer.set_text_scale(settings.text_scale)
