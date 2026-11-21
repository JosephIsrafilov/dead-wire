class_name TimetableCard
extends Node3D

## The station's printed night timetable, pinned on the wall right in front of
## the seated operator beside the Morse card. Reads on the desk wall directly
## and opens in the standard DocumentViewer on inspect.

signal card_inspected(text: String)

@export var prompt_message: String = "Read Night Timetable"

const TIMETABLE_TEXT: String = """BLACK CREEK & WESTERN — NIGHT TIMETABLE
TRAIN 17   | PASSENGER EAST | 01:15 | FORM 19 (CLEAR)
FREIGHT 71 | NIGHT FREIGHT  | 02:00 | RULE 44: FORM 31 (HOLD)
MJ SPUR    | MINE JUNCTION  | ----- | [CLOSED OCT 14, 1885]

WIRE CALL SIGNS (EAST DIVISION):
  BC — Black Creek (This Station)
  DN — Dunmore (West)    RS — Redstone (East)
  MJ — Mine Junction, Line 4 [DEAD SINCE OCT 14, 1885]"""

const WALL_CARD_TEXT: String = """BLACK CREEK & WESTERN
NIGHT TIMETABLE

TRAIN 17   01:15
FORM 19 (CLEAR)

FREIGHT 71 02:00
RULE 44: FORM 31 (HOLD)

MJ SPUR    -----
[CLOSED OCT 14, 1885]"""

var interactable: Interactable = null
var label_3d: Label3D = null

func _ready() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	label_3d = get_node_or_null("Label3D") as Label3D
	if interactable != null:
		interactable.prompt_text = prompt_message
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	if label_3d != null:
		label_3d.text = WALL_CARD_TEXT

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null and not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)
	return interactable

func get_timetable_text() -> String:
	return TIMETABLE_TEXT

func _on_interacted() -> void:
	card_inspected.emit(TIMETABLE_TEXT)
	var parent_node := get_parent()
	if parent_node != null:
		var viewer := parent_node.get_node_or_null("DocumentViewer") as DocumentViewer
		if viewer != null:
			viewer.open_document(
				"timetable_card", "BLACK CREEK & WESTERN — NIGHT TIMETABLE", TIMETABLE_TEXT,
				"[E / Esc] Put Down Timetable"
			)
