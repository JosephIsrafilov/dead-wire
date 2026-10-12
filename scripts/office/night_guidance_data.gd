class_name NightGuidanceData
extends Resource

## Elias's procedural reminders; no message, answer or hidden facts live here.
@export var entries: Array[Dictionary] = []
@export var automatic_interval: float = 12.0

func entry_for(context: StringName) -> Dictionary:
	for entry in entries:
		if entry.get("id", &"") == context:
			return entry
	return {}
