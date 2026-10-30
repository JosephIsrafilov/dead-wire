extends SceneTree

## First-launch brightness (plan 2.16): the title screen asks once, the marks
## brighten with the slider the way the room will, the choice is saved, and
## the next launch goes straight to the title.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Brightness Calibration Test Suite ---")
	var fresh := GameSettings.new()
	fresh.save()
	if not _check(BrightnessCalibration.needed(), "A first launch asks for brightness"): return

	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	var calibration := menu.get_node_or_null("BrightnessCalibration") as BrightnessCalibration
	if not _check(calibration != null, "The title screen shows the calibration first"): return
	calibration.slider.value = 1.0
	var dim := calibration.get_mark_value(0)
	calibration.slider.value = 1.4
	if not _check(calibration.get_mark_value(0) > dim, "The marks brighten as the room will"): return
	if not _check(calibration.get_mark_value(1) < calibration.get_mark_value(0), "The hidden mark stays darker than the visible one"): return
	calibration.confirm()
	await process_frame
	var saved := GameSettings.load_settings()
	if not _check(saved.brightness_calibrated and is_equal_approx(saved.brightness, 1.4), "The choice is saved"): return
	if not _check(not BrightnessCalibration.needed(), "It is not asked again"): return
	menu.queue_free()
	await process_frame

	var second := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(second)
	await process_frame
	if not _check(second.get_node_or_null("BrightnessCalibration") == null, "The next launch goes straight to the title"): return
	second.queue_free()
	for _frame in 3:
		await process_frame
	print("--- All Brightness Calibration Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func _check(ok: bool, message: String) -> bool:
	if ok:
		_passed += 1
		print("  PASS: ", message)
		return true
	printerr("  FAIL: ", message)
	quit(1)
	return false
