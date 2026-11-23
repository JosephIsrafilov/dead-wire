extends SceneTree

## The dawn train (plan 4.6): the board's consequence is seen and heard at
## dawn, without a verdict. Which train does what is data (.tres) read from
## WorldState - never from what Elias knows. Every board outcome maps to
## exactly one behaviour.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Dawn Train Test Suite ---")
	var script: Variant = load("res://scripts/office/dawn_train.gd")
	if not _check(script != null, "The dawn train has a script"): return
	var data: Variant = load("res://data/night/dawn_train.tres")
	if not _check(data != null, "Its outcome table is data"): return

	var world := root.get_node("WorldState") as WorldStateStore
	var knowledge := root.get_node("KnowledgeState") as KnowledgeStateStore

	# Passenger No. 17, by every way the board could have gone.
	var cases := {
		"train_17_routed_clear": "pass",
		"train_17_held_in_error": "stand",
		"train_17_no_order_sent": "distant",
		"telegram_missed_baseline_train_17": "distant",
	}
	for fact in cases:
		world.reset_for_new_game()
		knowledge.reset_for_new_game()
		world.set_fact(StringName(fact), true)
		if not _check(data.passenger_behaviour(world) == cases[fact],
				"No. 17 after '%s' does '%s'" % [fact, cases[fact]]): return

	var freight := {
		"freight_held_correctly": "stand",
		"freight_no_order_sent": "stand",
		"freight_cleared_in_error": "gone",
		"telegram_missed_attention_hold_freight": "stand",
	}
	for fact in freight:
		world.reset_for_new_game()
		world.set_fact(StringName(fact), true)
		if not _check(data.freight_behaviour(world) == freight[fact],
				"No. 71 after '%s' is '%s'" % [fact, freight[fact]]): return

	# What Elias knows changes nothing out there.
	world.reset_for_new_game()
	knowledge.reset_for_new_game()
	knowledge.learn(&"route_clear_east_baseline_train_17")
	if not _check(data.passenger_behaviour(world) == data.passenger_default,
			"Knowledge alone does not move a train - the world does"): return

	# The train itself: passing goes by the window, standing stops at the
	# points, distant never comes into view.
	var behaviours := {}
	for behaviour in ["pass", "stand", "distant"]:
		var train: Node3D = script.new()
		root.add_child(train)
		train.set_process(false)
		train.begin(behaviour, "gone")
		var xs: Array[float] = []
		for _step in 300:
			train.advance(0.1)
			xs.append(train.get_passenger_x())
		behaviours[behaviour] = {"min": xs.min(), "max": xs.max(), "end": xs.back(), "seen": train.was_passenger_visible()}
		train.queue_free()
	var stand_x: float = script.new().stand_x
	if not _check(behaviours["pass"]["min"] < -30.0 and behaviours["pass"]["end"] > 30.0, "A cleared No. 17 runs past without stopping"): return
	if not _check(absf(behaviours["stand"]["end"] - stand_x) < 0.5, "A held No. 17 comes to a stand at the points"): return
	if not _check(not behaviours["distant"]["seen"], "Without an order No. 17 is only a whistle far off"): return

	# Every outcome starts with a whistle the office listener can actually hear.
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	var actual := office.get_node("DawnTrain") as DawnTrain
	actual.set_process(false)
	for behaviour in ["pass", "stand", "distant"]:
		actual.begin(behaviour, "gone")
		actual.advance(actual.first_whistle_seconds + 0.01)
		var distance := actual._whistle.global_position.distance_to(office.player.camera.global_position)
		if not _check(distance < actual._whistle.max_distance,
				"The first %s whistle lies inside the real office listener's cutoff" % behaviour): return
		if behaviour == "distant":
			actual.advance(9.0)
			distance = actual._whistle.global_position.distance_to(office.player.camera.global_position)
			if not _check(distance < actual._whistle.max_distance,
					"The distant-only follow-up is not culled before reaching the office"): return
			if not _check(not actual._passenger.visible, "Audible distant whistles do not force a passing train"): return
	if not _check(_exhaust_count(actual) == 0, "A distant whistle leaves no plume over the yard"): return
	actual.begin("pass", "gone")
	actual.advance(actual.departure_seconds - 0.1)
	if not _check(_exhaust_count(actual) == 0, "There is no exhaust before No. 17 enters the line"): return
	for _step in 30:
		actual.advance(0.1)
	if not _check(_exhaust_count(actual, "StackSmoke") > 0, "A passing No. 17 leaves chimney exhaust"): return
	if not _check(_exhaust_count(actual, "CylinderSteam") == 0, "A through train does not vent at the points"): return
	while actual.get_passenger_x() < actual.end_x:
		actual.advance(0.1)
	if not _check(_exhaust_count(actual, "StackSmoke") > 0, "The plume survives the departure of the model"): return
	actual.advance(10.0)
	if not _check(_exhaust_count(actual) == 0, "The departed train's smoke dissipates"): return
	actual.begin("stand", "gone")
	while not actual._steamed:
		actual.advance(0.1)
	actual.advance(0.6)
	if not _check(_exhaust_count(actual, "CylinderSteam") > 0, "The existing stand hiss cues low steam"): return
	actual.advance(10.0)
	if not _check(_exhaust_count(actual, "CylinderSteam") == 0, "Cylinder steam disperses without retriggering"): return
	actual.begin("distant", "gone")
	if not _check(_exhaust_count(actual) == 0, "Starting another outcome clears the previous plume"): return
	office.get_parent().queue_free()
	await process_frame
	print("--- All Dawn Train Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _exhaust_count(train: Node3D, source: String = "") -> int:
	var count := 0
	for puff in train.find_children("*", "Sprite3D", true, false):
		if puff.visible and (source.is_empty() or str(puff.name).begins_with(source)):
			count += 1
	return count

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
