class_name WetInk
extends Node3D

## Fresh ink catches the lamp. Each glyph that lands leaves a small glossy
## sheen over its strokes that dulls as the ink soaks in; only the last few
## letters are ever wet. Purely surface: it never changes what was written.

## How many letters can be wet at once; the oldest dries first.
@export var max_glints: int = 3
## Drying time range in seconds. Each glyph's time comes from its index, so
## the same copy dries the same way every night.
@export var life_min: float = 2.0
@export var life_max: float = 10.0
## Sheen footprint over one glyph cell, in metres.
@export var glint_size: Vector2 = Vector2(0.011, 0.015)
@export var wet_alpha: float = 0.38

var _glints: Array[Dictionary] = []
var _quad: QuadMesh = null
var _sheen: GradientTexture2D = null

func _ready() -> void:
	_quad = QuadMesh.new()
	_quad.size = glint_size
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	_sheen = GradientTexture2D.new()
	_sheen.gradient = gradient
	_sheen.fill = GradientTexture2D.FILL_RADIAL
	_sheen.fill_from = Vector2(0.5, 0.5)
	_sheen.fill_to = Vector2(1.0, 0.5)
	_sheen.width = 32
	_sheen.height = 32

## A glyph has just been inked at `contact` (the paper's glyph contact, in
## this node's parent space) on a label whose basis is `face`.
func mark(glyph_index: int, contact: Vector3, face: Basis) -> void:
	if glyph_index == 0:
		clear()
	while _glints.size() >= max_glints:
		_drop(0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(glyph_index * 7919 + 17)
	var life := rng.randf_range(life_min, life_max)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.05, 0.05, 0.08, wet_alpha)
	material.albedo_texture = _sheen
	material.roughness = 0.06
	material.metallic_specular = 1.0
	material.render_priority = 1
	mesh.material_override = material
	# The glyph sits above and right of its baseline contact.
	var offset := Vector3(glint_size.x * 0.5, glint_size.y * 0.45, 0.0007)
	mesh.transform = Transform3D(face, contact + face * offset)
	add_child(mesh)
	_glints.append({"mesh": mesh, "material": material, "age": 0.0, "life": life})

func clear() -> void:
	while not _glints.is_empty():
		_drop(0)

func get_wet_count() -> int:
	return _glints.size()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	var index := 0
	while index < _glints.size():
		var glint := _glints[index]
		glint.age += delta
		var t := clampf(glint.age / maxf(glint.life, 0.001), 0.0, 1.0)
		if t >= 1.0:
			_drop(index)
			continue
		var material := glint.material as StandardMaterial3D
		var wet := 1.0 - t * t
		material.albedo_color.a = wet_alpha * wet
		material.roughness = lerpf(0.06, 0.55, t)
		index += 1

func _drop(index: int) -> void:
	var mesh := _glints[index].mesh as MeshInstance3D
	_glints.remove_at(index)
	if is_instance_valid(mesh):
		mesh.queue_free()
