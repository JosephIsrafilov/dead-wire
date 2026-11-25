class_name CampaignStateStore
extends Node

## Persistent day/night progression, 1890 integer-cent economy, saloon tokens,
## intoxication state, and JSON disk persistence across Night <-> Dawn <-> Town.
## WorldState (objective reality) and KnowledgeState (Elias's memory) remain
## strictly separate stores.

signal phase_changed(new_phase: StringName)
signal wallet_changed(wallet_cents: int)
signal state_reset

const PHASE_NIGHT_APPROACH := &"NIGHT_APPROACH"
const PHASE_NIGHT := &"NIGHT"
const PHASE_DAWN_WALK := &"DAWN_WALK"
const PHASE_DAY_TOWN := &"DAY_TOWN"
const PHASE_DUSK := &"DUSK_APPROACH"
const PHASE_TRIAL := &"TRIAL"

const DEFAULT_SAVE_PATH := "user://dead_wire_campaign.json"
const STARTING_WALLET_CENTS: int = 250
const BASE_SHIFT_WAGE_CENTS: int = 200
const CLEAN_SHIFT_BONUS_CENTS: int = 50
const CITATION_PENALTY_CENTS: int = 25
const MIN_SHIFT_WAGE_CENTS: int = 100
const MAX_SHIFT_WAGE_CENTS: int = 250

var day_index: int = 1
var phase: StringName = PHASE_NIGHT
var wallet_cents: int = STARTING_WALLET_CENTS
var last_shift_wage_cents: int = 0
var saloon_tokens: int = 0
var intoxication_level: float = 0.0
var bartender_rapport: int = 0
var npc_trust: Dictionary = {}
var pocket_items: Array[StringName] = []
var pending_spawn_point: StringName = &"depot_south"
var slept_after_shift: bool = false
var washed_face_today: bool = false

func reset_for_new_game() -> void:
	day_index = 1
	phase = PHASE_NIGHT
	wallet_cents = STARTING_WALLET_CENTS
	last_shift_wage_cents = 0
	saloon_tokens = 0
	intoxication_level = 0.0
	bartender_rapport = 0
	npc_trust.clear()
	pocket_items.clear()
	pending_spawn_point = &"depot_south"
	slept_after_shift = false
	washed_face_today = false
	state_reset.emit()

func compute_shift_wage(world: WorldStateStore) -> int:
	if world == null:
		return BASE_SHIFT_WAGE_CENTS
	var wage := BASE_SHIFT_WAGE_CENTS
	var clean_t17 := bool(world.get_fact(&"train_17_routed_clear", false)) \
		and not bool(world.get_fact(&"train_17_copy_unfiled", false))
	var clean_f71 := bool(world.get_fact(&"freight_held_correctly", false)) \
		and not bool(world.get_fact(&"freight_copy_unfiled", false))
	if clean_t17 and clean_f71:
		wage += CLEAN_SHIFT_BONUS_CENTS
	for fault_fact in [
		&"train_17_held_in_error",
		&"train_17_no_order_sent",
		&"freight_cleared_in_error",
		&"freight_no_order_sent",
		&"train_17_copy_unfiled",
		&"freight_copy_unfiled",
	]:
		if bool(world.get_fact(fault_fact, false)):
			wage -= CITATION_PENALTY_CENTS
	return clampi(wage, MIN_SHIFT_WAGE_CENTS, MAX_SHIFT_WAGE_CENTS)

func begin_dawn_from_shift(
	world: WorldStateStore,
	knowledge: KnowledgeStateStore,
	save_path: String = DEFAULT_SAVE_PATH
) -> int:
	var wage := compute_shift_wage(world)
	last_shift_wage_cents = wage
	wallet_cents += wage
	phase = PHASE_DAWN_WALK
	pending_spawn_point = &"depot_south"
	slept_after_shift = false
	washed_face_today = false
	wallet_changed.emit(wallet_cents)
	phase_changed.emit(phase)
	if not save_path.is_empty():
		save_to_disk(world, knowledge, save_path)
	return wage

func complete_sleep_to_day(
	world: WorldStateStore = null,
	knowledge: KnowledgeStateStore = null,
	save_path: String = DEFAULT_SAVE_PATH
) -> void:
	phase = PHASE_DAY_TOWN
	slept_after_shift = true
	intoxication_level = 0.0
	pending_spawn_point = &"boarding_house_porch"
	phase_changed.emit(phase)
	if not save_path.is_empty():
		save_to_disk(world, knowledge, save_path)

func adjust_wallet(delta_cents: int) -> bool:
	if wallet_cents + delta_cents < 0:
		return false
	wallet_cents += delta_cents
	wallet_changed.emit(wallet_cents)
	return true

func add_pocket_item(item_id: StringName) -> void:
	if item_id.is_empty() or item_id in pocket_items:
		return
	pocket_items.append(item_id)

func has_pocket_item(item_id: StringName) -> bool:
	return item_id in pocket_items

static func format_cents(cents: int) -> String:
	var neg := cents < 0
	var abs_cents := absi(cents)
	var prefix := "-" if neg else ""
	if abs_cents >= 100:
		return "%s$%d.%02d" % [prefix, abs_cents / 100, abs_cents % 100]
	return "%s%d¢" % [prefix, abs_cents]

func save_to_disk(
	world: WorldStateStore,
	knowledge: KnowledgeStateStore,
	save_path: String = DEFAULT_SAVE_PATH
) -> Error:
	var world_dict: Dictionary = {}
	if world != null:
		for key in world.snapshot():
			world_dict[String(key)] = world.get_fact(key)
	var known_facts: Array[String] = []
	var known_values: Dictionary = {}
	if knowledge != null:
		for key in knowledge.snapshot():
			known_facts.append(String(key))
		for key in knowledge.value_snapshot():
			known_values[String(key)] = knowledge.recall_value(key)
	var trust_out: Dictionary = {}
	for key in npc_trust:
		trust_out[String(key)] = int(npc_trust[key])
	var items_out: Array[String] = []
	for item_id in pocket_items:
		items_out.append(String(item_id))
	var payload := {
		"version": 1,
		"campaign": {
			"day_index": day_index,
			"phase": String(phase),
			"wallet_cents": wallet_cents,
			"last_shift_wage_cents": last_shift_wage_cents,
			"saloon_tokens": saloon_tokens,
			"intoxication_level": intoxication_level,
			"bartender_rapport": bartender_rapport,
			"npc_trust": trust_out,
			"pocket_items": items_out,
			"pending_spawn_point": String(pending_spawn_point),
			"slept_after_shift": slept_after_shift,
			"washed_face_today": washed_face_today,
		},
		"world_facts": world_dict,
		"known_facts": known_facts,
		"known_values": known_values,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return OK

func load_from_disk(
	world: WorldStateStore,
	knowledge: KnowledgeStateStore,
	save_path: String = DEFAULT_SAVE_PATH
) -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var raw := FileAccess.get_file_as_string(save_path)
	if raw.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return false
	var root_dict: Dictionary = parsed
	reset_for_new_game()
	if world != null:
		world.reset_for_new_game()
		var wf: Dictionary = root_dict.get("world_facts", {})
		for k in wf:
			world.set_fact(StringName(String(k)), wf[k])
	if knowledge != null:
		knowledge.reset_for_new_game()
		for k in root_dict.get("known_facts", []):
			knowledge.learn(StringName(String(k)))
		var kv: Dictionary = root_dict.get("known_values", {})
		for k in kv:
			knowledge.remember_value(StringName(String(k)), String(kv[k]))
	var camp: Dictionary = root_dict.get("campaign", {})
	day_index = int(camp.get("day_index", 1))
	phase = StringName(String(camp.get("phase", String(PHASE_NIGHT))))
	wallet_cents = int(camp.get("wallet_cents", STARTING_WALLET_CENTS))
	last_shift_wage_cents = int(camp.get("last_shift_wage_cents", 0))
	saloon_tokens = int(camp.get("saloon_tokens", 0))
	intoxication_level = float(camp.get("intoxication_level", 0.0))
	bartender_rapport = int(camp.get("bartender_rapport", 0))
	var trust_in: Dictionary = camp.get("npc_trust", {})
	for k in trust_in:
		npc_trust[StringName(String(k))] = int(trust_in[k])
	for item_str in camp.get("pocket_items", []):
		pocket_items.append(StringName(String(item_str)))
	pending_spawn_point = StringName(String(camp.get("pending_spawn_point", "depot_south")))
	slept_after_shift = bool(camp.get("slept_after_shift", false))
	washed_face_today = bool(camp.get("washed_face_today", false))
	wallet_changed.emit(wallet_cents)
	phase_changed.emit(phase)
	return true

static func has_saved_campaign(save_path: String = DEFAULT_SAVE_PATH) -> bool:
	return FileAccess.file_exists(save_path)
