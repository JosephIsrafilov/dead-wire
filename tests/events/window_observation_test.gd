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

	# 7. A watched trigger is queued without spending its visible lifetime.
	var watched_scene: PackedScene = ResourceLoader.load("res://scenes/office/window_observation_event.tscn")
	var watched_target: AttentionObservationTarget = watched_scene.instantiate() as AttentionObservationTarget
	if not assert_condition(watched_target != null, "Watched target instantiates"): return
	watched_target.position = Vector3(0.0, 1.5, -3.0)
	root.add_child(watched_target)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.5, 0.0)
	root.add_child(camera)
	await process_frame
	camera.look_at(watched_target.global_position, Vector3.UP)
	camera.make_current()
	await process_frame
	watched_target.trigger_event(2.0)
	if not assert_condition(watched_target.is_active and not watched_target.get_visual_indicator().visible, "Watched trigger remains pending while in view"): return
	watched_target._process(5.0)
	if not assert_condition(watched_target.is_active and not watched_target.get_visual_indicator().visible, "Pending trigger does not expire off-screen"): return
	camera.look_at(Vector3(0.0, 1.5, 3.0), Vector3.UP)
	watched_target._process(0.0)
	if not assert_condition(watched_target.get_visual_indicator().visible, "Pending figure appears after the player looks away"): return
	watched_target._process(1.9)
	if not assert_condition(watched_target.is_active, "Visible figure keeps its full post-appearance lifetime"): return
	watched_target._process(0.2)
	if not assert_condition(not watched_target.is_active and not watched_target.get_visual_indicator().visible, "Visible figure expires after its hold"): return

	# 8. A full-screen UI surface blocks observation without cancelling the event.
	knowledge.reset_for_new_game()
	var ui_scene: PackedScene = ResourceLoader.load("res://scenes/office/window_observation_event.tscn")
	var ui_target: AttentionObservationTarget = ui_scene.instantiate() as AttentionObservationTarget
	if not assert_condition(ui_target != null, "UI-blocked target instantiates"): return
	ui_target.position = Vector3(1.1, 1.5, -2.85)
	root.add_child(ui_target)
	var ui_camera := Camera3D.new()
	ui_camera.position = Vector3(0.0, 1.65, 0.0)
	root.add_child(ui_camera)
	await process_frame
	# Figure must be on screen first: trigger while looking away.
	ui_camera.look_at(Vector3(0.0, 1.65, 3.0), Vector3.UP)
	ui_camera.make_current()
	await process_frame
	ui_target.trigger_event(5.0)
	ui_target._process(0.0)
	if not assert_condition(ui_target.get_visual_indicator().visible, "UI-blocked case: figure appears while camera looks away"): return
	ui_camera.look_at(ui_target.global_position, Vector3.UP)
	await process_frame
	var observed_ui_blocked: bool = ui_target.check_camera(ui_camera, true)
	if not assert_condition(not observed_ui_blocked, "Observation blocked while a UI surface hides the world"): return
	if not assert_condition(not knowledge.knows("saw_window_event"), "No knowledge assigned through a covering UI"): return
	if not assert_condition(ui_target.is_active and ui_target.get_visual_indicator().visible, "UI block does not cancel or pause the event"): return
	var observed_ui_open: bool = ui_target.check_camera(ui_camera, false)
	if not assert_condition(observed_ui_open, "Same view observes once the surface is gone"): return
	if not assert_condition(knowledge.knows("saw_window_event"), "Knowledge assigned after the surface closes"): return

	# Clean up
	target_node.queue_free()
	watched_target.queue_free()
	camera.queue_free()
	ui_target.queue_free()
	ui_camera.queue_free()

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
