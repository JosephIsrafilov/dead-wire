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
	var scene := load("res://scenes/office/m1_office.tscn") as PackedScene
	var office := scene.instantiate() as M1OfficeController
	office.enable_psx_rendering = false
	root.add_child(office)
	await process_frame
	await process_frame

	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null:
		intro.skip_immediately()
	await process_frame

	# 1. Player starts standing (NOT locked into SeatedStationController) and chair is enabled
	var station := office.get_node_or_null("SeatedStationController") as SeatedStationController
	var seat := office.operator_seat
	var chair_act := office.get_node_or_null("Chair/Interactable") as Interactable
	_check(station != null and not station.is_activated(), "Player starts standing, not auto-locked into chair")
	_check(not office.player.seated_station_mode, "PlayerController.seated_station_mode starts false")
	_check(chair_act != null and chair_act.can_interact() and chair_act.collision_layer == 2,
		"Chair interactable stays active while standing")

	# 2. ShiftArrival advances and finishes cleanly
	var arrival := office.get_node_or_null("ShiftArrival") as ShiftArrival
	_check(arrival != null, "ShiftArrival node exists in M1Office")
	arrival._finished = false
	arrival.begin()
	_check(arrival.is_running(), "ShiftArrival enters running state on begin()")
	for i in 22:
		arrival.advance(0.16)
	_check(arrival.is_finished() and not arrival.is_running(), "ShiftArrival completes cleanly across steps")
	_check(not office.player.is_movement_locked, "Player movement unlocks once arrival completes")

	# 3. Living room interactions in RU & EN
	GameLocale.lock_language_for_test("ru")
	GameLocale.refresh_office_locale(office)
	var stove_act := office.get_node_or_null("CornerStove/StoveInteractable") as Interactable
	var map_act := office.get_node_or_null("DivisionMap/DivisionMapInteractable") as Interactable
	var notices_act := office.get_node_or_null("OfficeStorytellingProps/WallNoticesInteractable") as Interactable
	var coat_act := office.get_node_or_null("HangingCoat/CoatInteractable") as Interactable
	_check(stove_act != null and stove_act.can_interact() and stove_act.prompt_text.contains("угля"),
		"Coal stove is interactable with Russian prompt")
	_check(map_act != null and map_act.can_interact() and map_act.prompt_text.contains("карту"),
		"Division map is interactable with Russian prompt")
	_check(notices_act != null and notices_act.can_interact() and notices_act.prompt_text.contains("объявления"),
		"Wall noticeboard is interactable with Russian prompt")
	_check(coat_act != null and coat_act.can_interact() and coat_act.prompt_text.contains("пальто"),
		"Hanging coat is interactable with Russian prompt")

	var lamp := office.get_node_or_null("LampLife") as LampLife
	lamp.set_stove_heat_for_test(0.5)
	stove_act.interact()
	_check(lamp.get_stove_heat() > 1.0, "Stoking the coal stove raises stove_heat")

	map_act.interact()
	_check(office.document_viewer.is_open() and office.document_viewer.get_current_doc_id() == "division_map",
		"Inspecting division map opens DocumentViewer with division_map")
	office.document_viewer.close_document()
	await process_frame

	notices_act.interact()
	_check(office.document_viewer.is_open() and office.document_viewer.get_current_doc_id() == "wall_notices",
		"Inspecting wall notices opens DocumentViewer with wall_notices")
	office.document_viewer.close_document()
	await process_frame

	GameLocale.lock_language_for_test("en")
	GameLocale.refresh_office_locale(office)
	_check(stove_act.prompt_text == "Stoke the Coal Stove", "Stove prompt switches to English")
	GameLocale.lock_language_for_test("ru")
	GameLocale.refresh_office_locale(office)

	# 3b. Standing raycast reliably targets Chair (even looking at backrest), Stove, and Map without hitting Player
	var ic := office.player.get_node_or_null("InteractionController") as InteractionController
	var chair := office.get_node_or_null("Chair") as Node3D
	office.player.global_position = Vector3(-1.5, 0.0, -0.30)
	office.player.reset_physics_interpolation()
	office.player.aim_at(Vector3(-1.5, 0.84, -1.11))
	await physics_frame
	await physics_frame
	await process_frame
	ic._update_target(true)
	_check(ic.current_target == chair_act and chair != null,
		"Standing raycast hits Chair/Interactable even when aiming at backrest top")

	office.player.global_position = Vector3(1.1, 0.0, 1.55)
	office.player.reset_physics_interpolation()
	office.player.aim_at(Vector3(2.1, 1.10, 1.55))
	await physics_frame
	await physics_frame
	await process_frame
	ic._update_target(true)
	_check(ic.current_target == stove_act,
		"Standing raycast hits StoveInteractable even behind StoveSolid upper body")

	office.player.global_position = Vector3(1.1, 0.0, -1.20)
	office.player.reset_physics_interpolation()
	office.player.aim_at(Vector3(1.1, 1.85, -2.29))
	await physics_frame
	await physics_frame
	await process_frame
	ic._update_target(true)
	_check(ic.current_target == map_act,
		"Standing raycast hits DivisionMapInteractable and ignores Player capsule")

	# 3c. PauseMenu -> mode toggle -> resume clears focus so E stays active
	var pm := office.get_node_or_null("PauseMenu") as PauseMenu
	if pm != null:
		pm.pause()
		await process_frame
		var ro := pm.get_node_or_null(PauseMenu.READABILITY_PATH)
		if ro != null and ro._mode != null:
			ro._mode.grab_focus()
			ro._on_mode(1)
			await process_frame
			ro._on_mode(0)
			await process_frame
		pm.resume()
		await process_frame
		_check(not pm.is_paused and not ic.is_ui_blocked and office.get_viewport().gui_get_focus_owner() == null,
			"PauseMenu mode switch + resume releases GUI focus and unblocks interaction")
		# 3d. Focus loss + focus return recovers pause state, capture, reticle, and prompt
		var root_win := office.get_tree().root
		_check(root_win != null and root_win.focus_entered.is_connected(pm._on_window_focus_entered)
			and root_win.focus_exited.is_connected(pm._on_window_focus_exited),
			"PauseMenu binds focus signals on the root Window even across SubViewport reparenting")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pm._on_window_focus_exited()
		_check(office.get_tree().paused, "Focus exit pauses the shift cleanly")
		pm._on_window_focus_entered()
		await process_frame
		ic.refresh_prompt(true)
		var mode_ok := DisplayServer.get_name() == "headless" \
			or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		_check(not office.get_tree().paused and mode_ok
			and not ic.is_ui_blocked and ic.reticle.visible and ic.prompt_label.visible,
			"Focus return unpauses, recaptures mouse, and restores reticle + prompt")

		# 3e. Standing Alt-Tab / mouse-exit while SeatedStationController is inactive must NOT flip cursor_mode
		station.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		station.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
		pm._on_window_focus_exited()
		pm._on_window_focus_entered()
		await process_frame
		ic.refresh_prompt(true)
		_check(not ic.cursor_mode and ic.current_target == map_act
			and ic.reticle.visible and ic.prompt_label.visible,
			"Standing mouse-exit / Alt-Tab leaves cursor_mode false so reticle, prompt, and [E] keep working")

	# 4. Sitting on Chair activates SeatedStationController
	seat.approach_duration = 0.0
	seat.sit_duration = 0.0
	_check(seat.sit(), "Player sits in the operator chair")
	await process_frame
	_check(station.is_activated() and office.player.seated_station_mode,
		"Sitting activates SeatedStationController cursor workstation")

	# 4b. 360-degree seated camera turning from any view
	station.switch_view(SeatedStationController.View.LEFT_SIGNAL)
	station._on_nav_left_pressed()
	_check(station.current_view == SeatedStationController.View.BACK_DOOR,
		"Seated turn left from LEFT_SIGNAL reaches BACK_DOOR")
	station.switch_view(SeatedStationController.View.LEFT_SIGNAL)
	station._on_nav_down_pressed()
	_check(station.current_view == SeatedStationController.View.BACK_DOOR,
		"Seated turn down [S] from LEFT_SIGNAL reaches BACK_DOOR")
	station.switch_view(SeatedStationController.View.RIGHT_FILING)
	station._on_nav_right_pressed()
	_check(station.current_view == SeatedStationController.View.BACK_DOOR,
		"Seated turn right from RIGHT_FILING reaches BACK_DOOR")
	station.switch_view(SeatedStationController.View.RIGHT_FILING)
	station._on_nav_down_pressed()
	_check(station.current_view == SeatedStationController.View.BACK_DOOR,
		"Seated turn down [S] from RIGHT_FILING reaches BACK_DOOR")
	station._on_nav_up_pressed()
	_check(station.current_view == SeatedStationController.View.DESK,
		"Seated turn up [W] returns to DESK")

	# 5. Gradual realistic dawn (28.5 -> 30.0 pre-dawn ramp, then full begin_dawn)
	var moon := office.moon_weather
	var director := office.shift_director
	moon.dawn = 0.0
	director._station_display_hours = 26.0
	moon.advance(0.5)
	_check(is_zero_approx(moon.dawn), "MoonWeather keeps dawn at 0.0 during deep night (02:00)")
	director._station_display_hours = 29.5
	for i in 40:
		moon.advance(0.5)
	_check(moon.dawn > 0.15 and moon.dawn < 0.5,
		"MoonWeather pre-dawn rises gently between 04:30 and 06:00 (%.3f)" % moon.dawn)
	moon.begin_dawn()
	for i in 80:
		moon.advance(0.5)
	_check(moon.dawn >= 0.99, "MoonWeather completes full dawn to 1.0 after begin_dawn()")

	# 6. Standing up at dawn exits cursor workstation so Elias walks out
	director._set_phase(ShiftDirector.Phase.SHIFT_OVER)
	await process_frame
	_check(station.deactivate_for_dawn(), "Standing up at SHIFT_OVER deactivates SeatedStationController")
	_check(not station.is_activated() and not office.player.seated_station_mode,
		"Player returns to free-walk mode at dawn")
	_check(chair_act.can_interact() and chair_act.collision_layer == 2,
		"Chair interactable re-enabled after standing up")

	GameLocale.clear_test_override()
	office.queue_free()
	await process_frame
	print("Phase 2 assertions: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
