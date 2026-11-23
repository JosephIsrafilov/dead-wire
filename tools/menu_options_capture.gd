extends SceneTree

## Windowed capture of the pause menu and the redesigned FORM 19 live 3D main menu.
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
	pause_menu.resume()
	office.queue_free()
	await process_frame

	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as MainMenu
	root.add_child(menu)
	for _i in 6:
		await process_frame
	var calibration := menu.get_node_or_null("BrightnessCalibration")
	if calibration != null:
		calibration.call("confirm")
		await process_frame
	var ru_btn := menu.get_node_or_null("LocaleBar/RuButton") as Button
	if ru_btn != null:
		ru_btn.pressed.emit()
	await _shot("title")
	await _shot("title_ru")

	var en_btn := menu.get_node_or_null("LocaleBar/EnButton") as Button
	if en_btn != null:
		en_btn.pressed.emit()
	await _shot("title_en")

	if ru_btn != null:
		ru_btn.pressed.emit()
	menu.open_options()
	menu.select_options_tab("game", false)
	await _shot("title_options_game")
	menu.select_options_tab("audio", false)
	await _shot("title_options_audio")
	menu.select_options_tab("display", false)
	await _shot("title_options_display")
	menu.select_options_tab("game", false)
	await _shot("title_options")
	quit(0)

func _shot(label: String) -> void:
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	print("SHOT ", label, " ", image.save_png(OUT_DIR.path_join(label + ".png")))
