extends SceneTree

## Plan 10.3: Low / Medium / High. Medium is the night as drawn; Low lets a
## weak machine keep the room (no light in the air, smaller shadows); High
## spends more on the air and the shadow edges. The choice persists and reaches
## the office it is made in.

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> bool:
	if condition:
		_passed += 1
		print("  PASS: " + description)
		return true
	print("  FAIL: " + description)
	quit(1)
	return false

func _run() -> void:
	print("--- Quality presets ---")
	var fresh := GameSettings.new()
	if not check(fresh.get("quality") == 1, "A new install is Medium: the night as drawn"): return
	var path := "user://quality_preset_test.cfg"
	fresh.set("quality", 0)
	fresh.save(path)
	var loaded := GameSettings.load_settings(path)
	if not check(loaded.get("quality") == 0, "The preset survives a save and load"): return
	loaded.set("quality", 7)
	loaded.sanitize()
	if not check(loaded.get("quality") == 1, "An unknown preset falls back to Medium"): return
	loaded.set("quality", 2)
	loaded.restore_defaults()
	if not check(loaded.get("quality") == 1, "Default puts the preset back to Medium"): return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var office := (load("res://scenes/office/m1_office.tscn") as PackedScene).instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	await process_frame
	var air := (office.get_node("WorldEnvironment") as WorldEnvironment).environment
	var frame := office.player.get_viewport()
	if not check(frame is SubViewport, "The office renders in its own frame"): return
	var settings := GameSettings.new()
	settings.set("quality", 0)
	settings.apply(office.player)
	if not check(not air.volumetric_fog_enabled and frame.positional_shadow_atlas_size == 2048,
		"Low: no light in the air, a smaller shadow atlas"): return
	if not check(air.fog_enabled, "Even Low keeps the fog itself"): return
	settings.set("quality", 1)
	settings.apply(office.player)
	if not check(air.volumetric_fog_enabled and frame.positional_shadow_atlas_size == 4096,
		"Medium: the room as drawn"): return
	settings.set("quality", 2)
	settings.apply(office.player)
	if not check(air.volumetric_fog_enabled and frame.positional_shadow_atlas_size >= 4096,
		"High keeps everything Medium has"): return
	office.queue_free()
	await process_frame
	print("--- %d assertions passed ---" % _passed)
	quit(0)
