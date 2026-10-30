class_name SilenceTwo
extends Node

## Silence 2: the window teaches (plan 4.1).
##
## In the quiet before the second call an ordinary cloud crosses the moon: the
## light on the floor goes down and comes back, and the cloud is there in the
## sky to see. The sash creaks once in the wind, from the window. Nothing
## threatens. The player learns that the window is a place where things happen
## and that most of them are weather - which is what silence 3 then leans on.
##
## Runs on the shift director's clock; it happens once a night.

@export var slot_index: int = 1
## Late in the silence, after the foreign traffic has had the wire.
@export var cloud_after_seconds: float = 24.0
@export var cloud_hold_seconds: float = 7.0
@export var creak_stream: AudioStream = preload("res://audio/sfx/foley/floor_creak_2.wav")
@export var creak_volume_db: float = -17.0
## A sash is lighter timber than a floorboard.
@export var creak_pitch: float = 1.3
@export var creak_position: Vector3 = Vector3(-1.5, 1.6, -2.3)

var moon: MoonWeather = null
var director: ShiftDirector = null
var creaks_played: int = 0

var _done: bool = false
var _creak_player: AudioStreamPlayer3D = null

func _ready() -> void:
	var office := get_parent()
	if office != null:
		if moon == null:
			moon = office.get_node_or_null("MoonWeather") as MoonWeather
		if director == null:
			director = office.get_node_or_null("ShiftDirector") as ShiftDirector
	_creak_player = AudioStreamPlayer3D.new()
	_creak_player.bus = &"Ambience"
	_creak_player.volume_db = creak_volume_db
	_creak_player.pitch_scale = creak_pitch
	_creak_player.stream = creak_stream
	add_child(_creak_player)

func _process(_delta: float) -> void:
	if director == null or director.get_phase() != ShiftDirector.Phase.WAITING:
		return
	update(director.get_slot_index(), director.get_phase_timer(), director.get_current_wait_seconds())

func update(slot: int, seconds_into_silence: float, _silence_seconds: float) -> void:
	if _done or slot != slot_index or seconds_into_silence < cloud_after_seconds:
		return
	_done = true
	if moon != null:
		moon.pass_cloud(cloud_hold_seconds)
	creaks_played += 1
	if _creak_player != null and _creak_player.is_inside_tree() and _creak_player.stream != null:
		_creak_player.global_position = creak_position
		_creak_player.play()
