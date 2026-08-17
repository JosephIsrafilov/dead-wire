extends SceneTree

func _init() -> void:
	print("--- Starting Door Attention Test Suite (Gate 16) ---")

	var door_scene: PackedScene = ResourceLoader.load("res://scenes/office/door_attention_source.tscn")
	if not assert_condition(door_scene != null, "door_attention_source.tscn loads"): return
	var door_node: DoorAttentionSource = door_scene.instantiate() as DoorAttentionSource
	if not assert_condition(door_node != null and door_node is DoorAttentionSource, "instantiates as DoorAttentionSource"): return
	root.add_child(door_node)

	if not assert_condition(not door_node.is_active, "Initially inactive"): return
	if not assert_condition(door_node.steps_played == 0, "Initial steps_played is 0"): return

	var started_count: Array[int] = [0]
	var completed_count: Array[int] = [0]
	door_node.footsteps_started.connect(func(): started_count[0] += 1)
	door_node.footsteps_completed.connect(func(): completed_count[0] += 1)

	door_node.step_interval = 0.55
	door_node.trigger_footsteps()

	if not assert_condition(started_count[0] == 1, "footsteps_started emitted exactly once on trigger"): return
	if not assert_condition(door_node.is_active, "Door attention is active"): return
	if not assert_condition(door_node.steps_played == 1, "Step 1 played immediately"): return

	# Duplicate trigger while active must be ignored
	door_node.trigger_footsteps()
	if not assert_condition(started_count[0] == 1, "Duplicate trigger while active is ignored"): return

	# Step 2
	door_node._process(0.6)
	if not assert_condition(door_node.steps_played == 2, "Step 2 played after interval"): return
	if not assert_condition(door_node.is_active, "Door attention still active"): return

	# Step 3 (final)
	door_node._process(0.6)
	if not assert_condition(door_node.steps_played == 3, "Step 3 played after interval"): return
	if not assert_condition(completed_count[0] == 1, "footsteps_completed emitted exactly once"): return
	if not assert_condition(not door_node.is_active, "Door attention is inactive after completion"): return

	# Process further delta to prove no 4th step occurs
	door_node._process(1.0)
	if not assert_condition(door_node.steps_played == 3, "No 4th step occurs after completion"): return

	# Clean up
	door_node.queue_free()

	print("--- All Door Attention Tests PASSED ---")
	quit(0)

func assert_condition(condition: bool, description: String) -> bool:
	if not condition:
		printerr("FAIL: Assertion failed: %s" % description)
		quit(1)
		return false
	else:
		print("  PASS: %s" % description)
		return true
