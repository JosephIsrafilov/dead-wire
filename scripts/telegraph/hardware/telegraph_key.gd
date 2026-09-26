class_name TelegraphKey
extends Node3D

signal key_pressed()
## Any physical press, live line or not: the brass moves either way. Sound and
## motion only — never the scheduler, so the tape register cannot record it.
signal key_touched()

@export var is_enabled: bool = true
@export var prompt_message: String = "Answer the Line"
@export var press_travel: float = 0.011
@export var press_down_time: float = 0.05
@export var press_up_time: float = 0.16

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
	key_touched.emit()
	key_pressed.emit()

func _on_interacted() -> void:
	if is_enabled:
		press()
		return
	# A dead line still has a sprung key under the finger.
	_animate_press()
	key_touched.emit()

func _animate_press() -> void:
	if lever_mesh == null:
		lever_mesh = get_node_or_null("Lever") as Node3D
	if lever_mesh == null or _is_animating:
		return

	if not is_inside_tree():
		lever_mesh.position.y = _orig_lever_y
		return

	# A telegraph key is sprung: it goes down hard and comes back slower, with a
	# little bounce off the contact. The old version snapped to an offset and sat
	# there for 150 ms, which read as a glitch rather than a press.
	_is_animating = true
	var tween := create_tween()
	tween.tween_property(
			lever_mesh, "position:y", _orig_lever_y - press_travel, press_down_time
		).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(
			lever_mesh, "position:y", _orig_lever_y, press_up_time
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _is_animating = false)
