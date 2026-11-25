class_name NightTrainTraffic
extends Node3D

## Live night train movements visible and audible from the bay window (Phase 2).
##
## No. 17 moves right after baseline_train_17 closes if an order was set (passing
## through with warm carriage windows and a sweeping headlamp when cleared, or
## pulling up at the points with steam when held). No. 71 reacts on the mine spur
## after attention_hold_freight. Everything hides before shift_closed so DawnTrain
## owns the morning cleanly, and GDD §7 keeps audio ducked whenever Morse speaks.

const LOCOMOTIVE := preload("res://assets/models/dawn_train/no17.glb")
const PASSENGER_COACH := preload("res://assets/models/dawn_train/passenger_coach.glb")
const BAGGAGE_MAIL_CAR := preload("res://assets/models/dawn_train/baggage_mail_car.glb")
const GUARD_OBSERVATION_CAR := preload("res://assets/models/dawn_train/guard_observation_car.glb")
const Exhaust := preload("res://scripts/office/dawn_train_exhaust.gd")

const WHISTLE_STREAM := preload("res://audio/sfx/train/train_whistle.wav")
const RUMBLE_STREAM := preload("res://audio/sfx/train/train_rumble.wav")
const STEAM_STREAM := preload("res://audio/sfx/train/train_steam.wav")
const COUPLINGS_STREAM := preload("res://audio/sfx/ambience/outside_couplings.wav")
const CUP_CLINK_STREAM := preload("res://audio/sfx/foley/cup_clink.wav")

const STACK_OUTLET := Vector3(2.45, 3.73, 0.0)
const CYLINDER_OUTLET := Vector3(1.88, 0.89, 0.0)

const RAIL_LAYOUT := preload("res://scripts/town/black_creek_rail_layout.gd")

@export var line_z: float = RAIL_LAYOUT.OFFICE_MAIN_LINE_Z
@export var start_x: float = -62.0
@export var end_x: float = 76.0
@export var stand_x: float = -3.0
@export var pass_speed: float = 11.5

var _director: ShiftDirector = null
var _session: TelegraphSessionController = null
var _scheduler: MorseRuntimeScheduler = null
var _station: SeatedStationController = null
var _tin_cup: RigidBody3D = null

var _train17: Node3D = null
var _headlamp: SpotLight3D = null
var _window_sweep_light: OmniLight3D = null
var _exhaust: Exhaust = null
var _freight71: Node3D = null

var _whistle: AudioStreamPlayer3D = null
var _rumble: AudioStreamPlayer3D = null
var _steam: AudioStreamPlayer3D = null
var _cup_player: AudioStreamPlayer3D = null

var _armed_17: bool = false
var _delay_17: float = 0.0
var _done_17: bool = false
var _mode_17: String = ""
var _t17_time: float = -1.0
var _t17_x: float = -62.0
var _t17_steamed: bool = false
var _t17_cup_nudged: bool = false
var _t17_whistled: bool = false
var _t17_reacted: bool = false

var _armed_71: bool = false
var _delay_71: float = 0.0
var _done_71: bool = false
var _mode_71: String = ""
var _t71_time: float = -1.0

func _ready() -> void:
	_build_trains()
	_resolve_refs()
	_connect_signals()

func _resolve_refs() -> void:
	var office := get_parent()
	if office == null:
		return
	_director = office.get_node_or_null("ShiftDirector") as ShiftDirector
	_session = office.get_node_or_null("TelegraphSessionController") as TelegraphSessionController
	_scheduler = office.get_node_or_null("MorseRuntimeScheduler") as MorseRuntimeScheduler
	_station = office.get_node_or_null("SeatedStationController") as SeatedStationController
	_tin_cup = office.get_node_or_null("LooseProps/TinCup") as RigidBody3D

func _connect_signals() -> void:
	if _session != null and not _session.session_completed.is_connected(_on_session_completed):
		_session.session_completed.connect(_on_session_completed)
	if _director != null and not _director.shift_closed.is_connected(_on_shift_closed):
		_director.shift_closed.connect(_on_shift_closed)

func _on_session_completed(scen: TelegraphScenarioData) -> void:
	if scen == null:
		return
	if scen.scenario_id == "baseline_train_17" and not _done_17:
		_armed_17 = true
		_delay_17 = 1.4
	elif scen.scenario_id == "attention_hold_freight" and not _done_71:
		_armed_71 = true
		_delay_71 = 1.2

func _on_shift_closed() -> void:
	_armed_17 = false
	_armed_71 = false
	_t17_time = -1.0
	_t71_time = -1.0
	if _train17 != null:
		_train17.visible = false
	if _freight71 != null:
		_freight71.visible = false
	if _rumble != null:
		_rumble.stop()
	if _station != null:
		_station.tremor_offset_deg = Vector2.ZERO

## Immediately starts Train 17 across the yard (used both live and by verification).
func trigger_train_17_now(cleared: bool) -> void:
	if _train17 == null:
		_build_trains()
	_done_17 = true
	_armed_17 = false
	_mode_17 = "pass" if cleared else "stand"
	_t17_time = 0.0
	_t17_x = start_x
	_t17_steamed = false
	_t17_cup_nudged = false
	_t17_whistled = false
	_t17_reacted = false
	_exhaust.reset(0.0)
	_train17.visible = true
	_train17.position = Vector3(_t17_x, 0.0, line_z)
	if _can_play_audio() and _wire_idle():
		_t17_whistled = true
		_play_3d(_whistle, WHISTLE_STREAM, Vector3(-38.0, 3.5, line_z), -2.0)
	if _rumble != null and _can_play_audio():
		_rumble.stream = _looping(RUMBLE_STREAM)
		_rumble.volume_db = -28.0 if not _wire_idle() else -4.0
		_rumble.global_position = Vector3(_t17_x, 1.5, line_z)
		_rumble.play()

func trigger_freight_71_now(held: bool) -> void:
	if _freight71 == null:
		_build_trains()
	_done_71 = true
	_armed_71 = false
	_mode_71 = "stand" if held else "gone"
	_t71_time = 0.0
	_freight71.visible = true
	_freight71.position = Vector3(0.0, 0.0, -5.5 if held else 0.0)
	if _can_play_audio() and _wire_idle():
		if held:
			_play_3d(_steam, COUPLINGS_STREAM, Vector3(-2.5, 2.0, -24.0), -9.0)
		else:
			_play_3d(_steam, STEAM_STREAM, Vector3(-3.0, 2.0, -26.0), -11.0)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	var in_waiting := _director == null or _director.get_phase() == ShiftDirector.Phase.WAITING
	if _armed_17 and in_waiting:
		_delay_17 -= delta
		if _delay_17 <= 0.0 and _wire_idle():
			_resolve_and_launch_17()
	if _armed_71 and in_waiting:
		_delay_71 -= delta
		if _delay_71 <= 0.0 and _wire_idle():
			_resolve_and_launch_71()
	_advance_train_17(delta)
	_advance_freight_71(delta)

func _resolve_and_launch_17() -> void:
	var world := _world_state()
	if world != null and bool(world.get_fact(&"train_17_routed_clear", false)):
		trigger_train_17_now(true)
	elif world != null and bool(world.get_fact(&"train_17_held_in_error", false)):
		trigger_train_17_now(false)
	else:
		_done_17 = true
		_armed_17 = false

func _resolve_and_launch_71() -> void:
	var world := _world_state()
	if world != null and bool(world.get_fact(&"freight_held_correctly", false)):
		trigger_freight_71_now(true)
	elif world != null and bool(world.get_fact(&"freight_cleared_in_error", false)):
		trigger_freight_71_now(false)
	else:
		_done_71 = true
		_armed_71 = false

func _advance_train_17(delta: float) -> void:
	if _t17_time < 0.0 or _train17 == null:
		return
	_t17_time += delta
	var speed := pass_speed
	if _mode_17 == "pass":
		_t17_x = start_x + pass_speed * _t17_time
	else:
		_t17_x = stand_x + (start_x - stand_x) * exp(-0.28 * _t17_time)
		speed = absf(stand_x - _t17_x) * 0.28
	_train17.position = Vector3(_t17_x, 0.0, line_z)
	_exhaust.advance(_t17_time, _train17.position + STACK_OUTLET, _train17.position + CYLINDER_OUTLET,
		speed, _train17.visible)

	if not _t17_whistled and _t17_x > -34.0 and _wire_idle() and _can_play_audio():
		_t17_whistled = true
		_play_3d(_whistle, WHISTLE_STREAM, _train17.global_position + Vector3(2.0, 3.0, 0.0), +1.0)

	if _mode_17 == "stand" and not _t17_steamed and absf(_t17_x - stand_x) < 1.2:
		_t17_steamed = true
		_exhaust.release_steam(_t17_time)
		if _wire_idle() and _can_play_audio():
			_play_3d(_steam, STEAM_STREAM, _train17.global_position + CYLINDER_OUTLET, -1.5)

	if not _t17_reacted and _t17_x >= -14.0 and _wire_idle() and DisplayServer.get_name() != "headless":
		_t17_reacted = true
		var office := get_parent()
		var murmur := office.get_node_or_null("MurmurCaption") as MurmurCaption if office != null else null
		if murmur != null:
			if _mode_17 == "pass":
				murmur.show_outside_line(
					GameLocale.pick(
						"Вот и семнадцатый — пошёл по главному пути на восток. Прожектор бьёт прямо в стекло.",
						"There goes Number 17 — rolling clear on the main eastbound. Headlamp cuts straight through the bay glass."
					),
					4.8
				)
			else:
				murmur.show_outside_line(
					GameLocale.pick(
						"Семнадцатый затормозил у входного семафора — пар шипит во весь двор.",
						"Number 17 pulled up at the stop board — blowing off steam across the yard."
					),
					4.8
				)

	if _window_sweep_light != null:
		var pass_glow := clampf(1.0 - absf(_t17_x + 2.5) / 14.0, 0.0, 1.0)
		_window_sweep_light.position = Vector3(clampf(_t17_x * 0.35 - 0.8, -3.5, 1.5), 1.65, -2.95)
		_window_sweep_light.light_energy = pass_glow * 3.8

	if _mode_17 == "pass" and not _t17_cup_nudged and _t17_x >= -6.0:
		_t17_cup_nudged = true
		if _tin_cup != null:
			_tin_cup.apply_central_impulse(Vector3(0.012, 0.008, 0.006))
		if _wire_idle() and _can_play_audio() and _cup_player != null:
			_play_3d(_cup_player, CUP_CLINK_STREAM, Vector3(-1.82, 0.80, -1.86), -14.0)

	_update_rumble_and_tremor(speed)

	if _mode_17 == "pass" and _t17_x >= end_x:
		_t17_time = -1.0
		_train17.visible = false
		if _window_sweep_light != null:
			_window_sweep_light.light_energy = 0.0
		if _rumble != null:
			_rumble.stop()
		if _station != null:
			_station.tremor_offset_deg = Vector2.ZERO

func _update_rumble_and_tremor(speed: float) -> void:
	var near_window := _t17_x >= -18.0 and _t17_x <= 14.0 and speed > 1.2
	if _station != null:
		if near_window:
			_station.tremor_offset_deg = Vector2(
				0.14 * sin(_t17_time * 37.0),
				0.20 * cos(_t17_time * 43.0)
			)
		else:
			_station.tremor_offset_deg = Vector2.ZERO
	if _rumble != null and _rumble.playing:
		_rumble.global_position = Vector3(_t17_x, 1.5, line_z)
		var base_db := -1.5 if near_window else -9.0
		if _mode_17 == "stand":
			base_db = lerpf(-18.0, -5.0, clampf(speed / 6.0, 0.0, 1.0))
		_rumble.volume_db = -28.0 if not _wire_idle() else base_db

func _advance_freight_71(delta: float) -> void:
	if _t71_time < 0.0 or _freight71 == null or not _freight71.visible:
		return
	_t71_time += delta
	if _mode_71 == "stand":
		var t := clampf(_t71_time / 4.2, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 2.0)
		_freight71.position = Vector3(0.0, 0.0, lerpf(-5.5, 0.0, eased))
	else:
		_freight71.position = Vector3(-0.35 * _t71_time, 0.0, -3.2 * _t71_time)
		if _t71_time >= 8.0:
			_t71_time = -1.0
			_freight71.visible = false

func _world_state() -> WorldStateStore:
	return get_tree().root.get_node_or_null("WorldState") as WorldStateStore if is_inside_tree() else null

func _wire_idle() -> bool:
	return _scheduler == null or not _scheduler.is_playing()

func _can_play_audio() -> bool:
	return DisplayServer.get_name() != "headless" and is_inside_tree()

func _play_3d(player: AudioStreamPlayer3D, stream: AudioStream, at: Vector3, vol_db: float) -> void:
	if player == null or stream == null or not player.is_inside_tree():
		return
	player.stream = stream
	player.volume_db = vol_db
	player.global_position = at
	player.play()

func _looping(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return stream
	var copy := wav.duplicate() as AudioStreamWAV
	copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	copy.loop_begin = 0
	copy.loop_end = int(wav.get_length() * wav.mix_rate)
	return copy

func _build_trains() -> void:
	if _train17 != null:
		return
	_train17 = Node3D.new()
	_train17.name = "LiveNo17"
	add_child(_train17)
	var loco := LOCOMOTIVE.instantiate()
	_train17.add_child(loco)
	for m: MeshInstance3D in loco.find_children("*", "MeshInstance3D"):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = Color(1.0, 0.88, 0.62)
	bulb_mat.disable_fog = true
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.22
	bulb_mesh.height = 0.44
	var bulb := MeshInstance3D.new()
	bulb.mesh = bulb_mesh
	bulb.material_override = bulb_mat
	bulb.position = Vector3(3.05, 2.35, 0.0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_train17.add_child(bulb)

	_headlamp = SpotLight3D.new()
	_headlamp.name = "HeadlampSpot"
	_headlamp.position = Vector3(3.12, 2.35, 0.0)
	_headlamp.rotation = Vector3(-0.06, -1.62, 0.0)
	_headlamp.light_color = Color(1.0, 0.86, 0.56)
	_headlamp.light_energy = 26.0
	_headlamp.spot_range = 52.0
	_headlamp.spot_attenuation = 0.72
	_headlamp.spot_angle = 36.0
	_headlamp.shadow_enabled = false
	_train17.add_child(_headlamp)

	if _window_sweep_light == null:
		_window_sweep_light = OmniLight3D.new()
		_window_sweep_light.name = "TrainWindowSweep"
		_window_sweep_light.light_color = Color(1.0, 0.80, 0.46)
		_window_sweep_light.light_energy = 0.0
		_window_sweep_light.omni_range = 8.5
		_window_sweep_light.omni_attenuation = 1.4
		_window_sweep_light.shadow_enabled = false
		add_child(_window_sweep_light)

	var win_mat := StandardMaterial3D.new()
	win_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	win_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	win_mat.albedo_color = Color(1.0, 0.78, 0.42, 0.92)
	win_mat.disable_fog = true
	var win_mesh := BoxMesh.new()
	win_mesh.size = Vector3(0.46, 0.42, 0.04)

	for car_x in [-15.12, -27.92, -39.31]:
		var packed: PackedScene = PASSENGER_COACH
		if is_equal_approx(car_x, -27.92):
			packed = BAGGAGE_MAIL_CAR
		elif is_equal_approx(car_x, -39.31):
			packed = GUARD_OBSERVATION_CAR
		var car := packed.instantiate()
		car.position = Vector3(car_x, 0.0, 0.0)
		_train17.add_child(car)
		for m: MeshInstance3D in car.find_children("*", "MeshInstance3D"):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for w in 5:
			var win := MeshInstance3D.new()
			win.mesh = win_mesh
			win.material_override = win_mat
			win.position = Vector3(car_x - 3.0 + float(w) * 1.5, 2.34, 1.32)
			win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_train17.add_child(win)

	_train17.visible = false
	_exhaust = Exhaust.new()
	_exhaust.name = "LiveNo17Exhaust"
	add_child(_exhaust)

	_freight71 = Node3D.new()
	_freight71.name = "LiveFreight71"
	add_child(_freight71)
	var dark_mat := StandardMaterial3D.new()
	dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark_mat.albedo_color = Color(0.02, 0.024, 0.032)
	var tail_mat := StandardMaterial3D.new()
	tail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tail_mat.albedo_color = Color(1.0, 0.2, 0.1)
	tail_mat.disable_fog = true
	for c in 3:
		var z := -27.0 - 11.0 * float(c)
		var x := -2.0 + 0.15 * (z + 6.0)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.8, 3.0, 10.0)
		box.mesh = bm
		box.material_override = dark_mat
		box.position = Vector3(x, 1.9, z)
		box.rotation.y = 0.148
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_freight71.add_child(box)
	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.22, 0.22, 0.06)
	tail.mesh = tm
	tail.material_override = tail_mat
	tail.position = Vector3(-2.75, 3.6, -21.9)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_freight71.add_child(tail)
	_freight71.visible = false

	_whistle = _make_audio(&"Ambience", 240.0)
	_whistle.unit_size = 36.0
	_rumble = _make_audio(&"Ambience", 70.0)
	_steam = _make_audio(&"Ambience", 50.0)
	_cup_player = _make_audio(&"Foley", 8.0)

func _make_audio(bus_name: StringName, max_dist: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = bus_name if AudioServer.get_bus_index(bus_name) >= 0 else &"Master"
	p.max_distance = max_dist
	p.unit_size = 12.0
	add_child(p)
	return p
