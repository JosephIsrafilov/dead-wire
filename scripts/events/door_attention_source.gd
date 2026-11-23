class_name DoorAttentionSource
extends Node3D

signal footsteps_started()
signal footsteps_completed()

@export var footstep_sound: AudioStream = preload("res://audio/sfx/foley/footstep_boards_3.wav")
@export var step_interval: float = 0.55
@export var total_steps: int = 3
@export var volume_db: float = -9.0

var _player: AudioStreamPlayer3D = null
## Audio fairness by construction (GDD §7): a step never lands on a Morse
## MARK. A step only starts when its whole sample fits in the current gap,
## and a MARK that arrives mid-sample cuts the optional foley short.
var scheduler: MorseRuntimeScheduler = null
var _bound_scheduler: MorseRuntimeScheduler = null
var is_active: bool = false
var steps_played: int = 0
var _step_timer: float = 0.0

## Whoever walks past carries a light (plan 4.11): a warm patch crosses the gap
## under the door with the steps and is gone. Explainable - the watchman's
## lantern, or not - and a second place to look. Offsets are along the gap,
## relative to this node, which stands on the landing behind the door.
@export var lantern_gap_half_width: float = 0.42
@export var lantern_gap_local: Vector3 = Vector3(0.0, -0.176, -0.587)
@export var lantern_color: Color = Color(1.0, 0.72, 0.38)
@export var lantern_spill_energy: float = 0.55

var _lantern_time: float = -1.0
var _lantern_glow: float = 0.0
var _lantern_offset: float = 0.0
var _lantern_strip: MeshInstance3D = null
var _lantern_strip_material: StandardMaterial3D = null
var _lantern_spill: OmniLight3D = null

## Someone heavier than the operator, heard through a closed door: lower,
## muffled.
const PITCH_VARIATIONS: Array[float] = [0.84, 0.88, 0.82]
const THROUGH_DOOR_CUTOFF_HZ: float = 1400.0
## An ear to the wood lets more of the step through.
const LISTENING_CUTOFF_HZ: float = 3600.0
var _listener: PlayerController = null
const FOLEY_SAFETY_MARGIN: float = 0.08

func _ready() -> void:
	_setup_audio_player()
	_setup_lantern()

func _setup_lantern() -> void:
	if _lantern_strip != null:
		return
	_lantern_strip = MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(0.2, 0.005, 0.006)
	_lantern_strip_material = StandardMaterial3D.new()
	_lantern_strip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	strip.material = _lantern_strip_material
	_lantern_strip.mesh = strip
	_lantern_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern_strip.visible = false
	add_child(_lantern_strip)
	# The spill lies on the boards just inside the door: small and low, so it
	# reaches the floor and nothing else.
	_lantern_spill = OmniLight3D.new()
	_lantern_spill.light_color = lantern_color
	_lantern_spill.light_energy = 0.0
	_lantern_spill.omni_range = 0.7
	_lantern_spill.omni_attenuation = 1.8
	_lantern_spill.shadow_enabled = false
	_lantern_spill.visible = false
	add_child(_lantern_spill)

func get_lantern_glow() -> float:
	return _lantern_glow

func get_lantern_offset() -> float:
	return _lantern_offset

func _advance_lantern(delta: float) -> void:
	if _lantern_time < 0.0:
		return
	_lantern_time += delta
	if is_active and steps_played > 0:
		# If Morse delays the next step, the lantern waits with it.
		_lantern_time = minf(_lantern_time, step_interval * float(steps_played))
	var duration := step_interval * float(total_steps) + 0.9
	var progress := clampf(_lantern_time / duration, 0.0, 1.0)
	_lantern_offset = lerpf(-lantern_gap_half_width, lantern_gap_half_width, progress)
	_lantern_glow = pow(sin(PI * progress), 0.7) if progress < 1.0 else 0.0
	if progress >= 1.0:
		_lantern_time = -1.0
	_apply_lantern()

func _apply_lantern() -> void:
	var lit := _lantern_glow > 0.001
	if _lantern_strip != null:
		_lantern_strip.visible = lit
		_lantern_strip.position = lantern_gap_local + Vector3(_lantern_offset, 0.0, 0.0)
		_lantern_strip_material.albedo_color = Color(0.42, 0.34, 0.24).lerp(lantern_color * 1.6, _lantern_glow)
	if _lantern_spill != null:
		_lantern_spill.visible = lit
		_lantern_spill.position = lantern_gap_local + Vector3(_lantern_offset, 0.05, -0.18)
		_lantern_spill.light_energy = lantern_spill_energy * _lantern_glow

func _setup_audio_player() -> void:
	if _player == null:
		_player = AudioStreamPlayer3D.new()
		_player.name = "FootstepPlayer"
		_player.stream = footstep_sound
		_player.volume_db = volume_db
		_player.pitch_scale = 1.0
		_player.max_distance = 12.0
		_player.attenuation_filter_cutoff_hz = THROUGH_DOOR_CUTOFF_HZ
		_player.attenuation_filter_db = -18.0
		# The steps are the designed attention event of a critical copy: they ride
		# the Events bus, which the fairness gate (7.7) does not duck.
		_player.bus = &"Events" if AudioServer.get_bus_index(&"Events") >= 0 else &"Master"
		add_child(_player)

func trigger_footsteps() -> void:
	if is_active:
		return
	is_active = true
	steps_played = 0
	_step_timer = 0.0
	_bind_fairness()
	if not _can_start_next_step():
		return
	_play_step()

func _play_step() -> void:
	var pitch_idx := steps_played % PITCH_VARIATIONS.size()
	if _player != null:
		_player.pitch_scale = PITCH_VARIATIONS[pitch_idx]
		if is_inside_tree():
			_player.play()

	steps_played += 1
	_step_timer = step_interval
	if steps_played == 1:
		_lantern_time = 0.0
		_advance_lantern(0.0)
		footsteps_started.emit()

	if steps_played >= total_steps:
		is_active = false
		footsteps_completed.emit()

func _process(delta: float) -> void:
	_bind_fairness()
	_listen_at_door()
	if is_active and steps_played < total_steps:
		_step_timer -= delta
		if _step_timer <= 0.0 and _can_start_next_step():
			_play_step()
	_advance_lantern(delta)

## An ear to the door (plan 3.8): leaning in close, the steps beyond it come
## through less muffled. The same lean that reads the copy and peers at the yard.
func _listen_at_door() -> void:
	if _player == null:
		return
	if _listener == null:
		_listener = get_parent().get_node_or_null("Player") as PlayerController if get_parent() != null else null
		if _listener == null:
			return
	var closeness := 0.0
	if _listener.camera != null:
		var distance := _listener.camera.global_position.distance_to(global_position)
		closeness = 1.0 - smoothstep(0.9, 1.7, distance)
	var listening := _listener.get_lean_weight() * closeness
	_player.attenuation_filter_cutoff_hz = lerpf(THROUGH_DOOR_CUTOFF_HZ, LISTENING_CUTOFF_HZ, listening)

## True when a sample of [param seconds] (plus safety margin) finishes before
## the next MARK. Only a GAP with enough room left admits optional foley.
func can_fit_foley(seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 0.0:
		return false
	if scheduler == null or not scheduler.is_playing():
		return true
	var event := scheduler.get_current_event()
	if event == null or event.kind != MorseTimingEvent.Kind.GAP:
		return false
	return event.end_seconds - scheduler.get_elapsed_seconds() >= seconds + FOLEY_SAFETY_MARGIN

func _can_start_next_step() -> bool:
	if footstep_sound == null:
		return true
	var pitch := PITCH_VARIATIONS[steps_played % PITCH_VARIATIONS.size()]
	return can_fit_foley(footstep_sound.get_length() / maxf(pitch, 0.01))

func _bind_fairness() -> void:
	if _bound_scheduler == scheduler:
		return
	if is_instance_valid(_bound_scheduler) and _bound_scheduler.timing_event_started.is_connected(_on_wire_event):
		_bound_scheduler.timing_event_started.disconnect(_on_wire_event)
	_bound_scheduler = scheduler
	if scheduler != null:
		scheduler.timing_event_started.connect(_on_wire_event)

func _on_wire_event(event: MorseScheduledEvent) -> void:
	if event.kind == MorseTimingEvent.Kind.MARK and _player != null and _player.playing:
		_player.stop()
