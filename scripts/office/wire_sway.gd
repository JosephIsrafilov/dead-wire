class_name WireSway
extends Node

## The line outside breathes in the wind (plan 3.9): the two wires beyond the
## glass swing a little, slowly, never in step with each other. Nothing that
## pulls the eye from the yard - a few millimetres and a fraction of a degree.

@export var wire_paths: Array[NodePath] = [^"../ExteriorWireHigh", ^"../ExteriorWireLow"]
@export var swing_degrees: float = 0.35
@export var lift_metres: float = 0.008
@export var period_seconds: float = 5.5

var _wires: Array[Node3D] = []
var _rest: Array[Transform3D] = []
var _time: float = 0.0

func _ready() -> void:
	for path in wire_paths:
		var wire := get_node_or_null(path) as Node3D
		if wire != null:
			_wires.append(wire)
			_rest.append(wire.transform)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	_time += delta
	for i in _wires.size():
		var phase := _time * TAU / period_seconds + float(i) * 1.9
		var swing := sin(phase) * 0.7 + sin(phase * 2.3 + 0.6) * 0.3
		var rest := _rest[i]
		var basis := rest.basis * Basis(Vector3.RIGHT, deg_to_rad(swing_degrees) * swing)
		_wires[i].transform = Transform3D(basis, rest.origin + Vector3.UP * lift_metres * swing)

## How far a wire is from its rest pose, for tests.
func get_offset(index: int) -> float:
	if index >= _wires.size():
		return 0.0
	return _wires[index].transform.origin.distance_to(_rest[index].origin)
