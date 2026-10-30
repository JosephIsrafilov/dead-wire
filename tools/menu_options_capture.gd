extends SceneTree

## The pause menu and the title's options, as the player sees them (plan 6.8).
## Windowed only. Writes to .dream-loop/menus/.
##
##   godot --path . --resolution 1920x1080 --script tools/menu_options_capture.gd

const OUT_DIR := "res://.dream-loop/menus"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var office: M1OfficeController = load("res://scenes/office/m1_office.tscn").instantiate()
	root.add_child(office)
	for _i in 4:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	var pause_menu := office.get_node("PauseMenu") as PauseMenu
	pause_menu.pause()
	await _shot("pause_menu")
	pause_menu._on_leave_pressed()
	await _shot("pause_leave_armed")
	pause_menu.resume()
	office.queue_free()
	await process_frame
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	for _i in 4:
		await process_frame
	var calibration := menu.get_node_or_null("BrightnessCalibration")
	if calibration != null:
		await _shot("title_calibration")
		calibration.call("confirm")
		await process_frame
	await _shot("title")
	# Plan 6.7: both title backdrops under the same menu, for the owner.
	var mood := menu.get_node_or_null("TitleMood") as TitleMood
	if mood != null:
		await _shot("title_window")
		mood._image.texture = TitleMood.BACKDROPS["desk"]
		await _shot("title_desk")
		mood._image.texture = TitleMood.BACKDROPS["window"]
	if menu.has_method("open_options"):
		menu.call("open_options")
	else:
		var panel := menu.get("options_panel") as Control
		if panel != null:
			panel.visible = true
	await _shot("title_options")
	quit(0)

func _shot(label: String) -> void:
	for _i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	print("SHOT ", label, " ", image.save_png(OUT_DIR.path_join(label + ".png")))
