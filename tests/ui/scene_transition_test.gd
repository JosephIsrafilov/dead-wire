extends SceneTree

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var cfg := ConfigFile.new()
	_check(cfg.load("res://project.godot") == OK, "project.godot loads cleanly")
	_check(str(cfg.get_value("autoload", "SceneTransition", "")).ends_with("scene_transition.gd"),
		"SceneTransition autoload is registered in project.godot")
	var splash_path := str(cfg.get_value("application", "boot_splash/image", ""))
	_check(not splash_path.is_empty() and ResourceLoader.exists(splash_path),
		"Configured boot splash image exists: " + splash_path)
	var clear_col: Variant = cfg.get_value("rendering", "environment/defaults/default_clear_color", Color.GRAY)
	_check(clear_col is Color and (clear_col as Color).r < 0.1 and (clear_col as Color).g < 0.1 and (clear_col as Color).b < 0.1,
		"Default clear color is dark charcoal rather than grey")

	var mgr := root.get_node_or_null("SceneTransition") as SceneTransitionManager
	if mgr == null:
		mgr = SceneTransitionManager.new()
		mgr.name = "SceneTransition"
		root.add_child(mgr)
	await process_frame
	_check(not mgr.visible and mgr.layer == 120, "SceneTransitionManager mounts hidden at top overlay layer")

	for locale in ["ru", "en"]:
		GameLocale.lock_language_for_test(locale)
		for path in [
			"res://scenes/office/m1_office.tscn",
			"res://scenes/town/interiors/copper_mule_saloon.tscn",
			"res://scenes/town/interiors/boarding_house_room.tscn",
			"res://scenes/town/black_creek_exterior.tscn",
			"res://scenes/ui/main_menu.tscn",
		]:
			mgr.preview_for_capture(path, 0.55, 1.2)
			_check(not mgr._title_label.text.is_empty() and not mgr._status_label.text.is_empty(),
				"Loading screen renders destination & status in %s for %s" % [locale, path.get_file()])

	mgr.visible = false
	mgr._is_transitioning = true
	_check(not mgr.transition_to("res://scenes/ui/main_menu.tscn"),
		"Re-entrant transitions are rejected while one is active")
	mgr._is_transitioning = false
	_check(SceneTransitionManager.go(self, "res://scenes/ui/main_menu.tscn"),
		"Headless SceneTransitionManager.go switches scene immediately")
	await process_frame
	_check(current_scene is MainMenu, "Scene switched cleanly to MainMenu")
	if current_scene != null:
		current_scene.queue_free()
	GameLocale.clear_test_override()
	await process_frame
	quit(int(_failures > 0))

func _check(ok: bool, desc: String) -> void:
	_failures += int(not ok)
	print("  %s: %s" % ["PASS" if ok else "FAIL", desc])
