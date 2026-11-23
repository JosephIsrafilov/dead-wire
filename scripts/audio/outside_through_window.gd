class_name OutsideThroughWindow
extends Node3D

## Plan 7.2: the yard is heard through the glass — the headframe working in the
## wind, switch points thrown, a string of cars taking up slack. Rare, far off,
## dulled by the pane and coming from beyond the north window, so the player
## learns where outside is by ear. Never over a critical copy, never in the hush
## before the last call: silence stays silence (GDD §7, no stingers).

signal yard_sounded(stream: AudioStream)

@export var office: M1OfficeController
@export var ambience: OfficeAmbience
@export var streams: Array[AudioStream] = [
	preload("res://audio/sfx/ambience/outside_headframe.wav"),
	preload("res://audio/sfx/ambience/outside_switch.wav"),
	preload("res://audio/sfx/ambience/outside_couplings.wav"),
]
@export var first_after_seconds: float = 45.0
@export var min_interval_seconds: float = 35.0
@export var max_interval_seconds: float = 90.0
## Measured in the night recording: at -15 dB, behind distance, glass and the
## room's bus, the yard sat level with the room tone and was not heard at all.
@export var volume_db: float = -9.0
## Sources stand out in the yard, beyond the north wall (z = -2.36).
@export var yard_min: Vector3 = Vector3(-7.0, 0.5, -14.0)
@export var yard_max: Vector3 = Vector3(5.0, 6.0, -7.0)
## The pane takes the edge off, not the iron: at 1100 Hz / -18 dB the switch
## points and the couplings vanished under the room tone in the recording.
@export var glass_cutoff_hz: float = 2500.0
@export var glass_filter_db: float = -10.0
@export var open_cutoff_hz: float = 5000.0
## Seconds of quiet a sound needs before the next call, beyond its own length:
## it must end before the call, and before the hush that precedes the last one.
@export var call_clearance_seconds: float = 4.0

var sounds_played: int = 0
var _player: AudioStreamPlayer3D = null
var _wait: float = 0.0
var _last_stream: int = -1
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if office == null:
		office = get_parent() as M1OfficeController
	if ambience == null and office != null:
		ambience = office.get_node_or_null("OfficeAmbience") as OfficeAmbience
	_player = AudioStreamPlayer3D.new()
	_player.name = "YardPlayer"
	_player.bus = &"Ambience"
	_player.volume_db = volume_db
	_player.unit_size = 8.0
	_player.max_distance = 40.0
	_player.attenuation_filter_db = glass_filter_db
	add_child(_player)
	_rng.randomize()
	_wait = first_after_seconds

func get_player() -> AudioStreamPlayer3D:
	return _player

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	_wait -= maxf(delta, 0.0)
	if _wait > 0.0:
		return
	if not is_quiet_allowed():
		# Try again shortly after the wire or the hush lets go.
		_wait = 4.0
		return
	play_next()
	_wait = _rng.randf_range(min_interval_seconds, max_interval_seconds)

## The phases in which the wire is calling, being answered or being copied.
const BUSY_PHASES: Array[ShiftDirector.Phase] = [
	ShiftDirector.Phase.CALLING, ShiftDirector.Phase.ANSWERING, ShiftDirector.Phase.RECEIVING]

## Whether the yard may speak now: only in a real quiet. Not while anything is
## on the wire, not between the answer and the first mark (a 3 s sound started
## there would run into the copy), not after a critical copy until the room is
## back, not in a hush.
func is_quiet_allowed() -> bool:
	var director := office.shift_director if office != null else null
	if director != null and director.get_phase() in BUSY_PHASES:
		return false
	if director != null and director.get_phase() == ShiftDirector.Phase.WAITING:
		var until_call := director.get_current_wait_seconds() - director.get_phase_timer()
		if until_call < _longest_seconds() + call_clearance_seconds:
			return false
	var session := office.session_controller if office != null else null
	if session != null and session.scheduler != null and session.scheduler.is_playing():
		return false
	var gate := office.get_node_or_null("FairnessGate") as FairnessGate if office != null else null
	if gate != null and (gate.is_critical_live() or gate.get_duck_db() < -0.5):
		return false
	if ambience != null and (ambience.clock_muted or ambience.get_hush_db() < -1.0):
		return false
	return true

func _longest_seconds() -> float:
	var longest := 0.0
	for stream in streams:
		if stream != null:
			longest = maxf(longest, stream.get_length())
	return longest

func play_next() -> void:
	if streams.is_empty() or _player == null:
		return
	var pick := _rng.randi_range(0, streams.size() - 1)
	if pick == _last_stream and streams.size() > 1:
		pick = (pick + 1) % streams.size()
	_last_stream = pick
	_player.stream = streams[pick]
	_player.position = Vector3(_rng.randf_range(yard_min.x, yard_max.x), _rng.randf_range(yard_min.y, yard_max.y),
		_rng.randf_range(yard_min.z, yard_max.z))
	var open := ambience != null and ambience.is_open_to_outside()
	_player.attenuation_filter_cutoff_hz = open_cutoff_hz if open else glass_cutoff_hz
	_player.pitch_scale = _rng.randf_range(0.94, 1.05)
	sounds_played += 1
	if _player.is_inside_tree():
		_player.play()
	yard_sounded.emit(_player.stream)
