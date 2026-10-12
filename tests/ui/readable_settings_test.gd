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

	settings.vertical_fov = 500.0
	settings.text_scale = -10.0
	settings.presentation_mode = -5
	settings.call("save", path)
	loaded = settings_script.call("load_settings", path)
	if not require(is_equal_approx(loaded.vertical_fov, 85.0) and is_equal_approx(loaded.text_scale, 1.0) and loaded.presentation_mode == 0, "Invalid preferences clamp to explicit bounds"): return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Readable settings assertions: ", passed)
	quit(0)
