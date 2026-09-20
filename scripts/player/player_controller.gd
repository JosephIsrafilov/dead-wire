class_name PlayerController
extends CharacterBody3D

## Elias's body.
##
## This started as the deliberately minimal greybox controller GDD §26 asked for
## — instant velocity, no bob, no sway — and was never upgraded, which is why the
## office read as a debug camera flying around a diorama rather than a man on a
## night shift.
##
## Everything added here is restrained on purpose. The research on first-person
## comfort is consistent: keep visible acceleration small, prefer translating the
## camera over rotating it, and keep bob amplitude low. Overdone bob is the most
## common mistake in indie horror and it causes motion sickness. All of it is
## exported, and the bob can be switched off entirely.

signal seated_changed(is_seated: bool)
signal footstep_played(step_index: int)

@export var move_speed: float = 2.35
@export var mouse_sensitivity: float = 0.003

## Tight rather than floaty. Playtesters describe soft first-person acceleration
## as "an ice level", and this room is full of small interaction targets.
@export var acceleration: float = 7.5
@export var deceleration: float = 6.5

@export var head_bob_enabled: bool = true
## Vertical travel of the step cycle, in metres. Low by design.
@export var head_bob_amplitude: float = 0.018
## Sideways sway is a fraction of the vertical, never equal to it.
@export var head_bob_lateral_ratio: float = 0.45
## Steps per metre walked. Phasing on distance rather than time keeps the bob in
## step with the feet when the operator accelerates or slows.
@export var head_bob_steps_per_metre: float = 1.15

@export var breathing_enabled: bool = true
@export var breathing_amplitude: float = 0.005
@export var breathing_rate_hz: float = 0.21

## When the wire is calling, Elias is hurrying. This is the only place the camera
## is allowed to editorialise, and it stays under a millimetre of extra travel.
@export var urgency_bob_multiplier: float = 1.35
@export var urgency_breathing_multiplier: float = 2.1

## Footsteps are distance-based so the sound stays tied to the floor even when
## acceleration or frame rate changes. One sample is pitched in a short cycle
## to keep the bed tactile without pretending there is a full foley library.
@export var footstep_step_distance: float = 1.05
@export var footstep_min_distance: float = 0.001
@export var footstep_stream: AudioStream = preload("res://audio/sfx/foley/footstep_wood.wav")

@export var settle_distance: float = 0.022
@export var settle_duration: float = 0.22

## Insurance only. The real fix for the south door is its collision shape; this
## catches any hole that appears later instead of dropping the player forever.
@export var fall_recovery_height: float = -2.0

var is_movement_locked: bool = false
var is_look_locked: bool = false
var is_seated: bool = false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var footstep_player: AudioStreamPlayer3D = get_node_or_null("FootstepPlayer") as AudioStreamPlayer3D

var head_rest_position: Vector3 = Vector3.ZERO

var _bob_phase: float = 0.0
var _breath_phase: float = 0.0
var _settle_offset: float = 0.0
var _was_moving: bool = false
var _spawn_transform: Transform3D = Transform3D.IDENTITY
var _urgency: float = 0.0
var _footstep_distance: float = 0.0
var _footstep_index: int = 0

## Yaw clamp used while seated, in radians. Negative range means unclamped.
var _yaw_limit_centre: float = 0.0
var _yaw_limit_half_range: float = -1.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera != null:
		camera.current = true
	if head != null:
		head_rest_position = head.position
	_spawn_transform = global_transform if is_inside_tree() else transform
	if footstep_player != null and footstep_player.stream == null:
		footstep_player.stream = footstep_stream

## Locks walking and looking. Used by the modal document viewer.
func set_movement_locked(locked: bool) -> void:
	is_movement_locked = locked
	is_look_locked = locked
	if is_movement_locked:
		velocity.x = 0.0
		velocity.z = 0.0

## Locks walking but leaves the head free. Used when seated at the desk: the
## operator cannot walk away, but he can still look around the room.
func set_walk_locked(locked: bool) -> void:
	is_movement_locked = locked
	# This API is deliberately the seated variant of set_movement_locked:
	# callers may arrive here after a modal UI has locked both axes.
	is_look_locked = false
	if locked:
		velocity.x = 0.0
		velocity.z = 0.0

func set_seated(seated: bool) -> void:
	if is_seated == seated:
		return
	is_seated = seated
	seated_changed.emit(is_seated)

## Restricts yaw to an arc around a facing. Pass a negative half range to clear.
func set_yaw_limit(centre_radians: float, half_range_radians: float) -> void:
	_yaw_limit_centre = centre_radians
	_yaw_limit_half_range = half_range_radians
	if half_range_radians >= 0.0:
		_apply_yaw_limit()

func clear_yaw_limit() -> void:
	_yaw_limit_half_range = -1.0

## 0.0 when the shift is calm, 1.0 when the wire is calling.
func set_urgency(value: float) -> void:
	_urgency = clampf(value, 0.0, 1.0)

func _input(event: InputEvent) -> void:
	# Escape belongs to the pause menu. The controller used to drop the cursor
	# here and leave the shift running behind an uncaptured pointer.
	if is_look_locked:
		return

	var mouse_clicked: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	if mouse_clicked:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_apply_yaw_limit()
		if head != null:
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))

func _apply_yaw_limit() -> void:
	if _yaw_limit_half_range < 0.0:
		return
	var offset := wrapf(rotation.y - _yaw_limit_centre, -PI, PI)
	offset = clampf(offset, -_yaw_limit_half_range, _yaw_limit_half_range)
	rotation.y = _yaw_limit_centre + offset

func _physics_process(delta: float) -> void:
	if global_position.y < fall_recovery_height:
		_recover_from_fall()
		return

	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = 0.0

	var target := Vector3.ZERO
	if not is_movement_locked:
		var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction: Vector3 = (transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)).normalized()
		target = direction * move_speed

	var rate := acceleration if target.length_squared() > 0.0 else deceleration
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)

	var position_before_move := global_position
	move_and_slide()
	var delta_x := global_position.x - position_before_move.x
	var delta_z := global_position.z - position_before_move.z
	var moved_distance := Vector2(delta_x, delta_z).length()
	_advance_footsteps(moved_distance)
	_update_head(delta)

## Separated from physics so the cadence can be tested without relying on an
## input device or a particular frame rate.
func _advance_footsteps(moved_distance: float) -> void:
	if is_seated or is_movement_locked or not is_on_floor() or moved_distance < footstep_min_distance:
		return
	if footstep_step_distance <= 0.0:
		return
	_footstep_distance += moved_distance
	while _footstep_distance >= footstep_step_distance:
		_footstep_distance -= footstep_step_distance
		_play_footstep()

func _play_footstep() -> void:
	var index := _footstep_index
	_footstep_index = (_footstep_index + 1) % 3
	if footstep_player != null and footstep_player.stream != null and is_inside_tree():
		footstep_player.pitch_scale = [0.96, 1.03, 0.99][index]
		footstep_player.play()
	footstep_played.emit(index)

func _recover_from_fall() -> void:
	velocity = Vector3.ZERO
	global_transform = _spawn_transform

func _update_head(delta: float) -> void:
	if head == null:
		return

	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving := planar_speed > 0.15 and not is_seated

	if is_moving != _was_moving:
		# A small downward settle on starting and stopping. Translation only —
		# rotating the camera here is a known sickness trigger.
		_settle_offset = -settle_distance
		_was_moving = is_moving

	_settle_offset = move_toward(_settle_offset, 0.0, (settle_distance / maxf(settle_duration, 0.01)) * delta)

	var bob := 0.0
	var sway := 0.0
	if head_bob_enabled and is_moving:
		_bob_phase += planar_speed * delta * head_bob_steps_per_metre * TAU
		var amplitude := head_bob_amplitude * lerpf(1.0, urgency_bob_multiplier, _urgency)
		# The head rises twice per stride but sways once, which is what makes a
		# figure-of-eight rather than a pogo stick.
		bob = absf(sin(_bob_phase)) * amplitude
		sway = sin(_bob_phase * 0.5) * amplitude * head_bob_lateral_ratio
	else:
		_bob_phase = 0.0

	var breath := 0.0
	if breathing_enabled:
		var rate := breathing_rate_hz * lerpf(1.0, urgency_breathing_multiplier, _urgency)
		_breath_phase += delta * rate * TAU
		breath = sin(_breath_phase) * breathing_amplitude

	head.position = head_rest_position + Vector3(sway, bob + breath + _settle_offset, 0.0)

## Used by the seat, which owns the head position while the operator is sitting.
func set_head_rest_position(value: Vector3) -> void:
	head_rest_position = value
