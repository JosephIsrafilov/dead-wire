class_name OperatorSeat
extends Node

## The operator's chair, and the reason leaving the desk costs something.
##
## The key only works from this chair. Standing up and sitting back down is about
## a second of real time each way, so every trip to the routing board, the
## ledger, the duty sheet or the window is a wager that the wire will stay quiet.
## That wager is the whole of GDD §3.2 in one interaction.
##
## The transition carries a small settle at the end. Sitting is one of the few
## places a first-person camera can move noticeably without causing discomfort,
## and it hides what would otherwise be a hard cut in eye height.

signal seated()
signal stood()

@export var office: M1OfficeController = null

## Seat surface is at 0.44 m; this is a seated eye above it.
@export var seat_eye_height: float = 1.19
## The chair faces the desk, which is due west of it.
@export var seat_facing_degrees: float = 90.0
## The operator can look over his shoulder, but not spin on the spot.
@export var look_half_arc_degrees: float = 115.0

## A man sitting down at a desk looks at the desk. Without this the seated view
## is a wall with the work somewhere below the bottom of the screen.
@export var seat_pitch_degrees: float = -17.0

@export var sit_duration: float = 0.8
@export var stand_duration: float = 0.6
@export var settle_overshoot: float = 0.035

const PROMPT_SIT: String = "Sit at the Operator's Desk"
const PROMPT_STAND: String = "Stand Up"
const HINT_SEATED: String = "[W A S D] Rise from the chair"

var interactable: Interactable = null
var is_seated: bool = false

var _player: PlayerController = null
var _standing_transform: Transform3D = Transform3D.IDENTITY
var _standing_head_y: float = 1.65
var _chair_collision: CollisionShape3D = null
var _is_animating: bool = false

func _ready() -> void:
	_resolve_nodes()
	_apply_prompt()

func _resolve_nodes() -> void:
	var chair := get_parent()
	if chair == null:
		return
	if interactable == null:
		interactable = chair.get_node_or_null("Interactable") as Interactable
		if interactable != null and not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	if _chair_collision == null:
		_chair_collision = chair.get_node_or_null("ChairSolid/CollisionShape3D") as CollisionShape3D
	if office == null:
		office = chair.get_parent() as M1OfficeController

func get_interactable() -> Interactable:
	_resolve_nodes()
	return interactable

func _player_controller() -> PlayerController:
	if _player != null:
		return _player
	_resolve_nodes()
	if office != null:
		_player = office.player
	return _player

func _apply_prompt() -> void:
	if interactable == null:
		return
	interactable.prompt_text = PROMPT_STAND if is_seated else PROMPT_SIT
	interactable.is_actionable = true

func _on_interacted() -> void:
	if _is_animating:
		return
	if is_seated:
		stand()
	else:
		sit()

func sit() -> bool:
	if is_seated:
		return false
	var player := _player_controller()
	var chair := get_parent() as Node3D
	if player == null or chair == null:
		return false

	_standing_transform = player.global_transform
	_standing_head_y = player.head_rest_position.y

	# The chair is solid so the operator cannot walk through it; while he is in
	# it, it must not push his own capsule out.
	if _chair_collision != null:
		_chair_collision.set_deferred("disabled", true)

	player.global_position = chair.global_position
	player.rotation.y = deg_to_rad(seat_facing_degrees)
	player.set_walk_locked(true)
	player.set_seated(true)
	player.set_yaw_limit(player.rotation.y, deg_to_rad(look_half_arc_degrees))

	is_seated = true
	_apply_prompt()
	_animate_head_to(seat_eye_height, sit_duration, true)
	_animate_head_pitch(deg_to_rad(seat_pitch_degrees), sit_duration)
	_set_hint(HINT_SEATED)
	_notify_office()
	seated.emit()
	return true

func stand() -> bool:
	if not is_seated:
		return false
	var player := _player_controller()
	if player == null:
		return false

	is_seated = false
	player.clear_yaw_limit()
	player.set_walk_locked(false)
	player.set_seated(false)
	player.global_transform = _standing_transform

	if _chair_collision != null:
		_chair_collision.set_deferred("disabled", false)

	_apply_prompt()
	_animate_head_to(_standing_head_y, stand_duration, false)
	_animate_head_pitch(0.0, stand_duration)
	_set_hint("")
	_notify_office()
	stood.emit()
	return true

func _animate_head_to(target_y: float, duration: float, add_settle: bool) -> void:
	var player := _player_controller()
	if player == null:
		return
	if not is_inside_tree() or duration <= 0.0:
		player.set_head_rest_position(Vector3(player.head_rest_position.x, target_y, player.head_rest_position.z))
		return

	_is_animating = true
	var rest := player.head_rest_position
	var tween := create_tween()
	if add_settle:
		# Drop slightly past the seat then come back up: weight, not a lerp.
		tween.tween_method(_set_head_height, rest.y, target_y - settle_overshoot, duration * 0.78) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_method(_set_head_height, target_y - settle_overshoot, target_y, duration * 0.22) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_method(_set_head_height, rest.y, target_y, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _is_animating = false)

## Posture, not a camera lock: the player can look back up the moment he wants to.
func _animate_head_pitch(target_radians: float, duration: float) -> void:
	var player := _player_controller()
	if player == null or player.head == null:
		return
	if not is_inside_tree() or duration <= 0.0:
		player.head.rotation.x = target_radians
		return
	var tween := create_tween()
	tween.tween_property(player.head, "rotation:x", target_radians, duration) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_head_height(value: float) -> void:
	var player := _player_controller()
	if player == null:
		return
	var rest := player.head_rest_position
	player.set_head_rest_position(Vector3(rest.x, value, rest.z))

func _set_hint(text: String) -> void:
	var player := _player_controller()
	if player == null:
		return
	var controller := player.get_node_or_null("InteractionController") as InteractionController
	if controller != null:
		controller.set_persistent_hint(text)

func _notify_office() -> void:
	if office != null and office.shift_director != null:
		office.shift_director.refresh_key_state()

func _process(_delta: float) -> void:
	if not is_seated or _is_animating:
		return
	# Trying to walk stands the operator up. No extra keybinding, and it is what
	# a player reaches for without being told.
	if office != null and office.document_viewer != null and office.document_viewer.is_open():
		return
	if office != null and office.routing_board != null and office.routing_board.is_open:
		return
	if Input.get_vector("move_left", "move_right", "move_forward", "move_backward").length_squared() > 0.01:
		stand()
