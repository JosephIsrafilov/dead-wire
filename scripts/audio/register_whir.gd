class_name RegisterWhir
extends Node

## Plan 7.11: the register's clockwork is heard. While the movement runs it
## whirs at the register; as the spring runs down the whir slows and drops in
## pitch, so a tired spring is heard before the winding thought is needed.
## It reads the spring only — never the record, never any text.

const WHIR := preload("res://audio/sfx/foley/register_whir.wav")

@export var office: M1OfficeController
@export var full_volume_db: float = -16.0
@export var slack_volume_db: float = -26.0
@export var slack_pitch: float = 0.62

var _player: AudioStreamPlayer3D = null
var _register: TapeRegisterController = null

func _ready() -> void:
	if office == null:
		office = get_parent() as M1OfficeController
	_attach.call_deferred()

func _attach() -> void:
	if office != null and office.session_controller != null:
		_register = office.session_controller.get_tape_register()
	if _register == null:
		return
	_player = AudioStreamPlayer3D.new()
	_player.name = "RegisterWhirPlayer"
	_player.stream = OfficeAmbience.as_looping(WHIR)
	_player.bus = &"Foley"
	_player.unit_size = 1.5
	_player.max_distance = 6.0
	_register.add_child(_player)

func get_player() -> AudioStreamPlayer3D:
	return _player

func _process(_delta: float) -> void:
	advance()

func advance() -> void:
	if _player == null or _register == null:
		return
	var tension := clampf(_register.spring_tension, 0.0, 1.0)
	_player.pitch_scale = lerpf(slack_pitch, 1.0, tension)
	_player.volume_db = lerpf(slack_volume_db, full_volume_db, tension)
	var running := _register.is_clockwork_running()
	if running and not _player.playing and _player.is_inside_tree():
		_player.play()
	elif not running and _player.playing:
		_player.stop()
