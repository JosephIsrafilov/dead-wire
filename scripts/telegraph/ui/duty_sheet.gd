class_name DutySheet
extends Node3D

## The operator's own paperwork, pinned by the south door.
##
## This is the game's only goal surface. There is no HUD, no quest log, and no
## marker: to find out what the shift expects of you, you walk away from the desk
## and read a piece of paper — which is itself an attention commitment.
##
## The sheet is written from KnowledgeState alone. It reports what Elias believes
## he did, never what actually happened. A message he never copied leaves a gap
## here even though the world recorded a consequence for it.

signal sheet_inspected(text: String)

@export var prompt_message: String = "Read Duty Sheet"
@export var office: M1OfficeController = null

## Traffic the station booked in advance, in slot order. Anything arriving beyond
## this list is unscheduled and is not printed until Elias has actually copied it.
@export var scheduled_labels: PackedStringArray = PackedStringArray([
	"TRAIN 17 — PASSENGER",
	"NIGHT FREIGHT — UNVERIFIED"
])

const HEADER: String = """BLACK CREEK STATION
NIGHT SHIFT, APRIL 1894 — 11 P.M. TO 6 A.M.
OPERATOR: E. CRANE
============================================

STANDING ORDERS

  1. Keep your chair. The key is worked seated; step
     away from it and walk to rise.
  2. Answer the office call (CR) on the key. Do not
     leave the wire calling.
  3. Copy each message as received. Copy nothing you
     did not hear.
  4. Set the route on the East Wall board before the
     sender releases the line.
  5. Routing rules are in the Dispatch Ledger.
  6. The outer door stays locked until the line closes.

--------------------------------------------
TONIGHT'S TRAFFIC
"""

const FOOTER: String = """
--------------------------------------------
This sheet records what you know.
It does not record what happened."""

const FOOTER_INCOMPLETE: String = """
--------------------------------------------
Not every item on this sheet is closed.
This sheet records what you know.
It does not record what happened."""

const STATUS_AWAITING: String = "AWAITING"
const STATUS_COPIED: String = "COPIED"
const STATUS_FILED: String = "COPIED / FILED"
const STATUS_NO_COPY: String = "NO COPY"
const STATUS_LAPSED: String = "NO ORDER SENT"

## Core-hook outcomes are deliberately phrased as Elias's paperwork, not as a
## replay of the wire. The lookup table keeps this surface data-driven: adding
## another knowledge-backed outcome does not require a second branch in the
## sheet renderer.
const STATUS_CORE_HOOK_WATER: String = "HEARD COPY SEALED"
const STATUS_CORE_HOOK_WATCHER: String = "WRITTEN COPY SEALED"
const STATUS_CORE_HOOK_LAPSED: String = "UNFILED"
const CORE_HOOK_OUTCOME_LABEL: String = "CORE HOOK RECORD"
const CORE_HOOK_OUTCOME_BY_FACT: Dictionary = {
	&"committed_water_core_hook": STATUS_CORE_HOOK_WATER,
	&"committed_watcher_core_hook": STATUS_CORE_HOOK_WATCHER,
	&"core_hook_commit_lapsed": STATUS_CORE_HOOK_LAPSED,
}

var interactable: Interactable = null

func _ready() -> void:
	if office == null:
		office = get_parent() as M1OfficeController

	interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		interactable.prompt_text = prompt_message
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null and not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)
	return interactable

func get_sheet_text() -> String:
	var lines := PackedStringArray()
	var scenarios := _scenarios()
	var unscheduled := PackedStringArray()

	for index in scenarios.size():
		var status := get_status_for(scenarios[index])
		if index < scheduled_labels.size():
			lines.append("  %d. %s" % [index + 1, _pad_status(scheduled_labels[index], status)])
		elif status != STATUS_AWAITING:
			# Unbooked traffic only exists on paper once it has been heard.
			unscheduled.append("  *  %s" % _pad_status("UNSCHEDULED TRAFFIC", status))

	if lines.is_empty():
		lines.append("  (no traffic booked)")

	var body := "\n".join(lines)
	if not unscheduled.is_empty():
		body += "\n\n" + "\n".join(unscheduled)
	var core_hook_status := get_core_hook_outcome_status()
	if not core_hook_status.is_empty():
		body += "\n\n" + _pad_status(CORE_HOOK_OUTCOME_LABEL, core_hook_status)
	return HEADER + body + (FOOTER_INCOMPLETE if _has_open_items() else FOOTER)

## Returns the terminal core-hook record Elias knows about, if any. This
## method intentionally never consults WorldState: the sheet can only show a
## consequence after the corresponding KnowledgeState fact has been learned.
func get_core_hook_outcome_status() -> String:
	var knowledge := _knowledge_state()
	if knowledge == null:
		return ""
	for fact_id in CORE_HOOK_OUTCOME_BY_FACT:
		if knowledge.knows(fact_id):
			return String(CORE_HOOK_OUTCOME_BY_FACT[fact_id])
	return ""

## Elias can see a gap in his own paperwork. He cannot see what it cost — that
## stays in WorldState, and the only thing that ever reports it is the wire.
func _has_open_items() -> bool:
	var scenarios := _scenarios()
	for index in scenarios.size():
		if index >= scheduled_labels.size():
			continue
		if get_status_for(scenarios[index]) != STATUS_FILED:
			return true
	return false

## Status is read from KnowledgeState only. WorldState is never consulted here.
func get_status_for(scenario: TelegraphScenarioData) -> String:
	if scenario == null:
		return STATUS_AWAITING
	var knowledge := _knowledge_state()
	if knowledge == null:
		return STATUS_AWAITING

	var identifier := scenario.scenario_id
	if knowledge.knows(StringName("filed_%s" % identifier)):
		return STATUS_FILED
	if knowledge.knows(StringName("lapsed_%s" % identifier)):
		return STATUS_LAPSED
	if knowledge.knows(StringName("copied_%s" % identifier)):
		return STATUS_COPIED
	if knowledge.knows(StringName("missed_call_%s" % identifier)):
		return STATUS_NO_COPY
	return STATUS_AWAITING

static func _pad_status(label: String, status: String) -> String:
	var width := 30
	var dots := maxi(2, width - label.length())
	return "%s %s %s" % [label, ".".repeat(dots), status]

func _scenarios() -> Array[TelegraphScenarioData]:
	if office == null:
		return [] as Array[TelegraphScenarioData]
	return office.get_scenario_list()

func _knowledge_state() -> KnowledgeStateStore:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			var store := tree.root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
			if store != null:
				return store
	var current: Node = get_parent()
	while current != null:
		var store := current.get_node_or_null("KnowledgeState") as KnowledgeStateStore
		if store != null:
			return store
		current = current.get_parent()
	return null

func _on_interacted() -> void:
	sheet_inspected.emit(get_sheet_text())
