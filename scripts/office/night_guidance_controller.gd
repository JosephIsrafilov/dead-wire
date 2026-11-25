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
var timetable_read := false
var ledger_read := false
var tape_read := false
var _context: StringName = &""
## A thought the room produced rather than the procedure: what just happened.
## It waits for a quiet moment (no wire, no document, no board) so it can never
## talk over Morse or a page the operator is reading.
var _pending_thought: String = ""
var _pending_seconds: float = 6.0
## A reaction goes stale. It describes something that just happened, so it is
## only worth saying while it is still the last thing that happened.
var _pending_age: float = 0.0
const REACTION_STALE_SECONDS: float = 8.0
## A creak is explained once per watch. It is a house settling, not a cue.
var _creaks_explained: bool = false
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
	# Stacked text channels: the whisper sits above (MurmurCaption), the
	# interaction prompt below — no band may overlap another.
	_label.offset_top = -190.0
	_label.offset_bottom = -124.0
	_label.offset_left = 32.0
	_label.offset_right = -32.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A thought is printed like the room's own paper: a period book face in
	# lamp-warm ink, not a modern caption.
	_label.add_theme_font_override("font", preload("res://assets/fonts/oldstandard/OldStandardTT-Regular.ttf"))
	_label.add_theme_font_size_override("font_size", 20)
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0.05, 0.04, 0.03, 0.78)
	band.border_color = Color(0.68, 0.56, 0.36, 0.54)
	band.border_width_top = 1
	band.border_width_bottom = 1
	band.content_margin_left = 14.0
	band.content_margin_right = 14.0
	band.content_margin_top = 4.0
	band.content_margin_bottom = 4.0
	_label.add_theme_stylebox_override("normal", band)
	_label.add_theme_color_override("font_color", Color(0.9, 0.84, 0.7, 1.0))
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
	_context_elapsed += delta
	if _blocked:
		return
	if _label != null and not current_text.is_empty():
		_label.modulate.a = minf(1.0, _label.modulate.a + delta * 8.0)
	_since_auto += delta
	if _remaining > 0.0:
		_remaining = maxf(0.0, _remaining - delta)
		if _remaining <= 0.0:
			_clear()
			return
	if not enabled:
		return
	# A reaction to what just happened outranks a procedural reminder: the
	# player is asking "what was that", and the procedure can wait a beat.
	if not _pending_thought.is_empty():
		_pending_age += delta
		if _pending_age > REACTION_STALE_SECONDS:
			_drop_reaction()
		elif current_text.is_empty():
			_show_reaction()
			return
	if data == null or not current_text.is_empty():
		return
	var entry := data.entry_for(_context)
	if entry.is_empty() or (_shown.has(_context) and entry.get("once", true)):
		return
	if not entry.get("automatic", true):
		return
	if _context_elapsed < float(entry.get("delay", 2.0)):
		return
	if not entry.get("paced_step", false) and _since_auto < data.automatic_interval:
		return
	_show(entry)
	_since_auto = 0.0
	_shown[_context] = true

## Something happened in the room. Queue the one-line answer to it; the thought
## is spoken at the next moment the operator is free to think about it.
func react(kind: StringName, delay: float = 0.0) -> void:
	if data == null or not enabled:
		return
	var entry := data.reaction_for(kind)
	if entry.is_empty():
		return
	_pending_thought = entry.get("text", "")
	_pending_seconds = maxf(0.0, delay if delay > 0.0 else float(entry.get("duration", 6.0)))
	_pending_age = 0.0

func _show_reaction() -> void:
	if _pending_thought.is_empty():
		return
	var text := _pending_thought
	_pending_thought = ""
	_show({"text": text, "duration": _pending_seconds})
	_since_auto = 0.0

func repeat_current() -> void:
	if _blocked or data == null:
		return
	var entry := data.entry_for(_context)
	if not entry.is_empty() and (_context != &"answer_late" or _context_elapsed >= float(entry.delay)):
		_show(entry)

func _show(entry: Dictionary) -> void:
	var english: String = entry.get("text", "")
	current_text = GameLocale.pick(String(entry.get("text_ru", english)), english)
	_remaining = float(entry.get("duration", 6.0))
	if _label != null:
		_label.text = current_text
		var line_height := _label.get_theme_font("font").get_height(_label.get_theme_font_size("font_size"))
		var half_height := clampf(_label.get_line_count() * (line_height + 2.0) * 0.5 + 8.0, 18.0, 36.0)
		_label.offset_top = -157.0 - half_height
		_label.offset_bottom = -157.0 + half_height
		_label.visible = true
		_label.modulate.a = 0.0

func _clear() -> void:
	current_text = ""
	_remaining = 0.0
	if _label != null:
		_label.visible = false

## A blocked surface discards a queued reaction: the room is not talking over a
## document, the wire or a modal, and a thought the player never saw must not
## arrive late describing something that is already over.
func _drop_reaction() -> void:
	_pending_thought = ""

func _process(delta: float) -> void:
	if office != null:
		_refresh_visible_context()
	if not get_tree().paused:
		advance_guidance(delta)

static func wire_busy(session: TelegraphSessionController) -> bool:
	return session.get_state() in [TelegraphSessionController.State.RECEIVING, TelegraphSessionController.State.COPYING] \
		or (session.scheduler != null and session.scheduler.is_playing())

func _refresh_visible_context() -> void:
	var session := office.session_controller
	var director := office.shift_director
	if session == null or director == null:
		set_context(&"", true)
		return
	var blocked := office.is_world_view_blocked() or get_tree().paused or wire_busy(session)
	blocked = blocked or not session.get_deadline_warning_text().is_empty()
	set_context(_work_context(session, director), blocked)

func _work_context(session: TelegraphSessionController, director: ShiftDirector) -> StringName:
	var seated := office.operator_seat != null and office.operator_seat.is_seated
	if director.is_shift_over():
		if seated:
			return &"dawn_seated"
		return &"" if office.dawn_evidence != null and office.dawn_evidence.is_inspected() else &"dawn"
	var phase := director.get_phase()
	if phase == ShiftDirector.Phase.PRE_SHIFT:
		return &"open_line" if seated else &"entry"
	var slot := director.get_slot_index()
	if phase == ShiftDirector.Phase.CALLING:
		if slot == 0:
			return &"answer"
		return &"answer_late" if slot == 1 else &""
	var register := session.get_tape_register()
	if register != null and register.needs_winding():
		return &"wind"
	var state := session.get_state()
	if slot == 0:
		match state:
			TelegraphSessionController.State.VERIFYING: return &"read_copy"
			TelegraphSessionController.State.AWAITING_ROUTE: return &"route"
			TelegraphSessionController.State.AWAITING_COMMIT: return &"filing"
	if slot == 1 and phase == ShiftDirector.Phase.WAITING and not ledger_read:
		return &"ledger"
	if slot == 2 and not tape_read and state in [
			TelegraphSessionController.State.AWAITING_ROUTE, TelegraphSessionController.State.AWAITING_COMMIT]:
		return &"compare"
	return &""

func _unhandled_input(event: InputEvent) -> void:
	# A real input action (plan 6.8), so it can be rebound like any other key.
	if event.is_action_pressed("repeat_thought") and not event.is_echo():
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
	if office.shift_director != null:
		office.shift_director.call_started.connect(_on_call_started)
		office.shift_director.call_answered.connect(_on_call_answered)
		office.shift_director.traffic_missed.connect(_on_traffic_missed)
		office.shift_director.foreign_traffic_heard.connect(_on_foreign_traffic)
	var unease := office.get_node_or_null("UneaseDirector") as UneaseDirector
	if unease != null:
		unease.creaked.connect(_on_creaked)
	session.transmission_finished.connect(_on_transmission_finished)
	session.copy_finished.connect(_on_copy_finished)
	session.routing_resolved.connect(_on_routing_resolved)

func _on_call_started(_slot: int, number: int) -> void:
	# Only the first call of a cycle needs explaining. The repeats are the
	# player's own chance to answer, not new information.
	if number == 1:
		react(&"call")

func _on_call_answered(_slot: int, _number: int) -> void:
	react(&"answered")

func _on_traffic_missed(_slot: int, _scenario: TelegraphScenarioData) -> void:
	react(&"missed")

func _on_transmission_finished(_scenario: TelegraphScenarioData) -> void:
	react(&"signal_end")

func _on_copy_finished(_scenario_id: String) -> void:
	react(&"copy_done")

func _on_routing_resolved(_action: String, outcome: TelegraphSessionController.RoutingOutcome) -> void:
	react(&"routed" if outcome != TelegraphSessionController.RoutingOutcome.LAPSED else &"route_lapsed")

func _on_foreign_traffic(_text: String) -> void:
	react(&"foreign")

func _on_creaked(_position: Vector3) -> void:
	# The building settles whether or not the operator is at the desk. Saying
	# so once turns an unexplained noise into a house; saying it every time
	# would turn it into a caption.
	if _creaks_explained:
		return
	_creaks_explained = true
	react(&"creak")

func _on_work_state_changed(_new: int, _old: int) -> void:
	_refresh_visible_context()

func _on_wire_started(_schedule: MorsePlaybackScheduleData) -> void:
	set_context(_context, true)

func _on_document_opened(document_id: String) -> void:
	match document_id:
		"timetable_card": timetable_read = true
		"dispatch_ledger": ledger_read = true
		TapeRegisterController.TAPE_DOC_ID:
			if office.shift_director.get_slot_index() == 2 and office.session_controller.get_state() in [
					TelegraphSessionController.State.VERIFYING, TelegraphSessionController.State.AWAITING_ROUTE,
					TelegraphSessionController.State.AWAITING_COMMIT]:
				tape_read = true
	set_context(_context, true)

static func refresh_interaction_hint(office: M1OfficeController) -> void:
	if not office.is_shift_directed() or office.player == null or office.session_controller == null:
		return
	var pen := office.get_node_or_null("DeskAmendment") as DeskAmendment
	if pen != null and pen.writing:
		return
	var interaction := office.player.get_node_or_null("InteractionController") as InteractionController
	if interaction == null:
		return
	# How to rise is told until the operator has done it once, then never again.
	var seat := office.operator_seat
	var seated := seat != null and seat.is_seated
	var cursor_station := office.player.seated_station_mode
	var seated_hint := seated and not seat.has_stood_once and not cursor_station
	var hint := GameLocale.pick("Встать со стула  ·  W A S D", OperatorSeat.HINT_SEATED) if seated_hint else ""
	match office.session_controller.get_state():
		TelegraphSessionController.State.VERIFYING:
			hint = GameLocale.pick("Прочтите готовую запись на столе", "Read the finished copy on the desk")
		TelegraphSessionController.State.AWAITING_ROUTE:
			hint = GameLocale.pick("Повернитесь налево [A] к рычагу сигнала", "Look left [A] for the signal lever") \
				if cursor_station else GameLocale.pick("Переведите рычаг сигнала", "Set the route on the signal board")
		TelegraphSessionController.State.AWAITING_COMMIT:
			if seated and office.get_pending_correction().is_empty():
				hint = GameLocale.pick(
					"Взять перо для правки или подшить справа [D]",
					"Take the pen to correct, or look right [D] to file"
				) if cursor_station else GameLocale.pick(
					"Возьмите перо для правки или подшейте копию справа",
					"Pick up the pen to correct, or file at the desk"
				)
			else:
				hint = GameLocale.pick("Повернитесь направо [D] для печати", "Look right [D] to stamp and file") \
					if cursor_station else GameLocale.pick("Подшейте копию на столе подшивки", "File the copy at the filing desk")
	if cursor_station:
		hint = ""
	if office.shift_director.get_phase() == ShiftDirector.Phase.PRE_SHIFT:
		if cursor_station:
			hint = ""
		else:
			hint = GameLocale.pick(
				"[E] Открыть линию ключом справа от листа",
				"[E] Open the line at the key right of the writing pad"
			) if seated else GameLocale.pick(
				"[W A S D] Ходить   [E] Осмотреть / Сесть за стол",
				"[W A S D] Move   [E] Interact / Sit at desk"
			)
			var wick := office.get_node_or_null("DeskSetup/OilLamp/WickInteractable") as Interactable
			if seated and wick != null and wick.can_interact():
				hint = GameLocale.pick(
					"[E] Прибавить лампу слева, затем ключ справа",
					"[E] Turn up the lamp on the left, then use the key on the right"
				)
	elif office.shift_director.get_phase() == ShiftDirector.Phase.CALLING:
		hint = "" if cursor_station else GameLocale.pick(
			"Вызов на линии — [E] ответить ключом",
			"The wire is calling. [E] Answer at the same key"
		)
	elif office.shift_director.get_phase() == ShiftDirector.Phase.WAITING \
			and office.shift_director.get_slot_index() == 0 and seated and not cursor_station:
		hint = GameLocale.pick(
			"Ждите первого вызова. Отвечайте тем же ключом",
			"Wait for the first call. Answer at the same key"
		)
	elif office.shift_director.is_shift_over():
		var need_handover: bool = office.dawn_evidence != null and office.dawn_evidence.is_revealed() \
			and not office.dawn_evidence.is_inspected()
		var leave_hint := ""
		if cursor_station:
			leave_hint = ""
		else:
			leave_hint = GameLocale.pick(
				"Прочтите передачу смены у двери",
				"Read the night handover beside the door"
			) if need_handover else GameLocale.pick(
				"Смена окончена — выходите в южную дверь",
				"The watch is over — leave through the south door"
			)
		hint = leave_hint
	# The sender's warning takes priority over the usual work prompt.
	var warning := office.session_controller.get_deadline_warning_text()
	if not warning.is_empty():
		hint = warning
	if interaction.persistent_hint != hint:
		interaction.set_persistent_hint(hint)
