class_name CandleLife
extends Node3D

## Gentle organic flicker for the brass corner candle so the flame and warm
## light pool breathe without strobing.

@export var light_pulse_depth: float = 0.09
@export var flame_scale_depth: float = 0.07

var _light: OmniLight3D = null
var _flame: Node3D = null
var _rest_energy: float = 1.75
var _rest_scale: Vector3 = Vector3.ONE
var _time: float = 0.0

func _ready() -> void:
	_light = get_node_or_null("CandleLight") as OmniLight3D
	_flame = get_node_or_null("FlameMesh") as Node3D
	if _light != null:
		_rest_energy = _light.light_energy
	if _flame != null:
		_rest_scale = _flame.scale

func _process(delta: float) -> void:
	_time += delta
	var slow := sin(_time * 2.1 * TAU) * 0.6
	var fast := sin(_time * 6.7 * TAU + 1.1) * 0.4
	var wave := slow + fast
	if _light != null:
		_light.light_energy = maxf(0.05, _rest_energy * (1.0 + wave * light_pulse_depth))
	if _flame != null:
		var y_scale := 1.0 + wave * flame_scale_depth
		_flame.scale = Vector3(_rest_scale.x, _rest_scale.y * y_scale, _rest_scale.z)
