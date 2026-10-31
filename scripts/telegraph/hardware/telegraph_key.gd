class_name TelegraphKey
extends Node3D

signal key_pressed()
## Any physical press, live line or not: the brass moves either way. Sound and
## motion only — never the scheduler, so the tape register cannot record it.
signal key_touched()

@export var is_enabled: bool = true
@export var prompt_message: String = "Answer the Line"
## Plan 8.1: the lever is a beam on a trunnion. The finger takes the knob down
## its travel and the tail comes up; it strikes the contact, comes off it a
## hair, and the spring brings it back against the back stop with the same
## small rebound.
## Travel at the knob.
@export var press_travel: float = 0.008
## The trunnion, in Lever-local coordinates.
@export var lever_pivot: Vector3 = Vector3(0.0, 0.008, 0.01)
## Where the finger meets the knob, along the lever (Lever-local z).
@export var knob_z: float = 0.068
@export var press_down_time: float = 0.045
@export var press_up_time: float = 0.08
## How far the lever comes back off the contact, and off the back stop, as a
## fraction of its travel.
@export var contact_rebound: float = 0.18
@export var stop_rebound: float = 0.12

var interactable: Interactable = null
var lever_mesh: Node3D = null

var press_count: int = 0
var _is_animating: bool = false
var _lever_rest: Transform3D = Transform3D.IDENTITY
var _press_amount: float = 0.0

func _ready() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if lever_mesh == null:
		lever_mesh = get_node_or_null("Lever") as Node3D

	if lever_mesh != null:
		_lever_rest = lever_mesh.transform

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
		set_press_amount(0.0)
		return

	# A telegraph key is sprung: the finger drives it down onto the contact, it
	# comes off it a hair, the spring returns it against the back stop, which
	# it leaves by a hair too. The old version snapped to an offset and sat
	# there for 150 ms, which read as a glitch rather than a press.
	_is_animating = true
	var tween := create_tween()
	var rebound_time := 0.022
	tween.tween_method(set_press_amount, 0.0, 1.0, press_down_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(set_press_amount, 1.0, 1.0 - contact_rebound, rebound_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(set_press_amount, 1.0 - contact_rebound, 1.0, rebound_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_method(set_press_amount, 1.0, 0.0, press_up_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(set_press_amount, 0.0, stop_rebound, rebound_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(set_press_amount, stop_rebound, 0.0, rebound_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _is_animating = false)

## Puts the lever at a fraction of its travel: 0 at rest on the back stop, 1
## with the knob down on the contact. It turns about the trunnion.
func set_press_amount(amount: float) -> void:
	if lever_mesh == null:
		lever_mesh = get_node_or_null("Lever") as Node3D
		if lever_mesh != null:
			_lever_rest = lever_mesh.transform
	if lever_mesh == null:
		return
	_press_amount = amount
	var angle := atan2(press_travel, knob_z - lever_pivot.z) * amount
	lever_mesh.transform = _lever_rest * Transform3D(Basis.IDENTITY, lever_pivot) \
		* Transform3D(Basis(Vector3.RIGHT, angle), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -lever_pivot)

func get_press_amount() -> float:
	return _press_amount
