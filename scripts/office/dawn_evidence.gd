class_name DawnEvidence
extends Node3D

## A physical morning document left behind after the last telegram.
## Elias's paper reads ONLY KnowledgeState (review §11 B11): what he filed,
## what he remembers, what he watched — never the objective world. The world
## may know more than he does; this sheet may not.

signal evidence_revealed(variant_id: StringName)
signal evidence_inspected(text: String)

@export var prompt_message: String = "Read the Night Handover"
@export var knowledge_state: KnowledgeStateStore = null

## Hook knowledge keys this paper reads. A single fact-key registry arrives
## with ROADMAP 4.4; until then they live here as named constants, guarded by
## the data-source test.
const KNOW_AMENDMENT_ENTERED: StringName = &"amendment_entered_core_hook"
const KNOW_SEALED_HEARD: StringName = &"committed_water_core_hook"
const KNOW_FILED_AS_WRITTEN: StringName = &"committed_watcher_core_hook"
const KNOW_LAPSED: StringName = &"core_hook_commit_lapsed"
const KNOW_FILED_WORD: StringName = &"filed_word_core_hook"
const KNOW_SAW_WINDOW: StringName = &"saw_window_event"

## Elias's own margin note, added only when his record says he watched the
## window during the unscheduled call. The note records the looking, never a
## confirmation — horror stays below the proof threshold (review §11 A4).
const MARGIN_HEADER: String = """


NOTE IN THE MARGIN (LATER HAND):"""
const WINDOW_MARGIN_LINE: String = """
Watched the window on the unscheduled call.
What the glass held is not written here."""
## Plan 4.7: watching the yard in the last silence (SilenceThree) is its own
## line, before the call - again the looking, never what was there.
const YARD_MARGIN_LINE: String = """
Looked out at the yard before the last call.
The yard is not this office's to enter."""

const VARIANT_WATER: StringName = &"water"
const VARIANT_WATCHER: StringName = &"watcher"
const VARIANT_LAPSED: StringName = &"lapsed"
const VARIANT_AMENDED: StringName = &"amended"

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
	var knowledge := _get_knowledge_state()
	if knowledge != null:
		# Sealing the heard copy outranks the plain amendment record: both
		# facts are learned on a true-word correction.
		if knowledge.knows(KNOW_SEALED_HEARD):
			return VARIANT_WATER
		if knowledge.knows(KNOW_AMENDMENT_ENTERED):
			return VARIANT_AMENDED
		if knowledge.knows(KNOW_FILED_AS_WRITTEN):
			return VARIANT_WATCHER
		if knowledge.knows(KNOW_LAPSED):
			return VARIANT_LAPSED
	return VARIANT_LAPSED

func _build_document(variant_id: StringName) -> String:
	var knowledge := _get_knowledge_state()
	var copy := "No copy filed. The unscheduled call remains open."
	if variant_id == VARIANT_WATER or variant_id == VARIANT_AMENDED:
		var word := knowledge.recall_value(KNOW_FILED_WORD, "") if knowledge != null else ""
		copy = "%s\n\nCorrection entered by E. Crane. The original\nworking transcript is retained beneath this copy." % word
	elif variant_id == VARIANT_WATCHER:
		copy = "WATCHER\n\nFiled as written by E. Crane. No correction\nentered. Retain the working transcript."
	var text := """BLACK CREEK STATION
HANDOVER — END OF NIGHT WATCH, APRIL 1890
────────────────────────────────

UNSCHEDULED NIGHT TRAFFIC

%s

Sender not entered in the night ledger.
No train number supplied.

Leave both sheets for the morning operator.
An entry is not a confirmation.

PREPARED: E. CRANE / NIGHT DESK""" % copy
	var saw_yard := knowledge != null and knowledge.knows(SilenceThree.KNOWLEDGE_SAW_YARD)
	var saw_window := knowledge != null and knowledge.knows(KNOW_SAW_WINDOW)
	if saw_yard or saw_window:
		text += MARGIN_HEADER
		if saw_yard:
			text += YARD_MARGIN_LINE
		if saw_window:
			text += WINDOW_MARGIN_LINE
	return text

func _update_labels() -> void:
	var result := get_node_or_null("ResultLabel") as Label3D
	var stamp := get_node_or_null("StampLabel") as Label3D
	var subtitle := get_node_or_null("SubtitleLabel") as Label3D
	if result == null or stamp == null or subtitle == null:
		return
	match _variant_id:
		VARIANT_WATER, VARIANT_AMENDED:
			var knowledge := _get_knowledge_state()
			result.text = knowledge.recall_value(KNOW_FILED_WORD, "") if knowledge != null else ""
			stamp.text = "AMENDED"
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

func _get_knowledge_state() -> KnowledgeStateStore:
	if knowledge_state != null:
		return knowledge_state
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		return get_tree().root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	var current: Node = get_parent()
	while current != null:
		var store := current.get_node_or_null("KnowledgeState") as KnowledgeStateStore
		if store != null:
			return store
		current = current.get_parent()
	return null
