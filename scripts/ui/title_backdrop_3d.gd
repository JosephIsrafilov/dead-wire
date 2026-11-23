class_name TitleBackdrop3D
extends Node3D

## Live 3D Black Creek station diorama rendered behind the FORM 19 main menu.
## Handles organic lamp flicker, mouse micro-parallax, rare · — · sounder ticks,
## a fleeting silhouette beat beyond the fence, and options/enter camera motion.

signal sounder_pulse()

const BASE_CAM_POS := Vector3(-0.56, 1.31, -0.58)
const BASE_CAM_TARGET := Vector3(-1.38, 1.12, -2.02)
const OPTIONS_CAM_POS := Vector3(-0.48, 1.32, -0.54)
const OPTIONS_CAM_TARGET := Vector3(-1.12, 1.12, -2.04)

var _clock: float = 0.0
var _lamp_rest: float = 2.85
var _bounce_rest: float = 0.20
var _moon_rest: float = 2.65
var _flame_rest: Vector3 = Vector3.ONE
var _mouse_offset: Vector2 = Vector2.ZERO
var _mouse_smooth: Vector2 = Vector2.ZERO
var _options_weight: float = 0.0
var _options_open: bool = false
var _enter_weight: float = 0.0
var _entering: bool = false

var _next_pulse_at: float = 19.0
var _pulse_timer: float = -1.0
var _next_figure_at: float = 34.0
var _figure_timer: float = -1.0
var _wick_dim_factor: float = 1.0

@onready var _camera: Camera3D = $Camera3D
@onready var _lamp_light: OmniLight3D = $DeskLampLight
@onready var _bounce_light: OmniLight3D = $PaperBounceLight
@onready var _moon_light: SpotLight3D = $WindowMoonLight
@onready var _flame_mesh: Node3D = get_node_or_null("DeskSetup/OilLamp/Flame") as Node3D
@onready var _window_figure: Node3D = get_node_or_null("WindowFigure/VisualIndicator") as Node3D
@onready var _figure_head: Node3D = get_node_or_null("WindowFigure/VisualIndicator/Head") as Node3D
@onready var _register_spool: Node3D = get_node_or_null("TapeRegister/Body/Spool") as Node3D
@onready var _register_stylus: Node3D = get_node_or_null("TapeRegister/Body/StylusPivot") as Node3D
@onready var _world_env: WorldEnvironment = $WorldEnvironment

func _ready() -> void:
	if _lamp_light != null:
		_lamp_rest = _lamp_light.light_energy
	if _bounce_light != null:
		_bounce_rest = _bounce_light.light_energy
	if _moon_light != null:
		_moon_rest = _moon_light.light_energy
	if _flame_mesh != null:
		_flame_rest = _flame_mesh.scale
	_disable_diorama_interactables()
	_pose_uncanny_figure()
	apply_campaign_mood()
	_update_camera(0.0)

func _disable_diorama_interactables() -> void:
	for node in find_children("*", "Area3D", true, false):
		var area := node as Area3D
		if area != null:
			area.monitoring = false
			area.monitorable = false
	var tape := get_node_or_null("TapeRegister")
	if tape != null:
		tape.set_process(false)
		tape.set_physics_process(false)

func _pose_uncanny_figure() -> void:
	if _window_figure != null:
		_window_figure.visible = false
	if _figure_head != null:
		_figure_head.rotation.z = deg_to_rad(20.0)

func apply_campaign_mood() -> void:
	if not CampaignStateStore.has_saved_campaign():
		return
	var saved_phase := _peek_saved_phase()
	if saved_phase == String(CampaignStateStore.PHASE_DAY_TOWN) \
			or saved_phase == String(CampaignStateStore.PHASE_DAWN_WALK):
		if _moon_light != null:
			_moon_light.light_color = Color(0.95, 0.80, 0.58, 1.0)
			_moon_light.light_energy = _moon_rest * 1.15
		if _world_env != null and _world_env.environment != null:
			_world_env.environment.fog_light_color = Color(0.28, 0.27, 0.24, 1.0)

func _peek_saved_phase() -> String:
	if not FileAccess.file_exists(CampaignStateStore.DEFAULT_SAVE_PATH):
		return ""
	var raw := FileAccess.get_file_as_string(CampaignStateStore.DEFAULT_SAVE_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		return String((parsed as Dictionary).get("phase", ""))
	return ""

func set_mouse_normalized(norm: Vector2) -> void:
	_mouse_offset = Vector2(clampf(norm.x, -1.0, 1.0), clampf(norm.y, -1.0, 1.0))

func set_options_open(open: bool) -> void:
	_options_open = open

func play_enter_transition() -> void:
	_entering = true

func _process(delta: float) -> void:
	advance_visual(delta)

func advance_visual(delta: float) -> void:
	_clock += delta
	_update_eerie_beats(delta)
	_update_lamp(delta)
	_update_camera(delta)

func _update_lamp(_delta: float) -> void:
	var wobble := 0.62 * sin(TAU * 7.3 * _clock) + 0.38 * sin(TAU * 1.7 * _clock + 1.7)
	var energy_mul := (1.0 + wobble * 0.065) * _wick_dim_factor
	if _lamp_light != null:
		_lamp_light.light_energy = _lamp_rest * energy_mul
	if _bounce_light != null:
		_bounce_light.light_energy = _bounce_rest * energy_mul
	if _flame_mesh != null:
		var sy := (1.0 + wobble * 0.05) * lerpf(0.76, 1.0, _wick_dim_factor)
		_flame_mesh.scale = Vector3(_flame_rest.x, _flame_rest.y * sy, _flame_rest.z)

func _update_camera(delta: float) -> void:
	if _camera == null:
		return
	var lerp_rate := minf(1.0, delta * 4.5) if delta > 0.0 else 1.0
	_mouse_smooth = _mouse_smooth.lerp(_mouse_offset, lerp_rate)
	var target_opt := 1.0 if _options_open else 0.0
	_options_weight = move_toward(_options_weight, target_opt, delta * 3.5 if delta > 0.0 else 1.0)
	if _entering:
		_enter_weight = minf(1.0, _enter_weight + delta * 2.8)

	var base_pos := BASE_CAM_POS.lerp(OPTIONS_CAM_POS, _options_weight)
	var base_target := BASE_CAM_TARGET.lerp(OPTIONS_CAM_TARGET, _options_weight)
	if _enter_weight > 0.0:
		base_pos = base_pos.lerp(Vector3(-1.12, 1.18, -1.35), _enter_weight)
		base_target = base_target.lerp(Vector3(-1.38, 0.92, -1.84), _enter_weight)

	var breath := Vector3(
		sin(_clock * 0.42) * 0.008,
		cos(_clock * 0.58) * 0.005,
		0.0
	)
	var parallax := Vector3(_mouse_smooth.x * 0.024, -_mouse_smooth.y * 0.014, 0.0)
	_camera.position = base_pos + breath + parallax
	_camera.look_at(base_target + Vector3(_mouse_smooth.x * 0.018, -_mouse_smooth.y * 0.012, 0.0), Vector3.UP)

func _update_eerie_beats(delta: float) -> void:
	if _clock >= _next_pulse_at and _pulse_timer < 0.0:
		_pulse_timer = 0.0
		_next_pulse_at = _clock + 26.0
		sounder_pulse.emit()
	if _pulse_timer >= 0.0:
		_pulse_timer += delta
		if _register_spool != null:
			_register_spool.rotate_z(-delta * 0.85)
		if _register_stylus != null:
			var is_dot := _pulse_timer < 0.14
			var is_dash := _pulse_timer > 0.24 and _pulse_timer < 0.56
			var is_dot2 := _pulse_timer > 0.68 and _pulse_timer < 0.82
			_register_stylus.position.y = 0.078 if (is_dot or is_dash or is_dot2) else 0.081
		if _pulse_timer > 1.0:
			_pulse_timer = -1.0
			if _register_stylus != null:
				_register_stylus.position.y = 0.081

	if _clock >= _next_figure_at and _figure_timer < 0.0 and not _options_open:
		_figure_timer = 0.0
		_next_figure_at = _clock + 38.0
	if _figure_timer >= 0.0:
		_figure_timer += delta
		if _figure_timer < 1.8 and not _options_open:
			_wick_dim_factor = lerpf(1.0, 0.78, sin((_figure_timer / 1.8) * PI))
			if _window_figure != null:
				_window_figure.visible = _figure_timer > 0.25 and _figure_timer < 1.55
		else:
			_wick_dim_factor = 1.0
			if _window_figure != null:
				_window_figure.visible = false
			_figure_timer = -1.0
