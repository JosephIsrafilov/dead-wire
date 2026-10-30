extends SceneTree

## Silence 3 asks the question (plan 4.2, 4.9). In the quiet before the third
## call the wick chars and sinks, the pane stops being a mirror, and a figure
## stands in the yard - appearing only between observations, held into the
## call. Silences 1 and 2 bring none of it. The figure is recorded as having
## stood (WorldState) but is only known if seen (KnowledgeState), and a pane
## that is a mirror never counts as seeing the yard.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Silence Three Test Suite ---")
	var script: Variant = load("res://scripts/office/silence_three.gd")
	if not _check(script != null, "Silence three has a script"): return

	var holder := Node3D.new()
	root.add_child(holder)
	var lamp := LampLife.new()
	holder.add_child(lamp)
	lamp.set_process(false)
	lamp.set_wick_immediate(1.0)
	var figure := _make_figure()
	holder.add_child(figure)
	figure.set_process(false)

	var silence: Node = script.new()
	silence.lamp = lamp
	silence.figure = figure
	holder.add_child(silence)
	silence.set_process(false)

	var world := root.get_node("WorldState") as WorldStateStore
	var knowledge := root.get_node("KnowledgeState") as KnowledgeStateStore
	world.reset_for_new_game()
	knowledge.reset_for_new_game()

	# Silences 1 and 2: the room is itself.
	for slot in [0, 1]:
		silence.update(slot, 49.0, 50.0)
	if not _check(is_equal_approx(lamp._wick_target, 1.0), "Silences 1 and 2 leave the lamp alone"): return
	if not _check(not figure.is_active, "Silences 1 and 2 put no one in the yard"): return

	# Silence 3, early: nothing yet.
	silence.update(2, 2.0, 50.0)
	if not _check(is_equal_approx(lamp._wick_target, 1.0) and not figure.is_active,
			"Silence 3 begins quiet"): return

	# The wick chars and sinks, and asks to be trimmed.
	silence.update(2, silence.gutter_after_seconds + 0.1, 50.0)
	if not _check(lamp._wick_target < 0.65 and lamp._wick_target >= lamp.sink_floor - 0.001,
			"In silence 3 the wick starts to sink toward its floor"): return
	for _step in int(silence.gutter_seconds * 10.0) + 10:
		lamp.advance(0.1)
	if not _check(WindowGlassMirror.yard_visibility(lamp.wick, 0.0) > 0.6,
			"With the wick sunk the pane stops being a mirror (yard visibility %.2f)"
			% WindowGlassMirror.yard_visibility(lamp.wick, 0.0)): return

	# Someone stands in the yard, recorded but not known.
	silence.update(2, silence.figure_after_seconds + 0.1, 50.0)
	if not _check(figure.is_active, "Later in silence 3 a figure stands in the yard"): return
	if not _check(world.get_fact(silence.world_fact_id) == true, "WorldState records that it stood there"): return
	if not _check(not knowledge.knows(silence.knowledge_fact_id), "Nothing is known before it is seen"): return
	if not _check(world.get_fact(&"window_event_occurred") != true,
			"The silence figure does not pose as the filing consequence"): return

	# It happens once a night.
	figure.reset_state()
	silence.update(2, silence.figure_after_seconds + 1.0, 50.0)
	if not _check(not figure.is_active, "Silence 3 puts it there only once"): return

	# A mirror pane hides the yard: looking at it is not seeing.
	figure.trigger_event(5.0, silence.world_fact_id, silence.knowledge_fact_id)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.5, 3.0), figure.global_position + Vector3.UP * 0.4)
	figure.view_obscured = true
	if not _check(not figure.check_camera(camera), "Looking at a mirror pane does not see the figure"): return
	figure.view_obscured = false
	if not _check(figure.check_camera(camera), "Through a clear pane the same look sees it"): return
	if not _check(knowledge.knows(silence.knowledge_fact_id), "Seeing it is what Elias knows"): return
	if not _check(not knowledge.knows(&"saw_window_event"),
			"Seeing the silence figure is not remembered as the filing's window event"): return

	holder.queue_free()
	for _frame in 3:
		await process_frame
	print("--- All Silence Three Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _make_figure() -> AttentionObservationTarget:
	var target := AttentionObservationTarget.new()
	var indicator := Node3D.new()
	indicator.name = "VisualIndicator"
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 1.8, 0.3)
	body.mesh = box
	indicator.add_child(body)
	target.add_child(indicator)
	return target

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
