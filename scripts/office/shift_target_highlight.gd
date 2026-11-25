class_name ShiftTargetHighlight
extends Node

## The same neutral affordance is shown for either route or filing decision.
const RIM_SHADER := preload("res://materials/shaders/diegetic_hint_rim.gdshader")
const ACCENT_IDS: Array[StringName] = [&"key", &"copy", &"pen", &"tape", &"winding_key", &"filing"]
const SURFACES := {
	&"chair": ["Chair/AuthoredChair"],
	&"key": ["TelegraphStation/TelegraphKey/AuthoredStatic", "TelegraphStation/TelegraphKey/Lever/AuthoredLever"],
	&"timetable": ["TimetableCard/CardFace", "TimetableCard/Paper"],
	&"copy": [
		"TranscriptPaper/ClipBar", "TranscriptPaper/ClipSpring",
		"TranscriptPaper/Sheet/FormFace", "TranscriptPaper/Sheet/PaperMesh",
	],
	&"board": [
		"RoutingBoard/BackboardTrimTop", "RoutingBoard/BackboardTrimBottom",
		"RoutingBoard/BackboardTrimLeft", "RoutingBoard/BackboardTrimRight",
		"RoutingBoard/Quadrant", "RoutingBoard/PivotBoss",
		"RoutingBoard/RepeaterBezel", "RoutingBoard/RepeaterCase",
	],
	&"filing": [
		"CopyCommitDesk/StampTool/Handle", "CopyCommitDesk/StampTool/Knob",
		"CopyCommitDesk/StampTool/Block", "CopyCommitDesk/BrassClipOne",
		"CopyCommitDesk/BrassClipTwo", "CopyCommitDesk/FormFaceOne", "CopyCommitDesk/FormFaceTwo",
	],
	&"winding_key": ["TelegraphSessionController/TapeRegister/Body/WindingKeyPivot/AuthoredWindingKey"],
	&"tape": [
		"TelegraphSessionController/TapeRegister/Body/PaperStrip",
		"TelegraphSessionController/TapeRegister/Body/Spool/AuthoredSpool",
		"TelegraphSessionController/TapeRegister/Body/AuthoredStatic",
	],
	&"pen": ["TranscriptPaper/RestingPen/Shaft", "TranscriptPaper/RestingPen/Nib"],
	&"handover": ["DawnEvidence/Frame", "DawnEvidence/Paper"],
	&"door": ["SouthDoor/Leaf/Doorknob/AuthoredKnob"],
}
const FOCUS_ROOTS := {
	&"chair": "Chair",
	&"key": "TelegraphStation/TelegraphKey",
	&"timetable": "TimetableCard",
	&"copy": "TranscriptPaper",
	&"board": "RoutingBoard",
	&"filing": "CopyCommitDesk",
	&"winding_key": "TelegraphSessionController/TapeRegister/WindInteractable",
	&"tape": "TelegraphSessionController/TapeRegister/Interactable",
	&"pen": "TranscriptPaper/AmendInteractable",
	&"handover": "DawnEvidence",
	&"door": "SouthDoor",
}

@onready var _office := get_parent() as M1OfficeController
@onready var _guidance := _office.get_node("NightGuidance") as NightGuidanceController
@onready var _interaction := _office.player.get_node("InteractionController") as InteractionController

var _material := ShaderMaterial.new()
var _geometry: Dictionary = {}
var _original_overlays: Dictionary = {}
var _strength: Dictionary = {}
var _accent_light: OmniLight3D = null
var _accent_energy: float = 0.0
var _accent_light_2: OmniLight3D = null
var _accent_energy_2: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material.shader = RIM_SHADER
	for id in SURFACES:
		var meshes: Array[GeometryInstance3D] = []
		for path: String in SURFACES[id]:
			var mesh := _office.get_node_or_null(path) as GeometryInstance3D
			if mesh != null:
				meshes.append(mesh)
				_original_overlays[mesh] = mesh.material_overlay
		_geometry[id] = meshes
		_strength[id] = 0.0
	_accent_light = _make_accent_light("HintAccentLight", 0.48)
	_accent_light_2 = _make_accent_light("HintAccentLightSecondary", 0.36)
	_office.session_controller.scheduler.playback_started.connect(_on_wire_started)

func _make_accent_light(node_name: String, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.light_color = Color(1.0, 0.78, 0.40)
	light.light_energy = 0.0
	light.omni_range = light_range
	light.shadow_enabled = false
	light.visible = false
	add_child(light)
	return light

func get_active_target_ids() -> Array[StringName]:
	if _is_blocked():
		return []
	var director := _office.shift_director
	var session := _office.session_controller
	var seated := _office.operator_seat != null and _office.operator_seat.is_seated
	var phase := director.get_phase()
	if phase == ShiftDirector.Phase.SHIFT_OVER:
		if seated:
			return []
		if _office.dawn_evidence.is_inspected():
			return [&"door"]
		return [&"handover"]
	if phase == ShiftDirector.Phase.PRE_SHIFT:
		if not seated:
			return [&"chair"]
		if _guidance.timetable_read:
			return [&"key"]
		return [&"key", &"timetable"]
	var register := session.get_tape_register()
	if register != null and register.needs_winding():
		return [&"winding_key"]
	if phase == ShiftDirector.Phase.CALLING:
		return [&"key"]
	return _copy_targets(session, director.get_slot_index())

func _copy_targets(session: TelegraphSessionController, slot: int) -> Array[StringName]:
	match session.get_state():
		TelegraphSessionController.State.VERIFYING:
			return [&"copy"]
		TelegraphSessionController.State.AWAITING_ROUTE:
			if slot == 0 and not _guidance.timetable_read:
				return [&"board", &"timetable"]
			if slot == 2 and not _guidance.tape_read:
				return [&"board", &"tape"]
			return [&"board"]
		TelegraphSessionController.State.AWAITING_COMMIT:
			var amendment := _office.get_node("DeskAmendment") as DeskAmendment
			if slot == 2 and amendment.can_amend() and _office.get_pending_correction().is_empty():
				if _guidance.tape_read:
					return [&"pen", &"filing"]
				return [&"tape", &"pen"]
			return [&"filing"]
	return []

func _is_blocked() -> bool:
	return _office == null or _office.shift_director == null or _office.session_controller == null \
		or get_tree().paused or _office.is_world_view_blocked() \
		or NightGuidanceController.wire_busy(_office.session_controller)

func _process(delta: float) -> void:
	var targets := get_active_target_ids()
	var blocked := _is_blocked()
	var accent_primary: StringName = &""
	var accent_secondary: StringName = &""
	for id: StringName in targets:
		if id in ACCENT_IDS and not _has_focus(id):
			if accent_primary == &"":
				accent_primary = id
			elif accent_secondary == &"":
				accent_secondary = id
	for id: StringName in _geometry:
		var desired := 0.0
		if id in targets and not _has_focus(id):
			desired = 0.65 if id == &"timetable" else 1.0
		var previous: float = _strength[id]
		var strength := 0.0 if blocked else move_toward(previous, desired, delta * 5.0)
		if strength == previous:
			continue
		_strength[id] = strength
		for mesh: GeometryInstance3D in _geometry[id]:
			mesh.set_instance_shader_parameter("hint_strength", strength)
			mesh.material_overlay = _material if strength > 0.0 else _original_overlays[mesh]
	_accent_energy = _drive_accent_light(_accent_light, _accent_energy, accent_primary, blocked, delta)
	_accent_energy_2 = _drive_accent_light(_accent_light_2, _accent_energy_2, accent_secondary, blocked, delta)

func _drive_accent_light(
	light: OmniLight3D, current_energy: float, target_id: StringName, blocked: bool, delta: float
) -> float:
	if light == null:
		return 0.0
	var desired := 0.0
	if not blocked and target_id != &"":
		var anchor := _office.get_node_or_null(FOCUS_ROOTS[target_id]) as Node3D
		if anchor != null:
			light.global_position = anchor.global_position + Vector3(0.0, 0.14, 0.02)
			var pulse := 0.85 + 0.15 * sin(float(Time.get_ticks_msec()) * 0.0024)
			desired = 0.36 * pulse
	var next_energy := 0.0 if blocked else move_toward(current_energy, desired, delta * 1.8)
	light.light_energy = next_energy
	light.visible = next_energy > 0.005
	return next_energy

func _on_wire_started(_schedule: MorsePlaybackScheduleData) -> void:
	_process(0.0)

func _has_focus(id: StringName) -> bool:
	var target := _interaction.current_target
	if target == null:
		return false
	var focus := _office.get_node_or_null(FOCUS_ROOTS[id])
	return focus != null and (focus == target or focus.is_ancestor_of(target))
