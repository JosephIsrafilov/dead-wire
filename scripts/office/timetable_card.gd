class_name TimetableCard
extends Node3D

## The station's printed night timetable, pinned on the wall right in front of
## the seated operator beside the Morse card. Reads on the desk wall directly
## and opens in the standard DocumentViewer on inspect.

signal card_inspected(text: String)

@export var prompt_message: String = "Расписание и коды"

const TIMETABLE_TEXT_EN: String = """TRAIN 17   | PASSENGER EAST | 01:15 | FORM 19 (CLEAR)
FREIGHT 71 | NIGHT FREIGHT  | 02:00 | RULE 44: FORM 31 (HOLD)
MJ SPUR    | MINE JUNCTION  | ----- | [CLOSED OCT 14, 1885]

WIRE CALL SIGNS (EAST DIVISION):
  BC — Black Creek (This Station)
  DN — Dunmore (West)    RS — Redstone (East)
  MJ — Mine Junction, Line 4 [DEAD SINCE OCT 14, 1885]"""

const TIMETABLE_TEXT_RU: String = """ПОЕЗД 17    | ПАССАЖИРСКИЙ (ВОСТОК) | 01:15 | ФОРМА 19: ПРОПУСТИТЬ
ТОВАРНЫЙ 71 | НОЧНОЙ ГРУЗОВОЙ       | 02:00 | ПРИКАЗ 44: ДЕРЖАТЬ
ВЕТКА MJ    | РУДНИЧНАЯ РАЗВЯЗКА    | ----- | [ЗАКРЫТА 14 ОКТ. 1885]

ПОЗЫВНЫЕ ЛИНИИ (ВОСТОЧНЫЙ УЧАСТОК):
  BC — Блэк-Крик (наша станция)
  DN — Данмор (запад)    RS — Редстоун (восток)
  MJ — Рудничная развязка, линия 4 [МЕРТВА С ОКТЯБРЯ 1885]

СЛОВАРЬ ПРОВОДА:
  TRAIN = поезд        FREIGHT = товарный
  CLEAR EAST = путь на восток    HOLD = держать"""

const WALL_CARD_TEXT_EN: String = """NIGHT TIMETABLE

No.      TIME     DIRECTION
17         01:15      EAST
71         02:00      EAST

MJ SPUR CLOSED"""

const WALL_CARD_TEXT_RU: String = """НОЧНОЕ РАСПИСАНИЕ

№       ВРЕМЯ      ПУТЬ
17        01:15      ВОСТОК
71        02:00      ВОСТОК

ВЕТКА MJ ЗАКРЫТА"""

var interactable: Interactable = null
var label_3d: Label3D = null

func _ready() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	label_3d = get_node_or_null("Label3D") as Label3D
	refresh_locale()
	if interactable != null and not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)

func refresh_locale() -> void:
	if interactable != null:
		interactable.prompt_text = GameLocale.pick("Расписание и коды", "Read Night Timetable")
	if label_3d != null:
		label_3d.text = GameLocale.pick(WALL_CARD_TEXT_RU, WALL_CARD_TEXT_EN)

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null and not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)
	return interactable

func get_timetable_text() -> String:
	return GameLocale.pick(TIMETABLE_TEXT_RU, TIMETABLE_TEXT_EN)

func _on_interacted() -> void:
	var text := get_timetable_text()
	card_inspected.emit(text)
	var parent_node := get_parent()
	if parent_node != null:
		var viewer := parent_node.get_node_or_null("DocumentViewer") as DocumentViewer
		if viewer != null:
			viewer.open_document(
				"timetable_card",
				GameLocale.pick(
					"Ж.Д. БЛЭК-КРИК — НОЧНОЕ РАСПИСАНИЕ",
					"BLACK CREEK & WESTERN — NIGHT TIMETABLE"
				),
				text,
				GameLocale.pick("[E / Esc / ПКМ] Отложить", "[E / Esc] Put Down Timetable")
			)
