class_name WorldStateStore
extends Node

signal fact_changed(fact_id: StringName, previous_value: Variant, new_value: Variant)
signal state_reset

var _facts: Dictionary[StringName, Variant] = {}

func set_fact(fact_id: StringName, value: Variant) -> void:
	if fact_id.is_empty():
		return

	var has_previous: bool = _facts.has(fact_id)
	var previous_value: Variant = _facts.get(fact_id, null)

	if has_previous and previous_value == value:
		return

	_facts[fact_id] = value
	fact_changed.emit(fact_id, previous_value, value)

func get_fact(fact_id: StringName, default_value: Variant = null) -> Variant:
	if fact_id.is_empty():
		return default_value
	return _facts.get(fact_id, default_value)

func has_fact(fact_id: StringName) -> bool:
	if fact_id.is_empty():
		return false
	return _facts.has(fact_id)

func snapshot() -> Dictionary[StringName, Variant]:
	return _facts.duplicate(true)

func reset_for_new_game() -> void:
	_facts.clear()
	state_reset.emit()
