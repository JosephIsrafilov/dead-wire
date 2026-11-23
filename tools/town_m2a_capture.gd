extends SceneTree
## Windowed visual verification capture for M2-A (Dawn Walk, Room #4 Dawn/Morning,
## and Sunlit Black Creek Day 1).
##   godot --path . --script tools/town_m2a_capture.gd

const OUT_DIR := "res://.dream-loop/town_m2a"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("town_m2a_capture requires windowed rendering (not --headless).")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	GameLocale.lock_language_for_test("ru")

	# 1. Capture BlackCreekExterior in DAWN + DAY_CLEAR
	var campaign := root.get_node_or_null("CampaignState") as CampaignStateStore
	if campaign != null:
		campaign.reset_for_new_game()
		campaign.phase = CampaignStateStore.PHASE_DAWN_WALK
		campaign.wallet_cents = 450

	var town := load("res://scenes/town/black_creek_exterior.tscn").instantiate() as BlackCreekExteriorController
	root.add_child(town)
	for _i in 6:
		await process_frame
	if town.fade_rect != null:
		town.fade_rect.visible = false
	town.player.set_process(false)
	town.player.set_physics_process(false)
	town.player.set_process_input(false)
	var cam := town.player.get_node("Head/Camera3D") as Camera3D

	await _snap(cam, Vector3(0.0, 1.75, 4.2), Vector3(16.0, 2.0, 35.0), "01_dawn_depot_exit.png")
	await _snap(cam, Vector3(-16.0, 2.2, 23.0), Vector3(14.0, 2.5, 32.0), "02_dawn_main_street.png")
	await _snap(cam, Vector3(24.0, 1.8, 27.5), Vector3(31.0, 2.2, 39.0), "03_dawn_boarding_porch.png")

	# Switch to sunlit DAY_CLEAR by reloading exterior as real gameplay does after Sleep!
	var host := town.get_parent()
	if host != null and host.get_parent() is SubViewportContainer:
		host.get_parent().queue_free()
	else:
		town.queue_free()
	for _i in 4:
		await process_frame

	if campaign != null:
		campaign.phase = CampaignStateStore.PHASE_DAY_TOWN
		campaign.pending_spawn_point = &"boarding_house_porch"
	var day_town := load("res://scenes/town/black_creek_exterior.tscn").instantiate() as BlackCreekExteriorController
	root.add_child(day_town)
	for _i in 6:
		await process_frame
	if day_town.fade_rect != null:
		day_town.fade_rect.visible = false
	day_town.player.set_process(false)
	day_town.player.set_physics_process(false)
	day_town.player.set_process_input(false)
	var dcam := day_town.player.get_node("Head/Camera3D") as Camera3D
	await _snap(dcam, Vector3(24.0, 1.8, 27.5), Vector3(31.0, 2.2, 39.0), "09_day_boarding_porch.png")
	await _snap(dcam, Vector3(14.0, 2.1, 21.5), Vector3(-6.0, 3.4, 38.0), "06_day_main_street_saloon.png")
	await _snap(dcam, Vector3(-4.0, 2.3, 18.0), Vector3(-4.0, 2.6, -6.0), "07_day_depot_and_mine.png")
	await _snap(dcam, Vector3(35.0, 2.5, 23.5), Vector3(49.0, 1.4, 22.5), "08_day_creek_bridge_town.png")

	var dhost := day_town.get_parent()
	if dhost != null and dhost.get_parent() is SubViewportContainer:
		dhost.get_parent().queue_free()
	else:
		day_town.queue_free()
	for _i in 4:
		await process_frame

	# 2. Capture BoardingHouseRoom in DAWN and Sunny Morning
	if campaign != null:
		campaign.phase = CampaignStateStore.PHASE_DAWN_WALK
	var room := load("res://scenes/town/interiors/boarding_house_room.tscn").instantiate() as BoardingHouseRoomController
	root.add_child(room)
	for _i in 6:
		await process_frame
	if room.fade_rect != null:
		room.fade_rect.visible = false
	room.player.set_process(false)
	room.player.set_physics_process(false)
	room.player.set_process_input(false)
	var rcam := room.player.get_node("Head/Camera3D") as Camera3D

	var anchor := room.room_builder.position
	var room_eye := anchor + Vector3(-0.14, 1.56, 1.25)
	var room_target := anchor + Vector3(0.02, 1.05, -0.94)
	await _snap(rcam, room_eye, room_target, "04_room_dawn.png")
	await _snap(rcam, Vector3(-1.46, 1.58, -4.06), Vector3(-0.72, 1.85, -0.95), "10_foyer_dawn.png")
	await _snap(rcam, Vector3(0.12, 4.28, 1.62), Vector3(2.07, 3.91, -0.35), "11_landing_dawn.png")
	await _snap(rcam, room_eye, anchor + Vector3(0.5, 1.12, -0.68),
		"12_room_dawn_desk.png")
	if "--flame" in OS.get_cmdline_user_args():
		var lamp := anchor + Vector3(1.396, 0.946, -1.07)
		rcam.global_position = lamp + Vector3(-0.37, 0.08, 0.22)
		rcam.look_at(lamp, Vector3.UP)
		for i in 10:
			await create_timer(0.059).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT_DIR.path_join("flame_%02d.png" % i))
	room.complete_sleep_immediate("")
	await _snap(rcam, room_eye, room_target, "05_room_sunny_morning.png")
	await _snap(rcam, room_eye, anchor + Vector3(0.5, 1.12, -0.68),
		"15_room_day_desk.png")
	await _snap(rcam, Vector3(-1.46, 1.58, -4.06), Vector3(-0.72, 1.85, -0.95), "13_foyer_day.png")
	await _snap(rcam, Vector3(0.12, 4.28, 1.62), Vector3(2.07, 3.91, -0.35), "14_landing_day.png")

	GameLocale.clear_test_override()
	quit(0)

func _snap(cam: Camera3D, eye: Vector3, target: Vector3, filename: String) -> void:
	cam.global_position = eye
	cam.look_at(target, Vector3.UP)
	for _i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT_DIR.path_join(filename))
	print("SHOT %s err=%d" % [filename, err])
