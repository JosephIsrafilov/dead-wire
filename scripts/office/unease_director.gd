class_name UneaseDirector
extends Node3D

## Atmosphere, not events.
##
## Two techniques, both from how horror games actually build dread rather than
## from jump scares:
##
## 1. **The delayed creak.** When the operator stops moving, the building settles
##    a beat later. The canonical example in the literature is a floorboard
##    creaking about two seconds after the player stops — long enough that it
##    reads as a separate thing happening, not as his own footstep.
##
## 2. **Silence before the wire.** A continuous ambient bed conditions the player
##    and dulls fear; well-placed silence makes them distrust their own ears. The
##    room goes quiet a beat before every call, so the sounder always breaks
##    silence rather than competing with wind.
##
## Neither is the Listener. GDD §10 holds: nothing here moves an object, and a
## settling timber building is a complete explanation on its own.

signal creaked(position: Vector3)

@export var office: M1OfficeController = null
@export var ambience: OfficeAmbience = null
@export var director: ShiftDirector = null

@export var creak_streams: Array[AudioStream] = [
	preload("res://audio/sfx/foley/floor_creak_1.wav"),
	preload("res://audio/sfx/foley/floor_creak_2.wav"),
	preload("res://audio/sfx/foley/floor_creak_3.wav")
]
@export var creak_bus: StringName = &"Ambience"
@export var creak_volume_db: float = -14.0

## How long the operator must be still before the building answers.
@export var creak_dwell_seconds: float = 2.0
## Not every stop creaks. A guaranteed creak is a mechanic; an occasional one is
## a house.
@export var creak_chance: float = 0.45
## Never twice in a row from close to the same spot.
@export var creak_min_separation: float = 1.4
@export var creak_cooldown_seconds: float = 9.0

## Duck the bed to near-silence this long before a call lands.
@export var pre_call_hush_seconds: float = 2.2
@export var hush_depth_db: float = -26.0
@export var hush_recover_seconds: float = 1.6

var creaks_played: int = 0
var is_hushed: bool = false

var _dwell: float = 0.0
var _cooldown: float = 0.0
var _armed: bool = false
var _last_creak_position: Vector3 = Vector3(9999.0, 0.0, 9999.0)
var _rng := RandomNumberGenerator.new()
var _creak_player: AudioStreamPlayer3D = null
var _hush_tween: Tween
var _hush_elapsed: float = 0.0

func _ready() -> void:
	_rng.seed = 18940414
	_resolve()
	_build_player()
	if director != null and not director.call_started.is_connected(_on_call_started):
		director.call_started.connect(_on_call_started)

func _resolve() -> void:
	if office == null:
		office = get_parent() as M1OfficeController
	if office == null:
		return
	if ambience == null:
		ambience = office.get_node_or_null("OfficeAmbience") as OfficeAmbience
	if director == null:
		director = office.shift_director

func _build_player() -> void:
	if _creak_player != null:
		return
	_creak_player = AudioStreamPlayer3D.new()
	_creak_player.name = "CreakPlayer"
	_creak_player.bus = creak_bus
	_creak_player.volume_db = creak_volume_db
	_creak_player.max_distance = 12.0
	_creak_player.unit_size = 4.0
	add_child(_creak_player)


func _process(delta: float) -> void:
	advance(delta)

## Separated from _process so tests can drive the dwell timer directly.
func advance(delta: float) -> void:
	_resolve()
	if is_hushed:
		_hush_elapsed += delta
		if _hush_elapsed >= pre_call_hush_seconds:
			release_hush()
	_cooldown = maxf(0.0, _cooldown - delta)

	var player := office.player if office != null else null
	if player == null:
		return

	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if speed > 0.2:
		# Moving. Arm the creak so it can only fire after an actual stop.
		_dwell = 0.0
		_armed = true
		return

	if not _armed:
		return

	_dwell += delta
	if _dwell < creak_dwell_seconds:
		return

	_armed = false
	_dwell = 0.0
	if _cooldown > 0.0:
		return
	if _rng.randf() > creak_chance:
		return
	_creak_near(player.global_position)

func _creak_near(listener_position: Vector3) -> void:
	# Behind and to one side, never under the operator's own feet.
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(1.2, 2.4)
	var spot := listener_position + Vector3(cos(angle) * radius, -1.5, sin(angle) * radius)

	if spot.distance_to(_last_creak_position) < creak_min_separation:
		spot += Vector3(-sin(angle), 0.0, cos(angle)) * creak_min_separation

	_last_creak_position = spot
	creaks_played += 1
	_cooldown = creak_cooldown_seconds

	if _creak_player != null and not creak_streams.is_empty():
		_creak_player.stream = creak_streams[_rng.randi_range(0, creak_streams.size() - 1)]
		_creak_player.global_position = spot
		_creak_player.pitch_scale = _rng.randf_range(0.9, 1.12)
		_creak_player.play()

	creaked.emit(spot)

func _on_call_started(_slot_index: int, call_number: int) -> void:
	# Only the first call of a message gets the hush; repeats are already loud.
	if call_number == 1:
		hush()

## Drops the ambience bed so the sounder breaks silence rather than competing.
func hush() -> void:
	if ambience == null or is_hushed:
		return
	if _hush_tween != null:
		_hush_tween.kill()
	is_hushed = true
	_hush_elapsed = 0.0
	ambience.set_hush_db(hush_depth_db)

func release_hush() -> void:
	if not is_hushed:
		return
	is_hushed = false
	if ambience == null:
		return
	if not is_inside_tree():
		ambience.set_hush_db(0.0)
		return
	_hush_tween = create_tween()
	_hush_tween.tween_method(ambience.set_hush_db, hush_depth_db, 0.0, hush_recover_seconds) \
		.set_trans(Tween.TRANS_SINE)
