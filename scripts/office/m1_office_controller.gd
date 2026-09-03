class_name M1OfficeController
extends Node3D

signal scenario_cycle_completed()

@export var enable_psx_rendering: bool = true
@export var render_scale: float = 0.5

@export var session_controller: TelegraphSessionController = null
@export var routing_board: RoutingBoard = null
@export var door_attention: DoorAttentionSource = null
@export var window_observation: AttentionObservationTarget = null
@export var document_viewer: DocumentViewer = null
@export var player_camera: Camera3D = null
@export var player: PlayerController = null
@export var shift_director: ShiftDirector = null
@export var operator_seat: OperatorSeat = null
@export var office_door: OfficeDoor = null
@export var shift_end_card: ShiftEndCard = null

@export var scenario_1: TelegraphScenarioData = preload("res://data/scenarios/m1_scenario_1_baseline.tres")
@export var scenario_2: TelegraphScenarioData = preload("res://data/scenarios/m1_scenario_2_attention.tres")
@export var scenario_3: TelegraphScenarioData = preload("res://data/scenarios/m1_scenario_3_core_hook.tres")

var _scenario_index: int = 0
var _scenario_list: Array[TelegraphScenarioData] = []
var _cycle_completed: bool = false

func _ready() -> void:
	if enable_psx_rendering:
		apply_psx_settings()

	_scenario_list = [scenario_1, scenario_2, scenario_3]
	_bind_signals()
	load_scenario_by_index(0)

func apply_psx_settings() -> void:
	var vp := get_viewport()
	if not vp:
		return
	vp.scaling_3d_scale = clampf(render_scale, 0.25, 1.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.use_debanding = false

func _bind_signals() -> void:
	if session_controller == null:
		session_controller = get_node_or_null("TelegraphSessionController") as TelegraphSessionController
	if routing_board == null:
		routing_board = get_node_or_null("RoutingBoard") as RoutingBoard
	if door_attention == null:
		door_attention = get_node_or_null("DoorAttentionSource") as DoorAttentionSource
	if window_observation == null:
		window_observation = get_node_or_null("WindowObservationEvent") as AttentionObservationTarget
	if document_viewer == null:
		document_viewer = get_node_or_null("DocumentViewer") as DocumentViewer
	if player == null:
		player = get_node_or_null("Player") as PlayerController
	if shift_director == null:
		shift_director = get_node_or_null("ShiftDirector") as ShiftDirector
	if operator_seat == null:
		operator_seat = get_node_or_null("Chair/OperatorSeat") as OperatorSeat
	if office_door == null:
		office_door = get_node_or_null("SouthDoor/DoorController") as OfficeDoor
	if shift_end_card == null:
		shift_end_card = get_node_or_null("ShiftEndCard") as ShiftEndCard

	var exit_trigger := get_node_or_null("OfficeExitTrigger") as Area3D
	if exit_trigger != null and not exit_trigger.body_entered.is_connected(_on_exit_body_entered):
		exit_trigger.body_entered.connect(_on_exit_body_entered)

	if document_viewer != null:
		if not document_viewer.document_opened.is_connected(_on_document_opened):
			document_viewer.document_opened.connect(_on_document_opened)
		if not document_viewer.document_closed.is_connected(_on_document_closed):
			document_viewer.document_closed.connect(_on_document_closed)

	# Connect desk documents to DocumentViewer
	var paper := get_node_or_null("TranscriptPaper") as TranscriptPaper
	if paper == null and session_controller != null:
		paper = session_controller.transcript_paper
	if paper != null and not paper.transcript_inspected.is_connected(_on_transcript_inspected):
		paper.transcript_inspected.connect(_on_transcript_inspected)

	var morse_card := get_node_or_null("MorseReferenceCard") as MorseReferenceCard
	if morse_card != null and not morse_card.card_inspected.is_connected(_on_card_inspected):
		morse_card.card_inspected.connect(_on_card_inspected)

	var ledger := get_node_or_null("DispatchLedger") as DispatchLedger
	if ledger != null and not ledger.ledger_inspected.is_connected(_on_ledger_inspected):
		ledger.ledger_inspected.connect(_on_ledger_inspected)

	var duty_sheet := get_node_or_null("DutySheet") as DutySheet
	if duty_sheet != null and not duty_sheet.sheet_inspected.is_connected(_on_duty_sheet_inspected):
		duty_sheet.sheet_inspected.connect(_on_duty_sheet_inspected)

	if routing_board != null:
		var board_act := routing_board.get_interactable()
		if board_act != null:
			board_act.prompt_text = routing_board.prompt_message
			if not board_act.interacted.is_connected(routing_board._on_interacted):
				board_act.interacted.connect(routing_board._on_interacted)
		if not routing_board.routing_action_selected.is_connected(_on_routing_action):
			routing_board.routing_action_selected.connect(_on_routing_action)

	if session_controller != null:
		if not session_controller.attention_event_triggered.is_connected(_on_attention_event):
			session_controller.attention_event_triggered.connect(_on_attention_event)

		if not session_controller.session_completed.is_connected(_on_session_completed):
			session_controller.session_completed.connect(_on_session_completed)

		if not session_controller.session_state_changed.is_connected(_on_session_state_changed):
			session_controller.session_state_changed.connect(_on_session_state_changed)

		if session_controller.telegraph_key != null:
			var key_act := session_controller.telegraph_key.get_interactable()
			if key_act != null and not key_act.interacted.is_connected(session_controller.telegraph_key._on_interacted):
				key_act.interacted.connect(session_controller.telegraph_key._on_interacted)
			if not session_controller.telegraph_key.key_pressed.is_connected(_on_key_pressed):
				session_controller.telegraph_key.key_pressed.connect(_on_key_pressed)

func _get_scenario_list() -> Array[TelegraphScenarioData]:
	if _scenario_list.is_empty():
		_scenario_list = [scenario_1, scenario_2, scenario_3]
	return _scenario_list

func get_scenario_list() -> Array[TelegraphScenarioData]:
	return _get_scenario_list()

## True while a ShiftDirector owns the pacing of the night.
func is_shift_directed() -> bool:
	return shift_director != null and shift_director.enabled

func load_scenario_by_index(idx: int) -> bool:
	_bind_signals()
	var list := _get_scenario_list()
	if idx < 0 or idx >= list.size():
		return false
	_scenario_index = idx
	if session_controller != null:
		if routing_board != null:
			routing_board.reset_for_new_transmission()
		if window_observation != null:
			window_observation.reset_state()
		var ok: bool = session_controller.load_scenario(list[_scenario_index])
		_update_key_feedback()
		return ok
	return false

func advance_to_next_scenario() -> bool:
	if _cycle_completed:
		return false
	var list := _get_scenario_list()
	var next_idx := _scenario_index + 1
	if next_idx < list.size():
		return load_scenario_by_index(next_idx)
	else:
		if not _cycle_completed:
			_cycle_completed = true
			scenario_cycle_completed.emit()
			_update_key_feedback()
		return false

func is_cycle_completed() -> bool:
	return _cycle_completed

func get_current_scenario_index() -> int:
	return _scenario_index

func _on_key_pressed() -> void:
	if is_shift_directed():
		return
	if session_controller != null and session_controller.get_state() == TelegraphSessionController.State.COMPLETE:
		if not _cycle_completed and _scenario_index + 1 < _get_scenario_list().size():
			advance_to_next_scenario.call_deferred()

func _on_routing_action(action: String) -> void:
	if session_controller != null:
		session_controller.submit_routing_decision(action)

func _on_attention_event(event_id: String) -> void:
	if event_id == "door_footsteps" and door_attention != null:
		door_attention.trigger_footsteps()
	elif event_id == "window_figure" and window_observation != null:
		window_observation.trigger_event(5.0)

func _on_session_completed(_scen: TelegraphScenarioData) -> void:
	var list := _get_scenario_list()
	if _scenario_index + 1 >= list.size():
		if not _cycle_completed:
			_cycle_completed = true
			scenario_cycle_completed.emit()
	_update_key_feedback()

func _on_session_state_changed(new_state: TelegraphSessionController.State, _prev_state: TelegraphSessionController.State) -> void:
	if routing_board != null:
		routing_board.set_awaiting_route(new_state == TelegraphSessionController.State.AWAITING_ROUTE)
	_update_key_feedback()

func _on_transcript_inspected(text: String) -> void:
	if document_viewer != null:
		document_viewer.open_document("transcript_paper", "TELEGRAM TRANSCRIPT (ELIAS CRANE)", text, "[E / Esc] Put Down Transcript")

func _on_card_inspected(text: String) -> void:
	if document_viewer != null:
		document_viewer.open_document("morse_reference", "AMERICAN MORSE CODE (1894)", text, "[E / Esc] Put Down Reference Card")

func _on_ledger_inspected(text: String) -> void:
	if document_viewer != null:
		document_viewer.open_document("dispatch_ledger", "BLACK CREEK STATION — DISPATCH LEDGER", text, "[E / Esc] Put Down Ledger")

## Stepping through the open door ends the slice. The record shown is Elias's
## own duty sheet, so it reports what he knows, never what actually happened.
func _on_exit_body_entered(body: Node) -> void:
	_bind_signals()
	if body != player or player == null:
		return
	if office_door == null or not office_door.is_open:
		return
	if shift_end_card == null or shift_end_card.is_running():
		return

	office_door.notify_player_left()
	player.set_movement_locked(true)

	var record := ""
	var sheet := get_node_or_null("DutySheet") as DutySheet
	if sheet != null:
		record = sheet.get_sheet_text()
	shift_end_card.play("END OF WATCH", record)

func _on_duty_sheet_inspected(text: String) -> void:
	if document_viewer != null:
		document_viewer.open_document("duty_sheet", "OPERATOR'S DUTY SHEET", text, "[E / Esc] Put Down Duty Sheet")

func _on_document_opened(_doc_id: String) -> void:
	if player != null:
		player.set_movement_locked(true)
		var ic := player.get_node_or_null("InteractionController") as InteractionController
		if ic != null:
			ic.is_ui_blocked = true

func _on_document_closed(_doc_id: String) -> void:
	if player != null:
		player.set_movement_locked(false)
		var ic := player.get_node_or_null("InteractionController") as InteractionController
		if ic != null:
			ic.is_ui_blocked = false

func _update_key_feedback() -> void:
	if is_shift_directed():
		return
	var key: TelegraphKey = session_controller.telegraph_key if session_controller != null else null
	if key == null:
		return

	if _cycle_completed:
		key.set_prompt_message("M1 Cycle Complete")
		key.set_enabled(false)
		return

	if session_controller == null:
		return

	match session_controller.get_state():
		TelegraphSessionController.State.IDLE:
			key.set_prompt_message("Line Inactive")
			key.set_enabled(false)
		TelegraphSessionController.State.READY:
			key.set_prompt_message("Press Key (Answer Line)")
			key.set_enabled(true)
		TelegraphSessionController.State.RECEIVING:
			key.set_prompt_message("Line Busy (Receiving Telegram)")
			key.set_enabled(false)
		TelegraphSessionController.State.AWAITING_ROUTE:
			key.set_prompt_message("Awaiting Route Decision on Board")
			key.set_enabled(false)
		TelegraphSessionController.State.COMPLETE:
			if _scenario_index + 1 < _get_scenario_list().size():
				key.set_prompt_message("Press Key (Prepare Next Telegram)")
				key.set_enabled(true)
			else:
				key.set_prompt_message("M1 Cycle Complete")
				key.set_enabled(false)

func _process(_delta: float) -> void:
	if window_observation != null and window_observation.is_active:
		var cam := player_camera
		if cam == null and player != null:
			cam = player.get_node_or_null("Head/Camera3D") as Camera3D
		if cam == null and is_inside_tree() and get_viewport() != null:
			cam = get_viewport().get_camera_3d()
		if cam != null:
			window_observation.check_camera(cam)
