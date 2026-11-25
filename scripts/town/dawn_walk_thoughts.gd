class_name DawnWalkThoughts
extends CanvasLayer

## Quiet OldStandardTT bottom-center thought line for Black Creek transitions.
## Reads KnowledgeState / CampaignState only, names the lingering detail or next
## action without ever explaining the plot or reassuring the player.

const FONT_REG := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")
const PANEL_WIDTH := 720.0
const PANEL_BOTTOM := -126.0

var _band: Control
var _panel: PanelContainer
var _label: Label
var _tween: Tween

func _ready() -> void:
	layer = 6
	_band = Control.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	_band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_set_band_offset(PANEL_BOTTOM)

	_panel = PanelContainer.new()
	_panel.name = "ThoughtPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.03, 0.80)
	style.border_color = Color(PeriodUIStyle.BRASS.darkened(0.11), 0.58)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.name = "ThoughtLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", FONT_REG)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80, 1.0))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_panel.add_child(_label)
	_band.resized.connect(_layout_panel)
	_panel.minimum_size_changed.connect(_layout_panel)
	_layout_panel()
	_panel.hide()

func _layout_panel() -> void:
	var half_width := clampf((_band.size.x - 48.0) * 0.5, 1.0, PANEL_WIDTH * 0.5)
	_panel.offset_left = -half_width
	_panel.offset_right = half_width
	_panel.offset_top = -_panel.get_combined_minimum_size().y
	_panel.offset_bottom = 0.0

func _set_band_offset(value: float) -> void:
	_band.offset_top = value
	_band.offset_bottom = value

func show_thought(text: String, hold_seconds: float = 5.5) -> void:
	if _panel == null or text.is_empty():
		return
	clear_thought()
	_label.text = text
	_panel.show()
	_panel.modulate.a = 1.0
	_set_band_offset(PANEL_BOTTOM)
	if not is_inside_tree():
		return
	_panel.modulate.a = 0.0
	_set_band_offset(PANEL_BOTTOM + 6.0)
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.28)
	_tween.parallel().tween_method(_set_band_offset, PANEL_BOTTOM + 6.0, PANEL_BOTTOM, 0.28)
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.85)
	_tween.tween_callback(_panel.hide)

func clear_thought() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _panel != null:
		_panel.hide()

func get_current_text() -> String:
	return _label.text if _panel != null and _panel.visible else ""


static func build_dawn_thoughts(knowledge: KnowledgeStateStore, _campaign: CampaignStateStore) -> Array[String]:
	var lines: Array[String] = []
	var saw_window := knowledge != null and knowledge.knows(&"saw_window_event")
	var filed_water := knowledge != null and knowledge.knows(&"committed_water_core_hook")
	var filed_watcher := knowledge != null and knowledge.knows(&"committed_watcher_core_hook")

	if filed_watcher:
		lines.append(GameLocale.pick(
			"На бланке так и торчит слово «WATCHER». Нахер я его туда вписал... Сайлас или Джед теперь точно докопаются.",
			"The damn handover still says WATCHER. What the hell possessed me to write that... Jed or Silas'll hound me for it."
		))
	elif filed_water:
		lines.append(GameLocale.pick(
			"Сука, башка трещит... рука строчила одно, а ключ отбил совсем другое. Хорошо хоть по ленте сверил.",
			"Hell, my head's splitting... hand wrote one thing while the key beat out another. Good thing I checked the tape."
		))
	else:
		lines.append(GameLocale.pick(
			"Ветер с ручья режет до костей. Блядская смена... последний лист так и валяется на столе.",
			"Wind off the creek cuts right to the bone. Damned shift... left that last sheet untouched."
		))

	if saw_window:
		lines.append(GameLocale.pick(
			"Какого хрена там ночью без фонаря кто-то торчал у забора... а в грязи под окном ни единого следа.",
			"Who the hell was standing out by the fence without a lantern... and not one boot print in the mud underneath."
		))
	else:
		lines.append(GameLocale.pick(
			"Пусто и тихо, хоть волком вой. И салун, сука, до полудня на замке.",
			"Dead quiet out here. Saloon's bolted shut till noon, of course."
		))

	lines.append(GameLocale.pick(
		"Вон пансион Харгроув в конце настила. Доползти бы до койки, пока ноги держат.",
		"Hargrove's boarding house is at the far end of the planks. Just get to the bunk before my legs give out."
	))
	return lines

static func build_sunny_morning_thought() -> String:
	return GameLocale.pick(
		"Солнце бьёт в глаза. «Медный Мул» открыли — пора выпить и вытянуть из бармена пару слов.",
		"Sun's straight in my eyes. The Copper Mule is open—time for a drink and a word with Silas."
	)
