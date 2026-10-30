class_name TitleMood
extends Control

## The title is the office at night (plan 6.7): a frame of the room itself,
## the lamp breathing a little, the side the menu stands on falling into the
## dark, the room's own tone and the wind at the pane, and — now and then,
## far off — the office call on a sounder that is not this one. The menu's
## lines are a telegraph blank's; choosing one is the click of a key.

const BACKDROPS := {
	"window": preload("res://assets/textures/title/title_window.png"),
	"desk": preload("res://assets/textures/title/title_desk.png"),
}
const ROOM_TONE := preload("res://audio/sfx/ambience/room_tone.wav")
const WIND := preload("res://audio/sfx/ambience/wind_window.wav")
const KEY_CLICK := preload("res://audio/sfx/foley/key_click.wav")
const SOUNDER_DOWN := preload("res://audio/sfx/telegraph/sounder_down.wav")
const SOUNDER_UP := preload("res://audio/sfx/telegraph/sounder_up.wav")
## American Morse "CR CR" as (down, up) pairs in units: C is "..  ." with its
## spaced dot, R is ".  ..". One unit is a slow, distant hand.
const CALL_UNITS := [[0, 1], [2, 3], [5, 6], [9, 10], [12, 13], [14, 15],
	[20, 21], [22, 23], [25, 26], [29, 30], [32, 33], [34, 35]]
const UNIT_SECONDS := 0.085

@export var backdrop_name: String = "window"
@export var call_interval: Vector2 = Vector2(35.0, 70.0)

var _image: TextureRect = null
var _clock: float = 0.0
var _next_call: float = 0.0
var _call_time: float = -1.0
var _call_step: int = 0
var _sounder: AudioStreamPlayer = null
var _click: AudioStreamPlayer = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image = TextureRect.new()
	_image.texture = BACKDROPS.get(backdrop_name, BACKDROPS["window"])
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)
	# The menu's side of the frame falls into the dark, so its lines read.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.0))
	gradient.set_color(1, Color(0, 0, 0, 0.82))
	gradient.add_point(0.45, Color(0, 0, 0, 0.1))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_loop(ROOM_TONE, -16.0)
	_loop(WIND, -20.0)
	_sounder = _player(-24.0)
	_click = _player(-8.0)
	_rng.seed = 1890
	_next_call = _rng.randf_range(8.0, 14.0)

func get_backdrop() -> Texture2D:
	return _image.texture if _image != null else null

## A key click: the sound of choosing a line on the blank.
func click() -> void:
	if _click != null and _click.is_inside_tree():
		_click.stream = KEY_CLICK
		_click.play()

func _process(delta: float) -> void:
	_clock += delta
	if _image != null:
		# The lamp breathes: a slow swell with a small flicker riding it.
		var breath := 0.965 + 0.025 * sin(_clock * 0.9) + 0.01 * sin(_clock * 7.3 + 1.7)
		_image.modulate = Color(breath, breath, breath, 1.0)
	_advance_call(delta)

func _advance_call(delta: float) -> void:
	if _call_time < 0.0:
		_next_call -= delta
		if _next_call <= 0.0:
			_call_time = 0.0
			_call_step = 0
		return
	_call_time += delta
	while _call_step < CALL_UNITS.size() * 2:
		var pair: Array = CALL_UNITS[_call_step / 2]
		var at: float = float(pair[_call_step % 2]) * UNIT_SECONDS
		if _call_time < at:
			return
		_sounder.stream = SOUNDER_DOWN if _call_step % 2 == 0 else SOUNDER_UP
		_sounder.play()
		_call_step += 1
	_call_time = -1.0
	_next_call = _rng.randf_range(call_interval.x, call_interval.y)

func _loop(stream: AudioStream, volume_db: float) -> void:
	var player := _player(volume_db)
	player.stream = stream
	player.finished.connect(player.play)
	player.play.call_deferred()

func _player(volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	if AudioServer.get_bus_index("Ambience") >= 0:
		player.bus = &"Ambience"
	add_child(player)
	return player
