class_name FootstepSurfacePaint
extends RefCounted

## Material footprints shared with the art direction of black_creek_ground.gdshader.
## The ballast rectangles approximate the blended edge; wagon ruts use the
## shader's quantized world coordinates and wetness equations directly.

## Track and spur datums, matching `black_creek_rail_layout.gd` and the shader
## uniforms the builder sets.
const MAIN_TRACK_Z := -18.0
const MJ_SPUR_X := 21.0

## Derived from `float yard = 1.0 - smoothstep(4.4, 6.4, abs(p.y - main_track_z));`
## half strength sits at 4.4 + 0.5 * (6.4 - 4.4) = 5.4 m off the centreline.
const YARD_HALF_DEPTH := 5.4
## `float yard_end = 1.0 - smoothstep(52.0, 58.0, abs(p.x));` -> 55.0 m.
const YARD_HALF_LENGTH := 55.0

## `float spur = spur_lane * (1.0 - smoothstep(0.4, 2.6, abs(p.x - mj_spur_x - 3.0)));`
## centred on (mj_spur_x + 3, main_track_z + 8.4); 3.4 + 0.9 = 4.3 m along z and
## 0.4 + 1.1 = 1.5 m along x at the 50 % of the lane term.
const SPUR_CENTER_Z_OFFSET := 8.4
const SPUR_X_OFFSET := 3.0
const SPUR_HALF_DEPTH := 4.3
const SPUR_HALF_LENGTH := 1.5

## `float apron = (1.0 - smoothstep(5.2, 6.6, abs(p.x - 4.4)))
##      * (1.0 - smoothstep(5.4, 6.8, abs(p.y + 10.2)));` scaled by 0.92. Both
## factors meet at 0.737 (t = 0.529) where the product is exactly 0.5, so the
## rect below is the conservative one: every point inside is at least half
## cinder, and the corner is exactly 0.5.
const APRON_CENTER := Vector2(4.4, -10.2)
const APRON_HALF_LENGTH := 5.94
const APRON_HALF_DEPTH := 6.14

## Rail zone half-width. `MainRailSouth`/`North` are 0.08 m boxes, so a 0.34 m
## zone overhangs by 0.13 m per side. Steel is a real 1.44 m gauge rail, not a
## knife edge: half a boot's width of slack is defensible, four times the drawn
## head is not. 0.14 m keeps a boot on the rail head without claiming
## phantom steel out to the sleeper edge.
const RAIL_HALF_WIDTH := 0.14

## The one strip the builder already places, repeated here so a caller can
## compare without digging through the scene.
const BED_HALF_DEPTH := 1.7

## Every cinder patch the shader paints, as zone specifications, highest
## priority last. `priority` wins over the ballast bed, so a patch laid on the
## bed (the yard overlaps it) still resolves to its own name if a caller adds one.
static func cinder_bands(main_track_z: float = MAIN_TRACK_Z, mj_spur_x: float = MJ_SPUR_X) -> Array[Dictionary]:
	return [
		{
			"name": "CinderSpurStub",
			"surface": &"ballast",
			"center": Vector3(mj_spur_x + SPUR_X_OFFSET, -0.02, main_track_z + SPUR_CENTER_Z_OFFSET),
			"size": Vector3(SPUR_HALF_LENGTH * 2.0, 0.30, SPUR_HALF_DEPTH * 2.0),
			"priority": 0,
		},
		{
			"name": "CinderDepotApron",
			"surface": &"ballast",
			"center": Vector3(APRON_CENTER.x, -0.02, APRON_CENTER.y),
			"size": Vector3(APRON_HALF_LENGTH * 2.0, 0.30, APRON_HALF_DEPTH * 2.0),
			"priority": 0,
		},
		{
			"name": "CinderYard",
			"surface": &"ballast",
			"center": Vector3(0.0, -0.02, main_track_z),
			"size": Vector3(YARD_HALF_LENGTH * 2.0, 0.30, YARD_HALF_DEPTH * 2.0),
			"priority": 0,
		},
	]

## Is this point inside the painted cinder, per the rects above? Used by the
## parity test to check the rects against a mirror of the shader.
static func is_painted(point: Vector3, main_track_z: float = MAIN_TRACK_Z,
		mj_spur_x: float = MJ_SPUR_X) -> bool:
	return caused_by(point, main_track_z, mj_spur_x) != ""

## Which patch would claim this point ("" when the ground is clay).
static func caused_by(point: Vector3, main_track_z: float = MAIN_TRACK_Z,
		mj_spur_x: float = MJ_SPUR_X) -> String:
	for band in cinder_bands(main_track_z, mj_spur_x):
		var center: Vector3 = band["center"]
		var size: Vector3 = band["size"]
		if absf(point.x - center.x) <= size.x * 0.5 and absf(point.z - center.z) <= size.z * 0.5:
			return band["name"]
	return ""

## The rails' own footprint, as zone specifications.
static func rail_bands(main_track_z: float = MAIN_TRACK_Z, half_gauge: float = 0.72) -> Array[Dictionary]:
	var bands: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		bands.append({
			"name": "RailBed%s" % ("South" if side > 0.0 else "North"),
			"surface": &"rail",
			"center": Vector3(0.0, 0.03, main_track_z + half_gauge * side),
			"size": Vector3(150.0, 0.30, RAIL_HALF_WIDTH * 2.0),
			"priority": 1,
		})
	return bands


static func avenue_surface(point: Vector3) -> StringName:
	if absf(point.y) > 0.35 or point.x < -58.0 or absf(point.z - 23.1) > 3.0:
		return &""
	var p := (Vector2(point.x, point.z) * 36.0).floor() / 36.0
	var wear := _ground_noise(p * Vector2(0.26, 0.79))
	var drift := (_value_noise(Vector2(p.x * 0.13, 3.7)) - 0.5) * 0.85
	var rut := 0.0
	for i in 4:
		var groove := absf(p.y - 23.1 - (i * 1.46 - 2.19) - drift)
		rut = maxf(rut, (1.0 - smoothstep(0.09, 0.34, groove)) * (0.34 + 0.66 * wear))
	var wet := smoothstep(0.44, 0.72, wear) * rut
	var pool := smoothstep(0.68, 0.83, _value_noise(p * Vector2(0.34, 2.0))) * rut
	return &"wet_mud" if maxf(wet, pool) >= 0.53 else &""

static func _ground_noise(p: Vector2) -> float:
	return _value_noise(p) * 0.66 + _value_noise(p * 2.17 + Vector2(13.7, 13.7)) * 0.34

static func _value_noise(p: Vector2) -> float:
	var cell := p.floor()
	var f := p - cell
	f *= f * (Vector2(3.0, 3.0) - f * 2.0)
	return lerpf(lerpf(_hash(cell), _hash(cell + Vector2.RIGHT), f.x),
		lerpf(_hash(cell + Vector2.DOWN), _hash(cell + Vector2.ONE), f.x), f.y)

static func _hash(p: Vector2) -> float:
	var value := sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453
	return value - floorf(value)
