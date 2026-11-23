class_name RoutingBoard
extends Node3D

signal routing_action_selected(action: String)
## Physical feedback acknowledges an accepted order, never the input that requested it.
signal route_accepted(action: String)
## The lever has met its stop (plan 8.2: the contact the hand feels).
signal lever_stopped()
signal board_opened()
signal board_closed()

@export var prompt_message: String = "Train-Order Signal"
@export var is_awaiting_route: bool = false

## The switch lever physically throws when a route is set. Angles in degrees from
## the lever's rest pose; CLEAR EAST throws one way, HOLD the other.
@export var lever_throw_degrees: float = 34.0
@export var lever_throw_duration: float = 0.42
@export var lever_impact_stream: AudioStream = preload("res://assets/audio/sfx/kenney_impact/lever_stop.ogg")
## The lever stop is furniture working, not the wire: it rides the Foley bus.
@export var lever_impact_bus: StringName = &"Foley"
## The repeater blade, as the semaphore outside: level is STOP, dropped is
## CLEAR. Rest is STOP — the signal stands at stop until an order clears it.
@export var repeater_clear_degrees: float = -55.0
## The framed rules beside the signal (plan 6.5): strict, in the company's voice.
@export var rules_title: String = "RULES FOR THE TRAIN-ORDER SIGNAL"
@export_multiline var rules_text: String = ""

var interactable: Interactable = null
var is_open: bool = false
var has_submitted_this_session: bool = false
## The last route that actually went out this watch. A new slot may reset the
## ability to submit, but the physical lever keeps the result until the watch
## itself is reset (plan R01).
var _last_route_action: String = ""
## Keep the dispatch guard until every synchronous authority listener returns,
## even if one listener advances the slot while publishing acceptance.
var _route_pending: bool = false
var _pending_route_action: String = ""
var _pending_route_resolved: bool = false
var _pending_route_accepted: bool = false
var _slot_generation: int = 0
var _pending_slot_generation: int = 0
var _watch_generation: int = 0
var _pending_watch_generation: int = 0
var _publishing_route_accept: bool = false

var _lever_rest_rotation: float = 0.0
var _lever_rest_captured: bool = false
var _lever_tween: Tween = null

func _capture_lever_rest() -> void:
	if _lever_rest_captured:
		return
	var pivot := get_node_or_null("LeverPivot") as Node3D
	if pivot != null:
		_lever_rest_rotation = pivot.rotation.z
		_lever_rest_captured = true

func _ready() -> void:
	_capture_lever_rest()
	interactable = get_node_or_null("Interactable") as Interactable

	if interactable != null:
		interactable.prompt_text = prompt_message
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	_add_direct_stop_targets()
	_bind_rules()
	refresh_locale()

func refresh_locale() -> void:
	prompt_message = GameLocale.pick("Поездной сигнал", "Train-Order Signal")
	var hdr := get_node_or_null("HeaderLabel3D") as Label3D
	if hdr != null:
		hdr.text = GameLocale.pick("ПОЕЗДНОЙ СИГНАЛ", "TRAIN-ORDER SIGNAL")
	var sub := get_node_or_null("HeaderLabel3DSub") as Label3D
	if sub != null:
		sub.text = GameLocale.pick("ВОСТОЧНЫЙ ПУТЬ · БЛЭК-КРИК", "EASTWARD — BLACK CREEK")
	var clear_lbl := get_node_or_null("ClearEastLabel3D") as Label3D
	if clear_lbl != null:
		clear_lbl.text = GameLocale.pick("ПРОПУСТИТЬ", "CLEAR EAST")
	var hold_lbl := get_node_or_null("HoldLabel3D") as Label3D
	if hold_lbl != null:
		hold_lbl.text = GameLocale.pick("ДЕРЖАТЬ", "HOLD")
	var clear_act := get_node_or_null("ClearStopInteractable") as Interactable
	if clear_act != null:
		clear_act.prompt_text = GameLocale.pick("Рычаг: ПРОПУСТИТЬ (CLEAR EAST)", "Throw Lever: CLEAR EAST")
	var hold_act := get_node_or_null("HoldStopInteractable") as Interactable
	if hold_act != null:
		hold_act.prompt_text = GameLocale.pick("Рычаг: ДЕРЖАТЬ (HOLD)", "Throw Lever: HOLD")
	_bind_rules()
	_update_presentation()

## The rules frame reads through the office's document viewer, like any paper.
func _bind_rules() -> void:
	var title := GameLocale.pick("ПРАВИЛА ПОЕЗДНОГО СИГНАЛА", rules_title)
	var body := GameLocale.pick(
		"Ж.Д. БЛЭК-КРИК — СЛУЖБА ДВИЖЕНИЯ\n\n"
		+ "221. Семафор стоит на СТОП. Открывать путь поезду только после приёма и проверки телеграммы.\n\n"
		+ "222. Неясный приказ не исполняется. Задержать поезд и запросить подтверждение.\n\n"
		+ "223. Рычагом работает только дежурный телеграфист. Между пазами рычаг не оставлять.\n\n"
		+ "224. Каждая копия подшивается за столом сразу после приказа. Правка вписывается отдельно.\n\n"
		+ "225. Самовольное открытие пути или задержка поезда без причины — увольнение.",
		rules_text
	)
	var text := get_node_or_null("SignalRules/Text") as Label3D
	if text != null:
		text.text = title + "\n\n" + body
	var rules := get_node_or_null("SignalRules/Interactable") as Interactable
	if rules != null:
		rules.prompt_text = GameLocale.pick("Правила сигнала", "Read Signal Rules")
		if not rules.interacted.is_connected(read_rules):
			rules.interacted.connect(read_rules)

func read_rules() -> bool:
	var office := get_parent() as M1OfficeController
	if office == null or office.document_viewer == null or rules_text.is_empty():
		return false
	var title := GameLocale.pick("ПРАВИЛА ПОЕЗДНОГО СИГНАЛА", rules_title)
	var body := GameLocale.pick(
		"Ж.Д. БЛЭК-КРИК — СЛУЖБА ДВИЖЕНИЯ\n\n"
		+ "221. Семафор стоит на СТОП. Открывать путь поезду только после приёма и проверки телеграммы.\n\n"
		+ "222. Неясный приказ не исполняется. Задержать поезд и запросить подтверждение.\n\n"
		+ "223. Рычагом работает только дежурный телеграфист. Между пазами рычаг не оставлять.\n\n"
		+ "224. Каждая копия подшивается за столом сразу после приказа. Правка вписывается отдельно.\n\n"
		+ "225. Самовольное открытие пути или задержка поезда без причины — увольнение.",
		rules_text
	)
	office.document_viewer.open_document(
		"signal_rules", title, body,
		GameLocale.pick("[E / Esc / ПКМ] Отложить", "[E / Esc] Put Down")
	)
	return true

func _add_direct_stop_targets() -> void:
	if get_node_or_null("ClearStopInteractable") != null:
		return
	# The two notches of the quadrant: aim at the side the lever should go.
	var configs := [
		["ClearStopInteractable", "CLEAR EAST", "Throw Lever: CLEAR EAST", Vector3(-0.34, 0.3, -0.2)],
		["HoldStopInteractable", "HOLD", "Throw Lever: HOLD", Vector3(0.34, 0.3, -0.2)],
	]
	for cfg in configs:
		var area := Interactable.new()
		area.name = cfg[0]
		area.collision_layer = 2
		area.collision_mask = 0
		area.prompt_text = cfg[2]
		area.enabled = false
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		# Owns the half of the quadrant on its side, from the notch up past
		# the grip's swing, so a real aim at the lever lands on a choice.
		box.size = Vector3(0.42, 0.58, 0.24)
		shape.shape = box
		area.add_child(shape)
		area.position = cfg[3]
		var route_name: String = cfg[1]
		area.interacted.connect(func() -> void: throw_direct_route(route_name))
		add_child(area)

func throw_direct_route(action: String) -> bool:
	# A direct lever throw is not a modal. It needs a closed board, a pending
	# decision and direct eligibility; it never opens or closes the modal,
	# never fakes a board_opened/board_closed lifecycle and never touches the
	# mouse. Only the authority's acknowledgement can throw the lever.
	if is_open or not is_awaiting_route or has_submitted_this_session or _route_pending or _publishing_route_accept:
		return false
	return _request_route(action)

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	return interactable

func set_awaiting_route(awaiting: bool) -> void:
	is_awaiting_route = awaiting
	_update_presentation()

func _update_presentation() -> void:
	_add_direct_stop_targets()
	var can_direct := is_awaiting_route and not has_submitted_this_session and not is_open
	for stop_name in ["ClearStopInteractable", "HoldStopInteractable"]:
		var stop_act := get_node_or_null(stop_name) as Interactable
		if stop_act != null:
			stop_act.enabled = can_direct
			stop_act.is_actionable = can_direct
			# An off-state target must not eat the interaction ray either: a
			# disabled stop leaves the layer so the ray reaches the board's
			# own surface behind it.
			stop_act.collision_layer = 2 if can_direct else 0
	if interactable == null:
		return
	# The backboard and repeater only show; the order is given at the lever
	# (plan 6.5), so E here never promises an interaction.
	interactable.is_actionable = false
	if not _last_route_action.is_empty() and not (is_awaiting_route and not has_submitted_this_session):
		# The night's last order stays on the repeater after the slot moves on.
		var act_label := _last_route_action
		if GameLocale.is_ru():
			act_label = "ПРОПУСТИТЬ" if _last_route_action == "CLEAR EAST" else "ДЕРЖАТЬ"
		interactable.prompt_text = GameLocale.pick("Сигнал: %s", "Signal at %s") % act_label
	else:
		interactable.prompt_text = prompt_message

func _input(event: InputEvent) -> void:
	if not is_open:
		_handle_stand_keys(event)
		return

	var escape_key: bool = event is InputEventKey and event.pressed \
		and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE)
	var is_cancel: bool = event.is_action_pressed("ui_cancel") or escape_key
	if is_cancel and not event.is_echo():
		close_board()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		return

	if event.is_echo() or not event.is_pressed():
		return

	var is_route_1: bool = event.is_action_pressed("route_clear_east")
	var is_route_2: bool = event.is_action_pressed("route_hold")

	if is_route_1:
		if select_action("CLEAR EAST"):
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
	elif is_route_2:
		if select_action("HOLD"):
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()

## At the stand, the route keys throw the lever directly, the way the commit
## desk takes its keys: only while the operator is looking at this signal.
func _handle_stand_keys(event: InputEvent) -> bool:
	if event.is_echo() or not event.is_pressed() or not is_awaiting_route or has_submitted_this_session:
		return false
	var action := ""
	if event.is_action_pressed("route_clear_east"):
		action = "CLEAR EAST"
	elif event.is_action_pressed("route_hold"):
		action = "HOLD"
	if action.is_empty():
		return false
	var office := get_parent() as M1OfficeController
	if office == null or office.player == null:
		return false
	var controller := office.player.get_node_or_null("InteractionController") as InteractionController
	if controller == null or controller.is_ui_blocked or controller.current_target == null \
			or not is_ancestor_of(controller.current_target):
		return false
	if throw_direct_route(action):
		get_viewport().set_input_as_handled()
		return true
	return false

## Kept for the keyboard-only path and the tests that drive it; nothing in the
## room opens it any more (plan 6.5: the order is given at the lever).
func open_board() -> void:
	if is_open:
		return
	# An idle board is a status surface, not a modal. Opening it would lock
	# movement behind a panel with nothing to decide.
	if not is_awaiting_route or has_submitted_this_session:
		return
	is_open = true
	_update_presentation()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	board_opened.emit()

func close_board() -> void:
	if not is_open:
		return
	is_open = false
	_update_presentation()
	var office := get_parent()
	var player_node := office.get("player") as Node if office != null else null
	var seated_mode := player_node != null and bool(player_node.get("seated_station_mode"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if seated_mode else Input.MOUSE_MODE_CAPTURED
	board_closed.emit()

func select_action(action: String) -> bool:
	# Only the real modal may submit through its own key path.
	if not is_open:
		return false
	var accepted := _request_route(action)
	# Only the modal caller closes a really-open modal after an acceptance.
	if accepted and _slot_generation == _pending_slot_generation:
		close_board()
	return accepted

## Common guarded submission, shared by the modal keys and the direct lever
## stops. Emits the intent to the session authority; success is the authority's
## synchronous acknowledgement, never the emit itself.
func _request_route(action: String) -> bool:
	if has_submitted_this_session or not is_awaiting_route or _route_pending or _publishing_route_accept:
		return false

	if not RouteAction.is_valid(action):
		return false

	# Intent is not a record. Only the authority's acknowledgement can submit
	# this slot; a rejected request leaves the board available for a retry.
	_route_pending = true
	_pending_route_action = action
	_pending_route_resolved = false
	_pending_route_accepted = false
	_pending_slot_generation = _slot_generation
	_pending_watch_generation = _watch_generation
	routing_action_selected.emit(action)
	var accepted := _pending_route_accepted
	_route_pending = false
	_pending_route_action = ""
	return accepted

## The session resolved the slot: an accepted route (correct or not — the order
## physically went out) throws the lever to its stop with the impact sound; a
## lapsed "NO ORDER" leaves the lever exactly where it was.
func play_route_accept(action: String, accepted: bool) -> void:
	if _publishing_route_accept:
		return
	if _route_pending:
		if _pending_route_resolved or action != _pending_route_action or _watch_generation != _pending_watch_generation:
			return
		_pending_route_resolved = true
	if not accepted or action.is_empty():
		return
	if _route_pending:
		_pending_route_accepted = true
	_publishing_route_accept = true
	if not _route_pending or _slot_generation == _pending_slot_generation:
		has_submitted_this_session = true
	# A slot reset may have happened inside the intent. Its old payload still
	# becomes watch memory, but must never submit the new slot.
	_last_route_action = action
	_update_presentation()
	_throw_lever(action)
	route_accepted.emit(action)
	_publishing_route_accept = false

## A route order is a physical act: the lever pivot swings to its stop, the
## mechanical needle follows, and the stop announces itself on the wire-side
## of the room. Targets are absolute against the once-captured rest pose, so
## repeated throws cannot drift; a new accepted throw kills the previous
## tween so a late result can never overwrite the fresh record.
func _throw_lever(action: String) -> void:
	var pivot := get_node_or_null("LeverPivot") as Node3D
	var needle := get_node_or_null("IndicatorPivot") as Node3D
	if pivot == null:
		return
	# Capture the authored rest exactly once, before any throw can move it.
	_capture_lever_rest()

	var direction := 1.0 if action == "CLEAR EAST" else -1.0
	var target := _lever_rest_rotation + direction * deg_to_rad(lever_throw_degrees)

	if _lever_tween != null and is_instance_valid(_lever_tween):
		_lever_tween.kill()

	var blade := deg_to_rad(repeater_clear_degrees) if action == "CLEAR EAST" else 0.0
	if not is_inside_tree():
		pivot.rotation.z = target
		if needle != null:
			needle.rotation.z = blade
		return

	_lever_tween = create_tween()
	_lever_tween.set_parallel(true)
	_lever_tween.tween_property(pivot, "rotation:z", target, lever_throw_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if needle != null:
		# The repeater answers the lever as the arm outside does: it drops for
		# CLEAR and stands level for HOLD.
		_lever_tween.tween_property(needle, "rotation:z", blade, lever_throw_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Impact lands when the lever meets the stop, not when the hand starts it.
	var sfx := get_node_or_null("LeverSfx") as AudioStreamPlayer3D
	if sfx != null:
		sfx.stream = lever_impact_stream
		sfx.bus = lever_impact_bus
	_lever_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(sfx):
			sfx.play()
		lever_stopped.emit())

## A new slot resets the ability to submit — nothing else. The lever, the
## needle and the recorded route are the night's memory, not this slot's.
func reset_for_new_transmission() -> void:
	if is_open:
		close_board()
	_slot_generation += 1
	has_submitted_this_session = false
	is_open = false
	is_awaiting_route = false
	_update_presentation()

## Only a new watch wipes the physical record: lever and needle return to
## rest and the board forgets the last route.
func reset_for_new_watch() -> void:
	_watch_generation += 1
	reset_for_new_transmission()
	_last_route_action = ""
	if _lever_tween != null and is_instance_valid(_lever_tween):
		_lever_tween.kill()
	_lever_tween = null
	_capture_lever_rest()
	var pivot := get_node_or_null("LeverPivot") as Node3D
	var needle := get_node_or_null("IndicatorPivot") as Node3D
	if _lever_rest_captured and pivot != null:
		pivot.rotation.z = _lever_rest_rotation
	if needle != null:
		needle.rotation.z = 0.0
	_update_presentation()

## The backboard is status only: an E aimed at it opens nothing. The order is
## the lever's (plan 6.5); a stale modal from an older build is put down.
func _on_interacted() -> void:
	if is_open:
		close_board()
