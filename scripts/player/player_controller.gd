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

@export var move_speed: float = 1.35
@export var mouse_sensitivity: float = 0.003
## Player option (plan 6.8): pushing the mouse forward looks down.
@export var invert_y: bool = false

## Tight rather than floaty. Playtesters describe soft first-person acceleration
## as "an ice level", and this room is full of small interaction targets.
@export var acceleration: float = 4.5
@export var deceleration: float = 8.0

@export var head_bob_enabled: bool = true
## Vertical travel of the step cycle, in metres. Low by design.
@export var head_bob_amplitude: float = 0.024
## Sideways sway is a fraction of the vertical, never equal to it.
@export var head_bob_lateral_ratio: float = 0.45

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
@export var footstep_step_distance: float = 0.65
@export var footstep_min_distance: float = 0.001
@export var footstep_stream: AudioStream = preload("res://audio/sfx/foley/footstep_wood_beta.wav")

@export var settle_distance: float = 0.022
@export var settle_duration: float = 0.22

## Insurance only. The real fix for the south door is its collision shape; this
## catches any hole that appears later instead of dropping the player forever.
@export var fall_recovery_height: float = -2.0

## Walking into a loose prop moves it. A CharacterBody3D in Godot 4 does not
## push rigid bodies on its own: move_and_slide reports the contact and stops,
## so without this the office is a room of statues that Elias walks through.
## The arithmetic lives in PushImpulse; the switch lives here.
@export var push_enabled: bool = true
@export var push_transfer: float = PushImpulse.TRANSFER
@export var push_max_impulse: float = PushImpulse.MAX_IMPULSE
@export var push_contact_seconds: float = PushImpulse.CONTACT_SECONDS

## Leaning in: hold the lean action and the head goes forward and a little down
## toward whatever Elias is looking at — the live copy, the window glass, the
## crack of the door. Translation only, eased, and stopped short of any surface.
@export var lean_enabled: bool = true
@export var lean_distance: float = 0.26
@export var lean_drop: float = 0.09
@export var lean_seconds: float = 0.3
## The camera stops this far short of whatever the lean would push it into.
@export var lean_clearance: float = 0.12
## Leaning in narrows the view a little, the way peering does (plan 3.8).
@export var lean_fov_narrowing: float = 8.0
## The player's chosen field of view; the lean narrows from it, never compounds.
var base_fov: float = 65.0
var _fov_leaning: bool = false

var is_movement_locked: bool = false
var is_look_locked: bool = false
var is_seated: bool = false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var footstep_player: AudioStreamPlayer3D = get_node_or_null("FootstepPlayer") as AudioStreamPlayer3D
## Bob weight change per second: ~0.15 s to fade a stride out when the body stops.
const BOB_FADE_RATE: float = 7.0
## The authored footstep level; each step varies around it.
var footstep_base_db: float = -13.0

var head_rest_position: Vector3 = Vector3.ZERO

var _bob_phase: float = 0.0
## 0..1: the stride fades in and out instead of snapping when the body stops.
var _bob_weight: float = 0.0
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
var _camera_rest_transform := Transform3D.IDENTITY
## 0..1, eased toward the lean action; read by the camera pose every frame.
var _lean_weight: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera != null:
		camera.current = true
		base_fov = camera.fov
		_camera_rest_transform = camera.transform
		camera.top_level = true
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		# Follow the interpolated position after the frame-driven chair pose.
		process_priority = 10
	if head != null:
		head_rest_position = head.position
	_spawn_transform = global_transform if is_inside_tree() else transform
	if footstep_player != null:
		footstep_base_db = footstep_player.volume_db
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
		_apply_mouse_look(event.relative)

func _apply_mouse_look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	_apply_yaw_limit()
	if head != null:
		head.rotate_x((relative.y if invert_y else -relative.y) * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	_update_camera_pose()

## Turns the body and head toward a world point. The camera is driven from the
## head every frame, so aiming the camera node directly would not stick.
func aim_at(point: Vector3) -> void:
	if head == null:
		return
	var to_point := point - head.global_position
	if to_point.length_squared() < 0.000001:
		return
	rotation.y = atan2(-to_point.x, -to_point.z)
	_apply_yaw_limit()
	var flat := Vector2(to_point.x, to_point.z).length()
	head.rotation.x = clampf(atan2(to_point.y, flat), deg_to_rad(-85.0), deg_to_rad(85.0))
	_update_camera_pose()

func _process(delta: float) -> void:
	var wants_lean := lean_enabled and not is_look_locked \
		and InputMap.has_action("lean") and Input.is_action_pressed("lean")
	_lean_weight = move_toward(_lean_weight, 1.0 if wants_lean else 0.0, delta / maxf(lean_seconds, 0.01))
	_update_camera_pose()

func get_lean_weight() -> float:
	return _lean_weight

func _update_camera_pose() -> void:
	if camera == null or head == null:
		return
	# Position follows the rendered body; mouse orientation has no tick delay.
	var origin := head.get_global_transform_interpolated().origin
	origin += head.global_basis * _camera_rest_transform.origin
	origin += _lean_offset(origin)
	camera.global_transform = Transform3D(head.global_basis * _camera_rest_transform.basis, origin)
	# The lean owns the FOV only while it is in use; otherwise whoever set it last
	# (settings, a capture tool) keeps it.
	if _lean_weight > 0.0:
		camera.fov = base_fov - lean_fov_narrowing * smoothstep(0.0, 1.0, _lean_weight)
		_fov_leaning = true
	elif _fov_leaning:
		camera.fov = base_fov
		_fov_leaning = false

func _lean_offset(origin: Vector3) -> Vector3:
	if _lean_weight <= 0.0:
		return Vector3.ZERO
	var forward := -head.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		return Vector3.ZERO
	var reach := forward.normalized() * lean_distance + Vector3.DOWN * lean_drop
	var eased := smoothstep(0.0, 1.0, _lean_weight)
	var length := reach.length()
	if is_inside_tree() and length > 0.0:
		# Never into the wall, the glass or the desk: stop short of the first hit.
		var query := PhysicsRayQueryParameters3D.create(origin, origin + reach / length * (length + lean_clearance))
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var room := maxf(0.0, origin.distance_to(hit.position) - lean_clearance)
			reach *= minf(1.0, room / length)
	return reach * eased

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
	_push_loose_bodies(delta)
	var delta_x := global_position.x - position_before_move.x
	var delta_z := global_position.z - position_before_move.z
	var moved_distance := Vector2(delta_x, delta_z).length()
	_advance_footsteps(moved_distance)
	_update_head(delta, moved_distance)

## Shove anything loose the capsule is leaning on. move_and_slide leaves the
## player stopped against a rigid body and hands us the contact, so this is the
## one place that turns "the body is walking" into "the object moves".
##
## The per-frame impulse is scaled by delta (see PushImpulse) so a contact that
## lasts nine frames delivers one shove, not nine.
func _push_loose_bodies(delta: float) -> void:
	if not push_enabled or delta <= 0.0:
		return
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var speed := planar.length()
	if speed < PushImpulse.MIN_SPEED:
		return
	var direction := planar / speed
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision == null:
			continue
		var body := collision.get_collider() as RigidBody3D
		if body == null or body.freeze:
			continue
		var impulse := PushImpulse.frame_impulse(
			body.mass, speed, delta, push_transfer, push_max_impulse, push_contact_seconds)
		if impulse <= 0.0:
			continue
		if body.has_method("wake"):
			body.call("wake")
		# Push along the walk and slightly downward: the contact point is
		# usually above the object's centre of mass, so a purely horizontal
		# shove would make a mug slide instead of tipping.
		var shove := (direction + Vector3.DOWN * 0.15).normalized()
		body.apply_impulse(shove * impulse, collision.get_position() - body.global_position)

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
		footstep_player.pitch_scale = [0.96, 1.03, 0.99][index] + randf_range(-0.02, 0.02)
		footstep_player.volume_db = footstep_base_db + randf_range(-1.5, 1.0)
		footstep_player.play()
	footstep_played.emit(index)

func _recover_from_fall() -> void:
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	reset_physics_interpolation()

func _update_head(delta: float, moved_distance: float = -1.0) -> void:
	if head == null:
		return

	var planar_speed := Vector2(velocity.x, velocity.z).length()
	# Production supplies actual floor travel, not intended velocity into a wall.
	var travel := planar_speed * delta if moved_distance < 0.0 else moved_distance
	var is_moving := travel > footstep_min_distance and not is_seated

	if is_moving != _was_moving:
		# A small downward settle on starting and stopping. Translation only —
		# rotating the camera here is a known sickness trigger.
		_settle_offset = -settle_distance
		# The last foot comes down when the body stops mid-stride.
		if not is_moving and not is_seated and not is_movement_locked \
				and is_on_floor() and _footstep_distance > footstep_step_distance * 0.35:
			_footstep_distance = 0.0
			_play_footstep()
		_was_moving = is_moving

	_settle_offset = move_toward(_settle_offset, 0.0, (settle_distance / maxf(settle_duration, 0.01)) * delta)

	var bob := 0.0
	var sway := 0.0
	_bob_weight = move_toward(_bob_weight, 1.0 if (head_bob_enabled and is_moving) else 0.0, BOB_FADE_RATE * delta)
	if head_bob_enabled and is_moving:
		_bob_phase += travel / footstep_step_distance * TAU
	if _bob_weight > 0.0:
		var amplitude := head_bob_amplitude * lerpf(1.0, urgency_bob_multiplier, _urgency) * _bob_weight
		# Each footfall is the low point; lateral weight shifts once per stride.
		bob = (0.5 - 0.5 * cos(_bob_phase)) * amplitude
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
