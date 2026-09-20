class_name DispatchLedger
extends Node3D

signal ledger_inspected(text: String)
signal ledger_closed()

@export var prompt_message: String = "Inspect Dispatch Ledger"
## The office wires this so entries come from the shift's own record, not a
## private copy of state. Without wiring the ledger shows standing orders only.
@export var office: M1OfficeController = null
## Scene wiring alternative when the office is a sibling.
@export var office_path: NodePath = ^""

const LEDGER_TEXT: String = """BLACK CREEK STATION — DISPATCH LEDGER (APRIL 1894)
──────────────────────────────────────────────────
SPECIAL ORDERS & ROUTING RULES:

1. SCHEDULED PASSENGER (TRAIN 17):
   - Priority route: CLEAR EAST immediately.
   - Do NOT hold on siding track unless express obstruction reported.

2. UNVERIFIED NIGHT FREIGHT:
   - Rule 44: HOLD all unscheduled freight pending mine superintendent check.
   - Water supply & mine junction cars remain restricted under 1889 quarantine."""

var interactable: Interactable = null
var label_3d: Label3D = null

func _ready() -> void:
	if office == null and not office_path.is_empty():
		office = get_node_or_null(office_path) as M1OfficeController
	interactable = get_node_or_null("Interactable") as Interactable
	label_3d = get_node_or_null("Label3D") as Label3D

	if interactable != null:
		interactable.prompt_text = prompt_message
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	if label_3d != null:
		label_3d.text = "DISPATCH LEDGER\nBLACK CREEK"

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	return interactable

func get_ledger_text() -> String:
	return LEDGER_TEXT + "\n\n" + _night_entries_text()

## Entries the operator actually made tonight, read from the shift's own
## knowledge record. WorldState is deliberately not consulted: the ledger is
## Elias's paperwork, not the objective world. Statuses come from the same
## knowledge-backed vocabulary the duty sheet uses (plan §7.1), and anything
## the record does not know is shown as unknown — never invented.
func _night_entries_text() -> String:
	var knowledge := _knowledge_state()
	if knowledge == null or office == null:
		return ""
	var scenarios: Array[TelegraphScenarioData] = office.get_scenario_list()
	if scenarios.is_empty():
		return ""
	var lines: PackedStringArray = ["NIGHT ENTRIES — %s" % NIGHT_ENTRIES_DATE]
	var any_entry := false
	for index in scenarios.size():
		var scenario := scenarios[index]
		if scenario == null:
			continue
		var entry := _entry_for(scenario, knowledge, index, _scheduled_count(scenarios))
		if not entry.is_empty():
			lines.append(entry)
			any_entry = true
	if not any_entry:
		lines.append("  (no traffic handled)")
	return "\n".join(lines)

## Booked traffic for the night. Mirrors the duty sheet's own split: booked
## rows are numbered, anything beyond them is unscheduled and only appears
## once the night actually produced a record for it.
func _scheduled_count(scenarios: Array[TelegraphScenarioData]) -> int:
	return maxi(scenarios.size() - 1, 0) if scenarios.size() >= 1 else 0

func _entry_for(
	scenario: TelegraphScenarioData, knowledge: KnowledgeStateStore,
	index: int, scheduled_count: int
) -> String:
	var identifier := scenario.scenario_id
	if identifier.is_empty():
		return ""
	var status := DutySheet.knowledge_status(identifier, knowledge)
	var is_unscheduled := index >= scheduled_count
	var incomplete: bool = knowledge.knows(StringName("incomplete_copy_%s" % identifier))
	# A terminal commit outcome (sealed or unfiled copy) is itself the night's
	# record for an unscheduled message: it must not wait for a copied_ fact
	# that a non-directed test night never teaches.
	var commit_outcome := "" if scenario.requires_routing else DutySheet.core_hook_outcome(knowledge)
	if status == DutySheet.STATUS_AWAITING and is_unscheduled and commit_outcome.is_empty():
		# Unbooked traffic only exists on paper once the night says so.
		return ""
	if status == DutySheet.STATUS_AWAITING and commit_outcome.is_empty():
		# One row per booked slot: the label is known in advance, the entry
		# honestly says nothing has been recorded yet.
		return _pad_entry(_label_for(scenario, is_unscheduled), DutySheet.STATUS_AWAITING, true)

	var outcome := ""
	if not scenario.requires_routing:
		# The commit desk's outcomes are Elias's own sealed copies.
		if not commit_outcome.is_empty():
			if incomplete and commit_outcome == DutySheet.STATUS_CORE_HOOK_LAPSED:
				outcome = "COPY INCOMPLETE / UNFILED"
			else:
				outcome = commit_outcome
		elif incomplete:
			outcome = "COPY INCOMPLETE"
		elif status == DutySheet.STATUS_COPIED:
			outcome = "COPIED"
		elif status == DutySheet.STATUS_NO_COPY:
			outcome = "NO COPY"
	else:
		match status:
			DutySheet.STATUS_FILED:
				# The journal records what was actually sent. If the record
				# does not say which way the lever went, it says nothing.
				outcome = "COPIED / FILED" if knowledge.knows(StringName("copied_%s" % identifier)) else "FILED"
				var action := _route_action(identifier, knowledge)
				if not action.is_empty():
					outcome += "    %s" % action
			DutySheet.STATUS_LAPSED:
				outcome = "COPY INCOMPLETE / NO ORDER SENT" if incomplete else "NO ORDER SENT"
			DutySheet.STATUS_INCOMPLETE:
				outcome = "COPY INCOMPLETE"
			DutySheet.STATUS_COPIED:
				outcome = "COPIED"
			DutySheet.STATUS_NO_COPY:
				outcome = "NO COPY"
	if outcome.is_empty():
		return ""
	return _pad_entry(_label_for(scenario, is_unscheduled), outcome, true)

## The route that actually went out, or nothing. "Filed" without a route fact
## stays directionless: absence of knowledge is not HOLD.
func _route_action(identifier: String, knowledge: KnowledgeStateStore) -> String:
	if knowledge.knows(StringName("route_clear_east_%s" % identifier)):
		return "CLEAR EAST"
	if knowledge.knows(StringName("route_hold_%s" % identifier)):
		return "HOLD"
	return ""

func _label_for(scenario: TelegraphScenarioData, is_unscheduled: bool) -> String:
	if is_unscheduled:
		return "UNSCHEDULED"
	match scenario.scenario_id:
		"baseline_train_17": return "TRAIN 17"
		"attention_hold_freight": return "NIGHT FREIGHT"
	return "TRAFFIC"

## The header date matches every other document of the night: the setting
## fixes the month and year, and no document anywhere names a day.
const NIGHT_ENTRIES_DATE: String = "APRIL 1894"

static func _pad_entry(label: String, status: String, _with_status: bool = true) -> String:
	var width := 34
	var dots := maxi(2, width - label.length())
	return "  %s %s %s" % [label, ".".repeat(dots), status]

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
	ledger_inspected.emit(get_ledger_text())
