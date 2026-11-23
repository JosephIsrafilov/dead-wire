extends SceneTree

## Readable-presentation preferences: presentation mode, vertical FOV and text
## scale persist to the settings file, load back, and are clamped to explicit
## bounds so a corrupt or hand-edited file cannot break the game.
##
## Accessed through Variant.call so that a missing property fails an assertion
## instead of making the whole suite fail to compile.

var passed: int = 0

func _init() -> void:
	call_deferred("_run")

func require(ok: bool, text: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok:
		quit(1)
		return false
	passed += 1
	return true

func _run() -> void:
	print("--- Starting Readable Settings Test Suite ---")

	var settings: Variant = GameSettings.new()
	if not require(settings.get("presentation_mode") != null, "Settings expose a presentation choice"): return
	if not require(settings.presentation_mode == 1, "New install defaults to readable"): return
	if not require(is_equal_approx(settings.vertical_fov, 65.0), "New install defaults to 65 degree vertical FOV"): return
	if not require(is_equal_approx(settings.text_scale, 1.2), "New install defaults to 1.2 text scale"): return
	if not require(settings.contextual_thoughts_enabled, "Contextual thoughts default to enabled"): return
	if not require(is_equal_approx(settings.telegraph_volume_db, 0.0) and is_equal_approx(settings.foley_volume_db, 0.0), "Separate Telegraph and Foley levels default to 0 dB"): return

	if not require(settings.get("music_volume_db") != null, "Music has its own saved volume"): return
	settings.set("music_volume_db", -13.0)
	var path := "user://readable_settings_test.cfg"
	settings.presentation_mode = 2
	settings.vertical_fov = 70.0
	settings.text_scale = 1.4
	settings.contextual_thoughts_enabled = false
	settings.telegraph_volume_db = -8.0
	settings.foley_volume_db = -12.0
	if not require(settings.call("save", path) == OK, "Isolated test settings saved"): return

	var settings_script: Variant = load("res://scripts/ui/game_settings.gd")
	var loaded: Variant = settings_script.call("load_settings", path)
	if not require(loaded.presentation_mode == 2 and is_equal_approx(loaded.vertical_fov, 70.0), "Mode and vertical FOV survive reload"): return
	if not require(is_equal_approx(loaded.text_scale, 1.4), "Text scale survives reload"): return
	if not require(not loaded.contextual_thoughts_enabled, "Contextual thoughts toggle survives reload"): return
	if not require(is_equal_approx(loaded.telegraph_volume_db, -8.0) and is_equal_approx(loaded.foley_volume_db, -12.0), "Telegraph and Foley levels survive reload"): return

	if not require(is_equal_approx(loaded.get("music_volume_db"), -13.0), "Music volume survives reload"): return
	loaded.apply(null)
	var music_bus := AudioServer.get_bus_index("Music")
	if not require(music_bus >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(music_bus), -13.0),
		"Saved music volume reaches its bus"): return
	if not require(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")), -4.0),
		"Music volume leaves the room ambience alone"): return
	loaded.set("music_volume_db", NAN)
	loaded.sanitize()
	if not require(is_equal_approx(loaded.get("music_volume_db"), -4.0), "Invalid music volume falls back to the authored level"): return
	loaded.set("music_volume_db", 90.0)
	loaded.sanitize()
	if not require(is_equal_approx(loaded.get("music_volume_db"), 6.0), "Music volume clamps to its upper bound"): return

	settings.vertical_fov = 500.0
	settings.text_scale = -10.0
	settings.presentation_mode = -5
	settings.call("save", path)
	loaded = settings_script.call("load_settings", path)
	if not require(is_equal_approx(loaded.vertical_fov, 85.0) and is_equal_approx(loaded.text_scale, 1.0) and loaded.presentation_mode == 0, "Invalid preferences clamp to explicit bounds"): return

	# Brightness (plan 2.16): a room exposure the player sets once, bounded,
	# remembered; and whether the first-run calibration has been done.
	var fresh: Variant = GameSettings.new()
	if not require(is_equal_approx(fresh.brightness, 1.0) and not fresh.brightness_calibrated,
			"New install: neutral brightness, not yet calibrated"): return
	fresh.brightness = 1.3
	fresh.brightness_calibrated = true
	fresh.save(path)
	var bright: Variant = settings_script.call("load_settings", path)
	if not require(is_equal_approx(bright.brightness, 1.3) and bright.brightness_calibrated,
			"Brightness and its calibration survive reload"): return
	fresh.brightness = 9.0
	fresh.save(path)
	if not require(settings_script.call("load_settings", path).brightness <= 1.8,
			"Brightness clamps to its bound"): return
	# It moves the room's exposure, not the interface.
	var office_stub := Node3D.new()
	var player_stub := PlayerController.new()
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	env_node.environment = Environment.new()
	env_node.environment.tonemap_exposure = 1.5
	office_stub.add_child(env_node)
	office_stub.add_child(player_stub)
	var lit: Variant = GameSettings.new()
	lit.brightness = 1.2
	lit.apply(player_stub)
	if not require(is_equal_approx(env_node.environment.tonemap_exposure, 1.8), "Brightness scales the room's exposure"): return
	lit.brightness = 0.8
	lit.apply(player_stub)
	if not require(is_equal_approx(env_node.environment.tonemap_exposure, 1.2), "From the authored exposure, not compounding"): return
	office_stub.free()

	# A run with the override saves and loads through the scratch file, so test
	# suites never overwrite the player's own settings.
	var previous_override := OS.get_environment(GameSettings.PATH_OVERRIDE_ENV)
	var scratch := ProjectSettings.globalize_path("user://readable_settings_override_test.cfg")
	OS.set_environment(GameSettings.PATH_OVERRIDE_ENV, scratch)
	var redirected := GameSettings.new()
	redirected.vertical_fov = 77.0
	redirected.save()
	var redirected_ok := FileAccess.file_exists(scratch) \
			and is_equal_approx(GameSettings.load_settings().vertical_fov, 77.0)
	if previous_override.is_empty():
		OS.unset_environment(GameSettings.PATH_OVERRIDE_ENV)
	else:
		OS.set_environment(GameSettings.PATH_OVERRIDE_ENV, previous_override)
	DirAccess.remove_absolute(scratch)
	if not require(redirected_ok, "The settings path override redirects save and load"): return

	# Plan 6.8: display and control options persist and clamp like the rest.
	var display_path := "user://readable_settings_display_test.cfg"
	var display: Variant = GameSettings.new()
	# Plan 9.1: a released build opens fullscreen; the editor binary that runs
	# suites and capture tools keeps a window, so frames keep their size.
	var released_full: bool = display.call("default_fullscreen") if display.has_method("default_fullscreen") else not OS.has_feature("template")
	if not require(released_full == OS.has_feature("template") and display.fullscreen == released_full,
		"New install: fullscreen in a released build, a window under the editor binary"): return
	if not require(not display.fullscreen and display.vsync and display.max_fps == 0 and not display.invert_y,
		"New install: windowed, VSync on, no frame limit, mouse Y not inverted"): return
	display.fullscreen = true
	display.vsync = false
	display.max_fps = 60
	display.invert_y = true
	display.save(display_path)
	var display_loaded: Variant = GameSettings.load_settings(display_path)
	if not require(display_loaded.fullscreen and not display_loaded.vsync and display_loaded.max_fps == 60 and display_loaded.invert_y,
		"Display and control options survive a save and load"): return
	display_loaded.max_fps = 75
	display_loaded.sanitize()
	if not require(display_loaded.max_fps == 0, "An unknown frame limit falls back to no limit"): return
	display_loaded.brightness = 1.6
	display_loaded.brightness_calibrated = true
	display_loaded.vertical_fov = 80.0
	display_loaded.restore_defaults()
	if not require(is_equal_approx(display_loaded.brightness, 1.0) and is_equal_approx(display_loaded.vertical_fov, 65.0)
		and not display_loaded.fullscreen and display_loaded.brightness_calibrated,
		"Default restores the look, and the first-launch calibration stays done"): return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(display_path))

	# Inverted Y: the same upward mouse motion turns the head the other way.
	var look_player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(look_player)
	look_player.head.rotation.x = 0.0
	look_player._apply_mouse_look(Vector2(0.0, -20.0))
	var normal_pitch: float = look_player.head.rotation.x
	look_player.head.rotation.x = 0.0
	look_player.invert_y = true
	look_player._apply_mouse_look(Vector2(0.0, -20.0))
	if not require(normal_pitch > 0.0 and look_player.head.rotation.x < 0.0, "Invert mouse Y flips the look"): return
	look_player.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Readable settings assertions: ", passed)
	quit(0)
