extends SceneTree

const OUT_DIR := "res://.dream-loop/depot_checkpoint/after"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("night_approach_capture.gd must run windowed (not --headless).")
		quit(2)
		return
	_run.call_deferred()

func _save_shot(filename: String) -> void:
	for _i in 4:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	if img == null or img.get_size() != DisplayServer.window_get_size():
		printerr("FAIL: unexpected window image size for " + filename)
		quit(1)
		return
	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var path := abs_dir.path_join(filename)
	var err := img.save_png(path)
	if err == OK:
		print("SAVED: " + path)
	else:
		printerr("FAIL save_png %s (%d)" % [path, err])

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame

	var campaign := root.get_node_or_null("CampaignState") as CampaignStateStore
	if campaign != null:
		campaign.reset_for_new_game()
		campaign.phase = CampaignStateStore.PHASE_NIGHT_APPROACH
		campaign.pending_spawn_point = &"night_arrival"
	GameLocale.lock_language_for_test("ru")

	var ext_scene := load("res://scenes/town/black_creek_exterior.tscn") as PackedScene
	var ext := ext_scene.instantiate() as BlackCreekExteriorController
	root.add_child(ext)
	for _i in 6:
		await process_frame

	current_scene = ext.get_parent().get_parent() if ext.get_viewport() != root else ext
	var intro := ext.get_node_or_null("NightApproachIntro") as NightApproachIntro
	if intro == null:
		printerr("FAIL: missing night intro")
		quit(1)
		return
	await _intro_shots(intro, "")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _intro_shots(intro, "720p_")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	intro.skip_immediately()
	await _save_shot("04_playable_night_spawn.png")

	for shot in [
		["07_trackside", Vector3(-10, 0.05, -17.1), Vector3(-0.8, 2.5, -8.0)],
		["08_platform_end", Vector3(11.5, 0.05, -4.0), Vector3(7.6, 0.6, -6.0)],
		["09_main_street", Vector3(-5, 0.05, 27.0), Vector3(15, 2.1, 28.0)],
		["10_freight_ramp", Vector3(16.4, 0.03, -12.9), Vector3(10.9, 0.60, -12.9)],
		["12_depot_south_facade", Vector3(-1.0, 0.05, 6.9), Vector3(3.3, 2.75, -7.0)],
		["11_trackside_west", Vector3(10.8, 0.05, -17.38), Vector3(-6.0, 2.9, -13.50)],
	]:
		await _aim_player(ext.player, shot[1], shot[2])
		await _save_shot(shot[0] + ".png")

	var door: Interactable = ext.builder.get_town_interactable(&"depot_door")
	await _aim_player(ext.player, door.global_position * Vector3(1, 0, 1) + Vector3(0, 0.31, 1.82),
		door.global_position + Vector3.UP * 0.13)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var interaction := ext.player.get_node("InteractionController") as InteractionController
	for _i in 6:
		await process_frame
	interaction.refresh_prompt()
	if interaction.current_target != door:
		await _save_shot("debug_door.png")
		printerr("FAIL: depot ray from %s (mouse %s, hit %s, blocked %s)" % [
			interaction.interaction_ray.global_position, Input.mouse_mode,
			interaction.interaction_ray.get_collider(), interaction.is_ui_blocked,
		])
		quit(1)
		return
	await _save_shot("05_depot_porch_door.png")
	if "--os-focus" in OS.get_cmdline_user_args():
		if not await _cycle_native_focus(ext):
			quit(1)
			return
		# Deliver E through the root Window, including the presentation container.
		Input.parse_input_event(_e_key())
		await process_frame
	else:
		ext.get_viewport().push_input(_e_key(), true)

	if not ext._transitioning:
		printerr("FAIL: E did not start the office transition")
		quit(1)
		return
	await _capture_arrival()


func _cycle_native_focus(ext: BlackCreekExteriorController) -> bool:
	if not root.has_focus():
		root.grab_focus()
		await process_frame
	var focus_events: Array[String] = []
	root.focus_exited.connect(func() -> void: focus_events.append("out"))
	root.focus_entered.connect(func() -> void: focus_events.append("in"))
	root.gui_embed_subwindows = false
	var other := Window.new()
	other.title = "FORM 19 focus test"
	other.size = Vector2i(420, 240)
	root.add_child(other)
	other.grab_focus()
	await create_timer(0.65, true).timeout
	var paused_on_loss := paused and ext.pause_menu._paused_for_focus
	root.grab_focus()
	await create_timer(0.65, true).timeout
	other.queue_free()
	var lost := focus_events.find("out")
	if lost < 0 or focus_events.find("in", lost + 1) < 0 or not paused_on_loss or paused \
		or not root.has_focus() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		printerr("FAIL: OS focus cycle/capture missing: %s" % [focus_events])
		return false
	print("PASS: native Windows focus out/in, pause and mouse capture")
	await _save_shot("05b_depot_after_focus_return.png")
	return true


func _e_key() -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	return key


func _capture_arrival() -> void:
	for _i in 240:
		await process_frame
		var office := root.find_child("M1Office", true, false) as M1OfficeController
		if office == null:
			continue
		var arrival := office.get_node_or_null("ShiftArrival") as ShiftArrival
		if arrival != null and arrival.is_running():
			await _save_shot("06_office_entry_threshold.png")
			await _capture_sunny_street()
			print("CAPTURE DONE")
			quit()
			return
	printerr("FAIL: office arrival missing after E")
	quit(1)


func _capture_sunny_street() -> void:
	var campaign := root.get_node("CampaignState") as CampaignStateStore
	campaign.phase = CampaignStateStore.PHASE_DAY_TOWN
	var old := current_scene
	if old != null:
		old.queue_free()
		await process_frame
		await process_frame
	var town := (load("res://scenes/town/black_creek_exterior.tscn") as PackedScene).instantiate()
	root.add_child(town)
	await create_timer(1.0).timeout
	for shot in [
		["13_sunny_main_street", Vector3(-11, 0.05, 23.5), Vector3(18, 2, 25.30)],
		["14_sunny_commerce", Vector3(-2, 0.05, 24.0), Vector3(-2.5, 2.7, 36.0)],
		["15_sunny_trackside", Vector3(14.5, 0.05, -20.0), Vector3(3.0, 3.1, -13.6)],
		["16_sunny_ramp", Vector3(16.0, 0.05, -11.0), Vector3(11.5, 0.5, -13.2)],
		["18_sunny_depot_front", Vector3(2.0, 0.05, 6.8), Vector3(4.2, 2.9, -6.9)],
		["19_sunny_mj_view", Vector3(-11.8, 0.05, -20.1), Vector3(7.0, 2.9, -15.2)],
	]:
		await _aim_player(town.player, shot[1], shot[2])
		await _save_shot(shot[0] + ".png")


func _intro_shots(intro: NightApproachIntro, prefix: String) -> void:
	for shot in [
		[2.5, "01_cold_open_fog_date.png"],
		[6.5, "02_cold_open_order41.png"],
		[11.0, "03_cold_open_form19.png"],
		[13.5, "03b_cold_open_walk_in.png"],
	]:
		intro.seek_for_capture(shot[0])
		await _save_shot(prefix + shot[1])


func _aim_player(player: PlayerController, at: Vector3, toward: Vector3) -> void:
	if not root.has_focus():
		root.grab_focus()
		await create_timer(0.3, true).timeout
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	player.aim_at(toward)
	await process_frame
	player._update_camera_pose()
