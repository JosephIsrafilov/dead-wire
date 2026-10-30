class_name WatchmanLantern
extends Node3D

## The mine's watchman walking his fence with a lantern (plan 3.10).
##
## It is the yard's ordinary life: a warm point that walks the beat along the
## mine fence and back, stops for a while, and is put out once the dawn is up.
## Against it, a figure that carries no light is the stranger thing — and it is
## also the room's "other explanation" (GDD §10): someone is out there, and he
## is only the watchman. It keeps well clear of the window and of the figure's
## column, and it touches nothing.

## The beat crosses the seated view's left half, 20 m out: seen from the desk,
## never behind the figure's column.
@export var walk_from: Vector3 = Vector3(-13.0, 0.95, -21.0)
@export var walk_to: Vector3 = Vector3(-5.0, 0.95, -19.0)
## A slow night walk, metres per second.
@export var walk_speed: float = 0.7
@export var pause_seconds: float = 6.0
## The lantern swings a little with each step.
@export var swing_height: float = 0.04
## Dawn level at which the watchman puts the lantern out.
@export var put_out_at_dawn: float = 0.6
@export var flame_color: Color = Color(1.0, 0.72, 0.38)

var _progress: float = 0.0
var _direction: float = 1.0
var _pause_left: float = 0.0
var _step_phase: float = 0.0
var _lit: bool = true
var _glow: MeshInstance3D = null
var _moon: MoonWeather = null

func _ready() -> void:
	_glow = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = flame_color
	material.disable_fog = true
	sphere.material = material
	_glow.mesh = sphere
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	var yard := get_parent()
	var office := yard.get_parent() if yard != null else null
	if office != null:
		_moon = office.get_node_or_null("MoonWeather") as MoonWeather
	position = walk_from

func _process(delta: float) -> void:
	advance(delta, _moon.dawn if _moon != null else 0.0)

func is_lit() -> bool:
	return _lit

## Separated from _process so tests can walk him deterministically.
func advance(delta: float, dawn: float) -> void:
	if _lit and dawn >= put_out_at_dawn:
		_lit = false
	if _glow != null:
		_glow.visible = _lit
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	var length := maxf(walk_from.distance_to(walk_to), 0.01)
	_progress += _direction * walk_speed * delta / length
	if _progress >= 1.0 or _progress <= 0.0:
		_progress = clampf(_progress, 0.0, 1.0)
		_direction = -_direction
		_pause_left = pause_seconds
	_step_phase += walk_speed * delta * TAU / 0.75
	position = walk_from.lerp(walk_to, _progress) + Vector3.UP * absf(sin(_step_phase)) * swing_height
