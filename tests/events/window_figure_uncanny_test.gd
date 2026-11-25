extends SceneTree
## Contract suite for Stage 1.1 redesigned 3D Window Figure:
## authored PSX meshes (zero glow light), 20 deg base tilt, 0 idle/breathing,
## +4 deg mechanical stare tilt after 1.8 s, and GDD §10 two-stage placement.
##   godot --headless --audio-driver Dummy --path . --script tests/events/window_figure_uncanny_test.gd

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Window Figure Uncanny Test Suite ---")
	var world := root.get_node_or_null("WorldState") as WorldStateStore
	var knowledge := root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	if world != null:
		world.reset_for_new_game()
	if knowledge != null:
		knowledge.reset_for_new_game()

	var fig_scene := ResourceLoader.load("res://scenes/office/window_observation_event.tscn") as PackedScene
	if not _a(fig_scene != null, "window_observation_event.tscn loads"):
		return
	var fig := fig_scene.instantiate() as AttentionObservationTarget
	if not _a(fig != null, "Instantiates as AttentionObservationTarget"):
		return
	root.add_child(fig)
	await process_frame

	# 1. Authored PSX meshes + zero Light3D/ShimmerLight
	var vi := fig.get_visual_indicator()
	var coat := vi.get_node_or_null("Coat") as MeshInstance3D if vi != null else null
	var head := vi.get_node_or_null("Head") as MeshInstance3D if vi != null else null
	var hat := vi.get_node_or_null("HatBrim") as MeshInstance3D if vi != null else null
	var eyes := head.get_node_or_null("EyeGlints") as MeshInstance3D if head != null else null
	if not _a(coat != null and coat.mesh is ArrayMesh, "Coat uses authored ArrayMesh"):
		return
	if not _a(head != null and head.mesh is ArrayMesh, "Head uses authored ArrayMesh"):
		return
	if not _a(hat != null and hat.mesh is ArrayMesh, "HatBrim uses authored ArrayMesh"):
		return
	if not _a(eyes != null and eyes.mesh is ArrayMesh, "Head/EyeGlints uses authored ArrayMesh"):
		return
	var lights := vi.find_children("*", "Light3D", true, false)
	if not _a(lights.is_empty() and vi.get_node_or_null("ShimmerLight") == null,
			"Figure has zero Light3D or ShimmerLight nodes"):
		return
	if not _a(head.position.is_equal_approx(hat.position),
			"Head and HatBrim share the exact same neck pivot"):
		return

	# 2. Base uncanny tilt (18-22 deg, authored 20 deg) and synced Head/HatBrim
	var base_deg := rad_to_deg(head.rotation.z)
	if not _a(base_deg >= 18.0 and base_deg <= 22.0,
			"Base head tilt is inside 18-22 deg (%.2f)" % base_deg):
		return
	if not _a(is_equal_approx(head.rotation.z, hat.rotation.z)
			and is_equal_approx(head.rotation.x, hat.rotation.x),
			"Head and HatBrim base rotation match identically"):
		return

	# 3. Zero breathing / zero idle sway across 10 seconds
	fig.trigger_event(30.0)
	var vi_pos0 := vi.position
	var coat_pos0 := coat.position
	var head_pos0 := head.position
	var head_rot0 := head.rotation
	for _tick in 600:
		fig._process(1.0 / 60.0)
	if not _a(vi.position.distance_to(vi_pos0) < 0.0001
			and coat.position.distance_to(coat_pos0) < 0.0001
			and head.position.distance_to(head_pos0) < 0.0001
			and head.rotation.distance_to(head_rot0) < 0.0001,
			"Zero breathing or idle movement across 10 s"):
		return

	# 4. Mechanical +4 deg stare tilt after 1.8 s hold
	fig.reset_state()
	fig.trigger_event(30.0)
	if not _a(fig.has_method("advance_stare"), "AttentionObservationTarget exposes advance_stare()"):
		return
	for _step in 17:
		fig.call("advance_stare", 0.1, true)
	if not _a(absf(rad_to_deg(head.rotation.z) - base_deg) < 0.05,
			"No stare tilt occurs before 1.8 s threshold"):
		return
	# Cross the threshold without jumping straight to the final pose.
	fig.advance_stare(0.25, true)
	var rotating_deg := rad_to_deg(head.rotation.z)
	if not _a(rotating_deg > base_deg + 0.05 and rotating_deg < base_deg + 3.95,
			"Stare tilt travels through intermediate angles after the threshold"):
		return
	if not _a(is_equal_approx(head.rotation.z, hat.rotation.z),
			"HatBrim stays locked to Head midway through the tilt"):
		return
	for _step in 15:
		fig.call("advance_stare", 0.1, true)
	var tilted_deg := rad_to_deg(head.rotation.z)
	if not _a(absf(tilted_deg - (base_deg + 4.0)) < 0.15,
			"Mechanical stare adds +4 deg tilt to Head (%.2f -> %.2f)" % [base_deg, tilted_deg]):
		return
	if not _a(is_equal_approx(head.rotation.z, hat.rotation.z),
			"HatBrim locks step with Head through +4 deg tilt"):
		return
	for _step in 20:
		fig.call("advance_stare", 0.1, true)
	if not _a(absf(rad_to_deg(head.rotation.z) - (base_deg + 4.0)) < 0.15,
			"Stare tilt holds dead still without overshoot"):
		return

	fig.reset_state()
	if not _a(absf(rad_to_deg(head.rotation.z) - base_deg) < 0.05
			and is_equal_approx(head.rotation.z, hat.rotation.z),
			"reset_state restores Head and HatBrim to base tilt"):
		return

	# Guard: mirror-obscured glass and Stage A fence do not stare-tilt
	fig.trigger_event(30.0)
	fig.view_obscured = true
	for _step in 32:
		fig.call("advance_stare", 0.1, true)
	if not _a(absf(rad_to_deg(head.rotation.z) - base_deg) < 0.05,
			"Opaque mirror glass prevents +4 deg stare tilt"):
		return
	fig.view_obscured = false
	fig.reset_state()
	if not _a(fig.has_method("set_stage"), "AttentionObservationTarget exposes set_stage()"):
		return
	fig.call("set_stage", 1) # Stage.FAR_FENCE
	fig.trigger_event(30.0)
	for _step in 32:
		fig.call("advance_stare", 0.1, true)
	if not _a(absf(rad_to_deg(head.rotation.z) - base_deg) < 0.05,
			"Stage A FAR_FENCE does not trigger +4 deg close-up tilt"):
		return

	fig.queue_free()
	await process_frame

	# 5. Office two-stage placement & GDD §10 contract
	if world != null:
		world.reset_for_new_game()
	if knowledge != null:
		knowledge.reset_for_new_game()
	var office_scene := ResourceLoader.load("res://scenes/office/m1_office.tscn") as PackedScene
	var office := office_scene.instantiate() as M1OfficeController
	office.enable_psx_rendering = false
	root.add_child(office)
	await process_frame
	await process_frame
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null:
		intro.skip_immediately()
	var off_fig := office.window_observation
	if not _a(off_fig != null and bool(off_fig.get("use_stage_positions")),
			"M1Office WindowObservationEvent enables two-stage positions"):
		return
	var far_pos: Vector3 = off_fig.get("far_stage_position")
	var close_pos: Vector3 = off_fig.get("close_stage_position")
	if not _a(far_pos.distance_to(close_pos) > 2.0,
			"Stage A far fence and Stage B close window are > 2.0 m apart"):
		return

	# Face player away (south) so GDD §10 permits hidden triggers/moves cleanly
	office.player.rotation.y = PI
	office.player.reset_physics_interpolation()
	await physics_frame
	await process_frame

	var shutter := office.get_node_or_null("ServiceShutterEvent") as ServiceShutterEvent
	if not _a(shutter != null, "ServiceShutterEvent exists in M1Office"):
		return
	shutter.trigger_delivery_now()
	if not _a(off_fig.is_active and int(off_fig.call("get_stage")) == 1
			and off_fig.position.distance_to(far_pos) < 0.05,
			"Miller knock triggers Stage A at far fence position"):
		return
	if not _a(world != null and world.get_fact(&"stage_a_figure_stood") == true
			and world.get_fact(&"window_event_occurred") != true
			and world.get_fact(&"silence_three_figure_stood") != true,
			"Stage A records its own WorldState fact without touching Stage B or consequence"):
		return

	# GDD §10: refuse to teleport while visible
	var off_vi := off_fig.get_visual_indicator()
	if not _a(off_vi != null and off_vi.visible, "Stage A figure became visible while facing south"):
		return
	off_fig.call("set_stage", 0) # attempt CLOSE_WINDOW while visible
	if not _a(off_fig.position.distance_to(far_pos) < 0.05,
			"GDD §10: visible figure refuses mid-observation teleport"):
		return
	off_fig.reset_state()
	if not _a(off_fig.position.distance_to(close_pos) < 0.05,
			"Pending Stage B position applies once figure is hidden"):
		return

	# SilenceThree places Stage B close to the window (3-4 m from seated camera)
	var silence3 := office.get_node_or_null("SilenceThree") as SilenceThree
	silence3.update(2, silence3.figure_after_seconds + 0.1, 50.0)
	var seated_cam_dist := off_fig.global_position.distance_to(Vector3(-1.5, 1.24, -1.11))
	if not _a(off_fig.is_active and int(off_fig.call("get_stage")) == 0
			and off_fig.position.distance_to(close_pos) < 0.05
			and seated_cam_dist >= 2.7 and seated_cam_dist <= 4.1,
			"SilenceThree stages Stage B at close window distance (%.2f m)" % seated_cam_dist):
		return

	# The figure can be discovered after its reveal, but a return look must
	# find the yard empty even if the event had time left on its clock.
	var camera := Camera3D.new()
	office.add_child(camera)
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.global_position = off_fig.global_position + Vector3(0, 0.45, 3.0)
	camera.make_current()
	camera.look_at(off_fig.global_position + Vector3.UP * 0.4)
	off_fig._process(0.0)
	if not _a(off_vi.visible, "The close figure stays present with its silhouette in the frame"):
		return
	camera.rotate_y(PI)
	off_fig._process(0.0)
	if not _a(not off_vi.visible and not off_fig.is_active,
			"Leaving the camera frustum immediately cuts the staged appearance"):
		return

	# 6. Reveal sting, Audio Fairness (GDD §7), and Stage A / Stage B reactions
	var staging := office.get_node_or_null("WindowFigureStaging") as WindowFigureStaging
	var sting := staging.get_node_or_null("WindowFigureSting") as AudioStreamPlayer if staging != null else null
	if not _a(staging != null and sting != null and sting.stream != null and sting.is_inside_tree(),
			"WindowFigureStaging attaches WindowFigureSting AudioStreamPlayer inside tree"):
		return
	var sched := office.session_controller.scheduler
	var murmur := office.get_node_or_null("MurmurCaption") as MurmurCaption
	if not _a(sched != null and murmur != null, "Scheduler and MurmurCaption exist for reveal checks"):
		return
	sched._state = MorseRuntimeScheduler.State.PLAYING
	staging._on_figure_observed()
	if not _a(not staging._reaction_stage_a_done and not staging._reaction_stage_b_done,
			"GDD §7: window figure reveal reaction is suppressed during live Morse playback"):
		return
	sched._state = MorseRuntimeScheduler.State.IDLE
	off_fig.reset_state()
	off_fig.call("set_stage", 1) # FAR_FENCE
	staging._on_figure_observed()
	if not _a(staging._reaction_stage_a_done and not murmur._perception_text.is_empty(),
			"Stage A far fence observation surfaces Elias startled line"):
		return
	var stage_a_line := murmur._perception_text
	off_fig.reset_state()
	off_fig.call("set_stage", 0) # CLOSE_WINDOW
	staging._on_figure_observed()
	if not _a(staging._reaction_stage_b_done and not murmur._perception_text.is_empty() \
			and murmur._perception_text != stage_a_line,
			"Stage B close window observation triggers distinct terrified reaction"):
		return

	office.queue_free()
	await process_frame
	print("--- Window Figure Uncanny Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _a(ok: bool, desc: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", desc)
		return true
	printerr("  FAIL: ", desc)
	quit(1)
	return false
