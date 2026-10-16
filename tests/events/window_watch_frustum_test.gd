extends SceneTree
## The figure exists only between observations: it may never appear or vanish
## while any part of it is inside the camera frame. Watching is therefore a
## frustum test on the figure's whole silhouette, not a 45° cone on its origin.
##   godot --headless --audio-driver Dummy --path . --script tests/events/window_watch_frustum_test.gd

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Window Watch Frustum Test Suite ---")
	root.size = Vector2i(1280, 720)

	# 1. FOV 65, 16:9: horizontal half-FOV is ~48.6°. A figure at 50° is
	# outside the old 45° cone (its origin), but its silhouette reaches into
	# the frame — so it is being watched.
	var camera65 := _make_camera(65.0)
	var figure := _make_target()
	figure.global_position = _at_angle(50.0, 5.0)
	if not _a(figure._is_being_watched(),
		"At 50° and FOV 65 the figure's silhouette already reaches the frame"): return

	# 2. The same placement at FOV 85: comfortably inside the wider frame.
	camera65.fov = 85.0
	if not _a(figure._is_being_watched(),
		"At 50° and FOV 85 the figure is inside the frame"): return
	camera65.fov = 65.0

	# 3. Behind the player's back: not watched, so appearance may proceed.
	figure.global_position = _at_angle(150.0, 5.0)
	if not _a(not figure._is_being_watched(),
		"A figure behind the player's back is not being watched"): return

	# 4. A tall figure whose head is cut off by the top of the frame is still
	# on screen: partially framed counts as watched.
	var tall := _make_target(Vector3(0.5, 2.4, 0.3))
	tall.global_position = Vector3(0.0, 0.0, -2.0)
	if not _a(tall._is_being_watched(),
		"A figure whose head pokes past the frame's top edge is still being watched"): return

	# 5. Through the public path: a pending appearance is held while the
	# silhouette touches the frame.
	var pending := _make_target()
	pending.global_position = _at_angle(50.0, 5.0)
	pending.trigger_event(5.0)
	if not _a(pending.get_visual_indicator() != null and not pending.get_visual_indicator().visible,
		"The figure does not appear while its silhouette is inside the frame"): return

	# 6. Knowledge follows the same rule: check_camera records an observation
	# only when the silhouette is actually framed, unblocked and in the open.
	var knowledge := root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if not _a(knowledge != null, "Fixture: the KnowledgeState autoload is present"): return
	var seen := _make_target()
	seen.knowledge_fact_id = &"frustum_seen"
	seen.global_position = _at_angle(50.0, 5.0)
	# Appear while the camera looks away, then bring the frame back over it.
	camera65.rotation.y = PI
	seen.trigger_event(5.0)
	if not _a(seen.get_visual_indicator() != null and seen.get_visual_indicator().visible,
		"Fixture: the figure appears while the camera looks away"): return
	camera65.rotation.y = 0.0
	if not _a(seen.check_camera(camera65),
		"A silhouette half in frame at 50° is observed through check_camera"): return
	if not _a(seen.is_observed and knowledge.knows(&"frustum_seen"),
		"Observing through check_camera records the knowledge fact"): return

	var behind := _make_target()
	behind.knowledge_fact_id = &"frustum_behind"
	behind.global_position = _at_angle(150.0, 5.0)
	behind.trigger_event(5.0)
	if not _a(behind.get_visual_indicator() != null and behind.get_visual_indicator().visible,
		"Fixture: the behind-the-back figure appears"): return
	if not _a(not behind.check_camera(camera65),
		"A silhouette behind the player is not observed"): return
	if not _a(not knowledge.knows(&"frustum_behind"), "No knowledge for an unframed silhouette"): return

	var blocked := _make_target()
	blocked.knowledge_fact_id = &"frustum_blocked"
	blocked.global_position = _at_angle(50.0, 5.0)
	camera65.rotation.y = PI
	blocked.trigger_event(5.0)
	camera65.rotation.y = 0.0
	if not _a(not blocked.check_camera(camera65, true),
		"A covering UI surface blocks observation of a framed silhouette"): return
	if not _a(not knowledge.knows(&"frustum_blocked"), "No knowledge assigned through a covering UI"): return
	if not _a(blocked.check_camera(camera65),
		"The same view observes once the surface is gone"): return

	var walled := _make_target()
	walled.knowledge_fact_id = &"frustum_walled"
	walled.global_position = _at_angle(50.0, 5.0)
	camera65.rotation.y = PI
	walled.trigger_event(5.0)
	camera65.rotation.y = 0.0
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(2.0, 3.0, 1.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = _at_angle(50.0, 2.5)
	root.add_child(wall)
	await process_frame
	await process_frame
	if not _a(not walled.check_camera(camera65),
		"A wall between the player and the framed silhouette blocks observation"): return
	if not _a(not knowledge.knows(&"frustum_walled"), "No knowledge through a wall"): return
	wall.queue_free()
	await process_frame
	await process_frame
	if not _a(walled.check_camera(camera65),
		"Removing the wall lets the framed silhouette be observed"): return

	camera65.queue_free()
	figure.queue_free()
	tall.queue_free()
	pending.queue_free()
	seen.queue_free()
	behind.queue_free()
	blocked.queue_free()
	walled.queue_free()

	print("--- All Window Watch Frustum Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _make_camera(fov_degrees: float) -> Camera3D:
	var camera := Camera3D.new()
	camera.fov = fov_degrees
	root.add_child(camera)
	camera.current = true
	return camera

## A figure target with a single box silhouette child, like the window figure.
## The subtree is fully built before entering the tree so _ready sees it.
func _make_target(box_size: Vector3 = Vector3(0.5, 1.1, 0.3)) -> AttentionObservationTarget:
	var target := AttentionObservationTarget.new()
	var indicator := Node3D.new()
	indicator.name = "VisualIndicator"
	target.add_child(indicator)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	indicator.add_child(mesh)
	root.add_child(target)
	return target

## Camera sits at the origin looking down -Z; this is a point at `angle_deg`
## horizontally off the view axis, `distance` metres out.
func _at_angle(angle_degrees: float, distance: float) -> Vector3:
	var angle := deg_to_rad(angle_degrees)
	return Vector3(sin(angle), 0.0, -cos(angle)) * distance

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
