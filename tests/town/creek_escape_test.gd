extends SceneTree

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var campaign := root.get_node("CampaignState") as CampaignStateStore
	campaign.reset_for_new_game()
	campaign.phase = CampaignStateStore.PHASE_DAY_TOWN
	var town := preload("res://scenes/town/black_creek_exterior.tscn").instantiate() as BlackCreekExteriorController
	town.enable_psx_rendering = false
	root.add_child(town)
	await process_frame

	var creek_group := town.builder.get_node_or_null("CreekAndBridge")
	_check(creek_group != null, "CreekAndBridge group exists")
	_check(creek_group != null and creek_group.get_node_or_null("WestCreekBankRamp") != null,
		"WestCreekBankRamp exists for climbing out west")
	_check(creek_group != null and creek_group.get_node_or_null("EastCreekBankRamp") != null,
		"EastCreekBankRamp exists for climbing out east")
	_check(creek_group != null and creek_group.get_node_or_null("CreekWaterTrigger") != null,
		"CreekWaterTrigger exists for stream wade feedback")

	var player := town.get_node("Player") as PlayerController
	_check(player != null, "Player exists in town exterior")

	if player != null:
		# 1. Drop into CreekBed on north side of bridge and walk west out onto dry ground
		await _walk_segment(player, Vector3(46.8, -0.35, 16.0), Vector2(41.8, 16.0),
			"Creek escape westbound climbs out onto dry bank")
		# 2. Drop into CreekBed south of bridge and walk east out onto dry ground
		await _walk_segment(player, Vector3(47.2, -0.35, 30.0), Vector2(52.2, 30.0),
			"Creek escape eastbound climbs out onto dry bank")

	# 3. Verify wading feedback in RU and EN (with cooldown reset between checks)
	for locale in ["ru", "en"]:
		GameLocale.lock_language_for_test(locale)
		town.refresh_locale()
		town._creek_splash_cooldown_msec = 0
		town.thoughts.clear_thought()
		town.builder.creek_waded.emit()
		var wet_line := town.thoughts.get_current_text()
		var expected_sub := "вод" if locale == "ru" else "water"
		_check(not wet_line.is_empty() and wet_line.to_lower().contains(expected_sub),
			"Creek wade swearing/wet thought localized: " + locale)

	# 4. Verify chapel door interaction works after chapel relocation
	var chapel_door := town.builder.get_town_interactable(&"chapel_door")
	_check(chapel_door != null, "Chapel door registers an interactable")
	if chapel_door != null:
		for locale in ["ru", "en"]:
			GameLocale.lock_language_for_test(locale)
			town.refresh_locale()
			town.thoughts.clear_thought()
			chapel_door.interact()
			_check(town.thoughts.get_current_text().is_empty(), "Chapel latch leaves a pause: " + locale)
			await create_timer(town.door_knock.thought_delay_seconds + 0.10).timeout
			var chapel_line := town.thoughts.get_current_text()
			_check(not chapel_line.is_empty(), "Chapel door interaction produces localized thought: " + locale)

	GameLocale.clear_test_override()
	town.queue_free()
	await process_frame
	print("--- Creek Escape & Chapel Door Tests (%s, failures=%d) ---"
		% ["PASSED" if _failures == 0 else "FAILED", _failures])
	quit(int(_failures != 0))

func _walk_segment(player: PlayerController, start: Vector3, finish: Vector2, label: String) -> void:
	player.global_position = start
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.aim_at(Vector3(finish.x, start.y + 1.56, finish.y))
	for _i in 8:
		await physics_frame
	Input.action_press("move_forward")
	for _i in 360:
		await physics_frame
		var p := Vector2(player.global_position.x, player.global_position.z)
		if p.distance_to(finish) < 0.18:
			break
	Input.action_release("move_forward")
	var end_pos := player.global_position
	var escaped := Vector2(end_pos.x, end_pos.z).distance_to(finish) < 0.25 and end_pos.y >= -0.05
	_check(escaped, "%s -> %s" % [label, str(end_pos)])

func _check(ok: bool, desc: String) -> void:
	if ok:
		print("  PASS: ", desc)
	else:
		_failures += 1
		printerr("  FAIL: ", desc)
