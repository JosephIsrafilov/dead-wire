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
## Lamp light thrown back off the copy sheet: follows the lamp exactly.
@export var bounce_light: OmniLight3D = null
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

## The wick: 0..1 of full flame. The watch starts turned down; the operator
## turns it up by hand (or the lamp comes up with the opened line).
signal wick_turned_up()
signal wick_turned_down()
@export var start_turned_down: bool = true
@export var turned_down_wick: float = 0.3
@export var wick_turn_seconds: float = 1.4
## A burning wick chars and sinks: after a while at full flame the lamp slowly
## dims, and the operator has to reach over and trim it. Never below the floor.
@export var sink_delay_seconds: float = 60.0
@export var sink_per_second: float = 0.0016
@export var sink_floor: float = 0.6
@export var trim_threshold: float = 0.86
## At dawn the lamp is turned down for the day man; this is how low.
@export var dawn_wick: float = 0.06
const PROMPT_WICK: String = "Turn Up the Wick"
const PROMPT_TRIM: String = "Trim the Wick"
const PROMPT_TURN_DOWN: String = "Turn Down the Lamp"
var _line_open: bool = false
var _dawn: bool = false
var _full_seconds: float = 0.0
var wick: float = 1.0
var _wick_target: float = 1.0
var _wick_rate: float = 0.0
var _wick_interactable: Interactable = null

var _lamp_rest: float = 0.0
var _stove_rest: float = 0.0
var _bounce_rest: float = 0.0
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
	if bounce_light != null:
		_bounce_rest = bounce_light.light_energy
	if flame_mesh != null:
		_flame_rest_scale = flame_mesh.scale
	if start_turned_down:
		set_wick_immediate(turned_down_wick)
	_bind_wick.call_deferred()

func _bind_wick() -> void:
	var office := get_parent()
	if office == null:
		return
	_wick_interactable = office.get_node_or_null("DeskSetup/OilLamp/WickInteractable") as Interactable
	if _wick_interactable != null:
		_wick_interactable.prompt_text = PROMPT_WICK
		_wick_interactable.enabled = wick < 1.0
		if not _wick_interactable.interacted.is_connected(_on_wick_interacted):
			_wick_interactable.interacted.connect(_on_wick_interacted)
	var director := office.get_node_or_null("ShiftDirector") as ShiftDirector
	if director != null and not director.shift_opened.is_connected(turn_up_wick):
		# A forgotten lamp: Elias turns it up himself when he opens the line.
		director.shift_opened.connect(turn_up_wick)
	if director != null and not director.shift_opened.is_connected(_on_line_opened):
		director.shift_opened.connect(_on_line_opened)

func _on_line_opened() -> void:
	_line_open = true

func _on_wick_interacted() -> void:
	if _dawn:
		turn_down_wick()
	else:
		turn_up_wick()

## Dawn: the lamp is offered to be turned down; nothing forces it.
func offer_turn_down() -> void:
	_dawn = true
	if _wick_interactable != null:
		_wick_interactable.prompt_text = PROMPT_TURN_DOWN
		_wick_interactable.enabled = wick > dawn_wick + 0.01

func turn_down_wick() -> void:
	_wick_target = dawn_wick
	_wick_rate = absf(wick - dawn_wick) / maxf(wick_turn_seconds, 0.01)
	if _wick_interactable != null:
		_wick_interactable.enabled = false
	wick_turned_down.emit()

func turn_up_wick() -> void:
	if _wick_target >= 1.0 and wick >= 1.0:
		return
	_wick_target = 1.0
	_wick_rate = (1.0 - wick) / maxf(wick_turn_seconds, 0.01)
	_full_seconds = 0.0
	if _wick_interactable != null:
		_wick_interactable.enabled = false
	wick_turned_up.emit()

func set_wick_immediate(value: float) -> void:
	wick = clampf(value, 0.05, 1.0)
	_wick_target = wick
	_wick_rate = 0.0
	if _wick_interactable != null:
		_wick_interactable.enabled = wick < 1.0

func _resolve() -> void:
	var office := get_parent()
	if office == null:
		return
	if lamp_light == null:
		lamp_light = office.get_node_or_null("DeskLampLight") as OmniLight3D
	if stove_light == null:
		stove_light = office.get_node_or_null("StoveEmberLight") as OmniLight3D
	if bounce_light == null:
		bounce_light = office.get_node_or_null("PaperBounceLight") as OmniLight3D

func _process(delta: float) -> void:
	advance(delta)

## Separated from _process so tests can step the flame deterministically.
func advance(delta: float) -> void:
	_time += delta
	if not is_equal_approx(wick, _wick_target):
		wick = move_toward(wick, _wick_target, _wick_rate * delta)
	elif _line_open and not _dawn:
		_advance_sink(delta)

	if lamp_light != null and _lamp_rest > 0.0:
		# Two incommensurate rates so the pattern never audibly repeats.
		var wobble := 0.62 * sin(TAU * lamp_fast_hz * _time) + 0.38 * sin(TAU * lamp_slow_hz * _time + 1.7)
		lamp_light.light_energy = _lamp_rest * wick * (1.0 + wobble * lamp_flicker_depth)
		if bounce_light != null:
			bounce_light.light_energy = _bounce_rest * wick * (1.0 + wobble * lamp_flicker_depth)
		if flame_mesh != null:
			var scale_factor := (1.0 + wobble * lamp_flicker_depth * 0.6) * lerpf(0.45, 1.0, wick)
			flame_mesh.scale = Vector3(_flame_rest_scale.x, _flame_rest_scale.y * scale_factor, _flame_rest_scale.z)

	if stove_light != null and _stove_rest > 0.0:
		var breath := sin(TAU * stove_hz * _time) * 0.7 + sin(TAU * stove_hz * 0.41 * _time + 2.3) * 0.3
		stove_light.light_energy = _stove_rest * (1.0 + breath * stove_pulse_depth)

func _advance_sink(delta: float) -> void:
	_full_seconds += delta
	if _full_seconds < sink_delay_seconds or wick <= sink_floor:
		return
	wick = maxf(wick - sink_per_second * delta, sink_floor)
	_wick_target = wick
	if wick < trim_threshold and _wick_interactable != null and not _wick_interactable.enabled:
		_wick_interactable.prompt_text = PROMPT_TRIM
		_wick_interactable.enabled = true

func get_lamp_rest_energy() -> float:
	return _lamp_rest

func get_stove_rest_energy() -> float:
	return _stove_rest
