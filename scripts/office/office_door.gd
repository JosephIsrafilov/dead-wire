class_name OfficeDoor
extends Node

## The south door: locked for the whole watch, and the way out when it ends.
##
## An operator who can walk out is not under pressure. The door stays shut while
## there is traffic on the wire, and trying it does what trying a locked door
## does — the knob turns a little, the leaf knocks against the jamb, nothing
## opens. Footsteps outside land harder when leaving is not an option.
##
## Nothing here is the Listener. The door is locked because Elias is on shift.

signal door_rattled()
signal door_opened()
signal player_left_office()

@export var director: ShiftDirector = null

@export var locked: bool = true
@export var open_angle_degrees: float = 84.0
@export var open_duration: float = 1.2
@export var rattle_duration: float = 0.34
@export var rattle_knob_degrees: float = 9.0
@export var rattle_leaf_metres: float = 0.009

const PROMPT_LOCKED: String = "Locked — You Are On Shift"
const PROMPT_UNLOCKED: String = "Leave the Office"
const PROMPT_STANDING_OPEN: String = "The Way Out"

var leaf: Node3D = null
var knob: Node3D = null
var blocker: StaticBody3D = null
var interactable: Interactable = null

var is_open: bool = false
var rattle_count: int = 0

var _leaf_rest_z: float = 0.0
var _is_animating: bool = false

func _ready() -> void:
	_resolve_nodes()
	if leaf != null:
		_leaf_rest_z = leaf.position.z
	if director != null and not director.shift_closed.is_connected(_on_shift_closed):
		director.shift_closed.connect(_on_shift_closed)
	_apply_prompt()

func _resolve_nodes() -> void:
	var door := get_parent()
	if door == null:
		return
	if leaf == null:
		leaf = door.get_node_or_null("Leaf") as Node3D
	if knob == null and leaf != null:
		knob = leaf.get_node_or_null("Doorknob") as Node3D
	if blocker == null:
		blocker = door.get_node_or_null("DoorBlocker") as StaticBody3D
	if interactable == null:
		interactable = door.get_node_or_null("Interactable") as Interactable
		if interactable != null and not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	if director == null:
		var office := door.get_parent()
		if office != null:
			director = office.get_node_or_null("ShiftDirector") as ShiftDirector

func get_interactable() -> Interactable:
	_resolve_nodes()
	return interactable

func is_locked() -> bool:
	return locked

func unlock() -> void:
	if not locked:
		return
	locked = false
	_apply_prompt()

func _on_shift_closed() -> void:
	unlock()

func _apply_prompt() -> void:
	_resolve_nodes()
	if interactable == null:
		return
	if is_open:
		interactable.prompt_text = PROMPT_STANDING_OPEN
		interactable.is_actionable = false
	elif locked:
		interactable.prompt_text = PROMPT_LOCKED
		# Still actionable: trying the handle and finding it locked is the point.
		interactable.is_actionable = true
	else:
		interactable.prompt_text = PROMPT_UNLOCKED
		interactable.is_actionable = true

func _on_interacted() -> void:
	if is_open or _is_animating:
		return
	if locked:
		rattle()
	else:
		open()

## The handle turns, the leaf knocks against the jamb, and it does not open.
func rattle() -> void:
	_resolve_nodes()
	rattle_count += 1
	door_rattled.emit()
	if not is_inside_tree():
		return

	_is_animating = true
	var tween := create_tween()
	tween.set_parallel(true)
	if knob != null:
		var twist := deg_to_rad(rattle_knob_degrees)
		tween.tween_property(knob, "rotation:z", -twist, rattle_duration * 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(knob, "rotation:z", 0.0, rattle_duration * 0.65) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if leaf != null:
		tween.tween_property(leaf, "position:z", _leaf_rest_z + rattle_leaf_metres, rattle_duration * 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(leaf, "position:z", _leaf_rest_z, rattle_duration * 0.7) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func() -> void: _is_animating = false)

func open() -> void:
	if locked or is_open:
		return
	_resolve_nodes()
	is_open = true
	_apply_prompt()

	if blocker != null:
		# Deferred: a body may be resting against this shape on the physics thread.
		blocker.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		var shape := blocker.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape != null:
			shape.set_deferred("disabled", true)

	if leaf != null and is_inside_tree():
		_is_animating = true
		var tween := create_tween()
		tween.tween_property(leaf, "rotation:y", -deg_to_rad(open_angle_degrees), open_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void: _is_animating = false)
	elif leaf != null:
		leaf.rotation.y = -deg_to_rad(open_angle_degrees)

	door_opened.emit()

## Called by the threshold trigger once the operator actually steps through.
func notify_player_left() -> void:
	if not is_open:
		return
	player_left_office.emit()
