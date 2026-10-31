class_name CreakyBoards
extends Node3D

## Plan 7.10: two boards in the floor that speak under the operator's weight —
## one just inside the door, one before the window. Each board always says the
## same thing (its own sample, a hair of pitch), so the room can be read by ear.
## They answer the operator's own steps only; nothing else ever loads them.

signal board_creaked(index: int)

@export var player: PlayerController
@export var board_positions: Array[Vector3] = [Vector3(-1.6, 0.0, 1.85), Vector3(-1.4, 0.0, -1.85)]
@export var board_streams: Array[AudioStream] = [
	preload("res://audio/sfx/foley/board_door.wav"),
	preload("res://audio/sfx/foley/board_window.wav"),
]
## How close to a board's centre a step has to land, on the floor plane.
@export var board_radius: float = 0.3
@export var volume_db: float = -19.0

var creaks_played: int = 0
var _players: Array[AudioStreamPlayer3D] = []
## A board speaks once as the weight comes on, not on every step taken on it.
var _loaded_board: int = -1

func _ready() -> void:
	for index in board_positions.size():
		var source := AudioStreamPlayer3D.new()
		source.name = "Board%d" % index
		source.stream = board_streams[index] if index < board_streams.size() else null
		source.bus = &"Foley"
		source.volume_db = volume_db
		source.unit_size = 2.0
		source.max_distance = 9.0
		source.position = board_positions[index]
		add_child(source)
		_players.append(source)
	if player == null:
		player = get_node_or_null("../Player") as PlayerController
	if player != null and not player.footstep_played.is_connected(_on_footstep):
		player.footstep_played.connect(_on_footstep)

func get_board_player(index: int) -> AudioStreamPlayer3D:
	return _players[index] if index >= 0 and index < _players.size() else null

## The board under a point on the floor, or -1.
func board_at(world_position: Vector3) -> int:
	var local := to_local(world_position)
	for index in board_positions.size():
		var offset := local - board_positions[index]
		if Vector2(offset.x, offset.z).length() <= board_radius:
			return index
	return -1

func _on_footstep(_step_index: int) -> void:
	if player == null:
		return
	step_at(player.global_position)

func step_at(world_position: Vector3) -> void:
	var board := board_at(world_position)
	if board == _loaded_board:
		return
	_loaded_board = board
	if board < 0:
		return
	creaks_played += 1
	var source := _players[board]
	if source.stream != null and source.is_inside_tree():
		source.pitch_scale = 1.0 + randf_range(-0.03, 0.03)
		source.play()
	board_creaked.emit(board)
