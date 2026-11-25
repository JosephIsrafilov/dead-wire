extends Node3D
## Painted timber wayfinding and a folded broadsheet at the printer's.

const FONT := preload("res://assets/fonts/oldstandard/OldStandardTT-Bold.ttf")
const DIRECTIONS := [
	["ДЕПО", "DEPOT", 1, Color(0.28, 0.36, 0.34)],
	["САЛУН «МЕДНЫЙ МУЛ»", "COPPER MULE SALOON", 1, Color(0.40, 0.23, 0.15)],
	["ПАНСИОН", "BOARDING HOUSE", -1, Color(0.31, 0.32, 0.21)],
	["ТИПОГРАФИЯ", "PRINT SHOP", 1, Color(0.25, 0.31, 0.27)],
]
var _labels: Array[Label3D] = []
var _timber: StandardMaterial3D

func build(timber: StandardMaterial3D) -> void:
	_timber = timber
	var post := Node3D.new()
	post.position = Vector3(3.95, 0.0, 26.4)
	post.rotation.y = PI + 0.28
	add_child(post)
	_box(post, Vector3(0, 1.15, 0), Vector3(0.16, 2.30, 0.16), timber)
	_box(post, Vector3(0, 2.31, 0), Vector3(0.19, 0.065, 0.19), timber)
	for i in DIRECTIONS.size():
		var spec: Array = DIRECTIONS[i]
		var panel := Node3D.new()
		panel.position = Vector3(0.25 * int(spec[2]), 2.08 - 0.245 * i, 0.107)
		panel.rotation.z = [-0.013, 0.018, -0.019, 0.012][i]
		post.add_child(panel)
		var wood := timber.duplicate() as StandardMaterial3D
		wood.albedo_color = spec[3]
		_box(panel, Vector3.ZERO, Vector3(1.19, 0.196, 0.069), wood)
		var tip := CSGPolygon3D.new()
		var s := float(spec[2])
		tip.polygon = PackedVector2Array([Vector2(0, -0.098), Vector2(0.19 * s, 0), Vector2(0, 0.098)])
		tip.position = Vector3(0.59 * s, 0, 0.034)
		tip.depth = 0.069
		tip.material = wood
		panel.add_child(tip)
		for x in [-0.535, 0.535]:
			_box(panel, Vector3(x, 0, 0.037), Vector3(0.018, 0.018, 0.01), _mat(Color(0.14, 0.12, 0.10)))
		_labels.append(_lettering(panel, Vector3(0, 0, 0.037), "", 54, 0.00120, Color(0.91, 0.81, 0.63)))
		var back := _lettering(panel, Vector3(0, 0, -0.037), "", 54, 0.00120, Color(0.91, 0.81, 0.63))
		back.rotation.y = PI
		_labels.append(back)
	_build_newspaper()
	refresh_locale()

func refresh_locale() -> void:
	for i in DIRECTIONS.size():
		var text := GameLocale.pick(DIRECTIONS[i][0], DIRECTIONS[i][1])
		_labels[i * 2].text = text
		_labels[i * 2 + 1].text = text

func _build_newspaper() -> void:
	var stand := Node3D.new()
	stand.position = Vector3(-11.1, 0.30, 13.93)
	add_child(stand)
	for x in [-0.33, 0.33]:
		for z in [-0.18, 0.18]:
			_box(stand, Vector3(x, 0.34, z), Vector3(0.078, 0.68, 0.08), _timber)
		_box(stand, Vector3(x, 0.27, 0), Vector3(0.057, 0.07, 0.40), _timber)
	_box(stand, Vector3(0, 0.52, 0.206), Vector3(0.79, 0.23, 0.068), _timber)
	_lettering(stand, Vector3(0, 0.52, 0.242), "C H R O N I C L E   •   5 ¢", 46, 0.00090, Color(0.83, 0.71, 0.49))
	var slab := Node3D.new()
	slab.position.y = 0.73
	slab.rotation.x = 0.42
	stand.add_child(slab)
	_box(slab, Vector3.ZERO, Vector3(0.82, 0.055, 0.50), _timber)
	_box(slab, Vector3(0, 0.04, 0.224), Vector3(0.81, 0.06, 0.05), _timber)
	var ivory := _mat(Color(0.72, 0.61, 0.43))
	for i in 4:
		var sheet := _box(slab, Vector3(0.009 * i, 0.032 + i * 0.006, -0.014), Vector3(0.63, 0.008, 0.39), ivory)
		sheet.rotation.y = i * 0.016
	var ink := Color(0.19, 0.125, 0.078)
	var masthead := _lettering(slab, Vector3(0.02, 0.058, -0.154), "Black Creek Chronicle", 52, 0.00105, ink)
	masthead.rotation.x = -PI * 0.5
	var date := _lettering(slab, Vector3(0.02, 0.056, -0.103), "VOL. VIII   •   APRIL 14, 1890", 40, 0.00063, ink)
	date.rotation.x = -PI * 0.5
	var line_ink := _mat(ink)
	for x in [-0.177, 0.02, 0.213]:
		for i in 11:
			var width := 0.159 if i != 5 and i != 10 else 0.11
			_box(slab, Vector3(x, 0.056, -0.075 + i * 0.021), Vector3(width, 0.001, 0.003), line_ink)

func _box(parent: Node3D, p: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = p
	parent.add_child(instance)
	return instance

func _lettering(parent: Node3D, p: Vector3, text: String, size: int, pitch: float, ink: Color) -> Label3D:
	var label := Label3D.new()
	label.font = FONT
	label.font_size = size
	label.pixel_size = pitch
	label.modulate = ink
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.text = text
	label.position = p
	parent.add_child(label)
	return label

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
