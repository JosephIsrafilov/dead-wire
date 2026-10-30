class_name NightGuidanceData
extends Resource

## Elias's procedural reminders; no message, answer or hidden facts live here.
@export var entries: Array[Dictionary] = []
@export var automatic_interval: float = 12.0

## One-line reactions to something that just physically happened, keyed by
## event id. These are the room explaining itself in the operator's own voice,
## never a tutorial and never a hint about hidden truth: each says only what
## the player could already see, hear or do.
@export var reactions: Array[Dictionary] = []

func entry_for(context: StringName) -> Dictionary:
	for entry in entries:
		if entry.get("id", &"") == context:
			return entry
	return {}

func reaction_for(kind: StringName) -> Dictionary:
	for entry in reactions:
		if entry.get("id", &"") == kind:
			return entry
	return {}
