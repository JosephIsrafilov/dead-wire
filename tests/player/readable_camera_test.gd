extends SceneTree

## Scene-default camera framing for the standing operator. Reads authored values
## from player.tscn without touching user:// settings. Collision and body shape
## are asserted unchanged so the eye-height fix cannot leak into movement.

var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, text: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok:
		_failures += 1

func _run() -> void:
	print("--- Starting Readable Camera Test Suite ---")
	var player := load("res://scenes/player/player.tscn").instantiate() as PlayerController
	var head := player.get_node("Head") as Node3D
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var shape := player.get_node("CollisionShape3D").shape as CapsuleShape3D

	_check(is_equal_approx(head.position.y, 1.56), "Standing eyes are 1.56 m")
	_check(is_equal_approx(camera.fov, 65.0), "Authored vertical FOV is 65 degrees")
	_check(camera.keep_aspect == Camera3D.KEEP_HEIGHT, "Camera keeps vertical FOV (KEEP_HEIGHT)")
	_check(is_equal_approx(shape.height, 1.8), "Collision capsule height remains 1.8")
	_check(is_equal_approx(player.get_node("CollisionShape3D").position.y, 0.9), "Collision capsule centre remains 0.9")

	player.free()
	print("--- Readable Camera: %d failure(s) ---" % _failures)
	quit(1 if _failures > 0 else 0)
