extends SceneTree

## The dawn trains (plan 4.6) as stills from the window: No. 17 running past,
## No. 17 at a stand by the points with No. 71 dark on the branch, and the
## empty line. The dawn sky is brought up by hand.
##
##   godot --path . --script tools/dawn_train_capture.gd
##
## Windowed only. Writes to .dream-loop/dawn_train/.

var out_dir := "res://.dream-loop/dawn_train"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.set_process(false)
	office.session_controller.set_process(false)
	office.session_controller.scheduler.auto_process = false
	var moon := office.get_node("MoonWeather") as MoonWeather
	moon.begin_dawn()
	moon.advance(moon.dawn_seconds + 1.0)
	(office.get_node("LampLife") as LampLife).set_wick_immediate(0.3)
	var train := office.get_node("DawnTrain") as DawnTrain
	train.set_process(false)

	office.player.global_position = Vector3(-1.5, 0.0, -1.2)
	await _aim(office, Vector3(-1.8, 1.0, -18.0))

	train.begin(DawnTrain.BEHAVIOUR_PASS, DawnTrain.BEHAVIOUR_GONE)
	_run_to(train, func() -> bool: return train.get_passenger_x() > -4.0)
	await _shot("t1_no17_running_past")

	train.begin(DawnTrain.BEHAVIOUR_STAND, DawnTrain.BEHAVIOUR_STAND)
	for _i in 400:
		train.advance(0.1)
	await _shot("t2_no17_standing_no71_held")

	train.begin(DawnTrain.BEHAVIOUR_DISTANT, DawnTrain.BEHAVIOUR_GONE)
	for _i in 200:
		train.advance(0.1)
	await _shot("t3_empty_line")
	quit(0)

func _run_to(train: DawnTrain, done: Callable) -> void:
	for _i in 600:
		train.advance(0.05)
		if done.call():
			return

func _aim(office: M1OfficeController, point: Vector3) -> void:
	var direction := point - office.player.camera.global_position
	office.player.rotation.y = atan2(-direction.x, -direction.z)
	office.player.head.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())
	for _i in 6:
		await physics_frame
	await process_frame

func _shot(label: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
	print("shot ", label)
