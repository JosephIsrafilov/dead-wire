class_name ShiftArrival
extends Node

## Opening arrival sequence: Elias opens the south door from the dark landing,
## steps onto the worn boards as cold air stirs the hanging coat and lamp
## flame, and closes the door behind him before walking freely around the room.

signal arrival_started()
signal arrival_finished()

const HINGE_STREAM: AudioStream = preload("res://audio/sfx/foley/door_hinge.wav")
const LATCH_STREAM: AudioStream = preload("res://audio/sfx/foley/door_latch.wav")
const STEP_STREAMS: Array[AudioStream] = [
	preload("res://audio/sfx/foley/footstep_boards_1.wav"),
	preload("res://audio/sfx/foley/footstep_boards_2.wav"),
	preload("res://audio/sfx/foley/footstep_boards_3.wav"),
]

static var arrived_from_town: bool = false

const START_POS := Vector3(-1.55, 0.0, 2.04)
const END_POS := Vector3(-1.35, 0.0, 1.42)
const START_YAW: float = -0.22
const END_YAW: float = -0.28
const DOOR_OPEN_DEG: float = -54.0

@export var enabled: bool = true
@export var duration_seconds: float = 1.35

var _office: M1OfficeController = null
var _player: PlayerController = null
var _interaction: InteractionController = null
var _leaf: Node3D = null
var _coat: HangingCoat = null
var _lamp_life: LampLife = null

var _running: bool = false
var _finished: bool = false
var _elapsed: float = 0.0
var _latch_played: bool = false
var _steps_played: int = 0
var _sfx_player: AudioStreamPlayer = null
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null

func _ready() -> void:
	_resolve_refs()
	_build_audio()
	if enabled and _player != null and DisplayServer.get_name() != "headless":
		_player.global_position = START_POS
		_player.rotation.y = START_YAW
		if _player.head != null:
			_player.head.rotation.x = -0.05
		_player.reset_physics_interpolation()
		_player._update_camera_pose()
		if arrived_from_town:
			_create_entry_fade()
	_bind_intro.call_deferred()

func _create_entry_fade() -> void:
	if _fade_layer != null:
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "EntryFadeLayer"
	_fade_layer.layer = 20
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

func is_running() -> bool:
	return _running

func is_finished() -> bool:
	return _finished

func _resolve_refs() -> void:
	if _office == null:
		_office = get_parent() as M1OfficeController
	if _office == null:
		return
	_player = _office.player if _office.player != null else _office.get_node_or_null("Player") as PlayerController
	if _player != null:
		_interaction = _player.get_node_or_null("InteractionController") as InteractionController
	var door := _office.get_node_or_null("SouthDoor")
	if door != null:
		_leaf = door.get_node_or_null("Leaf") as Node3D
	_coat = _office.get_node_or_null("HangingCoat") as HangingCoat
	_lamp_life = _office.get_node_or_null("LampLife") as LampLife

func _build_audio() -> void:
	if _sfx_player != null:
		return
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "ArrivalFoley"
	_sfx_player.bus = &"Foley" if AudioServer.get_bus_index(&"Foley") >= 0 else &"Master"
	_sfx_player.volume_db = -14.0
	add_child(_sfx_player)

func _bind_intro() -> void:
	_resolve_refs()
	if not enabled or _player == null:
		_finished = true
		return
	if DisplayServer.get_name() == "headless":
		skip_immediately()
		return
	var intro := _office.get_node_or_null("IntroCard") as IntroCard if _office != null else null
	if intro != null and intro.is_running() and not intro.is_finished():
		if not intro.intro_finished.is_connected(begin):
			intro.intro_finished.connect(begin, CONNECT_ONE_SHOT)
		return
	begin()

func begin() -> void:
	if _running or _finished or not enabled:
		return
	_resolve_refs()
	if _player == null:
		_finished = true
		arrival_finished.emit()
		return

	_running = true
	_elapsed = 0.0
	_latch_played = false
	_steps_played = 0

	_player.seated_station_mode = false
	_player.set_movement_locked(true)
	_player.set_head_rest_position(Vector3(0.0, 1.65, 0.0))
	_player.global_position = START_POS
	_player.rotation.y = START_YAW
	if _player.head != null:
		_player.head.rotation.x = -0.05
	_player.reset_physics_interpolation()
	_player._update_camera_pose()

	if _interaction != null:
		_interaction.cursor_mode = false
		_interaction.is_ui_blocked = true
		_interaction.refresh_reticle()

	if _leaf != null:
		_leaf.rotation.y = deg_to_rad(DOOR_OPEN_DEG)

	if _coat != null:
		_coat.draft(Vector3(-1.55, 1.45, 2.25), Vector3(0.75, 0.0, -0.66), 0.72)
	if _lamp_life != null:
		_lamp_life.gust(0.85)

	if arrived_from_town:
		arrived_from_town = false
		if _fade_rect != null and is_inside_tree():
			var fade_tw := create_tween()
			fade_tw.tween_property(_fade_rect, "color:a", 0.0, 0.60).set_trans(Tween.TRANS_SINE)
			fade_tw.tween_callback(_clear_entry_fade)

	_play_stream(HINGE_STREAM, -16.0, 0.96)
	arrival_started.emit()

func skip_immediately() -> void:
	if _finished and not _running:
		return
	_resolve_refs()
	_running = false
	_finished = true
	_clear_entry_fade()
	if _leaf != null:
		_leaf.rotation.y = 0.0
	if _player != null:
		_player.global_position = END_POS
		_player.rotation.y = END_YAW
		if _player.head != null:
			_player.head.rotation.x = -0.05
		_player.set_head_rest_position(Vector3(0.0, 1.65, 0.0))
		_player.set_movement_locked(false)
		_player.reset_physics_interpolation()
		_player._update_camera_pose()
	if _interaction != null:
		_interaction.is_ui_blocked = false
		_interaction.cursor_mode = false
		_interaction.refresh_reticle()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var murmur := _office.get_node_or_null("MurmurCaption") as MurmurCaption if _office != null else null
	if murmur != null and DisplayServer.get_name() != "headless":
		murmur.show_outside_line(
			GameLocale.pick(
				"Фух... снова сырой уголь и ветер в щелях. Ладно, Крейн, отсиди эту ночь — и в койку.",
				"Damp coal smoke and drafts through every plank. All right, Crane... get through the watch and get some sleep."
			),
			4.6
		)
	arrival_finished.emit()

func _process(delta: float) -> void:
	if _running:
		advance(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var code := (event as InputEventKey).keycode
		if code in [KEY_E, KEY_SPACE, KEY_ENTER]:
			skip_immediately()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_pressed() and not event.is_echo():
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			skip_immediately()
			get_viewport().set_input_as_handled()

func advance(delta: float) -> void:
	if not _running or delta < 0.0:
		return
	_elapsed += delta
	var total := maxf(duration_seconds, 0.5)
	var t := clampf(_elapsed / total, 0.0, 1.0)

	# Swing the south door leaf shut behind Elias cleanly as he steps inside.
	var door_t := clampf((_elapsed - 0.15) / 0.95, 0.0, 1.0)
	var door_eased := door_t * door_t * (3.0 - 2.0 * door_t)
	if _leaf != null:
		_leaf.rotation.y = deg_to_rad(lerpf(DOOR_OPEN_DEG, 0.0, door_eased))
	if not _latch_played and door_t >= 0.96:
		_latch_played = true
		_play_stream(LATCH_STREAM, -14.0, 1.0)

	# Two short, steady steps forward toward the warm desk without sideways turn.
	var walk_t := clampf(_elapsed / 1.15, 0.0, 1.0)
	var walk_eased := 1.0 - pow(1.0 - walk_t, 2.0)
	if _player != null:
		_player.global_position = START_POS.lerp(END_POS, walk_eased)
		_player.rotation.y = lerp_angle(START_YAW, END_YAW, walk_eased)
		if _player.head != null:
			_player.head.rotation.x = lerpf(-0.04, -0.06, walk_eased)
		var bob := sin(walk_t * PI * 2.0) * 0.015 * sin(walk_t * PI)
		_player.set_head_rest_position(Vector3(0.0, 1.65 + bob, 0.0))
		_player._update_camera_pose()

	var step_target := int(floor(walk_t * 2.0))
	while _steps_played < step_target and _steps_played < 2:
		var stream := STEP_STREAMS[_steps_played % STEP_STREAMS.size()]
		_play_stream(stream, -15.0, 0.97 + 0.03 * float(_steps_played))
		_steps_played += 1

	if t >= 1.0:
		_finish()

func _finish() -> void:
	_running = false
	_finished = true
	_clear_entry_fade()
	if _leaf != null:
		_leaf.rotation.y = 0.0
	if _player != null:
		_player.global_position = END_POS
		_player.rotation.y = END_YAW
		_player.set_head_rest_position(Vector3(0.0, 1.65, 0.0))
		_player.set_movement_locked(false)
		_player.reset_physics_interpolation()
		_player._update_camera_pose()
	if _interaction != null:
		_interaction.is_ui_blocked = false
		_interaction.cursor_mode = false
		_interaction.refresh_reticle()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var murmur := _office.get_node_or_null("MurmurCaption") as MurmurCaption if _office != null else null
	if murmur != null and DisplayServer.get_name() != "headless":
		murmur.show_outside_line(
			GameLocale.pick(
				"Фух... снова сырой уголь и ветер в щелях. Ладно, Крейн, отсиди эту ночь — и в койку.",
				"Damp coal smoke and drafts through every plank. All right, Crane... get through the watch and get some sleep."
			),
			4.6
		)
	arrival_finished.emit()

func _clear_entry_fade() -> void:
	if _fade_layer != null and is_instance_valid(_fade_layer):
		_fade_layer.queue_free()
	_fade_layer = null
	_fade_rect = null

func _play_stream(stream: AudioStream, vol_db: float, pitch: float) -> void:
	if stream == null or _sfx_player == null or not is_inside_tree():
		return
	if DisplayServer.get_name() == "headless":
		return
	_sfx_player.stream = stream
	_sfx_player.volume_db = vol_db
	_sfx_player.pitch_scale = pitch
	_sfx_player.play()
