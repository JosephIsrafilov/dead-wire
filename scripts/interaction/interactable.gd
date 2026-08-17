class_name Interactable
extends Area3D

signal interacted

@export var prompt_text: String = "Interact"
@export var enabled: bool = true
@export var is_actionable: bool = true

func get_prompt() -> String:
	if prompt_text.is_empty():
		return "Interact"
	return prompt_text

func can_interact() -> bool:
	return enabled

func interact() -> void:
	if not can_interact():
		return
	interacted.emit()
