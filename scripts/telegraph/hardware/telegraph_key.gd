class_name TelegraphKey
extends Node3D

signal key_pressed()

@export var is_enabled: bool = true
@export var prompt_message: String = "Press Key (Answer Line)"

var interactable: Interactable = null
var lever_mesh: Node3D = null

var press_count: int = 0
var _is_animating: bool = false
var _orig_lever_y: float = 0.0

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if lever_mesh == null:
		lever_mesh = get_node_or_null("Lever") as Node3D

	if lever_mesh != null:
		_orig_lever_y = lever_mesh.position.y

	if interactable != null:
		interactable.prompt_text = prompt_message
		interactable.enabled = true
		interactable.is_actionable = is_enabled
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	return interactable

func set_enabled(enabled: bool) -> void:
	is_enabled = enabled
	var act := get_interactable()
	if act != null:
		act.enabled = true
		act.is_actionable = enabled

func set_prompt_message(msg: String) -> void:
	prompt_message = msg
	var act := get_interactable()
	if act != null:
		act.prompt_text = msg

func press() -> void:
	if not is_enabled:
		return
	press_count += 1
	_animate_press()
	key_pressed.emit()

func _on_interacted() -> void:
	press()

func _animate_press() -> void:
	if lever_mesh == null:
		lever_mesh = get_node_or_null("Lever") as Node3D
	if lever_mesh == null or _is_animating:
		return
	_is_animating = true
	lever_mesh.position.y = _orig_lever_y - 0.008

	# Reset visual position after 150ms if inside tree
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var timer := tree.create_timer(0.15)
			timer.timeout.connect(func():
				if lever_mesh != null:
					lever_mesh.position.y = _orig_lever_y
				_is_animating = false
			)
	else:
		lever_mesh.position.y = _orig_lever_y
		_is_animating = false
