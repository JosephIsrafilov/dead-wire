class_name DawnEvidence
extends Node3D

## A physical morning document left behind after the last telegram.
## The variant is selected from WorldState: this is the railroad's account,
## not Elias's memory.

signal evidence_revealed(variant_id: StringName)
signal evidence_inspected(text: String)

@export var prompt_message: String = "Read Dawn Dispatch"
@export var world_state: WorldStateStore = null

const VARIANT_WATER: StringName = &"water"
const VARIANT_WATCHER: StringName = &"watcher"
const VARIANT_LAPSED: StringName = &"lapsed"

var interactable: Interactable = null
var _revealed: bool = false
var _inspected: bool = false
var _variant_id: StringName = StringName()
var _document_text: String = ""

func _ready() -> void:
	visible = false
	_resolve_nodes()
	_update_interaction()

func _resolve_nodes() -> void:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		interactable.prompt_text = prompt_message
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

func get_interactable() -> Interactable:
	_resolve_nodes()
	return interactable

func is_revealed() -> bool:
	return _revealed

func is_inspected() -> bool:
	return _inspected

func get_variant_id() -> StringName:
	return _variant_id

func get_document_text() -> String:
	return _document_text

func reveal() -> bool:
	if _revealed:
		return false
	_variant_id = _read_variant()
	_document_text = _build_document(_variant_id)
	_revealed = true
	_inspected = false
	visible = true
	_update_labels()
	_update_interaction()
	evidence_revealed.emit(_variant_id)

	if is_inside_tree():
		var reveal_light := get_node_or_null("RevealLight") as OmniLight3D
		if reveal_light != null:
			reveal_light.light_color = _reveal_light_color(_variant_id)
			reveal_light.light_energy = 0.0
		scale = Vector3(0.84, 0.84, 0.84)
		var rest_rotation := rotation.y
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector3.ONE, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if reveal_light != null:
			tween.tween_property(reveal_light, "light_energy", 0.48, 0.16).set_trans(Tween.TRANS_SINE)
			tween.chain().tween_property(reveal_light, "light_energy", 0.12, 0.72).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "rotation:y", rest_rotation + deg_to_rad(1.5), 0.22).set_trans(Tween.TRANS_SINE)
		tween.chain().tween_property(self, "rotation:y", rest_rotation, 0.42).set_trans(Tween.TRANS_SINE)
	return true

func reset_for_new_watch() -> void:
	_revealed = false
	_inspected = false
	_variant_id = StringName()
	_document_text = ""
	visible = false
	_update_labels()
	_update_interaction()

func _read_variant() -> StringName:
	var world := _get_world_state()
	if world != null:
		if world.get_fact(&"core_hook_filed_water", false) == true:
			return VARIANT_WATER
		if world.get_fact(&"core_hook_filed_watcher", false) == true:
			return VARIANT_WATCHER
		if world.get_fact(&"core_hook_commit_lapsed", false) == true:
			return VARIANT_LAPSED
	return VARIANT_LAPSED

func _build_document(variant_id: StringName) -> String:
	match variant_id:
		VARIANT_WATER:
			return """BLACK CREEK DISPATCH
MORNING DRAFT — 6:03 A.M.
================================

EASTBOUND MAIN
TANK 4 — WATER
STATUS: RELEASED

The morning clerk's copy agrees with
the wire. A clean line was handed over.

SIGNED: J. VALE / DAY DESK"""
		VARIANT_WATCHER:
			return """BLACK CREEK DISPATCH
MORNING DRAFT — 6:03 A.M.
================================

EASTBOUND MAIN
TRAIN: [NO NUMBER]
STATUS: RECORD DOES NOT MATCH

The day clerk has crossed out the copy.
In the margin, one word remains:

WATCHER

SIGNED: J. VALE / DAY DESK"""
		_:
			return """BLACK CREEK DISPATCH
MORNING DRAFT — 6:03 A.M.
================================

EASTBOUND MAIN
STATUS: NO COPY ON FILE

At 6:03 the dispatcher asked why
Black Creek held the line open.
No answer was attached to the docket.

SIGNED: J. VALE / DAY DESK"""

func _update_labels() -> void:
	var result := get_node_or_null("ResultLabel") as Label3D
	var stamp := get_node_or_null("StampLabel") as Label3D
	var subtitle := get_node_or_null("SubtitleLabel") as Label3D
	if result == null or stamp == null or subtitle == null:
		return
	match _variant_id:
		VARIANT_WATER:
			result.text = "RELEASED"
			stamp.text = "MATCHED"
			subtitle.text = "TANK 4 / EASTBOUND"
		VARIANT_WATCHER:
			result.text = "MISMATCH"
			stamp.text = "CROSSED OUT"
			subtitle.text = "NO TRAIN NUMBER"
		_:
			result.text = "NO COPY"
			stamp.text = "OPEN"
			subtitle.text = "LINE HELD OPEN"

func _update_interaction() -> void:
	_resolve_nodes()
	if interactable != null:
		interactable.enabled = _revealed

func _reveal_light_color(variant_id: StringName) -> Color:
	match variant_id:
		VARIANT_WATER:
			return Color(0.91, 0.68, 0.36, 1.0)
		VARIANT_WATCHER:
			return Color(0.42, 0.55, 0.92, 1.0)
		_:
			return Color(0.74, 0.24, 0.16, 1.0)

func _on_interacted() -> void:
	if _revealed:
		_inspected = true
		evidence_inspected.emit(_document_text)

func _get_world_state() -> WorldStateStore:
	if world_state != null:
		return world_state
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		return get_tree().root.get_node_or_null("WorldState") as WorldStateStore
	var current: Node = get_parent()
	while current != null:
		var store := current.get_node_or_null("WorldState") as WorldStateStore
		if store != null:
			return store
		current = current.get_parent()
	return null
