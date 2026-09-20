class_name DawnEvidence
extends Node3D

## A physical morning document left behind after the last telegram.
## WorldState selects the copy actually filed during this watch; knowledge
## records whether Elias inspected it. Neither confirms the message's meaning.

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
	var copy := "No copy filed. The unscheduled call remains open."
	if variant_id == VARIANT_WATER:
		copy = "WATER\n\nCorrection entered by E. Crane. The original\nworking transcript is retained beneath this copy."
	elif variant_id == VARIANT_WATCHER:
		copy = "WATCHER\n\nFiled as written by E. Crane. No correction\nentered. Retain the working transcript."
	return """BLACK CREEK STATION
HANDOVER — END OF NIGHT WATCH, APRIL 1894
────────────────────────────────

UNSCHEDULED NIGHT TRAFFIC

%s

Sender not entered in the night ledger.
No train number supplied.

Leave both sheets for the morning operator.
An entry is not a confirmation.

PREPARED: E. CRANE / NIGHT DESK""" % copy

func _update_labels() -> void:
	var result := get_node_or_null("ResultLabel") as Label3D
	var stamp := get_node_or_null("StampLabel") as Label3D
	var subtitle := get_node_or_null("SubtitleLabel") as Label3D
	if result == null or stamp == null or subtitle == null:
		return
	match _variant_id:
		VARIANT_WATER:
			result.text = "WATER"
			stamp.text = "CORRECTED"
			subtitle.text = "NIGHT COPY / RETAIN"
		VARIANT_WATCHER:
			result.text = "WATCHER"
			stamp.text = "AS WRITTEN"
			subtitle.text = "NO TRAIN NUMBER"
		_:
			result.text = "NO COPY"
			stamp.text = "OPEN"
			subtitle.text = "LINE HELD OPEN"

func _update_interaction() -> void:
	_resolve_nodes()
	if interactable != null:
		interactable.enabled = _revealed

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
