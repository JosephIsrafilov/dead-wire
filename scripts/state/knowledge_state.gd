class_name KnowledgeStateStore
extends Node

signal knowledge_learned(fact_id: StringName)
signal state_reset

var _known_facts: Dictionary[StringName, bool] = {}

func learn(fact_id: StringName) -> void:
	if fact_id.is_empty():
		return

	if _known_facts.has(fact_id):
		return

	_known_facts[fact_id] = true
	knowledge_learned.emit(fact_id)

func knows(fact_id: StringName) -> bool:
	if fact_id.is_empty():
		return false
	return _known_facts.has(fact_id)

func snapshot() -> Dictionary[StringName, bool]:
	return _known_facts.duplicate(true)

func reset_for_new_game() -> void:
	_known_facts.clear()
	state_reset.emit()
