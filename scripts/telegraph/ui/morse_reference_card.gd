class_name MorseReferenceCard
extends Node3D

signal card_inspected(text: String)
signal card_closed()

@export var prompt_message: String = "Inspect Morse Reference Card"

const REFERENCE_TEXT: String = """AMERICAN MORSE CODE (1894)
--------------------------
A  · —        N  — ·
C  · ·  ·     O  ·  ·
D  — · ·      R  ·  · ·
E  ·          S  · · ·
F  · — ·      T  —
G  — — ·      U  · · —
H  · · · ·    W  · — —
I  · ·        1  · — — ·
L  ——— (long) 7  — — · ·"""

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
		label_3d.text = "AMERICAN MORSE\nRAILROAD SERVICE\n1894"

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	return interactable

func get_reference_text() -> String:
	return REFERENCE_TEXT

func _on_interacted() -> void:
	card_inspected.emit(REFERENCE_TEXT)
