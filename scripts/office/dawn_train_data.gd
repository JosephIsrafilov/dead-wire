class_name DawnTrainData
extends Resource

## What the morning trains do, by what the board did in the night (plan 4.6).
## Keys are WorldState facts; the first one that is set wins. Read from the
## world, never from what Elias knows: he may not know where 17 went.

## No. 17, the morning passenger on the main line: "pass", "stand", "distant".
@export var passenger_by_fact: Dictionary = {}
@export var passenger_default: String = "distant"
## No. 71, the night freight on the mine branch: "stand" or "gone".
@export var freight_by_fact: Dictionary = {}
@export var freight_default: String = "stand"

func passenger_behaviour(world: WorldStateStore) -> String:
	return _first_set(world, passenger_by_fact, passenger_default)

func freight_behaviour(world: WorldStateStore) -> String:
	return _first_set(world, freight_by_fact, freight_default)

static func _first_set(world: WorldStateStore, table: Dictionary, fallback: String) -> String:
	if world == null:
		return fallback
	for fact in table:
		if world.get_fact(StringName(fact)) == true:
			return String(table[fact])
	return fallback
