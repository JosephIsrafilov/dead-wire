class_name SeatedStationController
extends CanvasLayer

## Seated Bay-Window Workstation controller (Variant A: Inscryption / FNAF style).
##
## Replaces free WASD room-walking during a watch with 4 curated seated views
## around the bay-window desk (Desk + Window, Left Signal Lever, Right Filing
## Desk & Bookcase, Back Office Door), owns the clean seated HUD (top-left duty
## strip, bottom-right quiet keybinds, floating cursor tooltip), and dispatches
## direct pointer interaction with physical instruments.

enum View {
	DESK,
	LEFT_SIGNAL,
	RIGHT_FILING,
	BACK_DOOR,
}

signal view_changed(new_view: View, previous_view: View)

@export var enabled: bool = true
@export var office: M1OfficeController = null
@export var view_lerp_speed: float = 12.0
@export var max_parallax_yaw_deg: float = 5.0
@export var max_parallax_pitch_deg: float = 3.5

const VIEW_PARAMS: Dictionary = {
	View.DESK: {"yaw": 0.0, "pitch": -11.0, "fov": 68.0, "reach": 2.6},
	View.LEFT_SIGNAL: {"yaw": 84.0, "pitch": -9.5, "fov": 66.0, "reach": 2.9},
	View.RIGHT_FILING: {"yaw": -84.0, "pitch": -14.0, "fov": 64.0, "reach": 3.4},
	View.BACK_DOOR: {"yaw": 172.0, "pitch": -2.0, "fov": 72.0, "reach": 4.8},
}

const FONT_LETTERPRESS := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")
const CHAIR_CREAK_STREAM := preload("res://audio/sfx/foley/chair_settle_cc0.ogg")
const DEBUG_SEATED_LOGS: bool = false

var current_view: View = View.DESK
## Additive micro-tremor applied by external physical events (e.g. Train 17 rumble).
var tremor_offset_deg: Vector2 = Vector2.ZERO

var _activated: bool = false
var _player: PlayerController = null
var _seat: OperatorSeat = null
var _interaction: InteractionController = null
var _lamp_life: LampLife = null
var _key_sender: OperatorKeySender = null
var _hovered_target: Interactable = null
var _swivel_player: AudioStreamPlayer = null
var _rng := RandomNumberGenerator.new()

var _pointer_inside: bool = false
var _mouse_pos: Vector2 = Vector2.ZERO
var _cramp_vignette: ColorRect = null
var _cramp_pulse: float = 0.0

var _current_yaw_rad: float = 0.0
var _current_pitch_rad: float = deg_to_rad(-11.0)
var _current_fov: float = 68.0

var _btn_left: Button = null
var _btn_right: Button = null
var _btn_down: Button = null
var _btn_up: Button = null
var _btn_stand: Button = null
var _style_normal: StyleBoxFlat = null
var _style_attention: StyleBoxFlat = null
var _hovering_nav: bool = false
var quiet_silence_dim_enabled: bool = true
var _standing_fov: float = 0.0
var _post_lock_notice_timer: float = 0.0
var _post_lock_notice_kind: int = 0

var _duty_panel: PanelContainer = null
var _duty_primary: Label = null
var _duty_sub: Label = null
var _controls_label: Label = null

var _tooltip_panel: PanelContainer = null
var _tooltip_label: Label = null
var _tooltip_active_style: StyleBoxFlat = null
var _tooltip_muted_style: StyleBoxFlat = null

func _ready() -> void:
	layer = 6
	_rng.randomize()
	if not enabled:
		visible = false
		return
	_resolve_refs()
	_build_audio()
	_build_nav_ui()
	_build_hud_overlays()
	_bind_intro.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if DEBUG_SEATED_LOGS and DisplayServer.get_name() != "headless":
			print("[SeatedStation] notif=%d enabled=%s activated=%s" % [what, enabled, _activated])
		if not enabled or not _activated:
			return
		_pointer_inside = false
		_hovering_nav = false
		_clear_cursor_target()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _build_audio() -> void:
	if _swivel_player != null:
		return
	_swivel_player = AudioStreamPlayer.new()
	_swivel_player.name = "ChairSwivelPlayer"
	_swivel_player.stream = CHAIR_CREAK_STREAM
	_swivel_player.volume_db = -21.0
	_swivel_player.bus = &"Foley" if AudioServer.get_bus_index(&"Foley") >= 0 else &"Master"
	add_child(_swivel_player)

func _resolve_refs() -> void:
	if office == null:
		office = get_parent() as M1OfficeController
	if office == null:
		return
	_player = office.player if office.player != null else office.get_node_or_null("Player") as PlayerController
	_seat = office.operator_seat if office.operator_seat != null \
		else office.get_node_or_null("Chair/OperatorSeat") as OperatorSeat
	if _player != null:
		_interaction = _player.get_node_or_null("InteractionController") as InteractionController
	_lamp_life = office.get_node_or_null("LampLife") as LampLife
	_key_sender = office.get_node_or_null("OperatorKeySender") as OperatorKeySender

func _bind_intro() -> void:
	if not enabled:
		return
	_resolve_refs()
	_set_nav_visible(false)
	if _seat != null and not _seat.sit_completed.is_connected(_on_seat_sit_completed):
		_seat.sit_completed.connect(_on_seat_sit_completed)
	_connect_director_signals()
	# Ensure the chair stays interactable while Elias walks around before sitting.
	var chair := office.get_node_or_null("Chair") as Node3D if office != null else null
	if chair != null:
		var chair_interact := chair.get_node_or_null("Interactable") as Interactable
		if chair_interact != null:
			chair_interact.enabled = true
			chair_interact.collision_layer = 2
	# Keep HUD overlays hidden until Elias sits at the desk.
	if _duty_panel != null:
		_duty_panel.visible = false
	if _controls_label != null:
		_controls_label.visible = false

func _on_seat_sit_completed() -> void:
	if not _activated and enabled:
		_activate_station(false)

func activate_station() -> void:
	_activate_station(true)

func _activate_station(emit_seat_signals: bool = true) -> void:
	if _activated or not enabled:
		return
	_resolve_refs()
	if _player == null:
		return
	_activated = true
	if DEBUG_SEATED_LOGS and DisplayServer.get_name() != "headless":
		print("[SeatedStation] activated emit=%s" % emit_seat_signals)
	_player.seated_station_mode = true
	_player.clear_yaw_limit()
	_player.set_walk_locked(true)
	_player.set_seated(true)

	var chair := office.get_node_or_null("Chair") as Node3D if office != null else null
	if chair != null:
		_player.global_position = chair.global_position
		var chair_solid := chair.get_node_or_null("ChairSolid/CollisionShape3D") as CollisionShape3D
		if chair_solid != null:
			chair_solid.set_deferred("disabled", true)
		var chair_interact := chair.get_node_or_null("Interactable") as Interactable
		if chair_interact != null:
			chair_interact.enabled = false
			chair_interact.collision_layer = 0

	if _seat != null:
		_seat.is_seated = true
		_seat.has_stood_once = true
		_player.set_head_rest_position(Vector3(0.0, _seat.seat_eye_height, 0.0))

	if _standing_fov <= 0.0 and _player != null:
		_standing_fov = _player.base_fov
	_post_lock_notice_timer = 0.0
	_post_lock_notice_kind = 0

	current_view = View.DESK
	_current_yaw_rad = deg_to_rad(float(VIEW_PARAMS[View.DESK].yaw))
	_current_pitch_rad = deg_to_rad(float(VIEW_PARAMS[View.DESK].pitch))
	_current_fov = float(VIEW_PARAMS[View.DESK].fov)
	_apply_camera_pose(_current_yaw_rad, _current_pitch_rad, _current_fov)

	if _interaction != null:
		_interaction.cursor_mode = true
		_interaction.refresh_reticle()

	_connect_director_signals()
	if office != null and office.shift_director != null:
		office.shift_director.refresh_key_state()
	if emit_seat_signals:
		if _seat != null:
			_seat.seated.emit()
			_seat.sit_completed.emit()
		if office != null:
			office._on_operator_sit_completed()

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_refresh_nav_buttons()
	_refresh_overlay_hud()

func _connect_director_signals() -> void:
	if office != null and office.shift_director != null \
			and not office.shift_director.shift_opened.is_connected(_on_shift_opened):
		office.shift_director.shift_opened.connect(_on_shift_opened)

func can_stand_up() -> bool:
	if office == null or office.shift_director == null:
		return true
	var phase := office.shift_director.get_phase()
	return phase == ShiftDirector.Phase.PRE_SHIFT or office.shift_director.is_shift_over()

func get_post_lock_notice_text() -> String:
	if _post_lock_notice_timer <= 0.0:
		return ""
	return SeatedHudCopy.post_lock_notice_text(_post_lock_notice_kind)

func _on_shift_opened() -> void:
	if _activated:
		_set_post_lock_notice(SeatedHudCopy.NOTICE_LINE_OPENED, 4.5)

func _trigger_post_lock_warning() -> void:
	_set_post_lock_notice(SeatedHudCopy.NOTICE_POST_LOCKED, 3.5)

func _set_post_lock_notice(kind: int, duration: float) -> void:
	_post_lock_notice_kind = kind
	_post_lock_notice_timer = duration
	_refresh_nav_buttons()
	_refresh_overlay_hud()

func deactivate_for_dawn() -> bool:
	return stand_up_from_station()

func stand_up_from_station() -> bool:
	if not _activated or _player == null:
		return false
	_clear_cursor_target()
	_activated = false
	_post_lock_notice_timer = 0.0
	_post_lock_notice_kind = 0
	if DEBUG_SEATED_LOGS and DisplayServer.get_name() != "headless":
		print("[SeatedStation] stood_up_from_station")
	_hovering_nav = false
	_player.seated_station_mode = false
	_player.window_lean_requested = false
	if _standing_fov > 0.0:
		_player.base_fov = _standing_fov
		if _player.camera != null:
			_player.camera.fov = _standing_fov
	_set_nav_visible(false)
	if _duty_panel != null:
		_duty_panel.visible = false
	if _controls_label != null:
		_controls_label.visible = false

	if _interaction != null:
		_interaction.cursor_mode = false
		_interaction.refresh_reticle()

	var chair := office.get_node_or_null("Chair") as Node3D if office != null else null
	if chair != null:
		var chair_interact := chair.get_node_or_null("Interactable") as Interactable
		if chair_interact != null:
			chair_interact.enabled = true
			chair_interact.collision_layer = 2

	if _seat != null:
		_seat.stand()
	else:
		_player.set_walk_locked(false)
		_player.set_seated(false)

	if DisplayServer.get_name() != "headless":
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return true

func _build_nav_ui() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.05, 0.04, 0.03, 0.45)
	_style_normal.border_color = Color(0.45, 0.38, 0.28, 0.35)
	_style_normal.set_border_width_all(1)
	_style_normal.set_corner_radius_all(3)

	_style_attention = _style_normal.duplicate() as StyleBoxFlat
	_style_attention.bg_color = Color(0.10, 0.075, 0.04, 0.62)
	_style_attention.border_color = Color(0.92, 0.72, 0.36, 0.78)

	_cramp_vignette = ColorRect.new()
	_cramp_vignette.name = "CrampVignette"
	_cramp_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cramp_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cramp_vignette.color = Color(0.08, 0.02, 0.02, 0.0)
	add_child(_cramp_vignette)

	_btn_left = _make_nav_button("‹ Signal", _on_nav_left_pressed)
	_btn_left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_btn_left.offset_left = 12.0
	_btn_left.offset_right = 116.0
	_btn_left.offset_top = 48.0
	_btn_left.offset_bottom = 86.0
	add_child(_btn_left)

	_btn_right = _make_nav_button("Filing ›", _on_nav_right_pressed)
	_btn_right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_btn_right.offset_left = -116.0
	_btn_right.offset_right = -12.0
	_btn_right.offset_top = 48.0
	_btn_right.offset_bottom = 86.0
	add_child(_btn_right)

	_btn_down = _make_nav_button("⌄ Door", _on_nav_down_pressed)
	_btn_down.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_btn_down.offset_left = -68.0
	_btn_down.offset_right = 68.0
	_btn_down.offset_top = -54.0
	_btn_down.offset_bottom = -14.0
	add_child(_btn_down)

	_btn_up = _make_nav_button("⌃ Desk", _on_nav_up_pressed)
	_btn_up.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_btn_up.offset_left = -148.0
	_btn_up.offset_right = -16.0
	_btn_up.offset_top = 14.0
	_btn_up.offset_bottom = 50.0
	add_child(_btn_up)

	_btn_stand = _make_nav_button("⌃ Встать [Tab]", _on_stand_pressed)
	_btn_stand.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_btn_stand.offset_left = -105.0
	_btn_stand.offset_right = 105.0
	_btn_stand.offset_top = -108.0
	_btn_stand.offset_bottom = -64.0
	add_child(_btn_stand)

	_set_nav_visible(false)

func _build_hud_overlays() -> void:
	_duty_panel = PanelContainer.new()
	_duty_panel.name = "DutyStrip"
	_duty_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_duty_panel.offset_left = 16.0
	_duty_panel.offset_top = 14.0
	_duty_panel.offset_right = 590.0
	_duty_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_duty_panel.visible = false
	var duty_style := StyleBoxFlat.new()
	duty_style.bg_color = Color(0.04, 0.03, 0.025, 0.62)
	duty_style.border_color = Color(0.48, 0.39, 0.27, 0.42)
	duty_style.set_border_width_all(1)
	duty_style.set_corner_radius_all(3)
	duty_style.content_margin_left = 12.0
	duty_style.content_margin_right = 14.0
	duty_style.content_margin_top = 7.0
	duty_style.content_margin_bottom = 7.0
	_duty_panel.add_theme_stylebox_override("panel", duty_style)
	add_child(_duty_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	_duty_panel.add_child(vbox)

	_duty_primary = Label.new()
	_duty_primary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_duty_primary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_duty_primary.add_theme_font_override("font", FONT_LETTERPRESS)
	_duty_primary.add_theme_font_size_override("font_size", 16)
	_duty_primary.add_theme_color_override("font_color", Color(0.92, 0.85, 0.70, 0.94))
	vbox.add_child(_duty_primary)

	_duty_sub = Label.new()
	_duty_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_duty_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_duty_sub.visible = false
	_duty_sub.add_theme_font_override("font", FONT_LETTERPRESS)
	_duty_sub.add_theme_font_size_override("font_size", 14)
	_duty_sub.add_theme_color_override("font_color", Color(0.96, 0.76, 0.40, 0.95))
	vbox.add_child(_duty_sub)

	_controls_label = Label.new()
	_controls_label.name = "ControlsStrip"
	_controls_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_controls_label.offset_left = -430.0
	_controls_label.offset_right = -16.0
	_controls_label.offset_top = -34.0
	_controls_label.offset_bottom = -12.0
	_controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_controls_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_label.visible = false
	_controls_label.add_theme_font_override("font", FONT_LETTERPRESS)
	_controls_label.add_theme_font_size_override("font_size", 13)
	_controls_label.add_theme_color_override("font_color", Color(0.84, 0.77, 0.63, 0.56))
	_controls_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_controls_label.add_theme_constant_override("shadow_offset_y", 1)
	_apply_controls_text()
	add_child(_controls_label)

	_tooltip_active_style = StyleBoxFlat.new()
	_tooltip_active_style.bg_color = Color(0.05, 0.04, 0.03, 0.86)
	_tooltip_active_style.border_color = Color(0.84, 0.69, 0.42, 0.78)
	_tooltip_active_style.set_border_width_all(1)
	_tooltip_active_style.set_corner_radius_all(3)
	_tooltip_active_style.content_margin_left = 10.0
	_tooltip_active_style.content_margin_right = 10.0
	_tooltip_active_style.content_margin_top = 4.0
	_tooltip_active_style.content_margin_bottom = 4.0

	_tooltip_muted_style = _tooltip_active_style.duplicate() as StyleBoxFlat
	_tooltip_muted_style.border_color = Color(0.45, 0.39, 0.30, 0.48)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.name = "CursorTooltip"
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	_tooltip_panel.add_theme_stylebox_override("panel", _tooltip_active_style)
	add_child(_tooltip_panel)

	_tooltip_label = Label.new()
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.add_theme_font_override("font", FONT_LETTERPRESS)
	_tooltip_label.add_theme_font_size_override("font_size", 15)
	_tooltip_label.add_theme_color_override("font_color", Color(0.95, 0.89, 0.76, 0.98))
	_tooltip_panel.add_child(_tooltip_label)

func _apply_controls_text() -> void:
	if _controls_label != null:
		_controls_label.text = GameLocale.pick(
			"[A/W/D/S] Обзор  ·  [Колесо] Лампа  ·  [ПКМ] Прильнуть / Закрыть",
			"[A/W/D/S] Look  ·  [Wheel] Lamp  ·  [RMB] Lean / Close"
		)

func refresh_locale() -> void:
	_apply_controls_text()
	_refresh_nav_buttons()
	_refresh_overlay_hud()

func _make_nav_button(label_text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", FONT_LETTERPRESS)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.88, 0.80, 0.64, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.76, 1.0))
	btn.add_theme_stylebox_override("normal", _style_normal)

	var hover := _style_normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.11, 0.09, 0.06, 0.72)
	hover.border_color = Color(0.75, 0.65, 0.48, 0.65)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	btn.pressed.connect(handler)
	btn.mouse_entered.connect(func() -> void: _hovering_nav = true)
	btn.mouse_exited.connect(func() -> void: _hovering_nav = false)
	return btn

func _set_nav_visible(show_nav: bool) -> void:
	for btn in [_btn_left, _btn_right, _btn_down, _btn_up, _btn_stand]:
		if btn != null:
			btn.visible = show_nav

func _on_stand_pressed() -> void:
	if _is_blocked():
		return
	if can_stand_up():
		stand_up_from_station()
	else:
		_trigger_post_lock_warning()

func is_activated() -> bool:
	return _activated

func get_duty_strip_alpha() -> float:
	return _duty_panel.modulate.a if _duty_panel != null else 0.0

func _is_fullscreen_modal_open() -> bool:
	if not enabled or not _activated or office == null:
		return true
	if get_tree() != null and get_tree().paused:
		return true
	if office.amendment_editor != null \
			and (office.amendment_editor.is_open() or office.amendment_editor.owns_transition_frame()):
		return true
	if office.document_viewer != null and office.document_viewer.is_open():
		return true
	if office.routing_board != null and office.routing_board.is_open:
		return true
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null and intro.visible:
		return true
	if office.shift_end_card != null and office.shift_end_card.is_running():
		return true
	var pause_menu := office.get_node_or_null("PauseMenu") as PauseMenu
	if pause_menu != null and pause_menu.is_paused:
		return true
	return false

func _is_blocked() -> bool:
	if _is_fullscreen_modal_open():
		return true
	var pen := office.get_node_or_null("DeskAmendment") as DeskAmendment if office != null else null
	if pen != null and pen.writing:
		return true
	return false

func switch_view(target: View) -> void:
	if target == current_view:
		return
	var previous := current_view
	current_view = target
	if current_view != View.DESK and _player != null:
		_player.window_lean_requested = false
	_clear_cursor_target()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_play_chair_swivel()
	_refresh_nav_buttons()
	view_changed.emit(current_view, previous)

func _play_chair_swivel() -> void:
	if _swivel_player == null or not _swivel_player.is_inside_tree():
		return
	if DisplayServer.get_name() == "headless":
		return
	_swivel_player.pitch_scale = _rng.randf_range(0.94, 1.06)
	_swivel_player.play()

func _refresh_nav_buttons() -> void:
	if _is_blocked():
		_set_nav_visible(false)
		return
	_btn_left.visible = true
	_btn_right.visible = true
	_btn_down.visible = current_view != View.BACK_DOOR
	_btn_up.visible = current_view != View.DESK
	var allow_stand := can_stand_up()
	var is_dawn := office != null and office.shift_director != null and office.shift_director.is_shift_over()
	if _btn_stand != null:
		_btn_stand.visible = allow_stand
		if allow_stand:
			_apply_nav_cue(_btn_stand, GameLocale.pick("⌃ Встать [Tab]", "⌃ Stand Up [Tab]"), is_dawn)

	var attn := _attention_flags()
	var s_sig := GameLocale.pick("Сигнал", "Signal")
	var s_fil := GameLocale.pick("Подшивка", "Filing")
	var s_door := GameLocale.pick("Дверь", "Door")
	var s_desk := GameLocale.pick("Стол", "Desk")
	match current_view:
		View.DESK:
			_apply_nav_cue(_btn_left, "‹ " + s_sig, attn.signal)
			_apply_nav_cue(_btn_right, s_fil + " ›", attn.filing)
			_apply_nav_cue(_btn_down, "⌄ " + s_door, attn.door)
		View.LEFT_SIGNAL:
			_apply_nav_cue(_btn_left, "‹ " + s_door, attn.door)
			_apply_nav_cue(_btn_right, s_desk + " ›", attn.desk or attn.filing)
			_apply_nav_cue(_btn_down, "⌄ " + s_door, attn.door)
			_apply_nav_cue(_btn_up, "⌃ " + s_desk, attn.desk or attn.filing)
		View.RIGHT_FILING:
			_apply_nav_cue(_btn_left, "‹ " + s_desk, attn.desk or attn.signal)
			_apply_nav_cue(_btn_right, s_door + " ›", attn.door)
			_apply_nav_cue(_btn_down, "⌄ " + s_door, attn.door)
			_apply_nav_cue(_btn_up, "⌃ " + s_desk, attn.desk or attn.signal)
		View.BACK_DOOR:
			_apply_nav_cue(_btn_left, "‹ " + s_fil, attn.filing)
			_apply_nav_cue(_btn_right, s_sig + " ›", attn.signal)
			_apply_nav_cue(_btn_up, "⌃ " + s_desk, attn.desk)

func _apply_nav_cue(btn: Button, base_text: String, active: bool) -> void:
	if btn == null:
		return
	btn.text = "%s •" % base_text if active else base_text
	btn.add_theme_stylebox_override("normal", _style_attention if active else _style_normal)
	var col := Color(1.0, 0.86, 0.56, 0.98) if active else Color(0.88, 0.80, 0.64, 0.85)
	btn.add_theme_color_override("font_color", col)

func _attention_flags() -> Dictionary:
	var flags := {"desk": false, "signal": false, "filing": false, "door": false}
	if office == null:
		return flags
	var director := office.shift_director
	var session := office.session_controller
	if director != null and director.get_phase() == ShiftDirector.Phase.CALLING:
		flags.desk = true
	if session != null:
		var st := session.get_state()
		if st == TelegraphSessionController.State.VERIFYING:
			flags.desk = true
		elif st == TelegraphSessionController.State.AWAITING_ROUTE:
			flags.signal = true
		elif st == TelegraphSessionController.State.AWAITING_COMMIT:
			flags.filing = true
	var shutter := office.get_node_or_null("ServiceShutterEvent")
	if shutter != null and shutter.has_method("has_unread_slip") and shutter.has_unread_slip():
		flags.door = true
	if office.office_door != null and (office.office_door.is_open or not office.office_door.is_locked()):
		flags.door = true
	if office.dawn_evidence != null and office.dawn_evidence.is_revealed() \
			and not office.dawn_evidence.is_inspected():
		flags.door = true
	return flags

func _refresh_overlay_hud() -> void:
	if _duty_panel == null:
		return
	var modal := _is_fullscreen_modal_open()
	_duty_panel.visible = not modal
	if _controls_label != null:
		_controls_label.visible = not modal
	if modal:
		_hide_tooltip()
		return

	var texts := _duty_texts()
	_duty_primary.text = texts.primary
	var sub: String = texts.sub
	_duty_sub.text = sub
	_duty_sub.visible = not sub.is_empty()
	_update_tooltip_visual()

func _duty_texts() -> Dictionary:
	return SeatedHudCopy.duty_texts(office, current_view, View, get_post_lock_notice_text())

func _on_nav_left_pressed() -> void:
	if _is_blocked():
		return
	match current_view:
		View.DESK: switch_view(View.LEFT_SIGNAL)
		View.LEFT_SIGNAL: switch_view(View.BACK_DOOR)
		View.BACK_DOOR: switch_view(View.RIGHT_FILING)
		View.RIGHT_FILING: switch_view(View.DESK)

func _on_nav_right_pressed() -> void:
	if _is_blocked():
		return
	match current_view:
		View.DESK: switch_view(View.RIGHT_FILING)
		View.RIGHT_FILING: switch_view(View.BACK_DOOR)
		View.BACK_DOOR: switch_view(View.LEFT_SIGNAL)
		View.LEFT_SIGNAL: switch_view(View.DESK)

func _on_nav_down_pressed() -> void:
	if _is_blocked():
		return
	if current_view != View.BACK_DOOR:
		switch_view(View.BACK_DOOR)

func _on_nav_up_pressed() -> void:
	if _is_blocked():
		return
	if current_view != View.DESK:
		switch_view(View.DESK)

func _process(delta: float) -> void:
	if not enabled or not _activated or _player == null:
		return
	_refresh_nav_buttons()
	var blocked := _is_blocked()
	if blocked:
		_player.window_lean_requested = false
		_clear_cursor_target()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if not blocked and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_update_camera(delta, blocked)
	if not blocked:
		_update_mouse_raycast()
	_post_lock_notice_timer = maxf(0.0, _post_lock_notice_timer - maxf(delta, 0.0))
	_refresh_overlay_hud()
	advance_hud_fade(delta)
	_update_cramp_feedback(delta, blocked)

func _is_quiet_silence() -> bool:
	if _post_lock_notice_timer > 0.0:
		return false
	if office == null or office.shift_director == null:
		return false
	if office.shift_director.get_phase() != ShiftDirector.Phase.WAITING:
		return false
	var session := office.session_controller
	if session != null and not session.get_deadline_warning_text().is_empty():
		return false
	var shutter := office.get_node_or_null("ServiceShutterEvent")
	if shutter != null and shutter.has_method("has_unread_slip") and shutter.has_unread_slip():
		return false
	var reg := session.get_tape_register() if session != null else null
	if reg != null and reg.needs_winding():
		return false
	return true

func advance_hud_fade(delta: float) -> void:
	if _duty_panel == null:
		return
	var silence := quiet_silence_dim_enabled and _is_quiet_silence()
	var target_duty := 0.24 if silence else 1.0
	var target_ctrl := 0.30 if silence else 0.88
	var step_w := minf(maxf(delta, 0.0) * 3.0, 1.0)
	_duty_panel.modulate.a = lerpf(_duty_panel.modulate.a, target_duty, step_w)
	if _controls_label != null:
		_controls_label.modulate.a = lerpf(_controls_label.modulate.a, target_ctrl, step_w)

func _update_cramp_feedback(delta: float, blocked: bool) -> void:
	if _cramp_vignette == null:
		return
	var target_alpha: float = 0.0
	if not blocked and _hovered_target != null and _hovered_target.name == "AmendInteractable":
		var session := office.session_controller if office != null else null
		var scen := session.get_current_scenario() if session != null else null
		if scen != null and scen.scenario_id == "core_hook_water_watcher":
			_cramp_pulse += delta * 5.2
			target_alpha = 0.14 + 0.06 * sin(_cramp_pulse)
	_cramp_vignette.color.a = lerpf(_cramp_vignette.color.a, target_alpha, minf(delta * 8.0, 1.0))

func _update_camera(delta: float, blocked: bool) -> void:
	var params: Dictionary = VIEW_PARAMS[current_view]
	var target_yaw := deg_to_rad(float(params.yaw))
	var target_pitch := deg_to_rad(float(params.pitch))
	var target_fov := float(params.fov)

	if not blocked and _pointer_inside:
		var vp := get_viewport()
		var rect := vp.get_visible_rect() if vp != null else Rect2(0, 0, 1280, 720)
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			var nx := clampf((_mouse_pos.x / rect.size.x) * 2.0 - 1.0, -1.0, 1.0)
			var ny := clampf((_mouse_pos.y / rect.size.y) * 2.0 - 1.0, -1.0, 1.0)
			target_yaw -= nx * deg_to_rad(max_parallax_yaw_deg)
			target_pitch -= ny * deg_to_rad(max_parallax_pitch_deg)

	target_yaw += deg_to_rad(tremor_offset_deg.x)
	target_pitch += deg_to_rad(tremor_offset_deg.y)

	var weight := 1.0 - exp(-view_lerp_speed * maxf(delta, 0.0))
	_current_yaw_rad = lerp_angle(_current_yaw_rad, target_yaw, weight)
	_current_pitch_rad = lerpf(_current_pitch_rad, target_pitch, weight)
	_current_fov = lerpf(_current_fov, target_fov, weight)
	_apply_camera_pose(_current_yaw_rad, _current_pitch_rad, _current_fov)

func _apply_camera_pose(yaw_rad: float, pitch_rad: float, fov_deg: float) -> void:
	if _player == null:
		return
	_player.rotation.y = yaw_rad
	if _player.head != null:
		_player.head.rotation.x = pitch_rad
	_player.base_fov = fov_deg
	if _player.camera != null and _player.get_lean_weight() <= 0.001:
		_player.camera.fov = fov_deg

func _camera_mouse_pos(cam_vp: Viewport) -> Vector2:
	var local_vp := get_viewport()
	if local_vp == null or cam_vp == null:
		return _mouse_pos
	var local_size := local_vp.get_visible_rect().size
	var cam_size := cam_vp.get_visible_rect().size
	if local_size.x > 1.0 and local_size.y > 1.0 and cam_size.x > 1.0 and cam_size.y > 1.0:
		return Vector2(_mouse_pos.x * cam_size.x / local_size.x, _mouse_pos.y * cam_size.y / local_size.y)
	return _mouse_pos

func _update_mouse_raycast() -> void:
	if not _pointer_inside or _player == null or _player.camera == null or _hovering_nav:
		_clear_cursor_target()
		if not _hovering_nav:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	var cam_vp := _player.camera.get_viewport()
	if cam_vp == null:
		_clear_cursor_target()
		return
	var cam_rect := cam_vp.get_visible_rect()
	var screen_pt := _camera_mouse_pos(cam_vp)
	if not Rect2(Vector2.ZERO, cam_rect.size).has_point(screen_pt):
		_clear_cursor_target()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	var origin := _player.camera.project_ray_origin(screen_pt)
	var dir := _player.camera.project_ray_normal(screen_pt)
	if dir.dot(-_player.camera.global_basis.z) <= 0.35:
		_clear_cursor_target()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	var space := _player.get_world_3d().direct_space_state if _player.is_inside_tree() else null
	if space == null:
		_clear_cursor_target()
		return
	var reach: float = float(VIEW_PARAMS[current_view].reach)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, 2)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := space.intersect_ray(query)
	var found: Interactable = null
	if not hit.is_empty():
		var col: Object = hit.get("collider")
		if col is Interactable and (col as Interactable).can_interact():
			var hit_pos: Vector3 = hit.get("position", origin)
			var dist := origin.distance_to(hit_pos)
			if not _is_solid_occluded(space, origin, dir, dist):
				found = col as Interactable
	_hovered_target = found
	if _interaction != null:
		_interaction.set_cursor_target(found)
	var show_hand := found != null and (found.is_actionable or _is_open_door_target(found))
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if show_hand else Input.CURSOR_ARROW)

func _update_tooltip_visual() -> void:
	if _tooltip_panel == null or _tooltip_label == null:
		return
	if _is_blocked() or not _pointer_inside or _hovering_nav or _hovered_target == null:
		_hide_tooltip()
		return
	var text := _friendly_cursor_label(_hovered_target)
	if text.is_empty():
		_hide_tooltip()
		return
	var active := _hovered_target.is_actionable or _is_open_door_target(_hovered_target)
	_tooltip_label.text = text
	_tooltip_label.add_theme_color_override(
		"font_color",
		Color(0.96, 0.90, 0.76, 0.98) if active else Color(0.76, 0.70, 0.58, 0.85)
	)
	_tooltip_panel.add_theme_stylebox_override(
		"panel",
		_tooltip_active_style if active else _tooltip_muted_style
	)
	_tooltip_panel.visible = true
	_tooltip_panel.reset_size()
	var vp := get_viewport()
	var rect := vp.get_visible_rect() if vp != null else Rect2(0, 0, 1280, 720)
	var tip_size := _tooltip_panel.get_combined_minimum_size()
	var pos := _mouse_pos + Vector2(18.0, 20.0)
	pos.x = clampf(pos.x, 8.0, maxf(rect.size.x - tip_size.x - 8.0, 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(rect.size.y - tip_size.y - 8.0, 8.0))
	_tooltip_panel.position = pos

func _hide_tooltip() -> void:
	if _tooltip_panel != null:
		_tooltip_panel.visible = false

func _friendly_cursor_label(target: Interactable) -> String:
	return SeatedHudCopy.cursor_label(office, target)

func _is_open_door_target(target: Interactable) -> bool:
	return office != null and office.office_door != null \
		and target == office.office_door.get_interactable() and office.office_door.is_open

func _is_solid_occluded(space: PhysicsDirectSpaceState3D, origin: Vector3, dir: Vector3, dist: float) -> bool:
	if dist <= 0.25:
		return false
	var occ_query := PhysicsRayQueryParameters3D.create(origin, origin + dir * (dist - 0.22), 1)
	occ_query.collide_with_areas = false
	occ_query.collide_with_bodies = true
	return not space.intersect_ray(occ_query).is_empty()

func _clear_cursor_target() -> void:
	_hovered_target = null
	if _activated and _interaction != null:
		_interaction.set_cursor_target(null)
	_hide_tooltip()

func _input(event: InputEvent) -> void:
	if not enabled or not _activated:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mouse_pos = mm.position
		var vp := get_viewport()
		var rect := vp.get_visible_rect() if vp != null else Rect2(0, 0, 1280, 720)
		_pointer_inside = Rect2(Vector2.ZERO, rect.size).has_point(_mouse_pos)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_mouse_pos = mb.position
		var vp := get_viewport()
		var rect := vp.get_visible_rect() if vp != null else Rect2(0, 0, 1280, 720)
		_pointer_inside = Rect2(Vector2.ZERO, rect.size).has_point(_mouse_pos)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not _activated:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and not mb.is_echo():
			if _player != null:
				_player.window_lean_requested = mb.pressed and current_view == View.DESK and not _is_blocked()
				get_viewport().set_input_as_handled()
			return
	if _is_blocked():
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event as InputEventKey).keycode == KEY_TAB:
			if can_stand_up():
				stand_up_from_station()
			else:
				_trigger_post_lock_warning()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("move_left"):
			_on_nav_left_pressed()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("move_right"):
			_on_nav_right_pressed()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("move_forward"):
			_on_nav_up_pressed()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("move_backward"):
			_on_nav_down_pressed()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and not mb.is_echo():
			if current_view == View.DESK and _lamp_life != null:
				if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					_lamp_life.adjust_wick(0.12)
					get_viewport().set_input_as_handled()
					return
				if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_lamp_life.adjust_wick(-0.12)
					get_viewport().set_input_as_handled()
					return
			if mb.button_index == MOUSE_BUTTON_LEFT and not _hovering_nav:
				_update_mouse_raycast()
				if _hovered_target != null and _hovered_target.can_interact():
					if _should_defer_key_to_sender(_hovered_target):
						return
					if _try_seated_door_exit(_hovered_target):
						get_viewport().set_input_as_handled()
						return
					if _hovered_target.is_actionable:
						_hovered_target.interact()
						get_viewport().set_input_as_handled()
						return

func _should_defer_key_to_sender(target: Interactable) -> bool:
	if office == null or office.session_controller == null:
		return false
	var key := office.session_controller.telegraph_key
	if key == null or target != key.get_interactable():
		return false
	if office.shift_director == null:
		return false
	var phase := office.shift_director.get_phase()
	return phase != ShiftDirector.Phase.PRE_SHIFT and phase != ShiftDirector.Phase.CALLING

func _try_seated_door_exit(target: Interactable) -> bool:
	if office == null or office.office_door == null:
		return false
	if target != office.office_door.get_interactable():
		return false
	if not office.office_door.is_open:
		return false
	office.trigger_seated_exit()
	return true
