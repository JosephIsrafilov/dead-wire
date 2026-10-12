extends SceneTree

## The shared readability widget used by both the title and pause menus.
## Accessed through Variant so a missing script fails an assertion, not compilation.

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
	print("--- Starting Readability Options Test Suite ---")

	var wiring := {
		"res://scenes/ui/main_menu.tscn": "CenterContainer/VBoxContainer/OptionsPanel/OptionsBox/ReadabilityOptions",
		"res://scenes/ui/pause_menu.tscn": "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ReadabilityOptions",
	}
	for scene_path in wiring:
		var scene := (load(scene_path) as PackedScene).instantiate() as Node
		var node := scene.get_node_or_null(wiring[scene_path])
		var wired := node is VBoxContainer and node.get_script() != null
		scene.free()
		if not require(wired, "Readable options wired in " + scene_path): return

	var widget_script: Variant = load("res://scripts/ui/readability_options.gd")
	if not require(widget_script != null, "Shared readability options widget exists"): return

	var initial := GameSettings.new()
	initial.presentation_mode = 2
	initial.vertical_fov = 70.0
	initial.text_scale = 1.4
	if not require(initial.save() == OK, "Seed test settings (run only via with_preserved_settings wrapper)"): return

	var widget: Variant = widget_script.new()
	root.add_child(widget)
	if not require(widget.get_child_count() >= 4, "Widget builds its mode, FOV and text controls"): return
	if not require(widget.get("_mode") != null and widget.get("_fov") != null and widget.get("_text") != null,
			"Widget exposes mode, FOV and text controls"): return

	widget.refresh()
	if not require(widget._mode.selected == 2, "Widget shows the saved presentation mode"): return
	if not require(is_equal_approx(widget._fov.value, 70.0), "Widget shows the saved vertical FOV"): return
	if not require(is_equal_approx(widget._text.value, 1.4), "Widget shows the saved reading size"): return

	widget._on_mode(0)
	if not require(GameSettings.load_settings().presentation_mode == 0, "Mode change saves immediately"): return

	widget._on_fov(60.0)
	if not require(is_equal_approx(GameSettings.load_settings().vertical_fov, 60.0), "FOV change saves immediately"): return

	widget._on_text(1.1)
	if not require(is_equal_approx(GameSettings.load_settings().text_scale, 1.1), "Reading size change saves immediately"): return

	var other := GameSettings.load_settings()
	other.mouse_sensitivity = 0.0045
	other.save()
	widget._on_fov(75.0)
	if not require(is_equal_approx(GameSettings.load_settings().mouse_sensitivity, 0.0045),
			"Readability change keeps an unrelated saved sensitivity"): return

	widget.free()
	print("Readability options assertions: ", passed)
	quit(0)
