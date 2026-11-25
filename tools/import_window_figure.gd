extends SceneTree
## Import the authored window-figure meshes as Godot ArrayMesh resources.
##
##   godot --headless --path . --script tools/import_window_figure.gd
##
## Keeps four named meshes (Coat, Head, HatBrim, EyeGlints) around the exact
## neck/origin pivots expected by window_observation_event.tscn and GDD 10.
const GLB := "res://assets/models/window_figure_v1/"
const OUT := "res://assets/models/window_figure_v1/"
const RIM := preload("res://materials/shaders/figure_moon_rim.gdshader")

const FINISHES := {
	"figure_coat": {
		"core_color": Color(0.006, 0.008, 0.012, 1.0),
		"rim_color": Color(0.20, 0.29, 0.44, 1.0),
		"rim_power": 3.4,
		"rim_strength": 0.40,
		"catch_glint": 0.0,
		"top_bias_amount": 0.44,
	},
	"figure_head": {
		"core_color": Color(0.010, 0.012, 0.017, 1.0),
		"rim_color": Color(0.24, 0.34, 0.48, 1.0),
		"rim_power": 3.0,
		"rim_strength": 0.46,
		"catch_glint": 0.0,
		"top_bias_amount": 0.18,
		"pallor_strength": 0.72,
	},
	"figure_hat": {
		"core_color": Color(0.005, 0.007, 0.010, 1.0),
		"rim_color": Color(0.25, 0.36, 0.54, 1.0),
		"rim_power": 2.4,
		"rim_strength": 0.66,
		"catch_glint": 0.0,
		"top_bias_amount": 0.54,
		"pallor_strength": 0.0,
	},
	"figure_eye_glints": {
		"core_color": Color(0.24, 0.28, 0.34, 1.0),
		"rim_color": Color(0.56, 0.66, 0.78, 1.0),
		"rim_power": 1.15,
		"rim_strength": 0.92,
		"catch_glint": 1.0,
		"top_bias_amount": 0.0,
		"pallor_strength": 0.0,
		"use_vertex_occlusion": true,
	},
}

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for part: String in FINISHES:
		_import(part)
	quit(1 if _failed else 0)

func _import(part: String) -> void:
	var scene := load(GLB + part + ".glb") as PackedScene
	if scene == null:
		printerr(part, ".glb missing")
		_failed = true
		return
	var node := scene.instantiate()
	var instances := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		instances.push_front(node as MeshInstance3D)
	if instances.size() != 1:
		printerr(part, ": expected 1 mesh, got ", instances.size())
		node.free()
		_failed = true
		return
	var source := instances[0] as MeshInstance3D
	var mesh := source.mesh.duplicate() as ArrayMesh
	var mat := _finish_material(FINISHES[part])
	for index in mesh.get_surface_count():
		mesh.surface_set_material(index, mat)
	mesh.resource_name = part
	var err := ResourceSaver.save(mesh, OUT + part + ".res")
	var has_colors := mesh.get_surface_count() > 0 \
		and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0
	print("IMPORT ", part, " surfaces=", mesh.get_surface_count(),
		" aabb=", mesh.get_aabb(), " vertex_colors=", has_colors,
		" result=", err)
	if err != OK:
		_failed = true
	node.free()

func _finish_material(params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = RIM
	for key: String in params:
		mat.set_shader_parameter(key, params[key])
	return mat
