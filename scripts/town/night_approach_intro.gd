class_name NightApproachIntro
extends CanvasLayer

## Cinematic PSX cold open before playable midnight approach in Black Creek.
## Runs in the active SubViewport camera first so every frame inherits the
## 5-bit Bayer dithering and palette grade, then glides directly into Elias's eyes.

signal intro_started()
signal intro_finished()

const FONT_DISPLAY := preload("res://assets/fonts/imfell/IMFeENrm28P.ttf")
const FONT_REG := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")
const WHISTLE_STREAM := preload("res://audio/sfx/train/train_whistle.wav")
const SOUNDER_STREAM := preload("res://audio/sfx/telegraph/sounder_down.wav")

const SKIP_UNLOCK_SECONDS: float = 1.8
const BAR_RATIO: float = 0.105
const DEPOT_ENTRANCE := TownArchitectureBuilder.DEPOT_ORIGIN + TownArchitectureBuilder.DEPOT_DOOR

@export var enabled: bool = true
@export var duration_seconds: float = 14.5

var _exterior: BlackCreekExteriorController = null
var _player: PlayerController = null
var _cam: Camera3D = null
var _hud_to_restore: Control = null

var _veil: ColorRect = null
var _top_bar: ColorRect = null
var _bot_bar: ColorRect = null
var _loc_label: Label = null
var _order_panel: Control = null
var _order_title: Label = null
var _order_body: Label = null
var _title_box: VBoxContainer = null
var _title_label: Label = null
var _sub_label: Label = null
var _skip_label: Label = null
var _sfx: AudioStreamPlayer = null

var _running: bool = false
var _finished: bool = false
var _elapsed: float = 0.0
var _cue_flags: Array[bool] = [false, false, false, false]

func setup(exterior: BlackCreekExteriorController, player: PlayerController, hud: Control = null) -> void:
	_exterior = exterior
	_player = player
	_hud_to_restore = hud

func is_running() -> bool:
	return _running

func is_finished() -> bool:
	return _finished

func _ready() -> void:
	layer = 8
	_build_overlay()
	_build_audio()

func _build_overlay() -> void:
	var root_ctrl := Control.new()
	root_ctrl.name = "ColdOpenRoot"
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	_veil = ColorRect.new()
	_veil.name = "OpeningVeil"
	_veil.color = Color(0.01, 0.012, 0.02, 1.0)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(_veil)

	_top_bar = ColorRect.new()
	_top_bar.name = "LetterboxTop"
	_top_bar.color = Color(0.012, 0.012, 0.018, 1.0)
	_top_bar.anchor_left = 0.0
	_top_bar.anchor_right = 1.0
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_bottom = BAR_RATIO
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(_top_bar)

	_bot_bar = ColorRect.new()
	_bot_bar.name = "LetterboxBottom"
	_bot_bar.color = Color(0.012, 0.012, 0.018, 1.0)
	_bot_bar.anchor_left = 0.0
	_bot_bar.anchor_right = 1.0
	_bot_bar.anchor_top = 1.0 - BAR_RATIO
	_bot_bar.anchor_bottom = 1.0
	_bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(_bot_bar)

	_loc_label = _make_label(FONT_REG, 22, Color(0.86, 0.87, 0.89, 1.0))
	_loc_label.anchor_left = 0.12
	_loc_label.anchor_right = 0.88
	_loc_label.anchor_top = 0.69
	_loc_label.anchor_bottom = 0.86
	_loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loc_label.modulate.a = 0.0
	root_ctrl.add_child(_loc_label)

	_order_panel = PanelContainer.new()
	_order_panel.anchor_left = 0.54
	_order_panel.anchor_right = 0.96
	_order_panel.anchor_top = 0.29
	_order_panel.anchor_bottom = 0.71
	_order_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_order_panel.modulate.a = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.05, 0.84)
	sb.border_color = Color(0.76, 0.67, 0.48, 0.42)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(16)
	_order_panel.add_theme_stylebox_override("panel", sb)
	root_ctrl.add_child(_order_panel)

	var order_vb := VBoxContainer.new()
	order_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	order_vb.add_theme_constant_override("separation", 12)
	order_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_order_panel.add_child(order_vb)

	_order_title = _make_label(FONT_REG, 17, Color(0.88, 0.78, 0.54, 1.0))
	_order_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_vb.add_child(_order_title)

	_order_body = _make_label(FONT_REG, 21, Color(0.94, 0.90, 0.80, 1.0))
	_order_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_vb.add_child(_order_body)

	_title_box = VBoxContainer.new()
	_title_box.anchor_left = 0.14
	_title_box.anchor_right = 0.86
	_title_box.anchor_top = 0.34
	_title_box.anchor_bottom = 0.66
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.add_theme_constant_override("separation", 10)
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.modulate.a = 0.0
	root_ctrl.add_child(_title_box)

	_title_label = _make_label(FONT_DISPLAY, 76, Color(0.95, 0.90, 0.77, 1.0))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_title_label)

	_sub_label = _make_label(FONT_REG, 16, Color(0.78, 0.77, 0.72, 0.92))
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_sub_label)

	_skip_label = _make_label(FONT_REG, 14, Color(0.78, 0.76, 0.70, 0.75))
	_skip_label.anchor_left = 0.55
	_skip_label.anchor_right = 0.97
	_skip_label.anchor_top = 0.905
	_skip_label.anchor_bottom = 0.975
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skip_label.modulate.a = 0.0
	root_ctrl.add_child(_skip_label)

	refresh_locale()

func _make_label(font_res: Font, sz: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", font_res)
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.94))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	return lbl

func refresh_locale() -> void:
	if _loc_label != null:
		_loc_label.text = GameLocale.pick(
			"14 АПРЕЛЯ 1890  ·  БЛЭК-КРИК, КОЛОРАДО\n00:42  ·  ПУТЬ НА НОЧНУЮ СМЕНУ",
			"APRIL 14, 1890  ·  BLACK CREEK, COLORADO\n12:42 A.M.  ·  WALK TO THE NIGHT WATCH"
		)
	if _order_title != null:
		_order_title.text = GameLocale.pick(
			"ПРИКАЗ № 41  ·  БЛЭК-КРИК И ЗАПАД",
			"ORDER NO. 41  ·  BLACK CREEK & WESTERN RY."
		)
	if _order_body != null:
		_order_body.text = GameLocale.pick(
			"Э. Крейну принять смену у Джеда Мерсера. Станция Блэк-Крик, позывной BC.\n"
			+ "Ветка MJ закрыта с октября 1885 г.\n"
			+ "Слушайте провод. Записывайте то, что приходит.",
			"E. Crane to relieve Jed Mercer at Black Creek, call BC.\n"
			+ "Mine Junction (MJ) has been closed since October 1885.\n"
			+ "Keep the wire. Copy what comes."
		)
	if _title_label != null:
		_title_label.text = "FORM 19"
	if _sub_label != null:
		_sub_label.text = GameLocale.pick(
			"П О С Т   Н О Ч Н О Г О   Т Е Л Е Г Р А Ф А",
			"N I G H T   T E L E G R A P H   W A T C H"
		)
	if _skip_label != null:
		_skip_label.text = GameLocale.pick(
			"Пробел / Enter / E / ЛКМ · Пропустить",
			"Space / Enter / E / Click · Skip"
		)

func _build_audio() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "ColdOpenSfx"
	_sfx.bus = &"Foley" if AudioServer.get_bus_index(&"Foley") >= 0 else &"Master"
	add_child(_sfx)

func _ensure_cam() -> void:
	if _cam != null and is_instance_valid(_cam):
		return
	if _exterior == null:
		return
	_cam = Camera3D.new()
	_cam.name = "NightApproachIntroCam"
	_cam.fov = 52.0
	_cam.near = 0.08
	_cam.far = 280.0
	_exterior.add_child(_cam)

func begin() -> void:
	if _running or _finished or not enabled:
		return
	if DisplayServer.get_name() == "headless":
		skip_immediately()
		return
	_ensure_cam()
	_running = true
	_elapsed = 0.0
	_cue_flags = [false, false, false, false]
	if _hud_to_restore != null:
		_hud_to_restore.visible = false
	if _player != null:
		_player.set_movement_locked(true)
		_player.get_node("InteractionUI").hide()
	if _cam != null:
		_cam.make_current()
	_apply_state(0.0)
	intro_started.emit()

func skip_immediately() -> void:
	if _finished and not _running:
		return
	_finish()

func seek_for_capture(seconds: float) -> void:
	_ensure_cam()
	_running = true
	_finished = false
	_elapsed = clampf(seconds, 0.0, duration_seconds)
	if _hud_to_restore != null:
		_hud_to_restore.visible = false
	if _player != null:
		_player.set_movement_locked(true)
		_player.get_node("InteractionUI").hide()
	if _cam != null:
		_cam.make_current()
	_apply_state(_elapsed)

func _process(delta: float) -> void:
	if not _running:
		return
	if _cam != null and is_instance_valid(_cam) and not _cam.current:
		_cam.make_current()
	_elapsed += delta
	_trigger_audio_cues()
	_apply_state(_elapsed)
	if _elapsed >= duration_seconds:
		_finish()

func _unhandled_input(event: InputEvent) -> void:
	if not _running or _elapsed < SKIP_UNLOCK_SECONDS:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var code := (event as InputEventKey).keycode
		if code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] or event.is_action_pressed("interact"):
			skip_immediately()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_pressed() and not event.is_echo():
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			skip_immediately()
			get_viewport().set_input_as_handled()

func _trigger_audio_cues() -> void:
	if DisplayServer.get_name() == "headless" or _sfx == null:
		return
	if not _cue_flags[0] and _elapsed >= 0.32:
		_cue_flags[0] = true
		_play_sfx(WHISTLE_STREAM, -22.0, 0.86)
	elif not _cue_flags[1] and _elapsed >= 4.51:
		_cue_flags[1] = true
		_play_sfx(SOUNDER_STREAM, -16.0, 0.98)
	elif not _cue_flags[2] and _elapsed >= 4.83:
		_cue_flags[2] = true
		_play_sfx(SOUNDER_STREAM, -16.0, 1.01)
	elif not _cue_flags[3] and _elapsed >= 5.23:
		_cue_flags[3] = true
		_play_sfx(SOUNDER_STREAM, -15.5, 0.97)

func _play_sfx(stream: AudioStream, vol_db: float, pitch: float) -> void:
	if _sfx == null or stream == null:
		return
	_sfx.stream = stream
	_sfx.volume_db = vol_db
	_sfx.pitch_scale = pitch
	_sfx.play()

func _apply_state(t: float) -> void:
	if _veil != null:
		_veil.color.a = 1.0 - clampf(t / 1.25, 0.0, 1.0)

	var bar_retract := clampf((t - 12.6) / 1.7, 0.0, 1.0)
	bar_retract = bar_retract * bar_retract * (3.0 - 2.0 * bar_retract)
	var cur_bar := BAR_RATIO * (1.0 - bar_retract)
	if _top_bar != null:
		_top_bar.anchor_bottom = cur_bar
	if _bot_bar != null:
		_bot_bar.anchor_top = 1.0 - cur_bar

	if _loc_label != null:
		_loc_label.modulate.a = _window_alpha(t, 1.15, 2.05, 4.05, 4.85)
	if _order_panel != null:
		_order_panel.modulate.a = _window_alpha(t, 5.05, 5.85, 8.35, 9.20)
	if _title_box != null:
		_title_box.modulate.a = _window_alpha(t, 9.50, 10.35, 12.45, 13.45)
	if _skip_label != null:
		_skip_label.modulate.a = _window_alpha(t, SKIP_UNLOCK_SECONDS, 2.4, 12.1, 12.8) * 0.8

	_update_camera(t)
	if DisplayServer.get_name() != "headless":
		_exterior.builder.set_approach_train_time(t)

func _window_alpha(t: float, in0: float, in1: float, out0: float, out1: float) -> float:
	if t <= in0 or t >= out1:
		return 0.0
	if t < in1:
		return clampf((t - in0) / maxf(in1 - in0, 0.01), 0.0, 1.0)
	if t > out0:
		return 1.0 - clampf((t - out0) / maxf(out1 - out0, 0.01), 0.0, 1.0)
	return 1.0

func _update_camera(t: float) -> void:
	if _cam == null:
		return
	var cam_pos: Vector3
	var look_at_pt: Vector3
	var fov: float
	if t < 4.9:
		var progress := smoothstep(0.0, 4.9, t)
		cam_pos = Vector3(-14.2, 0.63, -16.35).lerp(Vector3(-10.1, 1.02, -16.55), progress)
		look_at_pt = Vector3(15.0, 1.50, -15.35).lerp(Vector3(8.0, 1.58, -14.8), progress)
		fov = 52.0
	elif t < 9.4:
		var progress := smoothstep(4.9, 9.4, t)
		cam_pos = Vector3(-9.8, 3.24, -20.6).lerp(Vector3(-7.8, 3.28, -20.3), progress)
		look_at_pt = Vector3(-1.7, 4.08, -10.5)
		fov = lerpf(62.0, 57.0, progress)
	else:
		var progress := smoothstep(9.4, duration_seconds, t)
		var eye_pos := Vector3(-10.5, 1.70, 22.0)
		var eye_fov := 65.0
		if _player != null and _player.camera != null:
			eye_pos = _player.camera.global_position
			eye_fov = _player.base_fov
		cam_pos = Vector3(-14.3, 4.65, 28.1).lerp(eye_pos, progress)
		cam_pos.y += sin(t * TAU * 1.55) * 0.028 * sin(progress * PI)
		look_at_pt = Vector3(0.25, 2.6, -5.0).lerp(DEPOT_ENTRANCE, progress)
		fov = lerpf(54.0, eye_fov, progress)

	_cam.fov = fov
	_cam.global_position = cam_pos
	_cam.look_at(look_at_pt, Vector3.UP)

func _finish() -> void:
	if _running and _elapsed < duration_seconds and DisplayServer.get_name() != "headless":
		var tail := create_tween()
		tail.tween_method(_exterior.builder.set_approach_train_time, _elapsed, duration_seconds,
			duration_seconds - _elapsed)
	_running = false
	_finished = true
	if _veil != null:
		_veil.color.a = 0.0
	if _top_bar != null:
		_top_bar.anchor_bottom = 0.0
	if _bot_bar != null:
		_bot_bar.anchor_top = 1.0
	if _loc_label != null:
		_loc_label.modulate.a = 0.0
	if _order_panel != null:
		_order_panel.modulate.a = 0.0
	if _title_box != null:
		_title_box.modulate.a = 0.0
	if _skip_label != null:
		_skip_label.modulate.a = 0.0
	if _hud_to_restore != null:
		_hud_to_restore.visible = true
	if _cam != null and is_instance_valid(_cam):
		_cam.current = false
		_cam.queue_free()
		_cam = null
	if _player != null:
		_player.aim_at(DEPOT_ENTRANCE)
		_player.set_movement_locked(false)
		_player.get_node("InteractionUI").show()
		if _player.camera != null:
			_player.camera.make_current()
	if _player != null and DisplayServer.get_name() != "headless" and DisplayServer.window_is_focused():
		_player.restore_walk_mouse_capture()
	visible = false
	intro_finished.emit()
