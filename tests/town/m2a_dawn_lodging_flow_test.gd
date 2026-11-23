extends SceneTree
## Protects the M2-A Night -> Dawn Walk -> Boarding House -> Sleep -> Sunny Day
## contract, wage math, CampaignState JSON round-trip, and KnowledgeState-only
## isolation of Elias's Case Notebook.
##   godot --headless --audio-driver Dummy --path . --script tests/town/m2a_dawn_lodging_flow_test.gd

var _passed := 0
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, desc: String) -> void:
	if ok:
		print("  PASS: " + desc)
		_passed += 1
	else:
		print("  FAIL: " + desc)
		_failed += 1

func _ensure_autoloads() -> Dictionary:
	var world := root.get_node_or_null("WorldState") as WorldStateStore
	if world == null:
		world = WorldStateStore.new()
		world.name = "WorldState"
		root.add_child(world)
	var knowledge := root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge == null:
		knowledge = KnowledgeStateStore.new()
		knowledge.name = "KnowledgeState"
		root.add_child(knowledge)
	var campaign := root.get_node_or_null("CampaignState") as CampaignStateStore
	if campaign == null:
		campaign = CampaignStateStore.new()
		campaign.name = "CampaignState"
		root.add_child(campaign)
	return {"world": world, "knowledge": knowledge, "campaign": campaign}

func _run() -> void:
	var stores := _ensure_autoloads()
	var world: WorldStateStore = stores["world"]
	var knowledge: KnowledgeStateStore = stores["knowledge"]
	var campaign: CampaignStateStore = stores["campaign"]
	var test_save := "user://m2a_test_save.json"
	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))

	# 1. Wage calculation & cent formatting
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	campaign.reset_for_new_game()
	world.set_fact(&"train_17_routed_clear", true)
	world.set_fact(&"freight_held_correctly", true)
	_check(campaign.compute_shift_wage(world) == 250, "Clean shift earns $2.50 (base $2.00 + $0.50 bonus)")
	_check(CampaignStateStore.format_cents(250) == "$2.50", "format_cents renders dollars & cents")
	_check(CampaignStateStore.format_cents(25) == "25¢", "format_cents renders sub-dollar cents")

	world.reset_for_new_game()
	world.set_fact(&"train_17_held_in_error", true)
	world.set_fact(&"freight_copy_unfiled", true)
	_check(campaign.compute_shift_wage(world) == 150, "Two citations deduct $0.50 from $2.00 base")

	# 2. begin_dawn_from_shift preserves WorldState/KnowledgeState and writes JSON round-trip
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	campaign.reset_for_new_game()
	world.set_fact(&"train_17_routed_clear", true)
	world.set_fact(&"secret_world_only_fact", "OBJECTIVE_ONLY_LEAK_GUARD")
	knowledge.learn(&"committed_water_core_hook")
	knowledge.learn(&"saw_window_event")
	knowledge.remember_value(&"filed_word_core_hook", "WATER")
	knowledge.remember_value(&"signed_on_at", "11:42 PM")

	var earned := campaign.begin_dawn_from_shift(world, knowledge, test_save)
	_check(earned == 200 and campaign.wallet_cents == 450, "Standard shift adds $2.00 to starting $2.50")
	_check(campaign.phase == CampaignStateStore.PHASE_DAWN_WALK, "Phase advances to DAWN_WALK")
	_check(campaign.pending_spawn_point == &"depot_south", "Dawn spawn defaults to depot_south")

	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	campaign.reset_for_new_game()
	_check(campaign.load_from_disk(world, knowledge, test_save), "CampaignState loads saved JSON cleanly")
	_check(campaign.wallet_cents == 450 and world.get_fact(&"train_17_routed_clear", false) == true,
		"JSON round-trip restores wallet and WorldState facts")
	_check(knowledge.recall_value(&"filed_word_core_hook", "") == "WATER",
		"JSON round-trip restores KnowledgeState remembered values")

	# 3. Dawn thoughts react to KnowledgeState in RU & EN
	GameLocale.lock_language_for_test("ru")
	var ru_thoughts := DawnWalkThoughts.build_dawn_thoughts(knowledge, campaign)
	_check(ru_thoughts.size() == 3 and ru_thoughts[0].contains("ленте") and ru_thoughts[1].contains("фонаря"),
		"RU dawn thoughts reflect tape verification and window figure without plot exposition")
	GameLocale.lock_language_for_test("en")
	var en_thoughts := DawnWalkThoughts.build_dawn_thoughts(knowledge, campaign)
	_check(en_thoughts.size() == 3 and en_thoughts[0].contains("tape") and en_thoughts[1].contains("lantern"),
		"EN dawn thoughts match RU parity")
	GameLocale.lock_language_for_test("ru")

	# 4. BlackCreekExterior in DAWN_WALK spawns at depot_south and configures DAWN lighting
	var town_scene := load("res://scenes/town/black_creek_exterior.tscn") as PackedScene
	var town := town_scene.instantiate() as BlackCreekExteriorController
	town.enable_psx_rendering = false
	root.add_child(town)
	await process_frame
	await process_frame

	_check(town.time_of_day != null and town.time_of_day.current_preset == TownTimeOfDay.PRESET_DAWN,
		"BlackCreekExterior opens in DAWN preset when phase == DAWN_WALK")
	_check(town.player.global_position.distance_to(Vector3(0.0, 0.30, 3.0)) < 0.25,
		"Player spawns on Depot south platform at depot_south")
	_check(town.builder.get_town_interactable(&"boarding_door") != null
		and town.builder.get_town_interactable(&"saloon_door") != null
		and town.builder.get_town_interactable(&"mj_gate") != null,
		"Exterior builds boarding door, saloon door, and MJ gate interactables")
	_check(town.builder.get_town_interactable(&"boarding_door").prompt_text.contains("пансион"),
		"Boarding door prompt localizes to Russian")
	town.queue_free()
	await process_frame

	# 5. BoardingHouseRoom Case Notebook reads ONLY KnowledgeState (never WorldState)
	var room_scene := load("res://scenes/town/interiors/boarding_house_room.tscn") as PackedScene
	var room := room_scene.instantiate() as BoardingHouseRoomController
	room.enable_psx_rendering = false
	root.add_child(room)
	await process_frame
	await process_frame

	var nb_text := BoardingHouseRoomController.build_case_notebook_text(knowledge, campaign)
	_check(nb_text.contains("WATER") and not nb_text.contains("OBJECTIVE_ONLY_LEAK_GUARD"),
		"Case Notebook shows KnowledgeState facts and never leaks WorldState-only facts")
	_check(not room._is_day_mode, "Boarding House Room opens in Dawn bedside-lamp mode")

	room.trigger_wash_face()
	_check(campaign.washed_face_today, "Washstand sets washed_face_today")

	room.complete_sleep_immediate(test_save)
	_check(campaign.phase == CampaignStateStore.PHASE_DAY_TOWN and campaign.slept_after_shift,
		"Sleep ritual transitions CampaignState to DAY_TOWN")
	_check(campaign.pending_spawn_point == &"boarding_house_porch",
		"Sleep sets spawn point for exterior exit to boarding_house_porch")
	_check(room._is_day_mode and room.window_sun.visible,
		"Sleep immediately switches Boarding House Room into sunlit morning mode")
	_check(world.get_fact(&"train_17_routed_clear", false) == true
		and knowledge.recall_value(&"filed_word_core_hook", "") == "WATER",
		"Sleep preserves both WorldState and KnowledgeState into daytime")
	room.queue_free()
	await process_frame

	# 6. BlackCreekExterior in DAY_TOWN spawns on boarding_house_porch under bright sun
	var day_town := town_scene.instantiate() as BlackCreekExteriorController
	day_town.enable_psx_rendering = false
	root.add_child(day_town)
	await process_frame
	await process_frame

	_check(day_town.time_of_day.current_preset == TownTimeOfDay.PRESET_DAY_CLEAR,
		"BlackCreekExterior switches to bright DAY_CLEAR preset after sleep")
	_check(day_town.player.global_position.distance_to(Vector3(29.54, 0.46, 35.3)) < 0.25,
		"Player steps out onto boarding_house_porch in DAY_TOWN")
	var sun := day_town.get_node_or_null("SunLight") as DirectionalLight3D
	_check(sun != null and sun.light_energy > 1.2,
		"Daytime sun energy is bright (> 1.2) for clear RDR2/SBR daytime contrast")
	day_town.queue_free()
	await process_frame

	# 7. MainMenu.clear_state resets all three stores cleanly
	MainMenu.clear_state()
	_check(campaign.phase == CampaignStateStore.PHASE_NIGHT and campaign.wallet_cents == 250
		and world.snapshot().is_empty() and knowledge.snapshot().is_empty(),
		"MainMenu.clear_state resets WorldState, KnowledgeState, and CampaignState together")

	if FileAccess.file_exists(test_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save))
	GameLocale.clear_test_override()
	print("M2-A assertions: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
