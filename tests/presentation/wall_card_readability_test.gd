extends SceneTree

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := GameSettings.load_settings()
	settings.presentation_mode = ReadabilityPolicy.Mode.READABLE
	settings.save()
	for path in ["black_creek_exterior", "interiors/boarding_house_room", "interiors/copper_mule_saloon"]:
		var place := load("res://scenes/town/%s.tscn" % path).instantiate() as Node
		root.add_child(place)
		var host := place.get_node("PSXPresentationHost") as PSXPresentationHost
		var pause_menu := place.get_node("PauseMenu") as PauseMenu
		var widget := pause_menu.get_node(PauseMenu.READABILITY_PATH) as ReadabilityOptions
		var grade := host._grade_rect
		var preset := host._active_preset
		_check(grade.visible, path + " starts with the READABLE grade")
		widget._on_mode(1)
		_check(not grade.visible and host._presentation_mode == ReadabilityPolicy.Mode.CLEAN,
			path + " switches to CLEAN through the pause menu")
		widget._on_mode(0)
		_check(grade.visible and host._presentation_mode == ReadabilityPolicy.Mode.READABLE
			and host._active_preset == preset, path + " restores READABLE and keeps its lighting preset")
		place.queue_free()
		await process_frame

	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	for prop in ["TimetableCard", "MorseReferenceCard", "RoutingBoard", "OperatorCard", "CopyCommitDesk"]:
		var labels := office.get_node(prop).find_children("*", "Label3D", true, false)
		_check(not labels.is_empty(), prop + " contains physical text")
		for label: Label3D in labels:
			var font_path := label.font.resource_path if label.font != null else ""
			var font_ok := font_path.ends_with("/OldStandardTT-Bold.ttf") or font_path.ends_with("/OldStandardTT-Regular.ttf")
			_check(font_ok and label.alpha_cut != Label3D.ALPHA_CUT_DISCARD
				and label.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
				"%s/%s uses the readable font and filtering" % [prop, label.name])
	var morse := office.get_node("MorseReferenceCard") as MorseReferenceCard
	for locale in ["ru", "en"]:
		GameLocale.lock_language_for_test(locale)
		morse.refresh_locale()
		var lines := morse.label_3d.text.split("\n")
		_check(morse.get_card_text() == morse.label_3d.text and lines[1].split("   ").size() == 2,
			"Morse face keeps its wire-derived two-column format in " + locale)
	GameLocale.clear_test_override()
	office.queue_free()
	await process_frame
	quit(int(_failed))

func _check(ok: bool, message: String) -> void:
	_failed = _failed or not ok
	print("  %s: %s" % ["PASS" if ok else "FAIL", message])

