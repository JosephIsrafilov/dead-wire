class_name InteractionController
extends Node

@export var interaction_ray: RayCast3D
@export var prompt_label: Label

var current_target: Interactable = null
var is_ui_blocked: bool = false

func _ready() -> void:
	if not interaction_ray:
		interaction_ray = get_node_or_null("../Head/Camera3D/InteractionRay") as RayCast3D
	if not prompt_label:
		prompt_label = get_node_or_null("../InteractionUI/PromptLabel") as Label

	_update_prompt_ui()

func _process(_delta: float) -> void:
	if is_ui_blocked:
		if prompt_label != null and prompt_label.visible:
			prompt_label.visible = false
		current_target = null
		return

	_update_target()

func _unhandled_input(event: InputEvent) -> void:
	if is_ui_blocked:
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		if current_target and current_target.can_interact():
			current_target.interact()
			get_viewport().set_input_as_handled()

func _update_target() -> void:
	var new_target: Interactable = null

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and interaction_ray and interaction_ray.is_colliding():
		var collider: Object = interaction_ray.get_collider()
		if collider is Interactable and collider.can_interact():
			new_target = collider

	if new_target != current_target:
		current_target = new_target
		_update_prompt_ui()

func _update_prompt_ui() -> void:
	if not prompt_label:
		return

	if is_ui_blocked:
		prompt_label.visible = false
		return

	if current_target and current_target.can_interact() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if current_target.is_actionable:
			prompt_label.text = "[E] %s" % current_target.get_prompt()
		else:
			prompt_label.text = current_target.get_prompt()
		prompt_label.visible = true
	else:
		prompt_label.visible = false
