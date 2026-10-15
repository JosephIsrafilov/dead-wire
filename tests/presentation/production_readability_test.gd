# tests/presentation/production_readability_test.gd
# Production office must expose live presentation mode and apply the policy scale.
extends SceneTree

var _office: Node = null

func _init() -> void:
	_run.call_deferred()

func _finish(code: int) -> void:
	if is_instance_valid(_office):
		_office.queue_free()
		await process_frame
	quit(code)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/office/m1_office.tscn")
	if scene == null:
		print("  FAIL: Production office scene loads")
		await _finish(1)
		return
	_office = scene.instantiate()
	root.add_child(_office)
	await process_frame

	var ok: bool = _office.has_method("apply_presentation_mode")
	print(("  PASS: " if ok else "  FAIL: ") + "Production exposes live presentation mode")
	if not ok:
		await _finish(1)
		return

	_office.call("apply_presentation_mode", 1)
	ok = is_equal_approx(root.scaling_3d_scale, 1.0)
	print(("  PASS: " if ok else "  FAIL: ") + "Readable world is not locked to 360 lines at 720p")
	if not ok:
		await _finish(1)
		return

	# The grade material must follow the same contract as the policy: the
	# effective screen sampling cell equals the render divisor, never a second
	# independent rule that re-pixelates READABLE.
	var grade := _office.get_node_or_null("PSXDither/Grade") as CanvasItem
	if grade == null or not (grade.material is ShaderMaterial):
		print("  FAIL: PSXDither/Grade carries the ShaderMaterial")
		await _finish(1)
		return
	var material := grade.material as ShaderMaterial
	var cell: float = float(material.get_shader_parameter("pixel_size"))
	ok = is_equal_approx(cell, 1.0)
	print(("  PASS: " if ok else "  FAIL: ") + "Readable grade samples every screen line at 720p (pixel_size %.1f, expected 1)" % cell)
	if not ok:
		await _finish(1)
		return
	ok = grade.visible
	print(("  PASS: " if ok else "  FAIL: ") + "Readable keeps the grade enabled (color depth, not spatial decimation)")
	if not ok:
		await _finish(1)
		return

	# Resize round-trip: the window grows to 1080p and the policy and material
	# recalculate through the window's own size_changed wiring.
	root.size = Vector2i(1920, 1080)
	for i in 5:
		await process_frame
	cell = float(material.get_shader_parameter("pixel_size"))
	ok = is_equal_approx(cell, 1.0) and is_equal_approx(root.scaling_3d_scale, 1.0)
	print(("  PASS: " if ok else "  FAIL: ") + "Resize to 1080p recalculates READABLE to divisor 1 (cell %.1f, scale %.2f)" % [cell, root.scaling_3d_scale])
	if not ok:
		await _finish(1)
		return

	root.size = Vector2i(1280, 720)
	_office.call("apply_presentation_mode", 0)
	for i in 3:
		await process_frame
	cell = float(material.get_shader_parameter("pixel_size"))
	ok = cell >= 2.0 and is_equal_approx(root.scaling_3d_scale, 0.5)
	print(("  PASS: " if ok else "  FAIL: ") + "Classic still pixelates strongly at 720p (cell %.1f, scale %.2f)" % [cell, root.scaling_3d_scale])
	if not ok:
		await _finish(1)
		return

	_office.call("apply_presentation_mode", 2)
	for i in 3:
		await process_frame
	ok = not grade.visible and is_equal_approx(root.scaling_3d_scale, 1.0)
	print(("  PASS: " if ok else "  FAIL: ") + "Clean hides the grade and renders native")
	if not ok:
		await _finish(1)
		return
	await _finish(0)
