class_name BookshelfInspect
extends Node3D

## The shelf of division volumes by the east wall.
##
## It exists because the room's other reading surfaces — the ledger, the duty
## sheet, the Morse card — are all about the operator's own work, and a depot
## office also had the paperwork nobody opens until something goes wrong: the
## general orders, the tariff, the quarantine notices. Putting that on the shelf
## gives the east wall a reason to be looked at other than the routing board, and
## it is where the "dead line since the mine closed" context lives in print.
##
## Same contract as every other inspectable surface: it hands the office a block
## of authored text and never reads game state. Nothing here knows what happened
## tonight.

signal inspected(text: String)

@export var prompt_message: String = "Inspect Bookshelf"

## The shelf reads as one short history of the division, in the order it
## happened. The dates are the ones the setting fixes: the quarantine is the
## June BEFORE the flood, the general order is the last one issued while the
## line still carried mine traffic, and the cutting is what the company printed
## afterwards. Nothing on this shelf is dated after the night it is read on.
const SHELF_TEXT: String = """BLACK CREEK STATION — DIVISION VOLUMES
────────────────────────────────────────
GENERAL ORDER 12 (bound, 1884):
    Every operator will acknowledge receipt of each order. An order
    acknowledged is an order executed.

TARIFF SCHEDULE, EAST DIVISION:
    Message, ten words or under ............... 25c
    Each additional word ....................... 2c
    Night service, eleven to six .............. free

NOTICE — QUARANTINE, JUNE 1885:
    Water supply and mine junction cars remain restricted pending
    inspection. This notice has not been withdrawn.

NEWSPAPER CUTTING, OCTOBER 1885:
    ... THE MINE WILL NOT REOPEN. THE COMPANY THANKS THE TOWN FOR
    ITS PATIENCE AND ITS SONS ...

────────────────────────────────────────
STATION ORDER BOOK — MARGIN ENTRY (1885):
OCT 14, 1885 — 11:42 PM
Night watch closed unsigned by Sr. Operator J. Cole.
Register strip missing from reel. Relief entered by Asst. E. Crane.

────────────────────────────────────────
FOLDED PRESCRIPTION SLIP (inside the front cover):
Dr. Arthur Crane, County Physician — Black Creek
Margin note (A.C.): "Keep the hand steady, Elias. Never lie to the record."
"""

var interactable: Interactable = null

func _ready() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		interactable.prompt_text = prompt_message
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null and not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)
	return interactable

func get_shelf_text() -> String:
	return SHELF_TEXT

func _on_interacted() -> void:
	inspected.emit(SHELF_TEXT)
