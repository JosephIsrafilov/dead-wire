class_name BrightnessCalibration
extends Control

## First-launch brightness (plan 2.16). The room is lit by one lamp and the
## moon; on a dark monitor that is a black screen, so before the first watch
## the player sets the room's exposure once: two dark marks, the left one just
## visible, the right one not. Shown once; the pause menu keeps the slider.

signal calibrated(brightness: float)

## Night tones the marks stand for, before brightness.
const VISIBLE_MARK: float = 0.045
const HIDDEN_MARK: float = 0.016

var slider: HSlider = null
var _marks: Array[ColorRect] = []
var _settings: GameSettings = null

static func needed() -> bool:
	return not GameSettings.load_settings().brightness_calibrated

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_settings = GameSettings.load_settings()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 1.0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	centre.add_child(column)
	var heading := Label.new()
	heading.text = "Before the watch"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color(0.85, 0.78, 0.6))
	column.add_child(heading)
	var help := Label.new()
	help.text = "Turn the brightness until the left mark is only just there,\nand the right one is not."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.62, 0.57, 0.47))
	column.add_child(help)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 60)
	column.add_child(row)
	for tone in [VISIBLE_MARK, HIDDEN_MARK]:
		var mark := ColorRect.new()
		mark.custom_minimum_size = Vector2(90, 90)
		mark.set_meta(&"tone", tone)
		row.add_child(mark)
		_marks.append(mark)
	slider = HSlider.new()
	slider.min_value = 0.6
	slider.max_value = 1.8
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(360, 0)
	slider.value = _settings.brightness
	slider.value_changed.connect(_on_value)
	column.add_child(slider)
	var done := Button.new()
	done.text = "Take the Watch"
	done.pressed.connect(confirm)
	column.add_child(done)
	_on_value(slider.value)
	done.grab_focus.call_deferred()

## The marks brighten the way the room does: tone x brightness.
func get_mark_value(index: int) -> float:
	return _marks[index].color.r if index < _marks.size() else 0.0

func _on_value(value: float) -> void:
	for mark in _marks:
		var tone := float(mark.get_meta(&"tone")) * value
		mark.color = Color(tone, tone * 0.98, tone * 0.92)

func confirm() -> void:
	_settings = GameSettings.load_settings()
	_settings.brightness = slider.value
	_settings.brightness_calibrated = true
	_settings.save()
	calibrated.emit(_settings.brightness)
	queue_free()
