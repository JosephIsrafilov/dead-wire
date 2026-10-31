class_name OfficeAmbience
extends Node3D

## Continuous sound bed for the M1 office.
##
## The office is a divided-attention machine, so every layer except the room tone
## is positional: the player must be able to tell the window from the stove from
## the clock by ear alone, without looking.
##
## Nothing here competes with the sounder. All layers sit on the dedicated
## "Ambience" bus so the transmission mix can be balanced independently, and the
## clock is deliberately quiet — Morse timing is data and must stay readable.

signal clock_ticked(tick_count: int)

@export var room_tone_stream: AudioStream = preload("res://audio/sfx/ambience/room_tone.wav")
@export var wind_stream: AudioStream = preload("res://audio/sfx/ambience/wind_window.wav")
@export var stove_stream: AudioStream = preload("res://audio/sfx/ambience/stove_fire.wav")
@export var clock_tick_stream: AudioStream = preload("res://audio/sfx/foley/clock_tick.wav")
## Plan 7.9: the escapement strikes differently at the two ends of the swing.
@export var clock_tock_stream: AudioStream = preload("res://audio/sfx/foley/clock_tock.wav")
## Plan 7.8: wind in the telegraph wire outside, heard through the glass.
@export var wire_stream: AudioStream = preload("res://audio/sfx/ambience/wire_sing.wav")
@export var wire_volume_db: float = -14.0
@export var wire_position: Vector3 = Vector3(-1.5, 2.7, -3.4)
## Through the closed pane only the low hum reaches the room; with the door
## open the wire is brighter and nearer.
@export var wire_glass_cutoff_hz: float = 1400.0
@export var wire_open_cutoff_hz: float = 6000.0
@export var wire_open_boost_db: float = 6.0

@export var ambience_bus: StringName = &"Ambience"

@export var room_tone_volume_db: float = -12.0
@export var wind_volume_db: float = -9.0
@export var stove_volume_db: float = -13.0
@export var clock_volume_db: float = -17.0

## Local positions of the physical sources, relative to this node.
@export var wind_position: Vector3 = Vector3(-1.5, 1.55, -2.36)
@export var stove_position: Vector3 = Vector3(2.1, 0.75, 1.55)
@export var clock_position: Vector3 = Vector3(-2.8, 2.16, 0.62)

@export var wind_max_distance: float = 9.0
@export var stove_max_distance: float = 7.0
@export var clock_max_distance: float = 8.0

## A regulator clock runs at one escapement beat per second.
@export var clock_interval_seconds: float = 1.0
@export var clock_enabled: bool = true

var room_tone_player: AudioStreamPlayer = null
var wind_player: AudioStreamPlayer3D = null
var stove_player: AudioStreamPlayer3D = null
var clock_player: AudioStreamPlayer3D = null
var wire_player: AudioStreamPlayer3D = null
## Plan 7.5: in the hush before the last call the tick drops out of hearing.
## The movement keeps going — the pendulum and the hands do not stop.
var clock_muted: bool = false
var _hush_db: float = 0.0
var _outside_open: bool = false

var ticks_played: int = 0

var _clock_elapsed: float = 0.0

## Scene-local attenuation leaves the player's bus volume untouched, including
## when settings change mid-hush or the scene is abandoned.
func set_hush_db(value: float) -> void:
	_hush_db = value
	if wire_player != null:
		wire_player.volume_db = wire_volume_db + value + (wire_open_boost_db if _outside_open else 0.0)
	if room_tone_player != null:
		room_tone_player.volume_db = room_tone_volume_db + value
	if wind_player != null:
		wind_player.volume_db = wind_volume_db + value
	if stove_player != null:
		stove_player.volume_db = stove_volume_db + value
	if clock_player != null:
		clock_player.volume_db = clock_volume_db + value

func _ready() -> void:
	build_players()
	start()

func build_players() -> void:
	if room_tone_player == null:
		room_tone_player = AudioStreamPlayer.new()
		room_tone_player.name = "RoomTonePlayer"
		room_tone_player.stream = as_looping(room_tone_stream)
		room_tone_player.volume_db = room_tone_volume_db
		room_tone_player.bus = ambience_bus
		add_child(room_tone_player)

	if wind_player == null:
		wind_player = _build_positional(
			"WindPlayer", as_looping(wind_stream), wind_volume_db, wind_position, wind_max_distance)
	if stove_player == null:
		stove_player = _build_positional(
			"StovePlayer", as_looping(stove_stream), stove_volume_db, stove_position, stove_max_distance)
	if clock_player == null:
		clock_player = _build_positional(
			"ClockPlayer", clock_tick_stream, clock_volume_db, clock_position, clock_max_distance)
	if wire_player == null and wire_stream != null:
		wire_player = _build_positional(
			"WirePlayer", as_looping(wire_stream), wire_volume_db, wire_position, wind_max_distance)
		wire_player.attenuation_filter_cutoff_hz = wire_glass_cutoff_hz
		wire_player.attenuation_filter_db = -12.0

## The door is open to the night: the wire is heard without the glass.
func open_to_outside(open: bool = true) -> void:
	_outside_open = open
	if wire_player != null:
		wire_player.attenuation_filter_cutoff_hz = wire_open_cutoff_hz if open else wire_glass_cutoff_hz
	set_hush_db(_hush_db)

func is_open_to_outside() -> bool:
	return _outside_open

## The beds' loop is pinned in their tracked .import files (edit/loop_mode=1), so the
## importer already delivers looping streams. This guard stays: if a bed is ever
## re-exported without the flag, the room must not fall silent on a fresh checkout.
static func as_looping(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null or wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return stream

	var looping := wav.duplicate() as AudioStreamWAV
	looping.loop_mode = AudioStreamWAV.LOOP_FORWARD
	looping.loop_begin = 0
	looping.loop_end = int(round(looping.get_length() * float(looping.mix_rate)))
	return looping

func _build_positional(
	node_name: String, stream: AudioStream, volume_db: float,
	local_position: Vector3, max_distance: float
) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.stream = stream
	player.volume_db = volume_db
	player.bus = ambience_bus
	player.position = local_position
	player.max_distance = max_distance
	player.unit_size = 3.0
	add_child(player)
	return player

func start() -> void:
	_play_loop(room_tone_player)
	_play_loop(wind_player)
	_play_loop(stove_player)
	_play_loop(wire_player)
	var door := get_node_or_null("../SouthDoor/DoorController")
	if door != null and door.has_signal(&"door_opened") and not door.door_opened.is_connected(open_to_outside):
		door.door_opened.connect(open_to_outside.bind(true))

func stop() -> void:
	for player in [room_tone_player, wind_player, stove_player, clock_player, wire_player]:
		if player != null and player.playing:
			player.stop()

func _play_loop(player: Node) -> void:
	if player == null or player.stream == null:
		return
	if not player.playing:
		player.play()

func _process(delta: float) -> void:
	advance_clock(delta)

## Separated from _process so tests can drive the escapement without a real frame.
func advance_clock(delta: float) -> void:
	if not clock_enabled or clock_interval_seconds <= 0.0:
		return

	_clock_elapsed += delta
	while _clock_elapsed >= clock_interval_seconds:
		_clock_elapsed -= clock_interval_seconds
		_emit_tick()

func _emit_tick() -> void:
	ticks_played += 1
	if clock_player != null and is_inside_tree() and not clock_muted:
		# Tick at one end of the swing, tock at the other.
		var tock := ticks_played % 2 == 0 and clock_tock_stream != null
		clock_player.stream = clock_tock_stream if tock else clock_tick_stream
		if clock_player.stream != null:
			clock_player.play()
	clock_ticked.emit(ticks_played)

## The room's one mechanical clock, in seconds since the scene started ticking.
## The station clock's pendulum reads this so the swing and the tick share a
## phase instead of drifting apart.
func get_mechanical_elapsed() -> float:
	return _clock_elapsed + float(ticks_played) * clock_interval_seconds

func reset_telemetry() -> void:
	ticks_played = 0
	_clock_elapsed = 0.0
