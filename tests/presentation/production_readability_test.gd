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
	await _finish(0 if ok else 1)
