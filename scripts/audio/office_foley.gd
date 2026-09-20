extends Node

## S03 Luckius paper (CC0, opengameart.org/content/various-paper-sound-effects).
const PAPER = preload("res://audio/sfx/foley/paper_sheet.mp3")
## S01 Kenney impactPlate_heavy (CC0, kenney.nl/assets/impact-sounds).
const STAMP = preload("res://audio/sfx/foley/ink_stamp_cc0.ogg")
const LEVER = preload("res://audio/sfx/foley/route_lever.wav")
const LATCH = preload("res://audio/sfx/foley/door_latch.wav")
## S01 Kenney impactWood_medium (CC0): body weight meets the seat.
const CHAIR = preload("res://audio/sfx/foley/chair_settle_cc0.ogg")

## Local, physical sounds sit on their own bus so the room's fader never has to
## choose between the wind and a hand closing on paper.
const FOLEY_BUS: StringName = &"Foley"

func _ready() -> void:
	_bind.call_deferred()

func _bind() -> void:
	var office := get_parent() as M1OfficeController
	var paper := AudioStreamPlayer.new()
	paper.name = "Paper"
	paper.stream = PAPER
	paper.volume_db = -20.0
	paper.bus = FOLEY_BUS
	add_child(paper)
	office.document_viewer.document_opened.connect(func(_id): paper.play())
	office.document_viewer.document_closed.connect(func(_id): paper.play())
	# The new blank sheet landing on the writing zone has its own short
	# contact sound — the feed, not the viewer.
	var feed := AudioStreamPlayer.new()
	feed.name = "PaperFeed"
	feed.stream = PAPER
	feed.volume_db = -24.0
	feed.bus = FOLEY_BUS
	add_child(feed)
	office.session_controller.transcript_paper.sheet_fed.connect(func(): feed.play())
	var stamp := _source("Stamp", STAMP, office.copy_commit_desk.global_position, -13.0)
	# The stamp sound is the physical contact of the press, never the intent
	# a deadline may still reject (B1), and never the acceptance itself.
	office.copy_commit_desk.stamp_contact.connect(func(_id): stamp.play())
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
	player.bus = FOLEY_BUS
	add_child(player)
	player.global_position = position
	return player
