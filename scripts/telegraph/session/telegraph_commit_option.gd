class_name TelegraphCommitOption
extends Resource

@export var action_id: StringName = &""
@export var display_label: String = ""
@export var world_fact: String = ""
@export var knowledge_fact: String = ""
@export var result_text: String = ""

func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if action_id.is_empty():
		errors.append("action_id cannot be empty")
	if display_label.is_empty():
		errors.append("display_label cannot be empty")
	if world_fact.is_empty():
		errors.append("world_fact cannot be empty")
	if knowledge_fact.is_empty():
		errors.append("knowledge_fact cannot be empty")
	if result_text.is_empty():
		errors.append("result_text cannot be empty")
	return errors
