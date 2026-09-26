class_name OperatorSeat
extends Node

## The operator's chair, and the reason leaving the desk costs something.
##
## The key only works from this chair. Standing up and sitting back down is about
## a second of real time each way, so every trip to the routing board, the
## ledger, the duty sheet or the window is a wager that the wire will stay quiet.
## That wager is the whole of GDD §3.2 in one interaction.
##
## The body moves as a body: sitting glides the capsule onto the seat, standing
## returns it to a clear spot by the chair — never a teleport, never through
## furniture. The glide is a deterministic clock advanced in _process (the same
## pattern the paper and the writer rig use), not a tween: one transition owns
## the body at a time, and look stays free throughout — a settle that fights
## the mouse cancels itself the moment the player looks.

signal seated()
signal stood()
## Fires when the sit transition has physically finished, not when it began.
## Writing may resume only from here: the hand has a seat to come back to.
signal sit_completed()

enum BodyPhase {
	IDLE,
	SIT_APPROACH,
	STAND_GLIDE,
}

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
## Body approach to the chair, in seconds. The capsule glides to the seat
## instead of snapping: a seated view that starts where the player stood.
@export var approach_duration: float = 0.34
@export var settle_overshoot: float = 0.035
## Distance the body clears the chair when standing, in metres.
@export var stand_clearance: float = 0.85

const PROMPT_SIT: String = "Sit at the Operator's Desk"
const PROMPT_STAND: String = "Stand Up"
const HINT_SEATED: String = "Rise From the Chair  ·  W A S D"

var interactable: Interactable = null
var is_seated: bool = false

var _player: PlayerController = null
var _standing_transform: Transform3D = Transform3D.IDENTITY
var _standing_head_y: float = 1.65
var _chair_collision: CollisionShape3D = null
var _chair_body: PhysicsBody3D = null
## The chair's solid waits to re-arm until the body is clear of its box.
var _chair_reenable_pending: bool = false
var _is_animating: bool = false
## The body glide clock: deterministic, cancellable, one owner at a time.
var _body_phase: BodyPhase = BodyPhase.IDLE
var _body_elapsed: float = 0.0
var _body_duration: float = 0.0
var _sit_start: Transform3D = Transform3D.IDENTITY
var _sit_target: Transform3D = Transform3D.IDENTITY
var _stand_start: Vector3 = Vector3.ZERO
var _stand_target_origin: Vector3 = Vector3.ZERO
## Set the moment the player moves the mouse during a transition: the settle
## stops fighting the hand that is actually holding the camera.
var _user_look: bool = false
## One tween per head channel: a new transition replaces the old, never races it.
var _head_tween: Tween = null
var _pitch_tween: Tween = null

## Sitting down is a transition, not a toggle. Work at the desk — answering the
## wire, resuming the copy — requires the body to have actually arrived.
func is_settled() -> bool:
	return is_seated and not _is_animating and _body_phase == BodyPhase.IDLE

## True while the body is gliding between the chair and a standing spot.
func is_body_moving() -> bool:
	return _body_phase != BodyPhase.IDLE

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
		if _chair_collision != null:
			_chair_body = _chair_collision.get_parent() as PhysicsBody3D
	if office == null:
		office = chair.get_parent() as M1OfficeController

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_user_look = true
		# The posture settle yields to the hand holding the camera.
		if _pitch_tween != null and _pitch_tween.is_valid():
			_pitch_tween.kill()

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
	if _is_animating or _body_phase != BodyPhase.IDLE:
		return
	if is_seated:
		stand()
	else:
		sit()

func sit() -> bool:
	if is_seated or _body_phase != BodyPhase.IDLE:
		return false
	var player := _player_controller()
	var chair := get_parent() as Node3D
	if player == null or chair == null:
		return false

	_standing_transform = player.global_transform
	_standing_head_y = player.head_rest_position.y
	_user_look = false

	# The chair is solid so the operator cannot walk through it; while he is in
	# it, it must not push his own capsule out.
	if _chair_collision != null:
		_chair_reenable_pending = false
		_chair_collision.set_deferred("disabled", true)

	# The body glides onto the seat: no snap. The capsule travel is horizontal
	# toward the chair's own position, so the seated view starts where the
	# player actually stood.
	player.set_walk_locked(true)
	player.set_seated(true)
	_sit_target = Transform3D(Basis(Vector3.UP, deg_to_rad(seat_facing_degrees)), chair.global_position)
	if not is_inside_tree() or approach_duration <= 0.0:
		player.global_transform = _sit_target
		_finish_sit()
		return true
	_is_animating = true
	_sit_start = player.global_transform
	_body_phase = BodyPhase.SIT_APPROACH
	_body_elapsed = 0.0
	_body_duration = approach_duration
	return true

func _finish_sit() -> void:
	var player := _player_controller()
	if player == null:
		return
	player.set_yaw_limit(player.rotation.y, deg_to_rad(look_half_arc_degrees))
	is_seated = true
	_apply_prompt()
	_animate_head_to(seat_eye_height, sit_duration, true)
	_animate_head_pitch(deg_to_rad(seat_pitch_degrees), sit_duration)
	_set_hint(HINT_SEATED)
	_notify_office()
	seated.emit()
	if not is_inside_tree() or sit_duration <= 0.0:
		# No transition to wait for: the seat is ready this instant.
		sit_completed.emit()

## Standing is the same class of motion as sitting: a short glide to a clear
## spot by the chair. The preferred spot is the one the operator stood in
## before; if that is no longer clear, the nearest free point by the chair
## takes the body. Look stays free throughout.
func stand() -> bool:
	if not is_seated or _body_phase != BodyPhase.IDLE:
		return false
	var player := _player_controller()
	if player == null:
		return false

	is_seated = false
	_user_look = false
	player.clear_yaw_limit()
	player.set_walk_locked(false)
	player.set_seated(false)

	var target := _stand_target()
	if not is_inside_tree() or stand_duration <= 0.0:
		player.global_transform = target
		_finish_stand()
		_apply_prompt()
		_animate_head_to(_standing_head_y, stand_duration, false)
		_animate_head_pitch(0.0, stand_duration)
		_set_hint("")
		_notify_office()
		stood.emit()
		return true

	_is_animating = true
	_stand_start = player.global_position
	_stand_target_origin = target.origin
	_body_phase = BodyPhase.STAND_GLIDE
	_body_elapsed = 0.0
	_body_duration = stand_duration
	_apply_prompt()
	_animate_head_to(_standing_head_y, stand_duration, false)
	_animate_head_pitch(0.0, stand_duration)
	_set_hint("")
	_notify_office()
	stood.emit()
	return true

## One step of either glide. The capsule moves only through clear space; a
## blocked candidate simply is not applied, so the body stops at the last
## clear spot instead of passing through furniture.
func _advance_body(delta: float) -> void:
	if _body_phase == BodyPhase.IDLE:
		return
	var player := _player_controller()
	if player == null:
		_cancel_body()
		return
	_body_elapsed += maxf(delta, 0.0)
	var t := clampf(_body_elapsed / maxf(_body_duration, 0.0001), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 2.0)
	if _body_phase == BodyPhase.SIT_APPROACH:
		var candidate := _sit_start.interpolate_with(_sit_target, eased)
		if _transform_clear(candidate):
			player.global_transform = candidate
			# The body turns to face the desk on the way in — unless the
			# player is already looking somewhere else of his own accord.
			if not _user_look:
				player.rotation.y = candidate.basis.get_euler().y
	else:
		var origin := _stand_start.lerp(_stand_target_origin, eased)
		var candidate := Transform3D(player.global_transform.basis, origin)
		if _transform_clear(candidate):
			player.global_transform = candidate
	if t >= 1.0:
		_complete_body()

func _complete_body() -> void:
	var player := _player_controller()
	if _body_phase == BodyPhase.SIT_APPROACH:
		var phase_target := _sit_target
		_body_phase = BodyPhase.IDLE
		if player != null and _transform_clear(phase_target):
			player.global_transform = phase_target
		_finish_sit()
	elif _body_phase == BodyPhase.STAND_GLIDE:
		_body_phase = BodyPhase.IDLE
		if player != null and _transform_clear(Transform3D(player.global_transform.basis, _stand_target_origin)):
			player.global_position = _stand_target_origin
		_finish_stand()

func _cancel_body() -> void:
	_body_phase = BodyPhase.IDLE

## The body has cleared the chair: the seat becomes solid again once the body
## is actually out of its box, and the standing transition is over. The solid
## never re-enables under or beside the capsule — depenetrating the player out
## of the chair would read as a teleport.
func _finish_stand() -> void:
	_body_phase = BodyPhase.IDLE
	_is_animating = false
	_chair_reenable_pending = true

func _maybe_reenable_chair() -> void:
	if not _chair_reenable_pending or _chair_collision == null:
		return
	var chair := get_parent() as Node3D
	var player := _player_controller()
	if chair == null or player == null:
		return
	if player.global_position.distance_to(chair.global_position) < 0.8:
		return
	_chair_reenable_pending = false
	_chair_collision.set_deferred("disabled", false)

## The place the body returns to: the stored standing spot if it is still
## clear, else the nearest free point around the chair.
func _stand_target() -> Transform3D:
	var player := _player_controller()
	var chair := get_parent() as Node3D
	if player == null or chair == null:
		return _standing_transform
	if _transform_clear(_standing_transform):
		return _standing_transform
	var basis := player.global_transform.basis
	var ring_offsets := [
		Vector3(stand_clearance, 0, 0),
		Vector3(0, 0, stand_clearance),
		Vector3(0, 0, -stand_clearance),
		Vector3(-stand_clearance, 0, 0),
	]
	for offset in ring_offsets:
		var candidate := Transform3D(basis, chair.global_position + offset)
		if _transform_clear(candidate):
			return candidate
	# Nothing near is free (an exceptional layout): the stored spot is still
	# the honest answer, and move_and_slide will resolve any overlap.
	return _standing_transform

## True when the player's own capsule fits at a transform without overlapping
## world geometry. The chair itself is excluded while its solid is disabled:
## the body is allowed to be where the chair is during a transition.
func _transform_clear(candidate: Transform3D) -> bool:
	var player := _player_controller()
	if player == null or not player.is_inside_tree():
		return true
	var shape_node := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return true
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape_node.shape
	var shape_offset: Vector3 = shape_node.position
	params.transform = candidate.translated(shape_offset)
	params.exclude = [player.get_rid()]
	if _chair_body != null and _chair_collision != null and _chair_collision.disabled:
		params.exclude.append(_chair_body.get_rid())
	var space := player.get_world_3d().direct_space_state
	if space == null:
		return true
	return space.intersect_shape(params, 8).is_empty()

func _animate_head_to(target_y: float, duration: float, add_settle: bool) -> void:
	var player := _player_controller()
	if player == null:
		return
	if not is_inside_tree() or duration <= 0.0:
		player.set_head_rest_position(Vector3(player.head_rest_position.x, target_y, player.head_rest_position.z))
		return

	_is_animating = true
	var rest := player.head_rest_position
	if _head_tween != null and _head_tween.is_valid():
		_head_tween.kill()
	var tween := create_tween()
	_head_tween = tween
	if add_settle:
		# Drop slightly past the seat then come back up: weight, not a lerp.
		tween.tween_method(_set_head_height, rest.y, target_y - settle_overshoot, duration * 0.78) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_method(_set_head_height, target_y - settle_overshoot, target_y, duration * 0.22) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_method(_set_head_height, rest.y, target_y, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_head_transition_finished)

## The body has arrived wherever it was going. If that was the seat, the
## transition is complete and work at the desk can begin.
func _on_head_transition_finished() -> void:
	if _body_phase != BodyPhase.IDLE:
		return
	_is_animating = false
	if is_seated:
		sit_completed.emit()

## Posture, not a camera lock: the player can look back up the moment he wants
## to. The settle cancels itself on the first real mouse motion so it never
## fights the hand holding the camera.
func _animate_head_pitch(target_radians: float, duration: float) -> void:
	var player := _player_controller()
	if player == null or player.head == null:
		return
	if not is_inside_tree() or duration <= 0.0:
		player.head.rotation.x = target_radians
		return
	if _pitch_tween != null and _pitch_tween.is_valid():
		_pitch_tween.kill()
	_pitch_tween = create_tween()
	_pitch_tween.tween_property(player.head, "rotation:x", target_radians, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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

func _process(delta: float) -> void:
	_advance_body(delta)
	_maybe_reenable_chair()
	if _body_phase == BodyPhase.STAND_GLIDE and _player_wants_to_walk():
		# The player is already carrying the body somewhere: the stand glide
		# steps aside instead of fighting the legs. No snap — the body stays
		# wherever the walk has it.
		_finish_stand()
		return
	if not is_seated or _is_animating or _body_phase != BodyPhase.IDLE:
		return
	# Trying to walk stands the operator up. No extra keybinding, and it is what
	# a player reaches for without being told.
	if _player_wants_to_walk():
		stand()

func _player_wants_to_walk() -> bool:
	if office != null and office.document_viewer != null and office.document_viewer.is_open():
		return false
	if office != null and office.routing_board != null and office.routing_board.is_open:
		return false
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward").length_squared() > 0.01
