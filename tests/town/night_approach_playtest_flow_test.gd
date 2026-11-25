extends SceneTree

var _passed := 0
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(cond: bool, desc: String) -> void:
	if cond:
		print("  PASS: " + desc)
		_passed += 1
	else:
		print("  FAIL: " + desc)
		_failed += 1

func _run() -> void:
	const RAIL_LAYOUT := preload("res://scripts/town/black_creek_rail_layout.gd")
	var campaign := root.get_node_or_null("CampaignState") as CampaignStateStore
	if campaign != null:
		campaign.reset_for_new_game()
		campaign.phase = CampaignStateStore.PHASE_NIGHT_APPROACH
		campaign.pending_spawn_point = &"night_arrival"

	var ext_scene := load("res://scenes/town/black_creek_exterior.tscn") as PackedScene
	var ext := ext_scene.instantiate() as BlackCreekExteriorController
	ext.enable_psx_rendering = false
	root.add_child(ext)
	await process_frame
	await process_frame

	var tod := ext.get_node_or_null("TownTimeOfDay") as TownTimeOfDay
	var we := ext.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_check(tod != null and tod.current_preset == TownTimeOfDay.PRESET_NIGHT_APPROACH,
		"BlackCreekExterior applies PRESET_NIGHT_APPROACH when CampaignState is PHASE_NIGHT_APPROACH")
	_check(we != null and we.environment != null and we.environment.fog_enabled,
		"Night approach enables dense depth fog")

	var beacon := ext.find_child("DepotPorchBeacon", true, false) as Node3D
	var mj_lamp := ext.find_child("NightMJSwitchLamp", true, false) as Node3D
	_check(beacon != null and beacon.visible and mj_lamp != null and mj_lamp.visible,
		"DepotPorchBeacon and NightMJSwitchLamp are built and visible during night approach")

	var player := ext.get_node_or_null("Player") as PlayerController
	_check(player != null and player.global_position.distance_to(Vector3(-10.5, 0.05, 22.0)) < 0.25,
		"Player spawns at night_arrival intersection on Main Street")

	GameLocale.lock_language_for_test("ru")
	ext.refresh_locale()
	var depot_act := ext.builder.get_town_interactable(&"depot_door") as Interactable
	_check(depot_act != null and depot_act.prompt_text == "Войти на станцию",
		"Depot door displays RU night-entry prompt")
	GameLocale.lock_language_for_test("en")
	ext.refresh_locale()
	_check(depot_act != null and depot_act.prompt_text == "Enter the Depot",
		"Depot door displays EN night-entry prompt")
	GameLocale.lock_language_for_test("ru")
	ext.refresh_locale()

	var intro := ext.get_node_or_null("NightApproachIntro") as NightApproachIntro
	_check(intro != null, "NightApproachIntro cold open is mounted in night approach")
	intro.seek_for_capture(2.5)
	_check(intro._loc_label.modulate.a > 0.5 and intro._cam != null and intro._cam.current,
		"Cold open Shot 1 renders date/place over street with active cinematic camera")
	intro.seek_for_capture(6.5)
	_check(intro._order_panel.modulate.a > 0.5,
		"Cold open Shot 2 renders Order 41 card over fog")
	intro.seek_for_capture(11.0)
	_check(intro._title_box.modulate.a > 0.5 and intro._title_label.text == "FORM 19",
		"Cold open Shot 3 renders FORM 19 title card over fog")

	intro.seek_for_capture(1.0)
	_press_e(ext.get_viewport())
	_check(intro.is_running(), "E cannot skip the first 1.8 seconds of the cold open")
	intro.seek_for_capture(2.0)
	_press_e(ext.get_viewport())
	await process_frame
	_check(intro.is_finished() and not player.is_movement_locked and ext.hud_label.visible,
		"E skips the cold open, restores movement and HUD, and consumes the skip press")

	ext.door_knock.thought_delay_seconds = 0.12
	ext.builder.interactable_triggered.emit(&"boarding_door")
	_check(ext.thoughts.get_current_text().is_empty(), "Boarding house knock leaves a pause")
	await create_timer(0.18).timeout
	_check(not ext._transitioning and ext.thoughts.get_current_text().contains("00:45"),
		"Boarding house door refuses entry during midnight approach")

	ext.builder.interactable_triggered.emit(&"saloon_door")
	_check(ext.thoughts.get_current_text().is_empty(), "Saloon knock leaves a pause")
	await create_timer(0.18).timeout
	_check(not ext._transitioning and ext.thoughts.get_current_text().contains("Медный Мул"),
		"Saloon door refuses entry during midnight approach")

	await _focus_cycle_and_press_e(ext.pause_menu, player, depot_act, 1.0)
	_check(ext._transitioning and IntroCard.spare_next_card and ShiftArrival.arrived_from_town \
		and campaign.phase == CampaignStateStore.PHASE_NIGHT,
		"Entering depot sets spare_next_card, arrived_from_town, and PHASE_NIGHT")

	await process_frame
	await process_frame
	await process_frame
	if is_instance_valid(ext):
		ext.queue_free()
		await process_frame

	# Verify real transitioned M1Office spared duplicate Order 41 IntroCard and ShiftArrival doorway entry
	var office := root.find_child("M1Office", true, false) as M1OfficeController
	if office == null:
		office = current_scene as M1OfficeController
	_check(office != null, "Transitioning via depot_door loads M1OfficeController")
	if office != null:
		var south_rail := office.get_node("MineYard/RailMainSouth") as Node3D
		var north_rail := office.get_node("MineYard/RailMainNorth") as Node3D
		var dawn_train := office.get_node("DawnTrain")
		var night_train := office.get_node("NightTrainTraffic")
		var line_centre := (south_rail.position.z + north_rail.position.z) * 0.5
		_check(is_equal_approx(line_centre + RAIL_LAYOUT.DEPOT_ORIGIN.z, RAIL_LAYOUT.MAIN_LINE_Z)
			and is_equal_approx(line_centre, dawn_train.line_z)
			and is_equal_approx(line_centre, night_train.line_z),
			"Town rail, MineYard rail and both office trains share one line")
	var office_intro := office.get_node_or_null("IntroCard") as IntroCard if office != null else null
	var arrival := office.get_node_or_null("ShiftArrival") as ShiftArrival if office != null else null
	_check(office_intro != null and not office_intro.is_running() and not IntroCard.spare_next_card,
		"M1Office spares duplicate Order 41 IntroCard when entering from Black Creek")
	if arrival == null:
		quit(1)
		return
	arrival._finished = false
	arrival.begin()
	_check(not ShiftArrival.arrived_from_town and office.player.global_position.distance_to(ShiftArrival.START_POS) < 0.05,
		"ShiftArrival starts at doorway threshold and consumes arrived_from_town")
	for _i in 10:
		arrival.advance(0.15)
	_check(arrival.is_finished() and office.player.global_position.distance_to(ShiftArrival.END_POS) < 0.05 \
		and not office.player.is_movement_locked,
		"ShiftArrival completes straight doorway entry in 1.35s and unlocks movement")
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
	if office != null and is_instance_valid(office):
		office.queue_free()
	await process_frame
	await process_frame

	# Verify CopperMuleSaloon real PauseMenu scene instance
	var saloon_scene := load("res://scenes/town/interiors/copper_mule_saloon.tscn") as PackedScene
	var saloon := saloon_scene.instantiate()
	root.add_child(saloon)
	await process_frame
	await process_frame
	var pause := saloon.find_child("PauseMenu", true, false) as PauseMenu
	_check(pause != null and pause.resume_button != null and pause.quit_button != null \
		and pause.player == saloon.get_node_or_null("Player"),
		"CopperMuleSaloon instances real pause_menu.tscn with wired controls and player")
	pause.pause()
	_check(saloon.is_world_view_blocked(), "CopperMuleSaloon reports world view blocked while paused")
	pause.resume()
	_check(not saloon.is_world_view_blocked(), "CopperMuleSaloon clears blocked state on resume")
	await _focus_cycle_and_press_e(pause, saloon.get_node("Player") as PlayerController,
		saloon.get_node("SaloonExit") as Interactable, 1.0)
	_check(saloon.is_world_view_blocked(), "E operates the saloon exit after focus recovery")
	saloon.queue_free()
	await process_frame

	# Verify MainMenu.begin_night_approach state transition
	var menu_scene := load("res://scenes/ui/main_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	var started := menu.begin_night_approach()
	_check(started and campaign.phase == CampaignStateStore.PHASE_NIGHT_APPROACH \
		and campaign.pending_spawn_point == &"night_arrival",
		"MainMenu.begin_night_approach sets PHASE_NIGHT_APPROACH and night_arrival spawn")

	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _focus_cycle_and_press_e(pause: PauseMenu, player: PlayerController, door: Interactable, side: float) -> void:
	var pos := door.global_position
	player.global_position = Vector3(pos.x, player.global_position.y, pos.z + side * 1.55)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.aim_at(pos)
	await physics_frame
	await physics_frame
	await process_frame
	root.focus_exited.emit()
	_check(paused and pause._paused_for_focus, "%s pauses on window focus loss" % door.name)
	root.focus_entered.emit()
	await process_frame
	var interaction := player.get_node("InteractionController") as InteractionController
	_check(not paused and not pause._paused_for_focus and not interaction.is_ui_blocked
		and not interaction.cursor_mode, "%s regains standing input on window focus return" % door.name)
	_press_e(player.get_viewport())


func _press_e(viewport: Viewport) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.pressed = true
	viewport.push_input(press, true)
