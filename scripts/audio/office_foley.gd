extends Node

const PAPER = preload("res://audio/sfx/foley/paper_turn.wav")
const STAMP = preload("res://audio/sfx/foley/ink_stamp.wav")
const LEVER = preload("res://audio/sfx/foley/route_lever.wav")
const LATCH = preload("res://audio/sfx/foley/door_latch.wav")
const CHAIR = preload("res://audio/sfx/foley/floor_creak_1.wav")

func _ready() -> void:
	_bind.call_deferred()

func _bind() -> void:
	var office := get_parent() as M1OfficeController
	var paper := AudioStreamPlayer.new()
	paper.name = "Paper"
	paper.stream = PAPER
	paper.volume_db = -20.0
	add_child(paper)
	office.document_viewer.document_opened.connect(func(_id): paper.play())
	office.document_viewer.document_closed.connect(func(_id): paper.play())
	var stamp := _source("Stamp", STAMP, office.copy_commit_desk.global_position, -13.0)
	office.copy_commit_desk.option_committed.connect(func(_id): stamp.play())
	var lever := _source("Lever", LEVER, office.routing_board.global_position + Vector3(0, 0.7, 0), -13.0)
	office.routing_board.routing_action_selected.connect(func(_action): lever.play())
	var latch := _source("Latch", LATCH, Vector3(-1.6, 1.0, 2.25), -15.0)
	office.office_door.door_rattled.connect(latch.play.bind(0.0))
	office.office_door.door_opened.connect(latch.play.bind(0.0))
	var chair := _source("Chair", CHAIR, office.get_node("Chair").global_position, -22.0)
	office.operator_seat.seated.connect(chair.play.bind(0.0))
	office.operator_seat.stood.connect(chair.play.bind(0.0))

func _source(label: String, stream: AudioStream, position: Vector3, volume: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = label
	player.stream = stream
	player.volume_db = volume
	player.unit_size = 2.0
	player.max_distance = 8.0
	add_child(player)
	player.global_position = position
	return player
