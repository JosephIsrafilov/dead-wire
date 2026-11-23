class_name DawnWalkThoughts
extends CanvasLayer

## Quiet OldStandardTT bottom-center thought line for Black Creek transitions.
## Reads KnowledgeState / CampaignState only, names the lingering detail or next
## action without ever explaining the plot or reassuring the player.

const FONT_REG := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")

var _label: Label = null
var _tween: Tween = null

func _ready() -> void:
	layer = 6
	_label = Label.new()
	_label.name = "ThoughtLabel"
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -170.0
	_label.offset_bottom = -118.0
	_label.offset_left = 48.0
	_label.offset_right = -48.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", FONT_REG)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76, 0.94))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.modulate.a = 0.0
	_label.visible = false
	add_child(_label)

func show_thought(text: String, hold_seconds: float = 4.5) -> void:
	if _label == null or text.is_empty():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.text = text
	_label.visible = true
	_label.modulate.a = 0.0
	if not is_inside_tree():
		_label.modulate.a = 1.0
		return
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.75).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void:
		if _label != null:
			_label.visible = false)

func get_current_text() -> String:
	return _label.text if _label != null and _label.visible else ""

static func build_dawn_thoughts(knowledge: KnowledgeStateStore, _campaign: CampaignStateStore) -> Array[String]:
	var lines: Array[String] = []
	var saw_window := knowledge != null and knowledge.knows(&"saw_window_event")
	var filed_water := knowledge != null and knowledge.knows(&"committed_water_core_hook")
	var filed_watcher := knowledge != null and knowledge.knows(&"committed_watcher_core_hook")

	if filed_watcher:
		lines.append(GameLocale.pick(
			"На бланке осталось слово «WATCHER». Сайлас или Джед точно спросят.",
			"The handover still carries the word WATCHER. Jed or Silas will ask."
		))
	elif filed_water:
		lines.append(GameLocale.pick(
			"Рука написала одно, саундер отстучал другое. Хорошо, что сверил по ленте.",
			"My hand wrote one thing while the key tapped another. Good thing I checked the tape."
		))
	else:
		lines.append(GameLocale.pick(
			"Холодный ветер с ручья. Утренний лист остался на столе без моей правки.",
			"Cold air off the creek. That last morning sheet never got my pen."
		))

	if saw_window:
		lines.append(GameLocale.pick(
			"У забора ночью стоял человек без фонаря — а на снегу и грязи ни следа.",
			"Someone stood by the yard fence without a lantern—yet the mud shows nothing."
		))
	else:
		lines.append(GameLocale.pick(
			"Вдоль улицы ещё тихо. Окна салуна тёмные до полудня.",
			"The street is still empty. The Copper Mule stays dark until noon."
		))

	lines.append(GameLocale.pick(
		"Пансион миссис Харгроув в конце настила. Пора дойти до койки и выспаться.",
		"Mrs. Hargrove's boarding house is at the end of the planks. Time to get some sleep."
	))
	return lines

static func build_sunny_morning_thought() -> String:
	return GameLocale.pick(
		"Солнце над Блэк-Криком. Салун «Медный Мул» открыт через дорогу — стоит зайти к бармену.",
		"Sun over Black Creek. The Copper Mule across the street is open—worth talking to the bartender."
	)
