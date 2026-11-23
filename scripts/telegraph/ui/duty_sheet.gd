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

@export var prompt_message: String = "Read Night Orders"
@export var office: M1OfficeController = null

## Traffic the station booked in advance, in slot order. Anything arriving beyond
## this list is unscheduled and is not printed until Elias has actually copied it.
@export var scheduled_labels: PackedStringArray = PackedStringArray([
	"TRAIN 17 — PASSENGER",
	"NIGHT FREIGHT — UNVERIFIED"
])

const HEADER: String = """BLACK CREEK STATION — NIGHT SHIFT, APRIL 1890 (11 P.M.–6 A.M.)
OPERATOR: E. CRANE
────────────────────────────────

STANDING ORDERS
  1. Open the line on the brass key; answer on the same key.
  2. Read each finished sheet, then set the signal lever (left).
  3. Stamp & file every copy at the filing desk (right).
  4. Compare the wire tape register against your sheet when needed.
  5. Read the night handover before leaving through the south door.

────────────────────────────────
TONIGHT'S TRAFFIC
"""

const HEADER_RU: String = """СТАНЦИЯ БЛЭК-КРИК — НОЧНАЯ СМЕНА, АПРЕЛЬ 1890 (23:00–06:00)
ТЕЛЕГРАФИСТ: Э. КРЕЙН
────────────────────────────────

ПОРЯДОК СЛУЖБЫ
  1. Откройте линию и отвечайте на вызов телеграфным ключом.
  2. Прочтите готовый лист и переведите рычаг сигнала (слева).
  3. Поставьте печать и подшейте копию на столе подшивки (справа).
  4. При сомнении сверьте свою запись с телеграфной лентой у ключа.
  5. Перед уходом прочтите передачу смены у южной двери.

────────────────────────────────
ТРАФИК НА ЭТУ НОЧЬ
"""

const FOOTER: String = """
────────────────────────────────
Entries made by E. Crane. Retain station copies."""

const FOOTER_INCOMPLETE: String = """
────────────────────────────────
Not every item on this sheet is closed.
Entries made by E. Crane. Retain station copies."""

const FOOTER_RU: String = """
────────────────────────────────
Записи вёл Э. Крейн. Хранить для утренней сверки."""

const FOOTER_INCOMPLETE_RU: String = """
────────────────────────────────
Не все пункты смены закрыты.
Записи вёл Э. Крейн. Хранить для утренней сверки."""

const STATUS_AWAITING: String = "AWAITING"
const STATUS_COPIED: String = "COPIED"
const STATUS_FILED: String = "COPIED / FILED"
const STATUS_NO_COPY: String = "NO COPY"
const STATUS_LAPSED: String = "NO ORDER SENT"
const STATUS_INCOMPLETE: String = "COPY INCOMPLETE"

## Core-hook outcomes are deliberately phrased as Elias's paperwork, not as a
## replay of the wire. The lookup table keeps this surface data-driven: adding
## another knowledge-backed outcome does not require a second branch in the
## sheet renderer.
const STATUS_CORE_HOOK_WATER: String = "HEARD COPY SEALED"
const STATUS_CORE_HOOK_AMENDED: String = "AMENDED COPY SEALED"
const STATUS_CORE_HOOK_WATCHER: String = "WRITTEN COPY SEALED"
const STATUS_CORE_HOOK_LAPSED: String = "UNFILED"
const CORE_HOOK_OUTCOME_LABEL: String = "UNSCHEDULED COPY"
const CORE_HOOK_OUTCOME_BY_FACT: Dictionary = {
	&"amendment_entered_core_hook": STATUS_CORE_HOOK_AMENDED,
	&"committed_water_core_hook": STATUS_CORE_HOOK_WATER,
	&"committed_watcher_core_hook": STATUS_CORE_HOOK_WATCHER,
	&"core_hook_commit_lapsed": STATUS_CORE_HOOK_LAPSED,
}

const STATUS_RU_MAP: Dictionary = {
	STATUS_AWAITING: "ОЖИДАЕТСЯ",
	STATUS_COPIED: "ЗАПИСАНО",
	STATUS_FILED: "ПОДШИТО",
	STATUS_NO_COPY: "НЕТ КОПИИ",
	STATUS_LAPSED: "БЕЗ ПРИКАЗА",
	STATUS_INCOMPLETE: "НЕ ДОПИСАНО",
	STATUS_CORE_HOOK_WATER: "СЛЫШАННОЕ ПОДШИТО",
	STATUS_CORE_HOOK_AMENDED: "ПРАВКА ПОДШИТА",
	STATUS_CORE_HOOK_WATCHER: "ЗАПИСАННОЕ ПОДШИТО",
	STATUS_CORE_HOOK_LAPSED: "НЕ ПОДШИТО",
}

static func display_status(status: String) -> String:
	if GameLocale.is_ru() and STATUS_RU_MAP.has(status):
		return String(STATUS_RU_MAP[status])
	return status

var interactable: Interactable = null

func _ready() -> void:
	if office == null:
		office = get_parent() as M1OfficeController

	interactable = get_node_or_null("Interactable") as Interactable
	refresh_locale()
	if interactable != null and not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)

func refresh_locale() -> void:
	if interactable != null:
		interactable.prompt_text = GameLocale.pick("Ночной наряд", prompt_message)

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
	var ru_labels: Array[String] = ["ПОЕЗД 17 — ПАССАЖИРСКИЙ", "НОЧНОЙ ТОВАРНЫЙ — БЕЗ РАЗРЕШ."]

	for index in scenarios.size():
		var status := get_status_for(scenarios[index])
		if index < scheduled_labels.size():
			var row_label: String = ru_labels[index] if (GameLocale.is_ru() and index < ru_labels.size()) \
				else scheduled_labels[index]
			lines.append("  %d. %s" % [index + 1, _pad_status(row_label, display_status(status))])
		elif status != STATUS_AWAITING:
			# Unbooked traffic only exists on paper once it has been heard.
			unscheduled.append("  *  %s" % _pad_status(
				GameLocale.pick("ВНЕПЛАНОВАЯ ПЕРЕДАЧА", "UNSCHEDULED TRAFFIC"),
				display_status(status)
			))

	if lines.is_empty():
		lines.append(GameLocale.pick("  (передач не назначено)", "  (no traffic booked)"))

	var body := "\n".join(lines)
	if not unscheduled.is_empty():
		body += "\n\n" + "\n".join(unscheduled)
	var core_hook_status := get_core_hook_outcome_status()
	if not core_hook_status.is_empty():
		body += "\n\n" + _pad_status(
			GameLocale.pick("ВНЕПЛАНОВАЯ КОПИЯ", CORE_HOOK_OUTCOME_LABEL),
			display_status(core_hook_status)
		)
		var knowledge := _knowledge_state()
		var word := knowledge.recall_value(&"filed_word_core_hook", "") if knowledge != null else ""
		if not word.is_empty():
			body += GameLocale.pick("\n  ПОДШИТОЕ СЛОВО: ", "\n  FILED WORD: ") + word
	var hdr := HEADER_RU if GameLocale.is_ru() else HEADER
	var ftr := (FOOTER_INCOMPLETE_RU if GameLocale.is_ru() else FOOTER_INCOMPLETE) if _has_open_items() \
		else (FOOTER_RU if GameLocale.is_ru() else FOOTER)
	return hdr + body + ftr

func get_watch_record() -> String:
	var title := GameLocale.pick(
		"СТАНЦИЯ БЛЭК-КРИК\nНОЧНОЙ РЕГИСТР — Э. КРЕЙН\n\n",
		"BLACK CREEK STATION\nNIGHT REGISTER — E. CRANE\n\n"
	)
	var hdr := HEADER_RU if GameLocale.is_ru() else HEADER
	return title + get_sheet_text().substr(hdr.length())

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
## The vocabulary itself is shared with the dispatch ledger: one paperwork
## tradition, not two diverging condition trees (plan §7.1).
func get_status_for(scenario: TelegraphScenarioData) -> String:
	if scenario == null:
		return STATUS_AWAITING
	return knowledge_status(scenario.scenario_id, _knowledge_state())

## The one knowledge-backed status computation the whole night's paperwork
## shares. Filed beats lapsed beats incomplete, so a sheet that closed with ink
## missing reads as the terminal outcome it ended on.
static func knowledge_status(identifier: String, knowledge: KnowledgeStateStore) -> String:
	if identifier.is_empty() or knowledge == null:
		return STATUS_AWAITING
	if knowledge.knows(StringName("filed_%s" % identifier)):
		return STATUS_FILED
	if knowledge.knows(StringName("lapsed_%s" % identifier)):
		return STATUS_LAPSED
	if knowledge.knows(StringName("incomplete_copy_%s" % identifier)):
		return STATUS_INCOMPLETE
	if knowledge.knows(StringName("copied_%s" % identifier)):
		return STATUS_COPIED
	if knowledge.knows(StringName("missed_call_%s" % identifier)):
		return STATUS_NO_COPY
	return STATUS_AWAITING

## Returns the terminal core-hook outcome Elias knows about, if any. This
## computation intentionally never consults WorldState: paperwork can only
## show a consequence after the corresponding KnowledgeState fact is learned.
## Shared with the dispatch ledger for the same reason.
func get_core_hook_outcome_status() -> String:
	return core_hook_outcome(_knowledge_state())

static func core_hook_outcome(knowledge: KnowledgeStateStore) -> String:
	if knowledge == null:
		return ""
	for fact_id in CORE_HOOK_OUTCOME_BY_FACT:
		if knowledge.knows(fact_id):
			return String(CORE_HOOK_OUTCOME_BY_FACT[fact_id])
	return ""

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
