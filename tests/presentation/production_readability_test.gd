# tests/presentation/production_readability_test.gd
extends SceneTree

var passed := 0

func _init() -> void:
	_run.call_deferred()

func require(ok: bool, message: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + message)
	if not ok:
		quit(1)
		return false
	passed += 1
	return true

func _run() -> void:
	var original_size := root.content_scale_size
	var original_mode := root.content_scale_mode
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	await process_frame
	if not require(office.has_method("apply_presentation_mode"), "Production exposes live presentation mode"): return
	var project_atlas := int(ProjectSettings.get_setting(
		"rendering/lights_and_shadows/positional_shadow/atlas_size", 4096))
	if not require(office.get_viewport().positional_shadow_atlas_size == project_atlas,
			"The office frame casts lamp shadows through the project's shadow atlas"): return
	var grade := office.get_node("PSXDither/Grade") as CanvasItem
	var material := grade.material as ShaderMaterial
	if not require(material != null, "Production grade carries its shader"): return
	for size in [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1280, 720), Vector2i(3840, 2160)]:
		root.size = size
		for mode in [1, 0]:
			office.apply_presentation_mode(mode)
			await process_frame
			if not require(office.get_viewport() is SubViewport
					and office.get_viewport().size == Vector2i(960, 540),
					"World and UI share a 960x540 viewport in mode %d at %s" % [mode, size]): return
			if not require((office.get_viewport().get_parent() as Control).get_global_rect().size.is_equal_approx(Vector2(size)),
					"The final frame fills the window without cropping in mode %d at %s" % [mode, size]): return
			if not require(office.get_viewport().scaling_3d_scale == 1.0 and grade.visible
					and float(material.get_shader_parameter("pixel_size")) == 1.0,
					"The render grid is graded once in mode %d at %s" % [mode, size]): return
		office.apply_presentation_mode(2)
		await process_frame
		if not require(office.get_viewport().size == size
				and office.get_viewport().scaling_3d_scale == 1.0 and not grade.visible,
				"CLEAN restores native rendering at %s" % size): return
	# Resize without reselecting a mode, then leave the office for the menu.
	office.apply_presentation_mode(1)
	root.size = Vector2i(2560, 1440)
	for i in 5:
		await process_frame
	if not require(office.get_viewport().size == Vector2i(960, 540), "Window resize preserves the internal grid"): return
	office.queue_free()
	await process_frame
	if not require(root.content_scale_size == original_size and root.content_scale_mode == original_mode,
			"Leaving the office restores the window for the title screen"): return
	print("Production readability assertions: ", passed)
	quit(0)
