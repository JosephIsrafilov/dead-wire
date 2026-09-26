class_name M1OfficeController
extends Node3D

signal scenario_cycle_completed()

@export var enable_psx_rendering: bool = true
@export var render_scale: float = 0.5

@export var session_controller: TelegraphSessionController = null
@export var routing_board: RoutingBoard = null
@export var copy_commit_desk: CopyCommitDesk = null
@export var door_attention: DoorAttentionSource = null
@export var window_observation: AttentionObservationTarget = null
@export var document_viewer: DocumentViewer = null
@export var player_camera: Camera3D = null
@export var player: PlayerController = null
@export var shift_director: ShiftDirector = null
@export var operator_seat: OperatorSeat = null
@export var office_door: OfficeDoor = null
@export var shift_end_card: ShiftEndCard = null
@export var dawn_evidence: DawnEvidence = null

@export var scenario_1: TelegraphScenarioData = preload("res://data/scenarios/m1_scenario_1_baseline.tres")
@export var scenario_2: TelegraphScenarioData = preload("res://data/scenarios/m1_scenario_2_attention.tres")
@export var scenario_3: TelegraphScenarioData = preload("res://data/scenarios/m1_scenario_3_core_hook.tres")

var _scenario_index: int = 0
var _scenario_list: Array[TelegraphScenarioData] = []
var _cycle_completed: bool = false
var _exit_body_present: bool = false

func _ready() -> void:
	if enable_psx_rendering:
		apply_psx_settings()
	_apply_embedded_body_font()

	_scenario_list = [scenario_1, scenario_2, scenario_3]
	_bind_signals()
	load_scenario_by_index(0)
	_bind_room_fade_in.call_deferred()

## The room is heard faintly behind the intro's black card and comes up with
## the picture; at the end of the watch it leaves with the picture.
const ROOM_UNDER_CARD_DB: float = -18.0
const ROOM_GONE_DB: float = -40.0
const ROOM_FADE_IN_SECONDS: float = 1.2

func _bind_room_fade_in() -> void:
	var intro := get_node_or_null("IntroCard") as IntroCard
	var ambience := get_node_or_null("OfficeAmbience") as OfficeAmbience
	if intro == null or ambience == null or not intro.is_running():
		return
	ambience.set_hush_db(ROOM_UNDER_CARD_DB)
	intro.intro_finished.connect(func() -> void:
		_fade_room(ROOM_UNDER_CARD_DB, 0.0, ROOM_FADE_IN_SECONDS), CONNECT_ONE_SHOT)

func _fade_room(from_db: float, to_db: float, seconds: float) -> void:
	var ambience := get_node_or_null("OfficeAmbience") as OfficeAmbience
	if ambience == null:
		return
	if not is_inside_tree() or seconds <= 0.0:
		ambience.set_hush_db(to_db)
		return
	create_tween().tween_method(ambience.set_hush_db, from_db, to_db, seconds).set_trans(Tween.TRANS_SINE)

## Every printed surface in the room is 1894 letterpress (IM FELL English,
## OFL, bundled), never whatever the host machine's fallback happens to be.
## Labels with an explicitly authored font (Elias's hand) keep theirs.
func _apply_embedded_body_font() -> void:
	var font := load("res://assets/fonts/imfell/IMFeENrm28P.ttf") as Font
	if font == null:
		return
	for label in find_children("*", "Label3D", true, false):
		var label_3d := label as Label3D
		if label_3d.font == null:
			label_3d.font = font

## render_scale is authored against the 720-line reference window. The 3D
## buffer keeps that line count on any display, so a PSX pixel is the same
## size on a laptop and on a 4K monitor; the dither follows the same grid.
const REFERENCE_HEIGHT: float = 720.0

func apply_psx_settings() -> void:
	var vp := get_viewport()
	if not vp:
		return
	_apply_psx_scale()
	var window := get_window()
	if window != null and not window.size_changed.is_connected(_apply_psx_scale):
		window.size_changed.connect(_apply_psx_scale)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.use_debanding = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

func _apply_psx_scale() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var window := get_window()
	var height := float(window.size.y) if window != null and window.size.y > 0 else REFERENCE_HEIGHT
	var scale := clampf(render_scale * REFERENCE_HEIGHT / height, 0.1, 1.0)
	vp.scaling_3d_scale = scale
	var grade := get_node_or_null("PSXDither/Grade") as CanvasItem
	if grade != null and grade.material is ShaderMaterial:
		# The dither cell is one 3D pixel, measured in window pixels.
		(grade.material as ShaderMaterial).set_shader_parameter("pixel_size", 1.0 / scale)

func _bind_signals() -> void:
	if session_controller == null:
		session_controller = get_node_or_null("TelegraphSessionController") as TelegraphSessionController
	if routing_board == null:
		routing_board = get_node_or_null("RoutingBoard") as RoutingBoard
	if copy_commit_desk == null:
		copy_commit_desk = get_node_or_null("CopyCommitDesk") as CopyCommitDesk
	if door_attention == null:
		door_attention = get_node_or_null("DoorAttentionSource") as DoorAttentionSource
	if door_attention != null and session_controller != null:
		door_attention.scheduler = session_controller.scheduler
	if window_observation == null:
		window_observation = get_node_or_null("WindowObservationEvent") as AttentionObservationTarget
	if window_observation != null:
		if not window_observation.visibility_started.is_connected(_on_consequence_visibility_started):
			window_observation.visibility_started.connect(_on_consequence_visibility_started)
		if not window_observation.event_expired.is_connected(_on_consequence_visibility_expired):
			window_observation.event_expired.connect(_on_consequence_visibility_expired)
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
	if dawn_evidence == null:
		dawn_evidence = get_node_or_null("DawnEvidence") as DawnEvidence

	var exit_trigger := get_node_or_null("OfficeExitTrigger") as Area3D
	if exit_trigger != null:
		if not exit_trigger.body_entered.is_connected(_on_exit_body_entered):
			exit_trigger.body_entered.connect(_on_exit_body_entered)
		if not exit_trigger.body_exited.is_connected(_on_exit_body_exited):
			exit_trigger.body_exited.connect(_on_exit_body_exited)

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

	# The register strip lifts to the lamp through the same viewer (design
	# §4): raw marks only, never compared with the transcript sheet.
	if session_controller != null:
		var tape_register := session_controller.get_tape_register()
		if tape_register != null and not tape_register.tape_inspected.is_connected(_on_tape_inspected):
			tape_register.tape_inspected.connect(_on_tape_inspected)

	var morse_card := get_node_or_null("MorseReferenceCard") as MorseReferenceCard
	if morse_card != null and not morse_card.card_inspected.is_connected(_on_card_inspected):
		morse_card.card_inspected.connect(_on_card_inspected)

	var ledger := get_node_or_null("DispatchLedger") as DispatchLedger
	if ledger != null and not ledger.ledger_inspected.is_connected(_on_ledger_inspected):
		ledger.ledger_inspected.connect(_on_ledger_inspected)

	var duty_sheet := get_node_or_null("DutySheet") as DutySheet
	if duty_sheet != null and not duty_sheet.sheet_inspected.is_connected(_on_duty_sheet_inspected):
		duty_sheet.sheet_inspected.connect(_on_duty_sheet_inspected)

	if dawn_evidence != null and not dawn_evidence.evidence_inspected.is_connected(_on_dawn_evidence_inspected):
		dawn_evidence.evidence_inspected.connect(_on_dawn_evidence_inspected)

	if routing_board != null:
		var board_act := routing_board.get_interactable()
		if board_act != null:
			board_act.prompt_text = routing_board.prompt_message
			if not board_act.interacted.is_connected(routing_board._on_interacted):
				board_act.interacted.connect(routing_board._on_interacted)
		if not routing_board.routing_action_selected.is_connected(_on_routing_action):
			routing_board.routing_action_selected.connect(_on_routing_action)
		if not routing_board.board_opened.is_connected(_on_routing_board_opened):
			routing_board.board_opened.connect(_on_routing_board_opened)
		if not routing_board.board_closed.is_connected(_on_routing_board_closed):
			routing_board.board_closed.connect(_on_routing_board_closed)

	if session_controller != null:
		# The lever only moves for a route the world actually accepted: a lapsed
		# NO ORDER never throws it, and a deadline rejection leaves it untouched.
		if not session_controller.routing_resolved.is_connected(_on_routing_resolved_board):
			session_controller.routing_resolved.connect(_on_routing_resolved_board)

	if copy_commit_desk != null:
		if not copy_commit_desk.option_committed.is_connected(_on_commit_option_committed):
			copy_commit_desk.option_committed.connect(_on_commit_option_committed)

	if session_controller != null:
		if not session_controller.attention_event_triggered.is_connected(_on_attention_event):
			session_controller.attention_event_triggered.connect(_on_attention_event)
		if not session_controller.commit_requested.is_connected(_on_commit_requested):
			session_controller.commit_requested.connect(_on_commit_requested)
		if not session_controller.consequence_started.is_connected(_on_consequence_started):
			session_controller.consequence_started.connect(_on_consequence_started)
		if not session_controller.commit_resolved.is_connected(_on_commit_resolved):
			session_controller.commit_resolved.connect(_on_commit_resolved)
		if not session_controller.transmission_started.is_connected(_on_transmission_started):
			session_controller.transmission_started.connect(_on_transmission_started)

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

	if operator_seat != null:
		if not operator_seat.stood.is_connected(_on_operator_stood):
			operator_seat.stood.connect(_on_operator_stood)
		if not operator_seat.sit_completed.is_connected(_on_operator_sit_completed):
			operator_seat.sit_completed.connect(_on_operator_sit_completed)

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
	if idx == 0:
		_exit_body_present = false
		if dawn_evidence != null:
			dawn_evidence.reset_for_new_watch()
		if routing_board != null:
			# A fresh watch wipes the physical record: lever, needle, last
			# route. Slot changes (idx > 0) never touch it (plan R01).
			routing_board.reset_for_new_watch()
	if session_controller != null:
		if routing_board != null:
			routing_board.reset_for_new_transmission()
		if copy_commit_desk != null:
			copy_commit_desk.reset_for_new_transmission()
		if window_observation != null:
			window_observation.reset_state()
		var ok: bool = session_controller.load_scenario(list[_scenario_index])
		# Register after load_scenario resets transient consequence state.
		session_controller.set_consequence_visibility_required(window_observation != null)
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

## A telegram answered while the body is still settling into the chair starts
## all the same: the signal runs and cues are authorized, but no ink appears
## until the sit transition has physically finished.
func _on_transmission_started(_scen: TelegraphScenarioData) -> void:
	if session_controller != null and (operator_seat == null or not operator_seat.is_settled()):
		session_controller.notify_operator_stood()

func _on_operator_stood() -> void:
	if session_controller != null:
		session_controller.notify_operator_stood()

func _on_operator_sit_completed() -> void:
	if session_controller != null:
		session_controller.notify_operator_seated()

func _on_routing_action(action: String) -> void:
	if session_controller == null:
		return
	# An expired route deadline rejects input at the door: the lapse resolves
	# the slot, and a late lever throw must not produce a route or a result.
	if is_shift_directed() and shift_director.is_route_deadline_expired():
		return
	session_controller.submit_routing_decision(action)

## The board's apparatus answers the session's verdict, not the keypress: the
## lever reaches its stop only for an order that actually went out.
func _on_routing_resolved_board(action: String, outcome: TelegraphSessionController.RoutingOutcome) -> void:
	if routing_board == null:
		return
	routing_board.play_route_accept(action, outcome != TelegraphSessionController.RoutingOutcome.LAPSED)

func _on_routing_board_opened() -> void:
	if player == null:
		return
	player.set_movement_locked(true)
	var interaction := player.get_node_or_null("InteractionController") as InteractionController
	if interaction != null:
		interaction.is_ui_blocked = true
		interaction.refresh_prompt()

func _on_routing_board_closed() -> void:
	if player == null:
		return
	if operator_seat != null and operator_seat.is_seated:
		player.set_walk_locked(true)
	else:
		player.set_movement_locked(false)
	var interaction := player.get_node_or_null("InteractionController") as InteractionController
	if interaction != null:
		interaction.is_ui_blocked = false
		interaction.refresh_prompt()

func _on_attention_event(event_id: String) -> void:
	if event_id == "door_footsteps" and door_attention != null:
		door_attention.trigger_footsteps()

func _on_commit_requested(options: Array[TelegraphCommitOption]) -> void:
	if copy_commit_desk == null:
		return
	copy_commit_desk.configure(options)
	var awaiting_commit := session_controller != null \
		and session_controller.get_state() == TelegraphSessionController.State.AWAITING_COMMIT
	copy_commit_desk.set_enabled(awaiting_commit)

func _on_commit_option_committed(action_id: StringName) -> void:
	# The desk expressed intent. The session is the authority: its answer
	# comes back through commit_resolved and only that may change the
	# surface. A rejected intent deliberately changes nothing here.
	if session_controller != null:
		session_controller.submit_commit(action_id)

func _on_commit_resolved(action_id: StringName, result_text: String) -> void:
	# Every resolved outcome — accepted filing or lapse — is applied to the
	# desk by the same authoritative path (B1). Accepted outcomes stamp and
	# fire the contact sound; a lapse shows UNFILED and stays silent.
	if copy_commit_desk == null:
		return
	copy_commit_desk.apply_commit_result(action_id, result_text)

func _on_consequence_started(event_id: String, hold_seconds: float) -> void:
	if event_id == "window_figure" and window_observation != null:
		window_observation.trigger_event(maxf(hold_seconds, 0.0))

func _on_consequence_visibility_started() -> void:
	if session_controller != null:
		session_controller.notify_consequence_visible()

func _on_consequence_visibility_expired() -> void:
	if session_controller != null:
		session_controller.notify_consequence_expired()

func _on_session_completed(_scen: TelegraphScenarioData) -> void:
	if window_observation != null:
		window_observation.cancel_pending_appearance()
	if dawn_evidence != null and _scen != null and _scen.scenario_id == "core_hook_water_watcher":
		dawn_evidence.reveal()
	var list := _get_scenario_list()
	if not list.is_empty() and _scen == list.back():
		if not _cycle_completed:
			_cycle_completed = true
			scenario_cycle_completed.emit()
	_update_key_feedback()

func _on_session_state_changed(
		new_state: TelegraphSessionController.State,
		_prev_state: TelegraphSessionController.State
) -> void:
	if new_state == TelegraphSessionController.State.IDLE:
		if window_observation != null:
			window_observation.reset_state()
		if copy_commit_desk != null:
			copy_commit_desk.reset_for_new_transmission()
	if routing_board != null:
		if new_state != TelegraphSessionController.State.AWAITING_ROUTE and routing_board.is_open:
			routing_board.close_board()
		routing_board.set_awaiting_route(new_state == TelegraphSessionController.State.AWAITING_ROUTE)
	if copy_commit_desk != null:
		copy_commit_desk.set_enabled(new_state == TelegraphSessionController.State.AWAITING_COMMIT)
	_update_key_feedback()

func _on_transcript_inspected(text: String) -> void:
	# A half-written sheet is not a document yet: opening the viewer would freeze
	# mid-sentence ink and invite inspection of a copy that is not done. The
	# transcript prompt states the status instead.
	if _is_transcript_copy_in_progress():
		return
	if document_viewer == null:
		return
	var paper := _get_transcript_paper()
	# A blank pad is not a document either: no ink, nothing to read, no
	# document_opened event for a sheet that never received a message.
	if paper != null and paper.get_state() in [TranscriptPaper.PaperState.EMPTY, TranscriptPaper.PaperState.PREPARING]:
		return
	# A closed partial shows exactly the ink it has, with the honest mark. It
	# never reveals the hidden remainder and never verifies anything.
	if paper != null and paper.is_incomplete_closed():
		var body := text if not text.is_empty() else "(nothing was written)"
		document_viewer.open_document(
			"transcript_paper", "NIGHT COPY — E. CRANE",
			"%s\n\n— COPY INCOMPLETE —" % body, "[E / Esc] Put Down Transcript"
		)
		return
	# Finished sheets — current or an earlier telegram's — read as records; the
	# session's own listener decides whether reading verifies anything.
	document_viewer.open_document(
		"transcript_paper", "NIGHT COPY — E. CRANE", text,
		"[E / Esc] Put Down Transcript"
	)

func _get_transcript_paper() -> TranscriptPaper:
	var paper := get_node_or_null("TranscriptPaper") as TranscriptPaper
	if paper == null and session_controller != null:
		paper = session_controller.transcript_paper
	return paper

func _on_tape_inspected(text: String) -> void:
	# Dots and dashes only. No transcript on this surface, no comparison,
	# no verdict: checking the copy against the strip is the player's work.
	if document_viewer == null:
		return
	document_viewer.open_document(TapeRegisterController.TAPE_DOC_ID,
		TapeRegisterController.TAPE_TITLE, _wrap_tape_text(text),
		"[E / Esc] Put Down Tape")

## Paper strips are narrow: fold the mark sequence into ~40-column lines at
## space boundaries so the lamp-lit strip reads like the physical object.
static func _wrap_tape_text(text: String, columns: int = 40) -> String:
	if text.length() <= columns:
		return text
	var out := ""
	var line_start := 0
	while text.length() - line_start > columns:
		var window := text.substr(line_start, mini(columns + 1, text.length() - line_start))
		var space_at := window.rfind(" ")
		if space_at < 0:
			space_at = columns
		out += text.substr(line_start, space_at) + "\n"
		line_start += space_at + 1
	out += text.substr(line_start)
	return out

## True while the current session's sheet is still being written: receiving the
## signal or finishing the backlog after it.
func _is_transcript_copy_in_progress() -> bool:
	if session_controller == null:
		return false
	if session_controller.get_state() != TelegraphSessionController.State.RECEIVING \
			and session_controller.get_state() != TelegraphSessionController.State.COPYING:
		return false
	var paper := _get_transcript_paper()
	return paper != null and paper.is_copy_in_progress()

## Truthful target prompt for the sheet: while the hand is writing, E does
## nothing, so the prompt must not offer a read. Standing operators are sent
## back to the chair; seated ones are told the truth: the copy is not finished.
func _update_transcript_prompt() -> void:
	var paper := _get_transcript_paper()
	if paper == null:
		return
	var act := paper.get_interactable()
	if act == null:
		return
	if paper.get_state() == TranscriptPaper.PaperState.EMPTY:
		# Nothing has been written yet; the pad reports that instead of
		# offering a read that opens an empty document. (PREPARING is not
		# empty: a message is on the wire and the blank is feeding.)
		act.prompt_text = "No Copy Yet"
		act.is_actionable = false
	elif _is_transcript_copy_in_progress():
		var seated: bool = operator_seat != null and operator_seat.is_seated
		act.prompt_text = "Still Copying" if seated else "Return to the Chair to Finish the Copy"
		act.is_actionable = false
	elif paper.is_incomplete_closed():
		act.prompt_text = "Read Incomplete Copy"
		act.is_actionable = true
	else:
		act.prompt_text = paper.prompt_message
		act.is_actionable = true

## Any full-screen surface that hides the world also blocks observation through
## it. This is computed centrally so every caller shares one definition.
func is_world_view_blocked() -> bool:
	if document_viewer != null and document_viewer.is_open():
		return true
	if routing_board != null and routing_board.is_open:
		return true
	var intro := get_node_or_null("IntroCard") as IntroCard
	if intro != null and intro.visible:
		return true
	if shift_end_card != null and shift_end_card.is_running():
		return true
	var pause_menu := get_node_or_null("PauseMenu") as PauseMenu
	if pause_menu != null and pause_menu.is_paused:
		return true
	return false

## The deadline warning must be readable where the player actually is —
## including behind an open document. It updates the live footer of the open
## viewer without reopening it, rescrolling it or touching its snapshot.
func _update_deadline_warning_footer() -> void:
	if document_viewer == null or not document_viewer.is_open():
		return
	var warning := ""
	if session_controller != null:
		warning = session_controller.get_deadline_warning_text()
	if not warning.is_empty():
		document_viewer.set_live_footer("%s  —  [E / Esc] Put Down" % warning)
	else:
		document_viewer.set_live_footer("")

func _on_card_inspected(text: String) -> void:
	if document_viewer != null:
		document_viewer.open_document(
			"morse_reference", "AMERICAN MORSE CODE (1894)", text,
			"[E / Esc] Put Down Reference Card"
		)

func _on_ledger_inspected(text: String) -> void:
	if document_viewer != null:
		document_viewer.open_document(
			"dispatch_ledger", "BLACK CREEK STATION — DISPATCH LEDGER", text,
			"[E / Esc] Put Down Ledger"
		)

## Stepping through the open door ends the slice. The record shown is Elias's
## own duty sheet, so it reports what he knows, never what actually happened.
func _on_exit_body_entered(body: Node) -> void:
	if body == player:
		_exit_body_present = true
	_try_end_shift()

func _on_exit_body_exited(body: Node) -> void:
	if body == player:
		_exit_body_present = false

func _try_end_shift() -> void:
	_bind_signals()
	if not _exit_body_present or player == null:
		return
	if office_door == null or not office_door.is_open:
		return
	if shift_end_card == null or shift_end_card.is_running():
		return
	if document_viewer != null and document_viewer.is_open():
		return
	if dawn_evidence != null and dawn_evidence.is_revealed() and not dawn_evidence.is_inspected():
		var interaction := player.get_node_or_null("InteractionController") as InteractionController
		if interaction != null:
			interaction.set_persistent_hint("Read the night handover before leaving")
		return

	office_door.notify_player_left()
	player.set_movement_locked(true)

	var record := ""
	var sheet := get_node_or_null("DutySheet") as DutySheet
	if sheet != null:
		record = sheet.get_watch_record()
	shift_end_card.play("END OF WATCH", record)
	_fade_room(0.0, ROOM_GONE_DB, shift_end_card.fade_duration)
	var interaction := player.get_node_or_null("InteractionController") as InteractionController
	if interaction != null:
		interaction.is_ui_blocked = true
		interaction.refresh_prompt()

func _on_duty_sheet_inspected(text: String) -> void:
	if document_viewer != null:
		document_viewer.open_document("duty_sheet", "OPERATOR'S DUTY SHEET", text, "[E / Esc] Put Down Duty Sheet")

func _on_dawn_evidence_inspected(text: String) -> void:
	var interaction: InteractionController = player.get_node_or_null("InteractionController") \
		if player != null else null
	if interaction != null:
		interaction.set_persistent_hint("")
	if document_viewer != null:
		document_viewer.open_document(
			"dawn_evidence", "BLACK CREEK — NIGHT HANDOVER", text,
			"[E / Esc] Put Down Dispatch Draft"
		)

func _on_document_opened(_doc_id: String) -> void:
	if player != null:
		player.set_movement_locked(true)
		var ic := player.get_node_or_null("InteractionController") as InteractionController
		if ic != null:
			ic.is_ui_blocked = true
			ic.refresh_prompt()

func _on_document_closed(doc_id: String) -> void:
	if player != null:
		if operator_seat != null and operator_seat.is_seated:
			# Reading at the desk must not let WASD pull the capsule out of the
			# chair. Looking remains free, as it is during a normal seated watch.
			player.set_walk_locked(true)
		else:
			player.set_movement_locked(false)
		var ic := player.get_node_or_null("InteractionController") as InteractionController
		if ic != null:
			ic.is_ui_blocked = false
			ic.refresh_prompt()
	if doc_id == "dawn_evidence":
		_try_end_shift()

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
			key.set_prompt_message("Answer the Line")
			key.set_enabled(true)
		TelegraphSessionController.State.RECEIVING:
			key.set_prompt_message(ShiftDirector.PROMPT_RECEIVING)
			key.set_enabled(false)
		TelegraphSessionController.State.COPYING:
			key.set_prompt_message("Finishing the Copy")
			key.set_enabled(false)
		TelegraphSessionController.State.AWAITING_ROUTE:
			key.set_prompt_message("Awaiting Route Decision on Board")
			key.set_enabled(false)
		TelegraphSessionController.State.VERIFYING, \
		TelegraphSessionController.State.AWAITING_COMMIT, \
		TelegraphSessionController.State.CONSEQUENCE:
			key.set_prompt_message("Transcript Requires Attention")
			key.set_enabled(false)
		TelegraphSessionController.State.COMPLETE:
			if _scenario_index + 1 < _get_scenario_list().size():
				key.set_prompt_message("Press Key (Prepare Next Telegram)")
				key.set_enabled(true)
			else:
				key.set_prompt_message("M1 Cycle Complete")
				key.set_enabled(false)

func _process(_delta: float) -> void:
	_update_transcript_prompt()
	_refresh_guidance()
	_update_deadline_warning_footer()
	if window_observation != null and window_observation.is_active:
		var cam := player_camera
		if cam == null and player != null:
			cam = player.get_node_or_null("Head/Camera3D") as Camera3D
		if cam == null and is_inside_tree() and get_viewport() != null:
			cam = get_viewport().get_camera_3d()
		if cam != null:
			window_observation.check_camera(cam, is_world_view_blocked())

func _refresh_guidance() -> void:
	if not is_shift_directed() or player == null or session_controller == null:
		return
	var interaction := player.get_node_or_null("InteractionController") as InteractionController
	if interaction == null:
		return
	# How to rise is told until the operator has done it once, then never again.
	var seated_hint := operator_seat != null and operator_seat.is_seated and not operator_seat.has_stood_once
	var hint := OperatorSeat.HINT_SEATED if seated_hint else ""
	match session_controller.get_state():
		TelegraphSessionController.State.VERIFYING:
			hint = "Read the finished copy on the desk"
		TelegraphSessionController.State.AWAITING_ROUTE:
			hint = "Set the route on the east wall board"
		TelegraphSessionController.State.AWAITING_COMMIT:
			hint = "File one copy at the table by the stove"
	# A deadline warning is true everywhere the player can be, including behind
	# an open document: the sender does not wait for the reader.
	var warning := session_controller.get_deadline_warning_text()
	if not warning.is_empty():
		hint = warning
	if shift_director.get_phase() == ShiftDirector.Phase.PRE_SHIFT:
		hint = "Work the key to open the line" if operator_seat.is_seated else "[W A S D] Move   [E] Inspect   [Esc] Pause"
		var lamp_life := get_node_or_null("LampLife") as LampLife
		if operator_seat.is_seated and lamp_life != null and lamp_life.wick < 1.0:
			hint = "Turn up the lamp, then work the key to open the line"
	elif shift_director.get_phase() == ShiftDirector.Phase.CALLING:
		hint = "The office is calling — answer at the key"
	elif shift_director.is_shift_over():
		var leave_hint := "Read the night handover beside the door" \
			if dawn_evidence.is_revealed() and not dawn_evidence.is_inspected() \
			else "The watch is over — leave through the south door"
		hint = leave_hint
	if interaction.persistent_hint != hint:
		interaction.set_persistent_hint(hint)
