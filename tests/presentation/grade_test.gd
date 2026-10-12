# tests/presentation/grade_test.gd
# Production PSX grade must reference the external shader; native UI stays above it.
extends SceneTree

var passed := 0
var _office: Node = null

func _init() -> void:
	_run.call_deferred()

func require(ok: bool, message: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + message)
	if not ok:
		_finish(1)
		return false
	passed += 1
	return true

func _finish(code: int) -> void:
	if is_instance_valid(_office):
		_office.free()
	quit(code)

func _run() -> void:
	var path := "res://materials/shaders/psx_grade.gdshader"
	if not require(FileAccess.file_exists(path), "Production grade has an editable external shader"): return
	_office = (load("res://scenes/office/m1_office.tscn") as PackedScene).instantiate() as Node
	var shader := load(path) as Shader
	var grade := _office.get_node("PSXDither/Grade") as ColorRect
	var material_ok := grade.material is ShaderMaterial
	var ok := shader != null and material_ok and (grade.material as ShaderMaterial).shader != null
	if ok:
		ok = (grade.material as ShaderMaterial).shader.resource_path == path
	if not require(ok, "Production Grade references the external shader"): return
	var grade_layer := (_office.get_node("PSXDither") as CanvasLayer).layer
	var viewer_layer := (_office.get_node("DocumentViewer") as CanvasLayer).layer
	if not require(grade_layer < viewer_layer, "Document UI renders above the retro grade"): return
	_finish(0)
