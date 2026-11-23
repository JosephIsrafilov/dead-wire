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
## Plan 8.5: the wick wheel on the operator's side of the lamp. It turns with
## the hand that raises or lowers the wick — never on its own while the wick
## chars down — about three quarters of a turn over the wick's whole travel.
@export var wick_wheel: Node3D = null
const WHEEL_RADIANS_PER_WICK: float = 1.5 * PI
var _wheel_angle: float = 0.0
var _wheel_target: float = 0.0
var _wheel_rate: float = 0.0

## Fraction of rest energy. A guttering oil lamp is subtle; ±8% reads as alive.
@export var lamp_flicker_depth: float = 0.08
@export var lamp_fast_hz: float = 7.3
@export var lamp_slow_hz: float = 1.7

## A draft (plan 2.8): when the door opens the flame and its light shiver
## harder for a breath, then settle. The door is the cause, never the Listener.
@export var draft_flicker_boost: float = 2.6
@export var draft_seconds: float = 1.8
@export var draft_hz: float = 11.0
## The flame shader's resting sway; a draft multiplies it.
@export var flame_sway_rest: float = 0.0035
var _draft: float = 0.0

## A firebox breathes much more slowly and a little deeper than a wick.
@export var stove_pulse_depth: float = 0.13
@export var stove_hz: float = 0.37

## The wick: 0..1 of full flame. The watch starts turned down; the operator
## turns it up by hand; opening the telegraph line never moves the wheel.
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
const PROMPT_DIM: String = "Dim the Lamp"
const PROMPT_TRIM: String = "Trim the Wick"
const PROMPT_TURN_DOWN: String = "Turn Down the Lamp"
const DIM_WICK: float = 0.22
const MIN_MANUAL_WICK: float = 0.14
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

var stove_heat: float = 1.0
var _stove_stoke_timer: float = 0.0
var _ember_material: StandardMaterial3D = null
var _ember_rest_emission: float = 0.65
var _shift_director: ShiftDirector = null
var stove_cooling_enabled: bool = true

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

func stoke_stove() -> void:
	_stove_stoke_timer = 180.0
	stove_heat = maxf(stove_heat, 1.05)

func get_stove_heat() -> float:
	return stove_heat

func set_stove_heat_for_test(value: float) -> void:
	stove_heat = clampf(value, 0.25, 1.4)

func _bind_wick() -> void:
	var office := get_parent()
	if office == null:
		return
	_wick_interactable = office.get_node_or_null("DeskSetup/OilLamp/WickInteractable") as Interactable
	if _wick_interactable != null:
		_wick_interactable.enabled = true
		_sync_wick_prompt()
		if not _wick_interactable.interacted.is_connected(_on_wick_interacted):
			_wick_interactable.interacted.connect(_on_wick_interacted)
	var door := office.get_node_or_null("SouthDoor/DoorController") as OfficeDoor
	if door != null and not door.door_opened.is_connected(gust):
		door.door_opened.connect(gust.bind(1.0))
	var director := office.get_node_or_null("ShiftDirector") as ShiftDirector
	if director != null and not director.shift_opened.is_connected(_on_line_opened):
		director.shift_opened.connect(_on_line_opened)

func _on_line_opened() -> void:
	_line_open = true

func _on_wick_interacted() -> void:
	if _dawn:
		turn_down_wick()
	elif wick >= 0.72:
		dim_wick()
	else:
		turn_up_wick()

## Dawn: the lamp is offered to be turned down; nothing forces it.
func offer_turn_down() -> void:
	_dawn = true
	if _wick_interactable != null:
		_wick_interactable.prompt_text = GameLocale.pick("Прикрутить лампу", PROMPT_TURN_DOWN)
		_wick_interactable.enabled = wick > dawn_wick + 0.01

func turn_down_wick() -> void:
	_turn_wheel(dawn_wick - wick)
	_wick_target = dawn_wick
	_wick_rate = absf(wick - dawn_wick) / maxf(wick_turn_seconds, 0.01)
	if _wick_interactable != null:
		_wick_interactable.enabled = false
	wick_turned_down.emit()

func dim_wick() -> void:
	if _dawn:
		return
	var target := DIM_WICK
	_turn_wheel(target - wick)
	_wick_target = target
	_wick_rate = maxf(absf(wick - target) / maxf(wick_turn_seconds * 0.65, 0.01), 0.5)
	_sync_wick_prompt()
	wick_turned_down.emit()

func adjust_wick(delta_wick: float) -> void:
	if _dawn or is_zero_approx(delta_wick):
		return
	var next_target := clampf(_wick_target + delta_wick, MIN_MANUAL_WICK, 1.0)
	if is_equal_approx(next_target, _wick_target):
		return
	_turn_wheel(next_target - _wick_target)
	_wick_target = next_target
	_wick_rate = maxf(absf(_wick_target - wick) / 0.18, 0.8)
	if delta_wick > 0.0:
		_full_seconds = 0.0
	_sync_wick_prompt()

func turn_up_wick() -> void:
	if _wick_target >= 1.0 and wick >= 1.0:
		_sync_wick_prompt()
		return
	_turn_wheel(1.0 - wick)
	_wick_target = 1.0
	_wick_rate = (1.0 - wick) / maxf(wick_turn_seconds, 0.01)
	_full_seconds = 0.0
	_sync_wick_prompt()
	wick_turned_up.emit()

func refresh_locale() -> void:
	if _wick_interactable == null:
		return
	if _dawn:
		_wick_interactable.prompt_text = GameLocale.pick("Прикрутить лампу", PROMPT_TURN_DOWN)
	else:
		_sync_wick_prompt()

func _sync_wick_prompt() -> void:
	if _wick_interactable == null or _dawn:
		return
	_wick_interactable.enabled = true
	if _wick_target >= 0.72:
		_wick_interactable.prompt_text = GameLocale.pick("Приглушить лампу", PROMPT_DIM)
	else:
		_wick_interactable.prompt_text = GameLocale.pick("Прибавить фитиль", PROMPT_WICK)

## The hand turns the wheel by as much as it moves the wick, at the wick's pace.
func _turn_wheel(wick_amount: float) -> void:
	_wheel_target += wick_amount * WHEEL_RADIANS_PER_WICK
	_wheel_rate = absf(_wheel_target - _wheel_angle) / maxf(wick_turn_seconds, 0.01)

## Air moved past the lamp: 0..1 of a full gust.
func gust(strength: float = 1.0) -> void:
	_draft = maxf(_draft, clampf(strength, 0.0, 1.0))

func _set_flame_sway(value: float) -> void:
	var mesh_instance := flame_mesh as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	var material := mesh_instance.mesh.surface_get_material(0) as ShaderMaterial
	if material != null:
		material.set_shader_parameter("sway", value)

## The wick chars in a long quiet at full flame (plan 4.9, silence 3): it sinks
## to `to` over `seconds` and asks to be trimmed. Only the lamp's own burning
## does this; trimming brings the flame back.
func gutter(to: float, seconds: float) -> void:
	if _dawn or wick <= to + 0.001:
		return
	_wick_target = to
	_wick_rate = (wick - to) / maxf(seconds, 0.01)
	if _wick_interactable != null:
		_wick_interactable.prompt_text = GameLocale.pick("Подрезать фитиль", PROMPT_TRIM)
		_wick_interactable.enabled = true

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
	if wick_wheel == null:
		wick_wheel = office.get_node_or_null("DeskSetup/OilLamp/WickWheelPivot") as Node3D
	if _shift_director == null:
		_shift_director = office.get_node_or_null("ShiftDirector") as ShiftDirector
	if _ember_material == null:
		var ember := office.get_node_or_null("CornerStove/EmberSeam") as GeometryInstance3D
		if ember != null:
			var base_mat := ember.get("material") as StandardMaterial3D
			if base_mat == null:
				base_mat = ember.material_override as StandardMaterial3D
			if base_mat != null:
				_ember_material = base_mat.duplicate() as StandardMaterial3D
				_ember_rest_emission = _ember_material.emission_energy_multiplier
				if ember is CSGPrimitive3D:
					(ember as CSGPrimitive3D).material = _ember_material
				else:
					ember.material_override = _ember_material

func _process(delta: float) -> void:
	advance(delta)

## Separated from _process so tests can step the flame deterministically.
func advance(delta: float) -> void:
	_time += delta
	if not is_equal_approx(wick, _wick_target):
		wick = move_toward(wick, _wick_target, _wick_rate * delta)
	elif _line_open and not _dawn:
		_advance_sink(delta)
	if not is_equal_approx(_wheel_angle, _wheel_target):
		_wheel_angle = move_toward(_wheel_angle, _wheel_target, _wheel_rate * delta)
		if wick_wheel != null:
			# Clockwise to the operator raises the wick.
			wick_wheel.rotation.x = -_wheel_angle

	var had_draft := _draft > 0.0
	_draft = move_toward(_draft, 0.0, delta / maxf(draft_seconds, 0.01))
	if lamp_light != null and _lamp_rest > 0.0:
		# Two incommensurate rates so the pattern never audibly repeats.
		var wobble := 0.62 * sin(TAU * lamp_fast_hz * _time) + 0.38 * sin(TAU * lamp_slow_hz * _time + 1.7)
		# A draft adds a fast shiver on top and deepens the whole flicker.
		wobble += _draft * sin(TAU * draft_hz * _time + 0.4)
		var depth := lamp_flicker_depth * (1.0 + draft_flicker_boost * _draft)
		lamp_light.light_energy = _lamp_rest * wick * (1.0 + wobble * depth)
		if bounce_light != null:
			bounce_light.light_energy = _bounce_rest * wick * (1.0 + wobble * depth)
		if flame_mesh != null:
			var scale_factor := (1.0 + wobble * lamp_flicker_depth * 0.6) * lerpf(0.45, 1.0, wick)
			flame_mesh.scale = Vector3(_flame_rest_scale.x, _flame_rest_scale.y * scale_factor, _flame_rest_scale.z)
			if _draft > 0.0 or had_draft:
				_set_flame_sway(flame_sway_rest * (1.0 + 4.0 * _draft))

	if _stove_stoke_timer > 0.0:
		_stove_stoke_timer = maxf(_stove_stoke_timer - delta, 0.0)
	var natural_target := 1.0
	if stove_cooling_enabled and _shift_director != null:
		var hours := _shift_director.get_station_hours()
		if hours > 24.0:
			var cool_t := clampf((hours - 24.0) / 3.0, 0.0, 1.0)
			natural_target = lerpf(1.0, 0.36, cool_t)
	var heat_target := natural_target
	if _stove_stoke_timer > 0.0:
		heat_target = lerpf(natural_target, 1.24, clampf(_stove_stoke_timer / 180.0, 0.0, 1.0))
	var heat_rate := 0.45 if heat_target > stove_heat else 0.06
	stove_heat = move_toward(stove_heat, heat_target, delta * heat_rate)

	if stove_light != null and _stove_rest > 0.0:
		var breath := sin(TAU * stove_hz * _time) * 0.7 + sin(TAU * stove_hz * 0.41 * _time + 2.3) * 0.3
		stove_light.light_energy = _stove_rest * stove_heat * (1.0 + breath * stove_pulse_depth)
		if _ember_material != null:
			_ember_material.emission_energy_multiplier = _ember_rest_emission * stove_heat * (1.0 + breath * 0.2)

func _advance_sink(delta: float) -> void:
	_full_seconds += delta
	if _full_seconds < sink_delay_seconds or wick <= sink_floor:
		return
	wick = maxf(wick - sink_per_second * delta, sink_floor)
	_wick_target = wick
	if wick < trim_threshold and _wick_interactable != null and not _wick_interactable.enabled:
		_wick_interactable.prompt_text = GameLocale.pick("Подрезать фитиль", PROMPT_TRIM)
		_wick_interactable.enabled = true

func get_lamp_rest_energy() -> float:
	return _lamp_rest

func get_stove_rest_energy() -> float:
	return _stove_rest
