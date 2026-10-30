class_name HangingCoat
extends MeshInstance3D

## The operator's coat, hanging from the hook by the door — as CLOTH.
##
## Why this is simulated rather than modelled
## -----------------------------------------
## The coat used to be authored geometry in the props atlas: a lofted shell
## baked into wall_props_static.glb. It could be the right shape and nothing
## else. It could not sway when Elias walked past it, could not settle after a
## door draft, and could not hang one millimetre differently from the pose it
## was modelled in — and those three things are the whole reason cloth reads as
## cloth. A sculpture of a coat on a hook is exactly what it was.
##
## The model
## ---------
## A Verlet particle grid: `rings` rows down the coat by `segments` columns
## around it. The collar row is PINNED to the hook; everything below is free.
## Each frame the free particles integrate position += (position - previous) *
## damping + gravity * dt^2, then a few relaxation passes push every constraint
## back toward its authored rest length. That is the standard position-based
## cloth model, and it is stable at 60 Hz with these numbers.
##
## Constraints, in order of how much they define the silhouette:
##   * VERTICAL (structural): ring r to ring r+1, same column. These carry the
##     coat's weight and stop it stretching; without them gravity unrolls the
##     garment into a rag.
##   * RING (structural): column i to column i+1, same ring. These hold the
##     circumference, which is what stops a hanging tube collapsing inward.
##   * SHEAR (diagonal): r,i to r+1,i+1 both ways. Without these the grid folds
##     along its own axes only and looks like a lantern.
##   * BEND (skip two rings): softer, keeps the coat from creasing exactly at a
##     constraint row.
##
## The rest shape is a profile table (see PROFILE) taken from the geometry this
## replaces, so the coat keeps the shoulders, waist and flare it was authored
## with — the simulation is only allowed to hang it, not redesign it.
##
## What it touches
## ---------------
## Nothing in the session. It reads the player's position and speed to react to
## him walking past, and writes only its own mesh. It cannot reach the tape, the
## register, the shift or the door.

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
## Velocity retained per step. 0.97 is a damped garment; 1.0 would swing forever.
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

## Weak pull back toward the authored drape, applied once per step.
##
## A cloth with only length constraints has no memory: after a brush it settles
## into a NEW equilibrium, and the measured result was a hem left permanently
## 4.5 cm higher on one side than the other — the garment slowly drifting into a
## lopsided shape it never returns from. This is the restoring force that makes
## it hang the same way every night.
##
## Kept low on purpose: at 0.02 the time constant is about a second, so a swing
## still reads clearly, and afterwards the coat resumes its authored silhouette
## rather than hovering against gravity.
@export var shape_memory: float = 0.045

## The coat may only stop simulating once it is both still AND back within this
## many metres of the drape it was hung in. Freezing on velocity alone locked it
## into whatever deformed pose a brush left behind, because a frozen coat skips
## the shape memory that would have drawn it home.
const FREEZE_SHAPE_TOLERANCE: float = 0.004

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
	[1.985, 0.078, 0.052],   # collar, pinned to the hook
	[1.952, 0.170, 0.070],   # shoulder line
	[1.865, 0.183, 0.082],   # chest
	[1.700, 0.180, 0.079],   # waist
	[1.550, 0.187, 0.084],
	[1.400, 0.196, 0.088],   # skirt
	[1.335, 0.200, 0.090],
	[1.295, 0.203, 0.091],   # hem
]

## The wool tile of the props atlas, in GODOT's UV space.
##
## The generator in tools/build_office_props_blender.py addresses the atlas in
## BLENDER space, where V runs bottom-up; Godot's textures run top-down, so a
## tile index copied straight out of the generator samples the mirrored row.
## Measured with tools/atlas_probe.gd: the generator's (2,3) cell reads
## rgb 104 80 40 using its own V and rgb 64 56 48 with V flipped, and 64 56 48
## is exactly the wool colour the atlas palette declares. The coat was sampling
## a neighbouring tile and rendering olive-brown until this was flipped.
const WOOL_U0 := 130.0 / 256.0
const WOOL_U1 := 190.0 / 256.0
const WOOL_V0 := 2.0 / 256.0
const WOOL_V1 := 62.0 / 256.0

## A point inside the wool tile, wrapping `u_frac` / `v_frac`.
static func wool_uv(u_frac: float, v_frac: float) -> Vector2:
	return Vector2(
		lerpf(WOOL_U0, WOOL_U1, fposmod(u_frac, 1.0)),
		lerpf(WOOL_V0, WOOL_V1, fposmod(v_frac, 1.0)))

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
var _material: StandardMaterial3D = null
## Sleeves hang from the shoulder ring and follow it. They are separate tapered
## tubes rather than part of the cloth grid: a sleeve is a tube of its own with
## a different axis, and stitching one into the body grid would need a topology
## the simulation does not have. Following the shoulder particles means they
## still swing with the coat instead of being pinned to the wall.
var _sleeve_left: MeshInstance3D = null
var _sleeve_right: MeshInstance3D = null

## Extra outward push applied this step at each particle (e.g. from a passer-by).
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
	_build_material()
	_mesh = ArrayMesh.new()
	mesh = _mesh
	_build_sleeves()
	# The coat must not cast the room's shadows from a pose it is not in yet.
	_rebuild_mesh()

## Two tapered tubes hanging off the shoulder ring, with a cuff band. Built once
## in local space (origin at the shoulder, hanging down -Y) so the per-frame work
## is just a transform.
func _build_sleeves() -> void:
	_sleeve_left = _make_sleeve("SleeveLeft")
	_sleeve_right = _make_sleeve("SleeveRight")

func _make_sleeve(node_name: String) -> MeshInstance3D:
	var sleeve := MeshInstance3D.new()
	sleeve.name = node_name
	sleeve.mesh = _build_sleeve_mesh()
	sleeve.material_override = _material
	add_child(sleeve)
	return sleeve

func _build_sleeve_mesh() -> ArrayMesh:
	var built := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	const SIDES := 8
	const SECTIONS := 4
	# (y downstream, radius) from the shoulder to the cuff.
	var section_table := [[0.0, 0.062], [-0.16, 0.058], [-0.34, 0.054], [-0.50, 0.049]]
	for s in SECTIONS - 1:
		var top: Array = section_table[s]
		var bottom: Array = section_table[s + 1]
		for i in SIDES:
			var a0 := TAU * float(i) / float(SIDES)
			var a1 := TAU * float(i + 1) / float(SIDES)
			var p00 := Vector3(cos(a0) * top[1], top[0], sin(a0) * top[1])
			var p01 := Vector3(cos(a1) * top[1], top[0], sin(a1) * top[1])
			var p10 := Vector3(cos(a0) * bottom[1], bottom[0], sin(a0) * bottom[1])
			var p11 := Vector3(cos(a1) * bottom[1], bottom[0], sin(a1) * bottom[1])
			var normal := ((p10 - p00).cross(p01 - p00)).normalized()
			if normal.length_squared() < 0.0001:
				normal = Vector3.UP
			# UVs run once around the tube and twice along it. Sampling a single
			# texel for the whole sleeve — which the first version did — gave it
			# whatever colour that one texel happened to be, and the sleeves
			# came out bright orange against a dark coat.
			var su0 := float(i) / float(SIDES)
			var su1 := float(i + 1) / float(SIDES)
			var sv0 := float(s) / float(SECTIONS - 1) * 2.0
			var sv1 := float(s + 1) / float(SECTIONS - 1) * 2.0
			for tri in [[p00, p10, p01, Vector2(su0, sv0), Vector2(su0, sv1), Vector2(su1, sv0)],
					[p01, p10, p11, Vector2(su1, sv0), Vector2(su0, sv1), Vector2(su1, sv1)]]:
				vertices.append(tri[0])
				vertices.append(tri[1])
				vertices.append(tri[2])
				normals.append(normal)
				normals.append(normal)
				normals.append(normal)
				uvs.append(wool_uv(tri[3].x, tri[3].y))
				uvs.append(wool_uv(tri[4].x, tri[4].y))
				uvs.append(wool_uv(tri[5].x, tri[5].y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not vertices.is_empty():
		built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return built

## Hang the sleeves off the widest points of the shoulder ring each step, so
## they follow the cloth instead of the wall.
func _update_sleeves() -> void:
	if _sleeve_left == null or _sleeve_right == null or rings < 2:
		return
	var shoulder_ring := 1
	var left_index := -1
	var right_index := -1
	var min_x := INF
	var max_x := -INF
	for c in segments:
		var index := _particle_index(shoulder_ring, c)
		if _pos[index].x < min_x:
			min_x = _pos[index].x
			left_index = index
		if _pos[index].x > max_x:
			max_x = _pos[index].x
			right_index = index
	if left_index < 0 or right_index < 0:
		return
	_sleeve_left.global_position = _pos[left_index] + Vector3(0.0, -0.012, 0.012)
	_sleeve_right.global_position = _pos[right_index] + Vector3(0.0, -0.012, 0.012)

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

func _build_material() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var atlas := load("res://assets/textures/office_props_v1/props_atlas_256.png") as Texture2D
	if atlas != null:
		_material.albedo_texture = atlas
		_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Slightly darker than the atlas wool: the coat sits in the ember light's
	# reach and at full value it came up as bright as the boards behind it.
	#
	# Above 1.0 on purpose. The atlas wool tile is 64/255 because it was mixed
	# for the desk-lamp group, where the lamp is 6 cm from what it lights. The
	# coat hangs on the south wall, ~0.9 m from a 0.52-energy filing light, and
	# at the tile's own value it rendered as an unlit black mass with no fold
	# readable at all. Boosting only this material lifts the cloth to a mid-dark
	# grey it can actually show form at, without touching the hat or any other
	# prop that shares the tile.
	_material.albedo_color = Color(1.85, 1.80, 1.70)
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material

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
		for index in _pos.size():
			if _is_pinned(index):
				continue
			var velocity := (_pos[index] - _prev[index]) * damping
			_prev[index] = _pos[index]
			_pos[index] += velocity + gravity_step + _impulse[index]
			_impulse[index] = Vector3.ZERO
		for _pass in iterations:
			_solve_constraints()
		_apply_wall()
		_apply_shape_memory()
	# A coat that has settled is the normal state for most of the watch. There is
	# no point rebuilding 504 vertices and a surface every frame to redraw the
	# pose that is already on screen, so the mesh is only re-emitted when the
	# cloth actually moved. `changed` is tracked in the constraint solver's wake.
	if _moved_since_build():
		_rebuild_mesh()
	# A settled coat also has to be back near the shape it was hung in before the
	# solver may stop: freezing on velocity alone locked it into whatever
	# deformed pose a brush had left it in, because the freeze skips the shape
	# memory that would have drawn it home.
	if _home.is_empty() and is_settled():
		_home = _pos.duplicate()
	_frozen = is_settled() and _shape_error() < FREEZE_SHAPE_TOLERANCE

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

## The collar row is held by the hook and never moves.
func _is_pinned(index: int) -> bool:
	return index < segments

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

## The wall and the rack board are behind the coat; it may not drift into them.
## Draw the garment back toward the shape it was hung in. Without this the cloth
## has no equilibrium of its own and every interaction leaves it a little more
## deformed than the last one.
func _apply_shape_memory() -> void:
	if shape_memory <= 0.0:
		return
	var reference := _home_pose()
	for index in _pos.size():
		if _is_pinned(index):
			continue
		_pos[index] = _pos[index].lerp(reference[index], shape_memory)

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

## Rebuild the render mesh from the particles. Flat-shaded quads, one per grid
## cell, each with its own normal: the room's whole style is faceted surfaces,
## and a smooth-shaded cloth would be the only smooth object in the office.
func _rebuild_mesh() -> void:
	if _mesh == null:
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	# The wool tile is repeated around the coat and down it. One tile stretched
	# over the whole garment magnifies the atlas's 8-step quantised noise into
	# large flat colour blocks; two around and three down puts the texel back to
	# a few millimetres and reads as cloth.
	const REPS_U := 2.0
	const REPS_V := 3.0
	for r in rings - 1:
		for c in segments:
			var i00 := _particle_index(r, c)
			var i01 := _particle_index(r, c + 1)
			var i10 := _particle_index(r + 1, c)
			var i11 := _particle_index(r + 1, c + 1)
			var p00 := _pos[i00]
			var p01 := _pos[i01]
			var p10 := _pos[i10]
			var p11 := _pos[i11]
			var normal := (p10 - p00).cross(p01 - p00)
			if normal.length_squared() < 0.0000001:
				normal = Vector3.FORWARD
			normal = normal.normalized()
			var cu0 := float(c) / float(segments) * REPS_U
			var cu1 := float(c + 1) / float(segments) * REPS_U
			var rv0 := float(r) / float(maxi(rings - 1, 1)) * REPS_V
			var rv1 := float(r + 1) / float(maxi(rings - 1, 1)) * REPS_V
			for tri in [[p00, p10, p01, Vector2(cu0, rv0), Vector2(cu0, rv1), Vector2(cu1, rv0)],
					[p01, p10, p11, Vector2(cu1, rv0), Vector2(cu0, rv1), Vector2(cu1, rv1)]]:
				vertices.append(tri[0])
				vertices.append(tri[1])
				vertices.append(tri[2])
				normals.append(normal)
				normals.append(normal)
				normals.append(normal)
				uvs.append(wool_uv(tri[3].x, tri[3].y))
				uvs.append(wool_uv(tri[4].x, tri[4].y))
				uvs.append(wool_uv(tri[5].x, tri[5].y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_mesh.clear_surfaces()
	if not vertices.is_empty():
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_built_positions = _pos.duplicate()
	_update_sleeves()

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
