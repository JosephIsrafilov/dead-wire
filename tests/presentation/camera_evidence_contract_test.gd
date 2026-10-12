# tests/presentation/camera_evidence_contract_test.gd
# Evidence tools must measure the standing camera against the player's own head
# rest height (authored 1.56 m) and must not hardcode a stale FOV override.
extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, text: String) -> void:
	print(("  PASS: " if ok else "  FAIL: ") + text)
	if not ok:
		_failures += 1

func _run() -> void:
	print("--- Camera Evidence Contract Suite ---")
	var production := FileAccess.get_file_as_string("res://tools/production_evidence_capture.gd")
	var first_night := FileAccess.get_file_as_string("res://tools/capture_first_night.gd")

	_check(not production.contains("1.65"), "Production evidence has no stale 1.65 standing eye height")
	_check(production.contains("var authored_head_y: float = player.head_rest_position.y") and production.contains("player.camera.global_position.y - (player.global_position.y + player.head_rest_position.y)"), "Production evidence compares standing camera to player.head_rest_position.y")
	_check(not first_night.contains("fov = 78.0"), "Filing capture has no hardcoded 78 FOV override")
	_check(first_night.contains("var camera_fov: float = office.player.camera.fov"), "Filing capture records the current camera FOV before temporary overrides")
	_check(first_night.contains("office.player.camera.fov = camera_fov"), "Filing capture restores the current camera FOV for filing shots")

	print("--- Camera Evidence Contract: %d failure(s) ---" % _failures)
	quit(1 if _failures > 0 else 0)
