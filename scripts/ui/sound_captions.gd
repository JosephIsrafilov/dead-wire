class_name SoundCaptions
extends CanvasLayer

## Captions for the sounds that are not the wire (plan 6.9), off by default.
## They say what is heard, never what makes it: "steps beyond the door", not
## who is walking. The Morse itself is never captioned — reading it is the
## game, and critical copy stays an act of listening.

const CAPTION_SECONDS := 3.5
const FADE_SECONDS := 0.6
const CAPTIONS_EN := {
	&"call": "[the sounder calls]",
	&"steps": "[steps beyond the door]",
	&"creak": "[timber creaks]",
	&"register": "[the register is running down]",
}
const CAPTIONS_RU := {
	&"call": "[вызов на линии]",
	&"steps": "[шаги за дверью]",
	&"creak": "[скрип дерева]",
	&"register": "[регистр замедляется]",
}
const CAPTIONS := CAPTIONS_EN

@export var office: M1OfficeController
var enabled: bool = false:
	set(value):
		enabled = value
		if not value:
			_clear()
var current_text: String = ""
var _remaining: float = 0.0
var _label: Label = null
var _register_was_slow: bool = false

func _ready() -> void:
	if office == null:
		office = get_parent() as M1OfficeController
	enabled = GameSettings.load_settings().sound_captions
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 18.0
	_label.offset_bottom = 48.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf"))
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.7, 0.85))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)
	_bind.call_deferred()

func _bind() -> void:
	if office == null:
		return
	if office.shift_director != null:
		office.shift_director.call_started.connect(func(_slot: int, _number: int) -> void:
			caption(&"call"))
	if office.door_attention != null:
		office.door_attention.footsteps_started.connect(caption.bind(&"steps"))
	var unease := office.get_node_or_null("UneaseDirector") as UneaseDirector
	if unease != null:
		unease.creaked.connect(func(_position: Vector3) -> void: caption(&"creak"))

## Shows the caption for a heard sound, if captions are on.
func caption(kind: StringName) -> void:
	var table: Dictionary = CAPTIONS_RU if GameLocale.is_ru() else CAPTIONS_EN
	if not enabled or not table.has(kind):
		return
	current_text = table[kind]
	_remaining = CAPTION_SECONDS
	if _label != null:
		_label.text = current_text
		_label.visible = true
		_label.modulate.a = 1.0

func _process(delta: float) -> void:
	_watch_register()
	if _remaining <= 0.0:
		return
	_remaining -= delta
	if _label != null:
		_label.modulate.a = clampf(_remaining / FADE_SECONDS, 0.0, 1.0)
	if _remaining <= 0.0:
		_clear()

## The register's clockwork slowing is a sound with no signal of its own:
## caption it once each time it starts to run down.
func _watch_register() -> void:
	if office == null or office.session_controller == null:
		return
	var register := office.session_controller.get_tape_register()
	var slow := register != null and register.needs_winding()
	if slow and not _register_was_slow:
		caption(&"register")
	_register_was_slow = slow

func _clear() -> void:
	current_text = ""
	_remaining = 0.0
	if _label != null:
		_label.visible = false
