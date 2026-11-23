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

	# 1. YardFog layers exist, stay behind window figure column (z <= -6.0), react to dawn
	var fog := office.get_node_or_null("YardFog") as YardFog
	_check(fog != null, "YardFog node exists in M1Office")
	_check(fog.get_layer_count() == 4, "YardFog builds 4 depth-spaced mist planes")
	var all_behind := true
	for child in fog.get_children():
		if child is Node3D and (child as Node3D).position.z > -6.0:
			all_behind = false
	_check(all_behind, "All YardFog planes stand strictly behind z = -6.0 (clear of window figure)")

	office.moon_weather.dawn = 0.52
	fog._sync_weather()
	var mats := fog.get_layer_materials()
	_check(mats.size() == 4 and is_equal_approx(float(mats[0].get_shader_parameter("dawn_amount")), 0.52),
		"YardFog syncs shader dawn_amount with MoonWeather")

	# 2. Stove heat cools naturally toward 03:00 AM and boosts on stoke
	var lamp := office.get_node_or_null("LampLife") as LampLife
	var director := office.shift_director
	_check(lamp != null and lamp.stove_cooling_enabled, "LampLife stove cooling is enabled")
	director._station_display_hours = 23.0
	lamp.set_stove_heat_for_test(1.0)
	lamp.advance(1.0)
	_check(lamp.get_stove_heat() >= 0.95, "Stove stays warm at start of watch (23:00)")

	director._station_display_hours = 27.0
	for i in 40:
		lamp.advance(0.5)
	_check(lamp.get_stove_heat() < 0.5,
		"Stove embers cool naturally by 03:00 AM (%.3f)" % lamp.get_stove_heat())

	lamp.stoke_stove()
	for i in 10:
		lamp.advance(0.2)
	_check(lamp.get_stove_heat() > 1.05, "Stoking stove restores warm ember glow (> 1.05)")

	# 3. SeatedStationController dims DutyStrip during quiet WAITING silence & restores on call
	var station := office.get_node_or_null("SeatedStationController") as SeatedStationController
	station.activate_station()
	await process_frame
	director._slot_index = 1
	director._set_phase(ShiftDirector.Phase.WAITING)
	for i in 25:
		station.advance_hud_fade(0.1)
	_check(station.get_duty_strip_alpha() < 0.35,
		"DutyStrip dims unobtrusively during idle silence (%.2f)" % station.get_duty_strip_alpha())

	director._set_phase(ShiftDirector.Phase.CALLING)
	for i in 25:
		station.advance_hud_fade(0.1)
	_check(station.get_duty_strip_alpha() > 0.92,
		"DutyStrip snaps back to full visibility on incoming call (%.2f)" % station.get_duty_strip_alpha())

	office.queue_free()
	await process_frame
	print("Phase 3 assertions: passed=%d failed=%d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
