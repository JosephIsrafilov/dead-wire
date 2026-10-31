class_name HangingCoat
extends MeshInstance3D

## The operator's tailored wool coat follows a small Verlet cloth cage.
## Rendering uses the owner-selected Blender garment, including stitched sleeves;
## the cage alone handles weight, passing bodies, drafts and returning to sleep.

const CoatMeshBinding = preload("res://scripts/office/coat_mesh_binding.gd")
const AUTHORED_COAT = preload("res://assets/models/office_props_v1/coat_tailored.glb")

## Rows down the coat and columns around it. 8 x 12 is 96 particles and ~336
## constraints: about 1000 constraint solves a frame over 4 iterations, which is
## nothing next to the room's lighting, and enough resolution that the hem can
## form more than one fold.
@export var rings: int = 8
@export var segments: int = 12

## Emitted when the garment is set moving hard enough to be heard. `strength` is
## 0..1, so a caller can scale the rustle instead of playing one fixed sample.
signal rustled(strength: float)

## Where the coat hangs from. `coat_x` is the hook's position across the wall and
## `coat_z` is the depth plane the collar sits on; the vertical positions come
## from PROFILE, which is why they are not repeated here.
@export var coat_x: float = -0.350
@export var coat_z: float = 2.198

## Gravity, in m/s^2. Deliberately stronger than 9.8: a heavy wool coat on a
## hook reads as slow, upright cloth, not as a flag, and a heavier field keeps
## the folds shallow and vertical instead of billowing.
@export var gravity: float = 11.5
## Velocity retained per 120 Hz step; 0.97 leaves about 3% after one second.
@export var damping: float = 0.97
## Relaxation passes per step. More is stiffer and costs linearly. Six rather
## than four: a strong shove with four left the cloth visibly stretched between
## constraint rows, which reads as tearing rather than as fabric moving.
@export var iterations: int = 6
## Bending stiffness. Softer than the structural constraints so the coat creases
## where cloth creases rather than exactly between constraint rows.
@export var bend_stiffness: float = 0.22
## Circumferential bending: column i to column i+2 within a ring.
##
## Without this the coat collapses. Measured with tools/coat_probe.gd: the hem
## ring went from 0.397 m wide to 0.207 in sixty steps while its depth grew from
## 0.178 to 0.219 — the ellipse flattened into a ribbon while keeping roughly
## the same perimeter, which is exactly what a chain of adjacent-column links
## permits. A ring of only-adjacent constraints is a floppy polygon: it can fold
## at every vertex and still satisfy every rest length. Linking two columns
## apart pins the ring's curvature, because an ellipse and a folded line have
## very different two-apart chords even when their perimeters match.
@export var ring_bend_stiffness: float = 0.45

## How far into the room the coat may swing before the wall stops it. The south
## wall's room face is z = 2.30 and the rack board stands at 2.271..2.295.
##
## This must sit BEHIND the coat's own rest pose or the clamp fights the
## constraint solver every frame. The hem's back section is at z 2.289, so a
## limit of 2.286 was permanently clamping cloth that was already in the right
## place, which is a second source of the shudder the operator could see.
@export var wall_limit_z: float = 2.298

## Restoring acceleration per metre from the authored drape, in s^-2.
## TAU squared gives a one-second undamped spring period. Using the settled
## pose as its target would apply gravity twice and make each wake sag farther.
@export var shape_memory: float = TAU * TAU

## The coat may only stop simulating once it is both still AND back within this
## many metres of the drape it was hung in. Freezing on velocity alone locked it
## into whatever deformed pose a brush left behind, because a frozen coat skips
## the shape memory that would have drawn it home.
const FREEZE_SHAPE_TOLERANCE: float = 0.004
## Sleeping needs low speed as well as proximity, not just a swing turning point.
const FREEZE_STEP_TOLERANCE: float = 0.00002

## Radius, in metres, within which a passing body disturbs the cloth.
##
## Measured with tools/coat_flail_probe.gd. The original 1.35 was the flail bug —
## but only because the push was repeated every frame; with the rising-edge gate
## below, a wide radius is safe and is what makes the coat answer a man walking
## past at arm's length rather than only one who walks into it.
@export var disturbance_radius: float = 0.95
## Speed the body needs to be moving for it to count as "passing".
@export var disturbance_min_speed: float = 0.25
## How hard a passing body throws the hem, as a fraction of its own speed.
##
## This can be generous now that a pass only shoves once. Every earlier attempt
## to make the coat answer visibly had to be dialled down because the push was
## being applied continuously; with the rising-edge gate the magnitude is a
## single impulse and 0.45 reads as a heavy coat taking a shoulder, not as wind.
@export var disturbance_strength: float = 0.45
## One shove per pass. Without this the coat is re-shoved every frame the body
## stays in range, which is the same hurricane by another route.
@export var pass_cooldown_seconds: float = 1.1
## Below this a push is too gentle to be heard. Tuned against the actual push:
## a man walking past produces ~0.15 at the hem, so 0.05 leaves it audible while
## a knee brushed against the cloth stays silent.
@export var rustle_min_strength: float = 0.05
const RUSTLE_COOLDOWN_SECONDS: float = 0.45
var _rustle_cooldown: float = 0.0
## True while the body that shoved the coat is still inside the radius, so the
## same pass cannot shove it twice.
var _in_range: bool = false
var _pass_cooldown: float = 0.0

## The player, used only to decide whether the coat was walked past. Resolved
## from the scene when not set.
@export var player: PlayerController = null

## Profile of the coat from the collar down: y is absolute, hw/hd are the
## half-width and half-depth of that section. These are the numbers the authored
## coat used (it was 0.37 m across and 0.17 m deep at the chest, tapering to a
## 0.41 m hem) so the simulation hangs the garment the room already had.
const PROFILE: Array = [
	# y, half_width, half_depth
	[1.985, 0.078, 0.052],   # collar, supported at the rear loop
	[1.952, 0.170, 0.070],   # shoulder line
	[1.865, 0.183, 0.082],   # chest
	[1.700, 0.154, 0.066],   # waist
	[1.530, 0.172, 0.076],
	[1.355, 0.190, 0.084],   # skirt
	[1.260, 0.200, 0.090],
	[1.195, 0.203, 0.091],   # hem
]

## Rounded-rectangle section: a coat has corners, not the constant curvature of
## a lathe. Mirrors cloth_outline() in tools/build_office_props_blender.py.
static func section_point(index: int, count: int) -> Vector2:
	var theta := TAU * (float(index) + 0.5) / float(count)
	var c := cos(theta)
	var s := sin(theta)
	return Vector2(
		signf(c) * pow(absf(c), 2.0 / 3.0),
		signf(s) * pow(absf(s), 2.0 / 3.0))

var _pos: PackedVector3Array = PackedVector3Array()
var _prev: PackedVector3Array = PackedVector3Array()
var _rest: PackedVector3Array = PackedVector3Array()
## (a, b, rest_length, stiffness)
var _constraints: Array[PackedFloat32Array] = []
var _constraint_indices: Array[Vector2i] = []
var _mesh: ArrayMesh = null
var _binding: RefCounted

## Pending velocity change in m/s at each particle (e.g. from a passer-by).
var _impulse: PackedVector3Array = PackedVector3Array()
## Particle positions the current mesh was built from, so a settled coat can skip
## the rebuild entirely.
var _built_positions: PackedVector3Array = PackedVector3Array()
## True once the cloth has stopped moving; cleared by any push.
var _frozen: bool = false
## The pose the coat first settles into, which is the pose it is expected to
## return to. Captured once; empty until the first settle.
var _home: PackedVector3Array = PackedVector3Array()

func _ready() -> void:
	_build_particles()
	_build_constraints()
	# Bind the selected drape to a settled cage, not to its falling startup pose.
	for tick in 600:
		step(SIM_STEP)
		if _frozen:
			break
	_binding = CoatMeshBinding.new(AUTHORED_COAT, _pos, Vector3(coat_x, 0.0, coat_z))
	_mesh = ArrayMesh.new()
	mesh = _mesh
	_rebuild_mesh()

func _resolve_player() -> void:
	if player != null:
		return
	var node := get_parent()
	while node != null and player == null:
		player = node.get_node_or_null("Player") as PlayerController
		node = node.get_parent()

func _particle_index(ring: int, column: int) -> int:
	return ring * segments + (column % segments)

func _build_particles() -> void:
	_pos.resize(rings * segments)
	_prev.resize(rings * segments)
	_rest.resize(rings * segments)
	_impulse.resize(rings * segments)
	_impulse.fill(Vector3.ZERO)
	for r in rings:
		# Rings are spread across the profile table so the simulated coat keeps
		# the authored shoulder/waist/hem distribution.
		var t := float(r) / float(maxi(rings - 1, 1))
		var p := _sample_profile(t)
		var centre_y: float = p[0]
		var half_width: float = p[1]
		var half_depth: float = p[2]
		for c in segments:
			var section := section_point(c, segments)
			var point := Vector3(
				coat_x + section.x * half_width,
				centre_y,
				coat_z + section.y * half_depth)
			var index := _particle_index(r, c)
			if r == 0:
				if _is_pinned(index):
					# A narrow loop at the back, rather than an invisible coat hanger.
					point.x = coat_x + section.x * 0.025
					point.y = 2.022
					point.z = coat_z + section.y * 0.016
				else:
					point.y -= 0.045 * maxf(0.0, -section.y)
			elif r == 1:
				point.y -= 0.060 * absf(section.x)
			elif r >= 3 and c == segments * 2 / 3:
				# One off-centre fold opens toward the hem.
				point.z -= 0.024 * t
			# The fronts meet at the waist, then part again below the fastening.
			var front_column := int(float(segments) * 0.75) - 1
			if c == front_column or c == front_column + 1:
				var opening := 0.004 + 0.054 * pow(maxf(0.0, 1.0 - t * 2.5), 2.0)
				opening += 0.032 * pow(maxf(0.0, (t - 0.5) * 2.0), 2.0)
				point.x = coat_x + (-opening if c == front_column else opening)
			_pos[index] = point
			_prev[index] = point
			_rest[index] = point

## Linear sample of the profile at `t` in 0..1 from collar to hem.
func _sample_profile(t: float) -> Array:
	var span := float(PROFILE.size() - 1)
	var scaled := clampf(t, 0.0, 1.0) * span
	var lower := int(floor(scaled))
	var upper := mini(lower + 1, PROFILE.size() - 1)
	var frac := scaled - float(lower)
	var a: Array = PROFILE[lower]
	var b: Array = PROFILE[upper]
	return [
		lerpf(a[0], b[0], frac),
		lerpf(a[1], b[1], frac),
		lerpf(a[2], b[2], frac),
	]

func _build_constraints() -> void:
	_constraint_indices.clear()
	_constraints.clear()
	for r in rings:
		for c in segments:
			# Vertical: carries the weight.
			if r + 1 < rings:
				_link(_particle_index(r, c), _particle_index(r + 1, c), 1.0)
			# Ring: holds the circumference.
			_link(_particle_index(r, c), _particle_index(r, c + 1), 1.0)
			# Ring bend: holds the SECTION, not just the perimeter. This is the
			# constraint that stops the coat flattening into a ribbon.
			_link(_particle_index(r, c), _particle_index(r, c + 2), ring_bend_stiffness)
			# Shear both ways: keeps the grid from folding onto its own axes.
			if r + 1 < rings:
				_link(_particle_index(r, c), _particle_index(r + 1, c + 1), 0.8)
				_link(_particle_index(r, c + 1), _particle_index(r + 1, c), 0.8)
			# Bend: softer, two rings apart.
			if r + 2 < rings:
				_link(_particle_index(r, c), _particle_index(r + 2, c), bend_stiffness)

func _link(a: int, b: int, stiffness: float) -> void:
	var rest := _rest[a].distance_to(_rest[b])
	if rest <= 0.0001:
		return
	_constraint_indices.append(Vector2i(a, b))
	_constraints.append(PackedFloat32Array([rest, stiffness]))

## The solver's fixed timestep, in seconds.
##
## WHY THIS EXISTS
## ---------------
## The solver used to run once per rendered frame, with `damping`, the shape
## memory and every constraint pass applied per CALL rather than per second.
## Nothing in it was normalised by time except gravity, so the same shove from
## the same start left the hem 59.7 mm out after half a second at 30 Hz and
## 7.6 mm at 144 Hz: the garment was four times softer on a slow machine, and
## the "1/30 clamp" did not compensate for the time a long frame overran, it
## simply discarded it.
##
## Now the cloth always advances in units of this step. A frame contributes as
## many whole steps as it actually took, so 30 Hz, 60 Hz and 144 Hz all run the
## same physics — they only differ in how many steps each frame asks for.
const SIM_STEP: float = 1.0 / 120.0
## Ceiling on steps per call. A stalled frame must not turn into a hundred
## solver passes and a visible teleport; past this the cloth gives up the extra
## time, which is what a real deadline does. 0.25 s of hitch still simulates.
const MAX_STEPS_PER_CALL: int = 30
## Leftover time from the last call, in seconds. Never more than one step: the
## remainder is what keeps 144 Hz from losing a fraction of every frame.
var _step_accumulator: float = 0.0

## One simulation step, separated from _process so tests can drive it
## deterministically without waiting on real frames.
##
## `delta` is wall-clock time. It is converted into a whole number of fixed
## SIM_STEP advances, and the remainder is carried into the next call.
func step(delta: float) -> void:
	if delta <= 0.0 or _pos.is_empty():
		return
	# A coat hanging on a hook is motionless for most of the watch. Once it has
	# settled and nothing is pushing it, the solver has no work to do: skip it
	# entirely rather than solving ~2600 constraints a frame to reproduce the
	# pose already on screen. `disturb` and `draft` clear the freeze.
	if _frozen and not _has_pending_impulse():
		return
	_step_accumulator += delta
	var steps := int(_step_accumulator / SIM_STEP)
	if steps <= 0:
		return
	steps = mini(steps, MAX_STEPS_PER_CALL)
	_step_accumulator -= float(steps) * SIM_STEP
	# A capped call drops the time it could not simulate rather than banking it:
	# otherwise one hitch is followed by a burst of catch-up steps the next frame.
	if _step_accumulator > SIM_STEP * float(MAX_STEPS_PER_CALL):
		_step_accumulator = 0.0
	var dt := SIM_STEP
	var gravity_step := Vector3.DOWN * gravity * dt * dt
	for _substep in steps:
		_apply_shape_memory()
		for index in _pos.size():
			if _is_pinned(index):
				continue
			_prev[index] -= _impulse[index] * dt
			var velocity := (_pos[index] - _prev[index]) * damping
			_prev[index] = _pos[index]
			_pos[index] += velocity + gravity_step
			_impulse[index] = Vector3.ZERO
		for _pass in iterations:
			_solve_constraints()
		_apply_wall()
	# The authored mesh is rebuilt only while the cage moves; most of the
	# watch the coat sleeps and reuses its existing surfaces.
	if _moved_since_build():
		_rebuild_mesh()
	# A settled coat also has to be back near the shape it was hung in before the
	# solver may stop: freezing on velocity alone locked it into whatever
	# deformed pose a brush had left it in, because the freeze skips the shape
	# memory that would have drawn it home.
	if _home.is_empty() and is_settled(FREEZE_STEP_TOLERANCE):
		_home = _pos.duplicate()
	_frozen = is_settled(FREEZE_STEP_TOLERANCE) and _shape_error() < FREEZE_SHAPE_TOLERANCE

## True while any particle still carries an external push this step.
func _has_pending_impulse() -> bool:
	for value in _impulse:
		if value.length_squared() > 0.0:
			return true
	return false

## True when any particle has drifted far enough since the last mesh build that
## the rendered pose is out of date.
func _moved_since_build() -> bool:
	if _built_positions.size() != _pos.size():
		return true
	for index in _pos.size():
		if _pos[index].distance_squared_to(_built_positions[index]) > 0.00000001:
			return true
	return false

## Only the four points nearest the back of the collar attach to the loop.
func _is_pinned(index: int) -> bool:
	var back_column := float(segments) * 0.25 - 0.5
	return index < segments and absf(float(index) - back_column) < 2.0

func _solve_constraints() -> void:
	for i in _constraint_indices.size():
		var pair := _constraint_indices[i]
		var data := _constraints[i]
		var a := pair.x
		var b := pair.y
		var rest := data[0]
		var stiffness := data[1]
		var delta_vec := _pos[b] - _pos[a]
		var distance := delta_vec.length()
		if distance <= 0.00001:
			continue
		var correction := delta_vec * ((distance - rest) / distance) * 0.5 * stiffness
		var a_pinned := _is_pinned(a)
		var b_pinned := _is_pinned(b)
		if a_pinned and b_pinned:
			continue
		if a_pinned:
			_pos[b] -= correction * 2.0
		elif b_pinned:
			_pos[a] += correction * 2.0
		else:
			_pos[a] += correction
			_pos[b] -= correction

## Accelerate toward the authored shape, never teleport toward the settled pose.
func _apply_shape_memory() -> void:
	if shape_memory <= 0.0:
		return
	var spring_step := shape_memory * SIM_STEP * SIM_STEP
	for index in _pos.size():
		if _is_pinned(index):
			continue
		_prev[index] -= (_rest[index] - _pos[index]) * spring_step

func _apply_wall() -> void:
	for index in _pos.size():
		if _is_pinned(index):
			continue
		if _pos[index].z > wall_limit_z:
			_pos[index].z = wall_limit_z

## Something passed the coat. Push the free particles outward, weighted toward
## the hem, so the garment swings from the shoulder instead of sliding sideways
## as a slab.
func disturb(origin: Vector3, velocity: Vector3) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < disturbance_min_speed:
		return
	var direction := Vector3(velocity.x, 0.0, velocity.z).normalized()
	_apply_push(origin, direction, speed * disturbance_strength)

## A draft, not a body: the door opened somewhere in the room and the air moved.
## `strength` is a m/s figure like a walk, so the same code path moves the cloth
## and the same rustle fires. This only ever runs because something real
## happened — the coat never moves on its own (GDD §10: the Listener never
## touches objects, and neither does anything pretending to be it).
func draft(origin: Vector3, direction: Vector3, strength: float) -> void:
	if strength <= 0.0:
		return
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	_apply_push(origin, flat.normalized(), strength)

func _apply_push(origin: Vector3, direction: Vector3, magnitude: float) -> void:
	_frozen = false
	var moved := 0.0
	for index in _pos.size():
		if _is_pinned(index):
			continue
		var distance := _pos[index].distance_to(origin)
		if distance > disturbance_radius:
			continue
		var falloff := 1.0 - distance / disturbance_radius
		# Lower particles move more: a coat swings from the collar down.
		var row := float(index / segments) / float(maxi(rings - 1, 1))
		var weight := falloff * (0.25 + row * 0.75)
		_impulse[index] += direction * magnitude * weight
		moved = maxf(moved, weight * magnitude)
	if moved > rustle_min_strength:
		_maybe_rustle(moved)

## Rustling is throttled: one shove through the cloth is one sound, not one per
## frame for as long as a hand is in it.
func _maybe_rustle(strength: float) -> void:
	if _rustle_cooldown > 0.0:
		return
	_rustle_cooldown = RUSTLE_COOLDOWN_SECONDS
	rustled.emit(clampf(strength / 0.6, 0.0, 1.0))

func _process(delta: float) -> void:
	_rustle_cooldown = maxf(0.0, _rustle_cooldown - delta)
	_pass_cooldown = maxf(0.0, _pass_cooldown - delta)
	_resolve_player()
	if player != null:
		_maybe_disturb_from_player()
	step(delta)

## A body is worth disturbing the coat exactly once per pass: on the frame it
## first gets close enough, if it is actually moving.
##
## The rising edge is the whole point. Applying the same push every frame while
## the body stays in range integrates into an enormous force — the measured
## failure was a stationary shuffle lifting the hem half a metre.
func _maybe_disturb_from_player() -> void:
	var origin := player.global_position + Vector3.UP * 1.2
	# Distance to the nearest CLOTH, not to the coat's centre. Measuring to the
	# centre meant the 0.5 m of vertical offset between a man's chest and a coat
	# collar put the whole garment permanently out of reach: he could stand with
	# his shoulder inside the sleeve and nothing happened.
	if _nearest_particle_distance(origin) > disturbance_radius:
		_in_range = false
		return
	if _in_range or _pass_cooldown > 0.0:
		return
	if Vector2(player.velocity.x, player.velocity.z).length() < disturbance_min_speed:
		return
	_in_range = true
	_pass_cooldown = pass_cooldown_seconds
	disturb(origin, player.velocity)

## How far the furthest particle has drifted from where this coat actually hangs.
##
## NOT from the authored profile: gravity sags the garment about 18 mm below the
## profile it was built on, so measuring against the profile left a permanent
## error floor above any sensible tolerance and the coat could never be declared
## at rest. The reference is therefore the pose it first settles into — its home
## — which is also the pose the operator sees as "how the coat hangs".
func _home_pose() -> PackedVector3Array:
	return _home if not _home.is_empty() else _rest

func _shape_error() -> float:
	var reference := _home_pose()
	var worst := 0.0
	for index in _pos.size():
		if _is_pinned(index):
			continue
		worst = maxf(worst, _pos[index].distance_squared_to(reference[index]))
	return sqrt(worst)

func _nearest_particle_distance(origin: Vector3) -> float:
	var best := INF
	for index in _pos.size():
		best = minf(best, origin.distance_squared_to(_pos[index]))
	return sqrt(best)

## The solver and the render topology remain independent. All shared points
## use the same binding, including the armholes, collar and lining seams.
func _rebuild_mesh() -> void:
	if _mesh == null:
		return
	_binding.rebuild(_mesh, _pos)
	_built_positions = _pos.duplicate()

## True once the coat has stopped moving, within `tolerance` metres per step.
func is_settled(tolerance: float = 0.0005) -> bool:
	for index in _pos.size():
		if _pos[index].distance_to(_prev[index]) > tolerance:
			return false
	return true

func get_particle_position(ring: int, column: int) -> Vector3:
	return _pos[_particle_index(ring, column)]

## Where the garment actually is, in world space.
##
## The node's own transform is identity (the particles carry absolute room
## coordinates), so `global_position` is the world origin and is useless for
## placing anything near the coat — a sound source parented to it landed in the
## middle of the floor. This returns the centroid of the middle ring, which is
## the point a listener should perceive the cloth at.
func get_hang_position() -> Vector3:
	if _pos.is_empty():
		return global_position
	var ring := (rings - 1) / 2
	var centre := Vector3.ZERO
	for c in segments:
		centre += _pos[_particle_index(ring, c)]
	return centre / float(maxi(segments, 1))

func get_particle_count() -> int:
	return _pos.size()
