class_name LooseProp
extends RigidBody3D

## A small object the operator can actually disturb.
##
## Two rules make this safe to have in a room built almost entirely from static
## geometry, and both are enforced here rather than left to whoever places one:
##
## 1. **It rests until something touches it.** Every instance is authored in
##    place, then put to sleep on the first frame. Without that, Jolt settles the
##    body by a few millimetres on load and a cup visibly twitches on spawn.
##
## 2. **It can be put back.** The room is a fixed set of authored props and the
##    night restarts; anything knocked under the filing table would otherwise be
##    gone for the rest of the watch with no way to restore it for a fresh one.
##
## Nothing here reads or writes game state. A prop that is moved is a prop that
## is moved: it cannot reach the session, the tape or the shift.

signal settled
## Something hit this prop hard enough to be heard. `strength` is the speed lost
## in the collision, in m/s, so a caller can scale the sound by it.
signal impacted(strength: float)

## Mass in kilograms. 1894 depot items, not game units: a tin cup is 0.12, a
## full ink bottle 0.20, a coal scuttle about 3.
@export var prop_mass: float = 0.15
## Restitution. Enamel on boards barely bounces; glass does a little.
@export var prop_bounce: float = 0.08
## Sliding friction against the floor.
@export var prop_friction: float = 0.65
## Below this the body is considered parked and may sleep.
@export var sleep_threshold: float = 0.02
## Below this a collision is sliding, not an impact. 0.35 m/s is about the speed
## a cup reaches being nudged sideways by a knee; anything slower is the prop
## creeping and must not tick.
@export var impact_min_speed: float = 0.35

var _rest_transform: Transform3D = Transform3D.IDENTITY
var _rest_taken: bool = false
## Speed on the previous physics frame, so an impact can be measured as the
## speed a collision actually took away rather than as an absolute velocity.
var _previous_speed: float = 0.0

func _ready() -> void:
	mass = maxf(prop_mass, 0.001)
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = clampf(prop_bounce, 0.0, 1.0)
	physics_material_override.friction = clampf(prop_friction, 0.0, 2.0)
	can_sleep = true
	# Contacts are needed for the impact sound: `state.get_contact_count()` is
	# always zero without a monitor and a report budget.
	contact_monitor = true
	max_contacts_reported = 2
	# Authored in place: capture that pose and park the body on it.
	_rest_transform = global_transform
	_rest_taken = true
	sleeping = true
	# The body is asleep before the first physics step, so it does not settle
	# even a millimetre on load.
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Cheap guard against tunnelling through a floor that was authored thin.
	if state.transform.origin.y < -1.0:
		state.transform = _rest_transform
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_previous_speed = 0.0
		return
	# Contact sound: what a collision is worth hearing is the speed it removed.
	# Reading an absolute velocity instead would make the initial settle tick,
	# because a body resting on the floor also has contacts.
	var speed := state.linear_velocity.length()
	if state.get_contact_count() > 0:
		var lost := _previous_speed - speed
		if lost >= impact_min_speed:
			impacted.emit(lost)
	_previous_speed = speed

## Put the prop back where the room authored it. Used when a new watch starts,
## so a cup kicked under the table is not missing for the rest of the game.
func reset_to_rest() -> void:
	if not _rest_taken:
		return
	global_transform = _rest_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true

## True while the prop is exactly where it was authored, to within `tolerance`.
## Tests and the repair pass use this instead of comparing transforms by hand.
func is_at_rest(tolerance: float = 0.005) -> bool:
	if not _rest_taken:
		return true
	if global_position.distance_to(_rest_transform.origin) > tolerance:
		return false
	return global_basis.get_rotation_quaternion().angle_to(
		_rest_transform.basis.get_rotation_quaternion()) <= tolerance

## Wakes the body so a push is not swallowed by its sleep state.
func wake() -> void:
	sleeping = false

func _process(_delta: float) -> void:
	if sleeping and not _was_sleeping:
		_was_sleeping = true
		settled.emit()
	elif not sleeping:
		_was_sleeping = false

var _was_sleeping: bool = false
