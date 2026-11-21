class_name OperatorKeySender
extends Node

## Allows the seated operator to physically key Morse on the brass key
## (Space or Left Mouse Button while seated, or holding E while aiming at the
## key when the line is not waiting for a single-press open/answer).
##
## Every press clicks the sounder down/up, animates the brass lever, and inks
## honest MARK/GAP events onto the tape register (never passing text to it).
## A forgiving decoder (±35% around dot/dash unit lengths) recognizes:
##   - R   (.-.)          -> acknowledgement ("OK" after calls 1-2)
##   - RPT (.-. .--. -)   -> repeat request ("YOU HEARD ME" after call 3)
##
## Strictly optional: ignoring the key never blocks or soft-locks the shift.

signal signal_decoded(code: String)
signal wire_response_sent(text: String)

const RESPONSE_DELAY_HOOK_SECONDS: float = 2.0
const RESPONSE_DELAY_ACK_SECONDS: float = 0.9
const IDLE_COMMIT_SECONDS: float = 0.72
## ±35% tolerance around 1-unit dot and 3-unit dash durations.
const DURATION_TOLERANCE: float = 0.35

## Supported short operator signals in dot/dash notation matching the desk slip:
## R (.-.) and RPT (.-. .--. -).
const CODE_R: String = ".-."
const CODE_RPT_LETTERS: Array[String] = [".-.", ".--.", "-"]
const CODE_RPT_COMPACT: String = ".-..--.-"

@export var office: M1OfficeController = null
@export var profile: MorsePlaybackProfileData = preload("res://data/morse/m1_morse_playback_profile.tres")

var _is_keying: bool = false
var _key_down_time: float = 0.0
var _idle_since_release: float = -1.0
var _raw_events: Array[Dictionary] = []
var _pending_response_text: String = ""
var _pending_response_timer: float = -1.0
var _hook_rpt_answered: bool = false
var _last_completed_slot: int = -1

func _ready() -> void:
	if office == null:
		office = get_parent() as M1OfficeController
	_bind.call_deferred()

func _bind() -> void:
	if office == null or office.session_controller == null:
		return
	var session := office.session_controller
	if not session.transmission_finished.is_connected(_on_transmission_finished):
		session.transmission_finished.connect(_on_transmission_finished)
	if not session.scenario_loaded.is_connected(_on_scenario_loaded):
		session.scenario_loaded.connect(_on_scenario_loaded)

func _on_scenario_loaded(scenario: TelegraphScenarioData) -> void:
	if scenario != null and scenario.scenario_id == "baseline_train_17":
		_hook_rpt_answered = false
		_last_completed_slot = -1

func _on_transmission_finished(_scenario: TelegraphScenarioData) -> void:
	if office != null and office.shift_director != null:
		_last_completed_slot = office.shift_director.get_slot_index()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_seated_and_free():
		if _is_keying:
			_finish_press()
		return
	if _is_manual_key_event(event):
		if event.is_pressed() and not event.is_echo():
			if _can_manual_key_now():
				_start_press()
				get_viewport().set_input_as_handled()
		elif not event.is_pressed() and _is_keying:
			_finish_press()
			get_viewport().set_input_as_handled()

func _is_manual_key_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		if key_ev.keycode == KEY_SPACE:
			return true
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			return true
	if event.is_action("interact") and _aiming_at_key() and not _key_wants_single_press():
		return true
	return false

func _aiming_at_key() -> bool:
	if office == null or office.player == null or office.session_controller == null:
		return false
	var key := office.session_controller.telegraph_key
	if key == null:
		return false
	var ic := office.player.get_node_or_null("InteractionController") as InteractionController
	return ic != null and ic.current_target == key.get_interactable()

func _key_wants_single_press() -> bool:
	if office == null or office.shift_director == null:
		return false
	var phase := office.shift_director.get_phase()
	return phase == ShiftDirector.Phase.PRE_SHIFT or phase == ShiftDirector.Phase.CALLING

func _is_seated_and_free() -> bool:
	if office == null or office.session_controller == null:
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if office.is_world_view_blocked():
		return false
	if office.operator_seat == null or not office.operator_seat.is_settled():
		return false
	return true

func _can_manual_key_now() -> bool:
	if office == null or office.session_controller == null:
		return false
	if _key_wants_single_press():
		return false
	var session := office.session_controller
	# Never talk over an incoming live signal on the wire.
	if session.scheduler != null and session.scheduler.is_playing():
		return false
	if office.shift_director != null:
		var phase := office.shift_director.get_phase()
		if phase in [ShiftDirector.Phase.PRE_SHIFT, ShiftDirector.Phase.ANSWERING, ShiftDirector.Phase.SHIFT_OVER]:
			return false
	return true

func _start_press() -> void:
	if _is_keying:
		return
	var session := office.session_controller
	if not _raw_events.is_empty() and _idle_since_release >= 0.0:
		_raw_events.append({"kind": MorseTimingEvent.Kind.GAP, "seconds": _idle_since_release})
	_is_keying = true
	_key_down_time = 0.0
	_idle_since_release = -1.0
	if session.telegraph_key != null:
		session.telegraph_key.begin_manual_hold()
	if session.sounder != null:
		session.sounder.play_down(-1)
	var tape := session.get_tape_register()
	if tape != null:
		tape.set_manual_stylus_down(true)

func _finish_press() -> void:
	if not _is_keying:
		return
	_is_keying = false
	var held := maxf(_key_down_time, 0.02)
	_key_down_time = 0.0
	_idle_since_release = 0.0
	_raw_events.append({"kind": MorseTimingEvent.Kind.MARK, "seconds": held})
	var session := office.session_controller
	if session != null:
		if session.telegraph_key != null:
			session.telegraph_key.end_manual_hold()
		if session.sounder != null:
			session.sounder.play_up(-1)
		var tape := session.get_tape_register()
		if tape != null:
			tape.set_manual_stylus_down(false)

func _process(delta: float) -> void:
	if _is_keying:
		_key_down_time += delta
		if not _is_seated_and_free():
			_finish_press()
	elif _idle_since_release >= 0.0 and not _raw_events.is_empty():
		_idle_since_release += delta
		if _idle_since_release >= IDLE_COMMIT_SECONDS:
			_commit_manual_take()
	if _pending_response_timer >= 0.0:
		_pending_response_timer -= delta
		if _pending_response_timer <= 0.0:
			_try_send_pending_response()

func _commit_manual_take() -> void:
	var events := _raw_events.duplicate()
	_raw_events.clear()
	_idle_since_release = -1.0
	var spu := profile.seconds_per_unit if profile != null and profile.seconds_per_unit > 0.0 else 0.1
	var threshold_units := profile.send_threshold_units if profile != null else 2.0
	var timing_events := _quantize_events(events, spu, threshold_units)
	if timing_events.is_empty():
		return
	var session := office.session_controller if office != null else null
	var tape := session.get_tape_register() if session != null else null
	if tape != null:
		tape.record_manual_take(timing_events, spu)
	var decoded := decode_signal(events, spu, threshold_units)
	if not decoded.is_empty():
		signal_decoded.emit(decoded)
		_handle_decoded_signal(decoded)

## Quantizes raw key durations into honest MARK/GAP MorseTimingEvents for the tape.
static func _quantize_events(raw: Array[Dictionary], spu: float, threshold_units: float) -> Array[MorseTimingEvent]:
	var out: Array[MorseTimingEvent] = []
	var threshold_sec := spu * threshold_units
	for entry in raw:
		var ev := MorseTimingEvent.new()
		ev.kind = int(entry.get("kind", MorseTimingEvent.Kind.MARK))
		var sec := float(entry.get("seconds", spu))
		if ev.kind == MorseTimingEvent.Kind.MARK:
			ev.duration_units = 1 if sec < threshold_sec else 3
		else:
			var units := int(round(sec / spu))
			ev.duration_units = clampi(units, 1, 6)
		out.append(ev)
	return out

## Decodes short operator signals with forgiving ±35% tolerance around dot (1u)
## and dash (3u) durations. Recognizes "R" (.-.) and "RPT" (.-. .--. -).
static func decode_signal(raw: Array[Dictionary], spu: float, threshold_units: float = 2.0) -> String:
	if raw.is_empty() or spu <= 0.0:
		return ""
	var dot_max := maxf(spu * threshold_units, spu * 1.0 * (1.0 + DURATION_TOLERANCE))
	var dash_min := minf(spu * threshold_units, spu * 3.0 * (1.0 - DURATION_TOLERANCE))
	var split_sec := (dot_max + dash_min) * 0.5
	var letter_gap_sec := spu * 3.0 * (1.0 - DURATION_TOLERANCE)

	var letters: Array[String] = []
	var current := ""
	var compact := ""
	for entry in raw:
		var kind := int(entry.get("kind", MorseTimingEvent.Kind.MARK))
		var sec := float(entry.get("seconds", 0.0))
		if kind == MorseTimingEvent.Kind.MARK:
			var sym := "." if sec < split_sec else "-"
			current += sym
			compact += sym
		elif sec >= letter_gap_sec and not current.is_empty():
			letters.append(current)
			current = ""
	if not current.is_empty():
		letters.append(current)

	if letters.size() == 1 and letters[0] == CODE_R:
		return "R"
	if letters == CODE_RPT_LETTERS or compact == CODE_RPT_COMPACT:
		return "RPT"
	return ""

func _handle_decoded_signal(code: String) -> void:
	if office == null or office.session_controller == null:
		return
	var scenario := office.session_controller.get_current_scenario()
	var is_hook := scenario != null and scenario.scenario_id == "core_hook_water_watcher"
	var after_hook_signal := is_hook and office.session_controller.get_state() in [
		TelegraphSessionController.State.COPYING,
		TelegraphSessionController.State.VERIFYING,
		TelegraphSessionController.State.AWAITING_COMMIT,
		TelegraphSessionController.State.CONSEQUENCE,
		TelegraphSessionController.State.COMPLETE,
	]
	if code == "RPT" and (after_hook_signal or _last_completed_slot == 2) and not _hook_rpt_answered:
		_hook_rpt_answered = true
		_queue_wire_response("YOU HEARD ME", RESPONSE_DELAY_HOOK_SECONDS)
		return
	if code == "R" and not is_hook and _last_completed_slot in [0, 1]:
		_queue_wire_response("OK", RESPONSE_DELAY_ACK_SECONDS)

func _queue_wire_response(text: String, delay_seconds: float) -> void:
	_pending_response_text = text
	_pending_response_timer = maxf(delay_seconds, 0.05)

func _try_send_pending_response() -> void:
	if _pending_response_text.is_empty() or office == null or office.shift_director == null:
		_pending_response_timer = -1.0
		return
	if office.session_controller != null and office.session_controller.scheduler != null \
			and office.session_controller.scheduler.is_playing():
		# Wait until the wire is quiet; never collide with critical Morse.
		_pending_response_timer = 0.25
		return
	var text := _pending_response_text
	_pending_response_text = ""
	_pending_response_timer = -1.0
	if office.shift_director.send_stray_on_wire(text) > 0.0:
		wire_response_sent.emit(text)
