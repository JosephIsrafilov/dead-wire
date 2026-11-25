class_name DoorKnockSequence
extends Node3D

const WOOD_KNOCK := preload("res://audio/sfx/town/door_knock_wood.wav")
const LATCH := preload("res://audio/sfx/foley/door_latch.wav")

@export var thought_delay_seconds := 1.65

var _sound := AudioStreamPlayer3D.new()
var _active_door: Node3D
var _knock_serial := 0
var _waiting := false

func _ready() -> void:
	name = "DoorKnockSequence"
	_sound.name = "DoorFoley"
	_sound.bus = &"Foley"
	_sound.unit_size = 2.0
	_sound.max_distance = 10.0
	add_child(_sound)

func start(door: Node3D, thoughts: DawnWalkThoughts, text: String, use_latch := false) -> void:
	if door == null or thoughts == null or get_tree().paused:
		return
	if door == _active_door and (_waiting or _sound.playing):
		return
	cancel()
	_active_door = door
	_waiting = true
	thoughts.clear_thought()
	_sound.stream = LATCH if use_latch else WOOD_KNOCK
	_sound.volume_db = -7.0 if use_latch else -2.0
	_sound.global_position = door.global_position
	_sound.play()
	var serial := _knock_serial
	await get_tree().create_timer(thought_delay_seconds, false).timeout
	if serial != _knock_serial:
		return
	_waiting = false
	if is_instance_valid(door) and is_instance_valid(thoughts):
		thoughts.show_thought(text)

func is_pending() -> bool:
	return _waiting

func cancel() -> void:
	_knock_serial += 1
	_active_door = null
	_waiting = false
	_sound.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cancel()
