class_name DawnTrain
extends Node3D

## The morning after the board (plan 4.6), seen and heard from the window.
##
## No. 17, the morning passenger, comes along the main line beyond the yard:
## it runs past if it was cleared, comes to a stand at the points and blows off
## steam if it was held, and if no order went out it is only a whistle far off
## that never comes nearer. No. 71, the night freight, stands dark on the mine
## branch if it was held, or is simply gone if it was cleared into the shut
## mine's junction. What happens is read from WorldState (DawnTrainData); there
## is no verdict anywhere - the wire has already asked its question.
##
## It all happens after the watch is closed, so no train sound ever lies over
## Morse. Simple geometry under the night fog, like the rest of the yard.

const BEHAVIOUR_PASS: String = "pass"
const BEHAVIOUR_STAND: String = "stand"
const BEHAVIOUR_DISTANT: String = "distant"
const BEHAVIOUR_GONE: String = "gone"
const LOCOMOTIVE := preload("res://assets/models/dawn_train/no17.glb")
const PASSENGER_COACH := preload("res://assets/models/dawn_train/passenger_coach.glb")
const BAGGAGE_MAIL_CAR := preload("res://assets/models/dawn_train/baggage_mail_car.glb")
const GUARD_OBSERVATION_CAR := preload("res://assets/models/dawn_train/guard_observation_car.glb")
const Exhaust := preload("res://scripts/office/dawn_train_exhaust.gd")
# No. 17 model coordinates (+X forward, +Y up).
const STACK_OUTLET := Vector3(2.45, 3.73, 0.0)
const CYLINDER_OUTLET := Vector3(1.88, 0.89, 0.0)

@export var data: DawnTrainData = preload("res://data/night/dawn_train.tres")
## The main line runs across the view, this far out.
const RAIL_LAYOUT := preload("res://scripts/town/black_creek_rail_layout.gd")

@export var line_z: float = RAIL_LAYOUT.OFFICE_MAIN_LINE_Z
@export var start_x: float = -70.0
@export var end_x: float = 80.0
## Where a held No. 17 comes to a stand: by the points.
@export var stand_x: float = -3.0
@export var run_speed: float = 9.0
@export var brake_rate: float = 0.35
@export var first_whistle_seconds: float = 3.0
@export var departure_seconds: float = 6.0
@export var whistle_stream: AudioStream = preload("res://audio/sfx/train/train_whistle.wav")
@export var rumble_stream: AudioStream = preload("res://audio/sfx/train/train_rumble.wav")
@export var steam_stream: AudioStream = preload("res://audio/sfx/train/train_steam.wav")

var _passenger_behaviour: String = ""
var _freight_behaviour: String = ""
var _time: float = -1.0
var _passenger_x: float = 0.0
var _passenger_seen: bool = false
var _near_whistled: bool = false
var _steamed: bool = false

var _passenger: Node3D = null
var _freight: Node3D = null
var _whistle: AudioStreamPlayer3D = null
var _rumble: AudioStreamPlayer3D = null
var _steam: AudioStreamPlayer3D = null
var _exhaust: Exhaust
var _silhouette: StandardMaterial3D = null

func _ready() -> void:
	_build()
	var office := get_parent()
	var director := office.get_node_or_null("ShiftDirector") as ShiftDirector if office != null else null
	if director != null and not director.shift_closed.is_connected(_on_shift_closed):
		director.shift_closed.connect(_on_shift_closed)

func _on_shift_closed() -> void:
	var world := get_tree().root.get_node_or_null("WorldState") as WorldStateStore if is_inside_tree() else null
	if data == null:
		return
	begin(data.passenger_behaviour(world), data.freight_behaviour(world))

func _process(delta: float) -> void:
	advance(delta)

## Starts the morning: what No. 17 does, and whether No. 71 stands.
func begin(passenger_behaviour: String, freight_behaviour: String) -> void:
	if _passenger == null:
		_build()
	_passenger_behaviour = passenger_behaviour
	_freight_behaviour = freight_behaviour
	_time = 0.0
	_passenger_x = start_x
	_passenger_seen = false
	_near_whistled = false
	_steamed = false
	_exhaust.reset(departure_seconds)
	_freight.visible = freight_behaviour == BEHAVIOUR_STAND
	_place_passenger()

func get_passenger_x() -> float:
	return _passenger_x

func was_passenger_visible() -> bool:
	return _passenger_seen

func advance(delta: float) -> void:
	if _time < 0.0:
		return
	var before := _time
	_time += delta
	if before < first_whistle_seconds and _time >= first_whistle_seconds:
		# The first whistle is always far off to the west, before anything moves.
		_play(_whistle, whistle_stream, Vector3(start_x - 60.0, 4.0, line_z - 30.0), -6.0)
	if _passenger_behaviour == BEHAVIOUR_DISTANT:
		if before < first_whistle_seconds + 9.0 and _time >= first_whistle_seconds + 9.0:
			_play(_whistle, whistle_stream, Vector3(start_x - 70.0, 4.0, line_z - 40.0), -9.0)
		return
	if _time < departure_seconds:
		return
	var moving := _time - departure_seconds
	var speed := run_speed
	if _passenger_behaviour == BEHAVIOUR_PASS:
		_passenger_x = start_x + run_speed * moving
	else:
		_passenger_x = stand_x + (start_x - stand_x) * exp(-brake_rate * moving)
		speed = absf(stand_x - _passenger_x) * brake_rate
	_passenger_seen = true
	_place_passenger()
	if _rumble != null and not _rumble.playing and _passenger_x < end_x and _rumble.is_inside_tree():
		_rumble.stream = _looping(rumble_stream)
		_rumble.play()
	if _rumble != null:
		var easing := 1.0
		if _passenger_behaviour == BEHAVIOUR_STAND:
			easing = clampf(absf(_passenger_x - stand_x) / 12.0, 0.0, 1.0)
		_rumble.volume_db = linear_to_db(maxf(easing, 0.001)) - 4.0
		if _passenger_x >= end_x:
			_rumble.stop()
	if not _near_whistled and _passenger_x > -30.0:
		_near_whistled = true
		var at := _passenger.global_position if _passenger.is_inside_tree() else Vector3.ZERO
		_play(_whistle, whistle_stream, at + Vector3(2.0, 3.0, 0.0), 0.0)
	if _passenger_behaviour == BEHAVIOUR_STAND and not _steamed and absf(_passenger_x - stand_x) < 1.0:
		_steamed = true
		_exhaust.release_steam(_time)
		var outlet := _passenger.to_global(CYLINDER_OUTLET) if is_inside_tree() else Vector3.ZERO
		_play(_steam, steam_stream, outlet, -3.0)
	_exhaust.advance(_time, _passenger.position + STACK_OUTLET,
		_passenger.position + CYLINDER_OUTLET, speed, _passenger.visible)

func _add_passenger_car(parent: Node3D, packed: PackedScene, x: float) -> void:
	var car := packed.instantiate()
	car.name = packed.resource_path.get_file().get_basename()
	car.position = Vector3(x, 0.0, 0.0)
	parent.add_child(car)
	# The dawn yard is read in silhouette; keep the detailed car dark enough to belong to it.
	for mesh: MeshInstance3D in car.find_children("*", "MeshInstance3D"):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _place_passenger() -> void:
	if _passenger == null:
		return
	_passenger.visible = _passenger_behaviour != BEHAVIOUR_DISTANT and _time >= departure_seconds \
			and _passenger_x < end_x
	_passenger.position = Vector3(_passenger_x, 0.0, line_z)
	if _rumble != null:
		_rumble.position = Vector3(_passenger_x, 1.5, line_z)

func _play(player: AudioStreamPlayer3D, stream: AudioStream, at: Vector3, volume_db: float) -> void:
	if player == null or stream == null or not player.is_inside_tree():
		return
	player.stream = stream
	player.volume_db = volume_db
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

# --- geometry ---------------------------------------------------------------

func _build() -> void:
	if _passenger != null:
		return
	_silhouette = _unshaded(Color(0.02, 0.024, 0.032), false)
	var tail := _unshaded(Color(1.0, 0.2, 0.1), true)

	_passenger = Node3D.new()
	_passenger.name = "PassengerNo17"
	add_child(_passenger)
	var locomotive := LOCOMOTIVE.instantiate()
	_passenger.add_child(locomotive)
	for mesh: MeshInstance3D in locomotive.find_children("*", "MeshInstance3D"):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Spacing follows the drawbars, not the bodies; the open end platforms remain visible.
	_add_passenger_car(_passenger, PASSENGER_COACH, -15.12)
	_add_passenger_car(_passenger, BAGGAGE_MAIL_CAR, -27.92)
	_add_passenger_car(_passenger, GUARD_OBSERVATION_CAR, -39.31)
	_passenger.visible = false
	_exhaust = Exhaust.new()
	_exhaust.name = "No17Exhaust"
	add_child(_exhaust)

	# No. 71: three dark box cars on the mine branch, a red lamp toward the yard.
	_freight = Node3D.new()
	_freight.name = "FreightNo71"
	add_child(_freight)
	for car in 3:
		var z := -27.0 - 11.0 * car
		var x := -2.0 + 0.15 * (z + 6.0)
		var boxcar := _box(_freight, Vector3(2.8, 3.0, 10.0), Vector3(x, 1.9, z), _silhouette)
		boxcar.rotation.y = 0.148
	_box(_freight, Vector3(0.22, 0.22, 0.06), Vector3(-2.75, 3.6, -21.9), tail)
	_freight.visible = false

	_whistle = _player(&"Ambience", 240.0)
	# The opening call is beyond the yard; it must reach the office, not be culled.
	_whistle.unit_size = 36.0
	_rumble = _player(&"Ambience", 70.0)
	_steam = _player(&"Ambience", 40.0)

func _player(bus: StringName, max_distance: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
	player.max_distance = max_distance
	player.unit_size = 12.0
	add_child(player)
	return player

func _unshaded(color: Color, no_fog: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.disable_fog = no_fog
	return material

func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(parent, box, at, material)

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
