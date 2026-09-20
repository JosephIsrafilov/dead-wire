class_name LampLife
extends Node

## Keeps the two live flames from reading as light bulbs.
##
## An oil lamp and a coal firebox do not hold a constant value. Both are driven
## by layered sine terms rather than random noise so nothing ever strobes, and
## both stay well under the amplitude where the flicker itself becomes the thing
## the player is watching — the same restraint the ambience mix uses.

@export var lamp_light: OmniLight3D = null
@export var stove_light: OmniLight3D = null
## NodePath so the scene can wire the wick mesh; resolved in _ready.
@export var flame_mesh_path: NodePath = ^""
@export var flame_mesh: Node3D = null

## Fraction of rest energy. A guttering oil lamp is subtle; ±8% reads as alive.
@export var lamp_flicker_depth: float = 0.08
@export var lamp_fast_hz: float = 7.3
@export var lamp_slow_hz: float = 1.7

## A firebox breathes much more slowly and a little deeper than a wick.
@export var stove_pulse_depth: float = 0.13
@export var stove_hz: float = 0.37

var _lamp_rest: float = 0.0
var _stove_rest: float = 0.0
var _flame_rest_scale: Vector3 = Vector3.ONE
var _time: float = 0.0

func _ready() -> void:
	_resolve()
	if flame_mesh == null and not flame_mesh_path.is_empty():
		flame_mesh = get_node_or_null(flame_mesh_path) as Node3D
	if lamp_light != null:
		_lamp_rest = lamp_light.light_energy
	if stove_light != null:
		_stove_rest = stove_light.light_energy
	if flame_mesh != null:
		_flame_rest_scale = flame_mesh.scale

func _resolve() -> void:
	var office := get_parent()
	if office == null:
		return
	if lamp_light == null:
		lamp_light = office.get_node_or_null("DeskLampLight") as OmniLight3D
	if stove_light == null:
		stove_light = office.get_node_or_null("StoveEmberLight") as OmniLight3D

func _process(delta: float) -> void:
	advance(delta)

## Separated from _process so tests can step the flame deterministically.
func advance(delta: float) -> void:
	_time += delta

	if lamp_light != null and _lamp_rest > 0.0:
		# Two incommensurate rates so the pattern never audibly repeats.
		var wobble := 0.62 * sin(TAU * lamp_fast_hz * _time) + 0.38 * sin(TAU * lamp_slow_hz * _time + 1.7)
		lamp_light.light_energy = _lamp_rest * (1.0 + wobble * lamp_flicker_depth)
		if flame_mesh != null:
			var scale_factor := 1.0 + wobble * lamp_flicker_depth * 0.6
			flame_mesh.scale = Vector3(_flame_rest_scale.x, _flame_rest_scale.y * scale_factor, _flame_rest_scale.z)

	if stove_light != null and _stove_rest > 0.0:
		var breath := sin(TAU * stove_hz * _time) * 0.7 + sin(TAU * stove_hz * 0.41 * _time + 2.3) * 0.3
		stove_light.light_energy = _stove_rest * (1.0 + breath * stove_pulse_depth)

func get_lamp_rest_energy() -> float:
	return _lamp_rest

func get_stove_rest_energy() -> float:
	return _stove_rest
