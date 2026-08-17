extends SceneTree

func _init() -> void:
	print("--- Starting Window Observation Event Test Suite (Phase J / Gate 18) ---")

	# Set up Autoloads if missing in headless runner
	var world: WorldStateStore = root.get_node_or_null("WorldState") as WorldStateStore
	if world == null:
		world = WorldStateStore.new()
		world.name = "WorldState"
		root.add_child(world)

	var knowledge: KnowledgeStateStore = root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if knowledge == null:
		knowledge = KnowledgeStateStore.new()
		knowledge.name = "KnowledgeState"
		root.add_child(knowledge)

	world.reset_for_new_game()
	knowledge.reset_for_new_game()

	var event_scene: PackedScene = ResourceLoader.load("res://scenes/office/window_observation_event.tscn")
	if not assert_condition(event_scene != null, "window_observation_event.tscn loads"): return
	var target_node: AttentionObservationTarget = event_scene.instantiate() as AttentionObservationTarget
	if not assert_condition(target_node != null and target_node is AttentionObservationTarget, "instantiates as AttentionObservationTarget"): return
	target_node.position = Vector3(1.1, 1.5, -2.85)
	root.add_child(target_node)

	# 1. Initial State
	if not assert_condition(not target_node.is_active, "Initially inactive"): return
	if not assert_condition(not target_node.is_observed, "Initially unobserved"): return
	if not assert_condition(not target_node.get_visual_indicator().visible, "Visual indicator initially hidden"): return

	# 2. Trigger Event
	target_node.trigger_event(5.0)
	if not assert_condition(target_node.is_active, "Event is active after trigger"): return
	if not assert_condition(target_node.get_visual_indicator().visible, "Visual indicator visible during event"): return
	if not assert_condition(world.get_fact("window_event_occurred") == true, "WorldState recorded window_event_occurred on trigger"): return
	if not assert_condition(not knowledge.knows("saw_window_event"), "KnowledgeState does NOT know about event before looking"): return

	# 3. Evaluation: Camera Looking Away
	var cam_pos := Vector3(0, 1.65, 0)
	var cam_fwd_away := Vector3(0, 0, 1) # Looking South towards door
	var observed_away := target_node.evaluate_observation(cam_pos, cam_fwd_away, false)
	if not assert_condition(not observed_away, "Looking away does not trigger observation"): return
	if not assert_condition(not knowledge.knows("saw_window_event"), "KnowledgeState remains false when looking away"): return

	# 4. Evaluation: Occluded by wall
	var to_target: Vector3 = (target_node.position - cam_pos).normalized()
	var observed_occluded := target_node.evaluate_observation(cam_pos, to_target, true)
	if not assert_condition(not observed_occluded, "Occlusion blocks observation"): return
	if not assert_condition(not knowledge.knows("saw_window_event"), "KnowledgeState remains false when occluded"): return

	# 5. Evaluation: Looking directly at window unobstructed
	var observed_direct := target_node.evaluate_observation(cam_pos, to_target, false)
	if not assert_condition(observed_direct, "Unobstructed view of window observes target"): return
	if not assert_condition(target_node.is_observed, "is_observed is true"): return
	if not assert_condition(knowledge.knows("saw_window_event"), "KnowledgeState recorded saw_window_event"): return

	# 6. Expiration
	target_node._process(6.0)
	if not assert_condition(not target_node.is_active, "Event expires after duration"): return
	if not assert_condition(not target_node.get_visual_indicator().visible, "Visual indicator hidden on expiration"): return

	# Clean up
	target_node.queue_free()

	print("--- All Window Observation Event Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
