extends SceneTree

## Fixed-camera BEFORE / AFTER checkpoint capture for Stage 1.1 Window Figure.
## Windowed D3D12 only (never headless).
##
##   godot --path . --script tools/window_figure_checkpoint_capture.gd
##         -- --out res://.dream-loop/window_figure_checkpoint/after
##
## The six cameras are the ones the BEFORE set was shot with, unchanged: an AFTER
## set is only worth looking at if nothing but the figure moved. Shot 05 is the
## one exception, and its BEFORE is knowingly mis-framed (the old camera aimed
## below the belt); it is reframed here and must be judged on its own.

const DEFAULT_OUT := "res://.dream-loop/window_figure_checkpoint/after"
const STAGE_B_FALLBACK := Vector3(-1.02, 0.96, -3.95)
const STAGE_A_FALLBACK := Vector3(-1.92, 0.96, -6.85)

var _out_dir := DEFAULT_OUT
var _shots := 0
var _player: PlayerController = null
var _figure: AttentionObservationTarget = null

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out_dir = args[i + 1]
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("window_figure_checkpoint_capture.gd must run windowed (not --headless).")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	for _i in 6:
		await process_frame

	var arrival := office.get_node_or_null("ShiftArrival") as Node
	if arrival != null:
		arrival.set_process(false)
		arrival.set("enabled", false)
		arrival.set("_running", false)
		arrival.set("_finished", true)
	var intro := office.get_node_or_null("IntroCard") as IntroCard
	if intro != null:
		intro.skip_immediately()
	for _i in 4:
		await process_frame

	office.shift_director.enabled = false
	office.shift_director.set_process(false)
	office.session_controller.set_process(false)
	office.session_controller.scheduler.auto_process = false

	_player = office.player
	_player.set_process(false)
	_player.set_physics_process(false)
	var ic := _player.get_node_or_null("InteractionController") as InteractionController
	if ic != null:
		# InteractionController is a plain Node: it has no `visible` of its own,
		# only the label and reticle under the player's own UI. Hiding the node
		# would be a type error, so the two surfaces are hidden directly.
		ic.set_process(false)
		ic.set_physics_process(false)
		if ic.prompt_label != null:
			ic.prompt_label.visible = false
		if ic.reticle != null:
			ic.reticle.visible = false
	var station := office.get_node_or_null("SeatedStationController") as Node
	if station != null:
		station.set_process(false)
		station.set_process_input(false)
	for layer_name in ["NightGuidance", "SeatedStationController", "SoundCaptions",
			"MurmurCaption", "PauseMenu", "DocumentViewer", "IntroCard"]:
		var layer := office.get_node_or_null(layer_name)
		if layer != null and "visible" in layer:
			layer.visible = false

	var moon := office.get_node_or_null("MoonWeather") as MoonWeather
	if moon != null:
		moon.set_process(false)
		if moon.moon_light != null:
			moon.moon_light.light_energy = moon.get_rest_energy()

	var lamp := office.get_node_or_null("LampLife") as LampLife
	if lamp != null:
		lamp.set_process(false)
		lamp.set_wick_immediate(0.30)

	_figure = office.window_observation
	_figure.set_process(false)
	_figure.reset_state()
	if _figure.has_method("set_stage"):
		_figure.call("set_stage", 0) # Stage.CLOSE_WINDOW
	var vi := _figure.get_visual_indicator()
	# Forced visibility alone is not enough: the uncanny tick only runs for an
	# event that is actually happening, so a figure posed by hand would sit at its
	# base tilt and shot 03 would be a duplicate of 02. The event is put in its
	# live state explicitly - its lifetime is irrelevant here because _process is
	# off and the stare is driven by hand.
	_figure.is_active = true
	vi.visible = true

	var cam := Camera3D.new()
	cam.name = "CheckpointCaptureCam"
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	office.add_child(cam)
	cam.make_current()

	var b_head := _head_target(_figure)
	# 1. Seated at desk (View.DESK eye, pitch -11 deg, FOV 68) with dimmed wick
	await _aim_and_shoot(
		cam,
		Vector3(-1.5, 1.24, -1.11),
		Vector3(-1.5, 1.24, -1.11) + Vector3(0.0, sin(deg_to_rad(-11.0)), -cos(deg_to_rad(-11.0))) * 3.0,
		68.0,
		"01_seated_stage_b_dim"
	)

	# 2. Seated leaning closer toward glass looking straight at figure head/upper torso
	await _aim_and_shoot(
		cam,
		Vector3(-1.42, 1.36, -1.68),
		b_head,
		54.0,
		"02_seated_stage_b_lean"
	)

	# 3. Exact same camera after advancing stare > 2.7 s (+4 deg mechanical tilt)
	if _figure.has_method("advance_stare"):
		for _s in 30:
			_figure.call("advance_stare", 0.1, true)
	await _aim_and_shoot(
		cam,
		Vector3(-1.42, 1.36, -1.68),
		b_head,
		54.0,
		"03_seated_stage_b_stare_tilt"
	)

	# 4. Stage A distant fence silhouette (turn camera away first so set_stage moves cleanly)
	cam.look_at_from_position(Vector3(-1.5, 1.34, -1.58), Vector3(-1.5, 1.34, 2.0), Vector3.UP)
	cam.reset_physics_interpolation()
	await process_frame
	_figure.reset_state()
	if _figure.has_method("set_stage"):
		_figure.call("set_stage", 1) # Stage.FAR_FENCE
	else:
		_figure.position = STAGE_A_FALLBACK
	_figure.is_active = true
	vi.visible = true
	if lamp != null:
		lamp.set_wick_immediate(0.35)
	await _aim_and_shoot(
		cam,
		Vector3(-1.5, 1.34, -1.58),
		_head_target(_figure),
		64.0,
		"04_seated_stage_a_fence"
	)

	# 5. Exterior closeup inspection camera: the whole silhouette, PSX graded.
	#
	#    Shot from BEHIND him, out in the yard (z more negative than his own), so
	#    the lit bay window is the backdrop and he is a hard cut-out against it.
	#    The BEFORE frame stood inside the room looking out at a black man on a
	#    black yard, which is why it read as nothing at all; and it aimed at his
	#    origin (his feet), which put his belt at the top of the frame.
	_figure.reset_state()
	if _figure.has_method("set_stage"):
		_figure.call("set_stage", 0) # Stage.CLOSE_WINDOW
	else:
		_figure.position = STAGE_B_FALLBACK
	_figure.is_active = true
	vi.visible = true
	var fig_pos := _figure.global_position
	await _aim_and_shoot(
		cam,
		fig_pos + Vector3(1.15, 1.24, -1.95),
		fig_pos + Vector3(0.0, 0.80, 0.0),
		46.0,
		"05_closeup_yard_silhouette"
	)

	# Tear down office presentation container cleanly before loading TitleMood
	var pres := office.get_parent().get_parent() if office.get_parent() != null else null
	if pres != null and pres.name == "OfficePresentation":
		pres.queue_free()
	else:
		office.queue_free()
	for _i in 6:
		await process_frame

	# 6. Title Menu 3D diorama with figure visible
	var title_mood := TitleMood.new()
	root.add_child(title_mood)
	for _i in 4:
		await process_frame
	var backdrop := title_mood.get_node_or_null("DioramaFrame/DioramaViewport/TitleBackdrop3D") as TitleBackdrop3D
	if backdrop != null:
		backdrop.set_process(false)
		var fig_ind := backdrop.get_node_or_null("WindowFigure/VisualIndicator") as Node3D
		if fig_ind != null:
			fig_ind.visible = true
		backdrop._wick_dim_factor = 0.78
		backdrop._update_lamp(0.0)
	await _wait_and_save("06_title_menu_figure")

	title_mood.queue_free()
	await process_frame
	print("CHECKPOINT_CAPTURES_DONE shots=%d dir=%s" % [_shots, _out_dir])
	quit(0)

func _head_target(figure: AttentionObservationTarget) -> Vector3:
	var head := figure.get_node_or_null("VisualIndicator/Head") as Node3D
	if head != null and head.is_inside_tree():
		return head.global_position + Vector3(0.0, 0.04, 0.0)
	return figure.global_position + Vector3(0.0, 0.56, 0.0)

func _aim_and_shoot(cam: Camera3D, from_pos: Vector3, look_pos: Vector3, fov_deg: float, label: String) -> void:
	cam.global_position = from_pos
	cam.fov = fov_deg
	cam.look_at(look_pos, Vector3.UP)
	cam.reset_physics_interpolation()
	# Sync WindowGlassMirror to capture camera position so leaning toward the glass clears the mirror
	if _player != null and _player.camera != null:
		_player.camera.top_level = true
		_player.camera.global_position = from_pos
		_player.camera.reset_physics_interpolation()
	await process_frame
	await _wait_and_save(label)

func _wait_and_save(label: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(label + ".png")
	var img := root.get_texture().get_image()
	var err := img.save_png(path)
	if err != OK:
		printerr("FAILED saving ", path, " err=", err)
	else:
		_shots += 1
		print("SHOT: ", path)
