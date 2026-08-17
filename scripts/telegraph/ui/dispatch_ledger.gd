class_name DispatchLedger
extends Node3D

signal ledger_inspected(text: String)
signal ledger_closed()

@export var prompt_message: String = "Inspect Dispatch Ledger"

const LEDGER_TEXT: String = """BLACK CREEK STATION — DISPATCH LEDGER (APRIL 1894)
==================================================
SPECIAL ORDERS & ROUTING RULES:

1. SCHEDULED PASSENGER (TRAIN 17):
   - Priority route: CLEAR EAST immediately.
   - Do NOT hold on siding track unless express obstruction reported.

2. UNVERIFIED NIGHT FREIGHT:
   - Rule 44: HOLD all unscheduled freight pending mine superintendent check.
   - Water supply & mine junction cars remain restricted under 1889 quarantine."""

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
		label_3d.text = "DISPATCH LEDGER\n[E to Inspect Rules]"

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	return interactable

func get_ledger_text() -> String:
	return LEDGER_TEXT

func _on_interacted() -> void:
	ledger_inspected.emit(LEDGER_TEXT)
