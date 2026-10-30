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

	await process_frame
	print("--- All Dawn Train Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
