class_name SeatedStationController
extends CanvasLayer

## Seated Bay-Window Workstation controller (Variant A: Inscryption / FNAF style).
##
## Replaces free WASD room-walking during a watch with 4 curated seated views
## around the bay-window desk (Desk + Window, Left Signal Lever, Right Filing
## Desk & Bookcase, Back Office Door) plus a live mouse cursor that interacts
## directly with physical instruments, adjusts the oil lamp wick with the wheel,
## and leans toward the window glass on right-click.

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
	View.LEFT_SIGNAL: {"yaw": 84.0, "pitch": -6.0, "fov": 62.0, "reach": 2.9},
	View.RIGHT_FILING: {"yaw": -84.0, "pitch": -14.0, "fov": 64.0, "reach": 3.4},
	View.BACK_DOOR: {"yaw": 172.0, "pitch": -2.0, "fov": 72.0, "reach": 4.8},
}

const FONT_LETTERPRESS := preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf")
const CHAIR_CREAK_STREAM := preload("res://audio/sfx/foley/chair_settle_cc0.ogg")

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
var _style_normal: StyleBoxFlat = null
var _style_attention: StyleBoxFlat = null
var _hovering_nav: bool = false

func _ready() -> void:
	layer = 6
	_rng.randomize()
	if not enabled:
		visible = false
		return
	_resolve_refs()
	_build_audio()
	_build_nav_ui()
	_bind_intro.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
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
	var intro := office.get_node_or_null("IntroCard") as IntroCard if office != null else null
	if intro != null and intro.is_running() and not intro.is_finished():
		if not intro.intro_finished.is_connected(_activate_station):
			intro.intro_finished.connect(_activate_station, CONNECT_ONE_SHOT)
		_set_nav_visible(false)
		return
	_activate_station()

func _activate_station() -> void:
	if _activated or not enabled:
		return
	_resolve_refs()
	if _player == null:
		return
	_activated = true
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

	current_view = View.DESK
	_current_yaw_rad = deg_to_rad(float(VIEW_PARAMS[View.DESK].yaw))
	_current_pitch_rad = deg_to_rad(float(VIEW_PARAMS[View.DESK].pitch))
	_current_fov = float(VIEW_PARAMS[View.DESK].fov)
	_apply_camera_pose(_current_yaw_rad, _current_pitch_rad, _current_fov)

	if _interaction != null:
		_interaction.cursor_mode = true
		_interaction.refresh_reticle()

	if office != null and office.shift_director != null:
		office.shift_director.refresh_key_state()
	if _seat != null:
		_seat.seated.emit()
		_seat.sit_completed.emit()
	if office != null:
		office._on_operator_sit_completed()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_refresh_nav_buttons()

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
	_btn_left.offset_left = 14.0
	_btn_left.offset_right = 136.0
	_btn_left.offset_top = -24.0
	_btn_left.offset_bottom = 24.0
	add_child(_btn_left)

	_btn_right = _make_nav_button("Filing ›", _on_nav_right_pressed)
	_btn_right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_btn_right.offset_left = -136.0
	_btn_right.offset_right = -14.0
	_btn_right.offset_top = -24.0
	_btn_right.offset_bottom = 24.0
	add_child(_btn_right)

	_btn_down = _make_nav_button("⌄ Door", _on_nav_down_pressed)
	_btn_down.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_btn_down.offset_left = -68.0
	_btn_down.offset_right = 68.0
	_btn_down.offset_top = -54.0
	_btn_down.offset_bottom = -14.0
	add_child(_btn_down)

	_btn_up = _make_nav_button("⌃ Desk", _on_nav_up_pressed)
	_btn_up.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_btn_up.offset_left = -68.0
	_btn_up.offset_right = 68.0
	_btn_up.offset_top = 14.0
	_btn_up.offset_bottom = 54.0
	add_child(_btn_up)

	_set_nav_visible(false)

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
	for btn in [_btn_left, _btn_right, _btn_down, _btn_up]:
		if btn != null:
			btn.visible = show_nav

func _is_blocked() -> bool:
	if not enabled or not _activated:
		return true
	if get_tree() != null and get_tree().paused:
		return true
	if office != null and office.is_world_view_blocked():
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
	_btn_left.visible = current_view != View.LEFT_SIGNAL
	_btn_right.visible = current_view != View.RIGHT_FILING
	_btn_down.visible = current_view == View.DESK
	_btn_up.visible = current_view != View.DESK

	var attn := _attention_flags()
	match current_view:
		View.DESK:
			_apply_nav_cue(_btn_left, "‹ Signal", attn.signal)
			_apply_nav_cue(_btn_right, "Filing ›", attn.filing)
			_apply_nav_cue(_btn_down, "⌄ Door", attn.door)
		View.LEFT_SIGNAL:
			_apply_nav_cue(_btn_right, "Desk ›", attn.desk or attn.filing or attn.door)
			_apply_nav_cue(_btn_up, "⌃ Desk", attn.desk or attn.filing or attn.door)
		View.RIGHT_FILING:
			_apply_nav_cue(_btn_left, "‹ Desk", attn.desk or attn.signal or attn.door)
			_apply_nav_cue(_btn_up, "⌃ Desk", attn.desk or attn.signal or attn.door)
		View.BACK_DOOR:
			_apply_nav_cue(_btn_left, "‹ Filing", attn.filing)
			_apply_nav_cue(_btn_right, "Signal ›", attn.signal)
			_apply_nav_cue(_btn_up, "⌃ Desk", attn.desk)

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
		if st == TelegraphSessionController.State.AWAITING_ROUTE:
			flags.signal = true
		elif st == TelegraphSessionController.State.AWAITING_COMMIT:
			flags.filing = true
	var shutter := office.get_node_or_null("ServiceShutterEvent")
	if shutter != null and shutter.has_method("has_unread_slip") and shutter.has_unread_slip():
		flags.door = true
	if office.office_door != null and (office.office_door.is_open or not office.office_door.is_locked()):
		flags.door = true
	if office.dawn_evidence != null and office.dawn_evidence.is_revealed() and not office.dawn_evidence.is_inspected():
		flags.door = true
	return flags

func _on_nav_left_pressed() -> void:
	if _is_blocked():
		return
	match current_view:
		View.DESK: switch_view(View.LEFT_SIGNAL)
		View.RIGHT_FILING: switch_view(View.DESK)
		View.BACK_DOOR: switch_view(View.RIGHT_FILING)

func _on_nav_right_pressed() -> void:
	if _is_blocked():
		return
	match current_view:
		View.DESK: switch_view(View.RIGHT_FILING)
		View.LEFT_SIGNAL: switch_view(View.DESK)
		View.BACK_DOOR: switch_view(View.LEFT_SIGNAL)

func _on_nav_down_pressed() -> void:
	if _is_blocked():
		return
	if current_view == View.DESK:
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
	_update_cramp_feedback(delta, blocked)

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
	if _interaction != null:
		_interaction.set_cursor_target(null)

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
