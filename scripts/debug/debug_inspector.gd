class_name DebugInspector
extends CanvasLayer

@export var session_controller: TelegraphSessionController = null

@onready var output_label: RichTextLabel = $PanelContainer/MarginContainer/Output

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	visible = false
	_connect_signals()
	_refresh_display()

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event.is_action_pressed("toggle_debug_inspector") and not event.is_echo():
		visible = !visible
		if visible:
			_refresh_display()
		var vp: Viewport = get_viewport()
		if vp:
			vp.set_input_as_handled()

func _process(_delta: float) -> void:
	if visible:
		_refresh_display()

func _get_autoload_node(node_name: String) -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		var node = get_tree().root.get_node_or_null(node_name)
		if node:
			return node
	if get_parent():
		var node = get_parent().get_node_or_null(node_name)
		if node:
			return node
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root:
		var node = main_loop.root.get_node_or_null(node_name)
		if node:
			return node
	return null

func _connect_signals() -> void:
	var world = _get_autoload_node("WorldState")
	if world:
		if world.has_signal("fact_changed") and not world.fact_changed.is_connected(_on_state_changed):
			world.fact_changed.connect(_on_state_changed)
		if world.has_signal("state_reset") and not world.state_reset.is_connected(_on_state_changed):
			world.state_reset.connect(_on_state_changed)

	var knowledge = _get_autoload_node("KnowledgeState")
	if knowledge:
		if knowledge.has_signal("knowledge_learned") and not knowledge.knowledge_learned.is_connected(_on_state_changed):
			knowledge.knowledge_learned.connect(_on_state_changed)
		if knowledge.has_signal("state_reset") and not knowledge.state_reset.is_connected(_on_state_changed):
			knowledge.state_reset.connect(_on_state_changed)

	if session_controller == null:
		session_controller = _get_autoload_node("TelegraphSessionController") as TelegraphSessionController
	if session_controller == null and get_parent() != null:
		session_controller = get_parent().get_node_or_null("TelegraphSessionController") as TelegraphSessionController

	if session_controller != null:
		if not session_controller.session_state_changed.is_connected(_on_state_changed):
			session_controller.session_state_changed.connect(_on_state_changed)
		if not session_controller.scenario_loaded.is_connected(_on_state_changed):
			session_controller.scenario_loaded.connect(_on_state_changed)
		if not session_controller.session_completed.is_connected(_on_state_changed):
			session_controller.session_completed.connect(_on_state_changed)

func _on_state_changed(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	if visible:
		_refresh_display()

func _refresh_display() -> void:
	if not output_label:
		output_label = get_node_or_null("PanelContainer/MarginContainer/Output") as RichTextLabel
	if not output_label:
		return

	var world_data: Dictionary = {}
	var knowledge_data: Dictionary = {}

	var world = _get_autoload_node("WorldState")
	if world and world.has_method("snapshot"):
		world_data = world.snapshot()

	var knowledge = _get_autoload_node("KnowledgeState")
	if knowledge and knowledge.has_method("snapshot"):
		knowledge_data = knowledge.snapshot()

	if session_controller != null:
		output_label.text = build_session_display_text(world_data, knowledge_data, session_controller)
	else:
		output_label.text = build_display_text(world_data, knowledge_data)

static func build_display_text(world_data: Dictionary, knowledge_data: Dictionary) -> String:
	var lines: Array[String] = [
		"DEAD WIRE — M1 DEBUG",
		"",
		"CURRENT PHASE:",
		"M1 OFFICE PROTOTYPE",
		"",
		"CURRENT TRANSMISSION:",
		"NOT IMPLEMENTED",
		"",
		"TRUE SIGNAL:",
		"NOT IMPLEMENTED",
		"",
		"ELIAS PERCEPTION:",
		"NOT IMPLEMENTED",
		"",
		"WRITTEN TRANSCRIPT:",
		"NOT IMPLEMENTED",
		"",
		"WORLDSTATE:"
	]

	if world_data.is_empty():
		lines.append("<EMPTY>")
	else:
		var world_keys: Array[String] = []
		for k in world_data.keys():
			world_keys.append(String(k))
		world_keys.sort()
		for key in world_keys:
			var val = world_data[StringName(key)]
			var val_str: String = ""
			if val is bool:
				val_str = "true" if val else "false"
			else:
				val_str = str(val)
			lines.append("%s = %s" % [key, val_str])

	lines.append("")
	lines.append("KNOWLEDGESTATE:")

	if knowledge_data.is_empty():
		lines.append("<EMPTY>")
	else:
		var know_keys: Array[String] = []
		for k in knowledge_data.keys():
			know_keys.append(String(k))
		know_keys.sort()
		for key in know_keys:
			lines.append(key)

	lines.append("")
	lines.append("MORSE STATE:")
	lines.append("NOT IMPLEMENTED")
	lines.append("")
	lines.append("ACTIVE EVENTS:")
	lines.append("NOT IMPLEMENTED")
	lines.append("")
	lines.append("SCHEDULED CONSEQUENCES:")
	lines.append("NOT IMPLEMENTED")

	return "\n".join(lines)

## Reads the shift clock without touching it. The inspector stays read-only.
static func describe_shift(controller: TelegraphSessionController) -> String:
	if controller == null or not controller.is_inside_tree():
		return "M1 OFFICE PROTOTYPE"
	var office := controller.get_parent()
	if office == null:
		return "M1 OFFICE PROTOTYPE"

	var director := office.get_node_or_null("ShiftDirector") as ShiftDirector
	if director == null or not director.enabled:
		return "M1 OFFICE PROTOTYPE (manual session)"

	var phase_name := "UNKNOWN"
	match director.get_phase():
		ShiftDirector.Phase.PRE_SHIFT: phase_name = "PRE_SHIFT (line not opened)"
		ShiftDirector.Phase.WAITING: phase_name = "WAITING (line quiet)"
		ShiftDirector.Phase.CALLING: phase_name = "CALLING"
		ShiftDirector.Phase.ANSWERING: phase_name = "ANSWERING (sender's beat)"
		ShiftDirector.Phase.RECEIVING: phase_name = "RECEIVING"
		ShiftDirector.Phase.AWAITING_ROUTE:
			phase_name = "AWAITING_ROUTE (%.1fs left)" % director.get_route_seconds_remaining()
		ShiftDirector.Phase.CLOSING: phase_name = "CLOSING"
		ShiftDirector.Phase.SHIFT_OVER: phase_name = "SHIFT_OVER"

	var station_time := ""
	var props := office.get_node_or_null("OfficeStorytellingProps")
	if props != null:
		var clock := props.get_node_or_null("StationClock") as StationClock
		if clock != null:
			station_time = "  |  station %s" % clock.get_station_time_text()

	return (
		"SHIFT %s  |  slot %d%s\n  calls %d  missed %d  lapsed %d"
		% [
			phase_name, director.get_slot_index(), station_time,
			director.calls_sent_total, director.messages_missed, director.routes_defaulted
		]
	)

static func build_session_display_text(
	world_data: Dictionary, knowledge_data: Dictionary,
	controller: TelegraphSessionController
) -> String:
	var scen: TelegraphScenarioData = controller.get_current_scenario() if controller != null else null
	var scen_id := scen.scenario_id if scen != null else "NONE"
	var true_sig := scen.transmission_data.true_message if scen != null and scen.transmission_data != null else "NONE"
	var perc := scen.transmission_data.elias_perception if scen != null and scen.transmission_data != null else "NONE"
	var written := scen.transmission_data.written_transcript if scen != null and scen.transmission_data != null else "NONE"

	var state_name := "IDLE"
	if controller != null:
		match controller.get_state():
			TelegraphSessionController.State.IDLE: state_name = "IDLE"
			TelegraphSessionController.State.READY: state_name = "READY (Waiting for Key)"
			TelegraphSessionController.State.RECEIVING: state_name = "RECEIVING (Playing Morse)"
			TelegraphSessionController.State.AWAITING_ROUTE: state_name = "AWAITING_ROUTE (Check Board)"
			TelegraphSessionController.State.COMPLETE: state_name = "COMPLETE"

	var morse_info := state_name
	if controller != null and controller.scheduler != null and controller.scheduler.is_playing():
		var ev: MorseScheduledEvent = controller.scheduler.get_current_event()
		var ev_kind := "MARK" if ev != null and ev.kind == MorseTimingEvent.Kind.MARK else ("GAP" if ev != null else "NONE")
		morse_info = "%s [Event %d (%s) %.2fs / %.2fs]" % [
			state_name,
			controller.scheduler.get_current_event_index(),
			ev_kind,
			controller.scheduler.get_elapsed_seconds(),
			controller.scheduler.get_total_duration_seconds()
		]

	var lines: Array[String] = [
		"DEAD WIRE — M1 DEBUG",
		"",
		"CURRENT PHASE:",
		describe_shift(controller),
		"",
		"CURRENT TRANSMISSION:",
		scen_id,
		"",
		"TRUE SIGNAL:",
		true_sig,
		"",
		"ELIAS PERCEPTION:",
		perc,
		"",
		"WRITTEN TRANSCRIPT:",
		written,
		"",
		"WORLDSTATE:"
	]

	if world_data.is_empty():
		lines.append("<EMPTY>")
	else:
		var world_keys: Array[String] = []
		for k in world_data.keys():
			world_keys.append(String(k))
		world_keys.sort()
		for key in world_keys:
			var val = world_data[StringName(key)]
			var val_str: String = ""
			if val is bool:
				val_str = "true" if val else "false"
			else:
				val_str = str(val)
			lines.append("%s = %s" % [key, val_str])

	lines.append("")
	lines.append("KNOWLEDGESTATE:")

	if knowledge_data.is_empty():
		lines.append("<EMPTY>")
	else:
		var know_keys: Array[String] = []
		for k in knowledge_data.keys():
			know_keys.append(String(k))
		know_keys.sort()
		for key in know_keys:
			lines.append(key)

	lines.append("")
	lines.append("MORSE STATE:")
	lines.append(morse_info)
	lines.append("")
	lines.append("ACTIVE EVENTS:")
	var act_event := "<NONE>"
	if controller != null and controller.is_inside_tree():
		var root_node = controller.get_parent()
		if root_node != null:
			var door_att = root_node.get_node_or_null("DoorAttentionSource") as DoorAttentionSource
			var win_obs = root_node.get_node_or_null("WindowObservationEvent") as AttentionObservationTarget
			if door_att != null and door_att.is_active:
				act_event = "door_footsteps (ACTIVE: playing steps)"
			elif win_obs != null and win_obs.is_active:
				act_event = "window_figure (ACTIVE: %.1fs remaining)" % win_obs._remaining_duration
			elif scen != null and not scen.attention_event_id.is_empty():
				if controller.get_state() == TelegraphSessionController.State.RECEIVING:
					act_event = "Pending: %s (at %.1fs)" % [scen.attention_event_id, scen.attention_event_start_time]
				else:
					act_event = "<NONE>"
	lines.append(act_event)
	lines.append("")
	lines.append("EXPECTED ROUTING:")
	var route_expected := scen.expected_routing_action if scen != null and scen.requires_routing else "<NONE>"
	lines.append(route_expected)

	return "\n".join(lines)
