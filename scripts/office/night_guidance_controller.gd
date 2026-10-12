class_name NightGuidanceController
extends CanvasLayer

## One current thought, based solely on procedures the operator can see.
@export var data: NightGuidanceData = preload("res://data/night_guidance/m1_guidance.tres")
@export var office: M1OfficeController
var enabled: bool = true:
	set(value):
		enabled = value
		if not value:
			_clear()
var current_text: String = ""
var _context: StringName = &""
var _blocked: bool = false
var _context_elapsed: float = 0.0
var _remaining: float = 0.0
var _since_auto: float = 100.0
var _shown: Dictionary = {}
var _label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if office == null:
		office = get_parent() as M1OfficeController
	enabled = GameSettings.load_settings().contextual_thoughts_enabled
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -124.0
	_label.offset_bottom = -72.0
	_label.offset_left = 24.0
	_label.offset_right = -24.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_override("font", preload("res://assets/fonts/noto/NotoSans-Regular.ttf"))
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_bind_visible_events.call_deferred()

func set_context(context: StringName, blocked: bool) -> void:
	if context != _context:
		_context = context
		_context_elapsed = 0.0
		_clear()
	_blocked = blocked
	if blocked:
		_clear()

func advance_guidance(delta: float) -> void:
	if _blocked:
		return
	if _label != null and not current_text.is_empty():
		_label.modulate.a = minf(1.0, _label.modulate.a + delta * 8.0)
	_since_auto += delta
	_context_elapsed += delta
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		_clear()
	if not enabled or data == null or not current_text.is_empty():
		return
	var entry := data.entry_for(_context)
	if entry.is_empty() or (_shown.has(_context) and entry.get("once", true)):
		return
	if _context_elapsed < float(entry.get("delay", 2.0)) or _since_auto < data.automatic_interval:
		return
	_show(entry)
	_since_auto = 0.0
	_shown[_context] = true

func repeat_current() -> void:
	if _blocked or data == null:
		return
	var entry := data.entry_for(_context)
	if not entry.is_empty():
		_show(entry)

func _show(entry: Dictionary) -> void:
	current_text = entry.get("text", "")
	_remaining = float(entry.get("duration", 6.0))
	if _label != null:
		_label.text = current_text
		_label.visible = true
		_label.modulate.a = 0.0

func _clear() -> void:
	current_text = ""
	_remaining = 0.0
	if _label != null:
		_label.visible = false

func _process(delta: float) -> void:
	if office != null:
		_refresh_visible_context()
	advance_guidance(delta)

func _refresh_visible_context() -> void:
	var session := office.session_controller
	var director := office.shift_director
	if session == null or director == null:
		set_context(&"", true)
		return
	var blocked := office.is_world_view_blocked() or get_tree().paused
	blocked = blocked or not session.get_deadline_warning_text().is_empty()
	blocked = blocked or (session.scheduler != null and session.scheduler.is_playing())
	var context: StringName = &""
	if director.is_shift_over():
		context = &"dawn"
	elif director.get_phase() == ShiftDirector.Phase.PRE_SHIFT:
		context = &"open_line" if office.operator_seat != null and office.operator_seat.is_settled() else &"entry"
	elif director.get_phase() == ShiftDirector.Phase.CALLING:
		context = &"answer"
	else:
		match session.get_state():
			TelegraphSessionController.State.VERIFYING: context = &"read_copy"
			TelegraphSessionController.State.AWAITING_ROUTE: context = &"route"
			TelegraphSessionController.State.AWAITING_COMMIT: context = &"filing"
			TelegraphSessionController.State.RECEIVING, TelegraphSessionController.State.COPYING:
				blocked = true
		if director.get_phase() == ShiftDirector.Phase.WAITING and director.get_slot_index() == 1:
			context = &"compare"
	set_context(context, blocked)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		if office != null:
			_refresh_visible_context()
		if not _blocked:
			repeat_current()
			get_viewport().set_input_as_handled()

func _bind_visible_events() -> void:
	if office == null or office.session_controller == null:
		return
	var session := office.session_controller
	session.session_state_changed.connect(_on_work_state_changed)
	if session.scheduler != null:
		session.scheduler.playback_started.connect(_on_wire_started)
	if office.document_viewer != null:
		office.document_viewer.document_opened.connect(_on_document_opened)

func _on_work_state_changed(_new: int, _old: int) -> void:
	_refresh_visible_context()

func _on_wire_started(_schedule: MorsePlaybackScheduleData) -> void:
	set_context(_context, true)

func _on_document_opened(_document_id: String) -> void:
	set_context(_context, true)
