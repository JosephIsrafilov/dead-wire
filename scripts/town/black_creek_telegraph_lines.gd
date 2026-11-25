extends RefCounted

const PAPER := preload("res://scripts/town/period_print_surface.gd")
const WANTED := preload("res://assets/textures/town_v2/print/wanted.png")

static func build(parent: Node3D, depot_origin: Vector3) -> void:
	var timber := StandardMaterial3D.new()
	timber.albedo_texture = preload("res://assets/textures/town_v2/plank_albedo.png")
	timber.albedo_color = Color("aa9075")
	timber.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("437b74")
	glass.roughness = 0.21
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("46403a")
	var poles := [-42.0, -24.0, -8.0, 8.0, 24.0, 38.0]
	for i in poles.size():
		var pos := Vector3(poles[i], 0, 12.6)
		_cylinder(parent, pos + Vector3.UP * 3.50, 0.091, 0.168, 7.08, timber)
		var arm := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.15, 0.14, 1.70)
		arm.mesh = bar
		arm.position = pos + Vector3.UP * 6.57
		arm.material_override = timber
		parent.add_child(arm)
		for lane in [-0.60, 0.0, 0.60]:
			var top := pos + Vector3(0, 6.71, lane)
			_cylinder(parent, top, 0.068, 0.081, 0.13, glass)
			_cylinder(parent, top + Vector3.DOWN * 0.043, 0.086, 0.086, 0.034, glass)
			if i < poles.size() - 1:
				_wire(parent, top, Vector3(poles[i+1], 6.71, 12.6 + lane), iron)
		if i % 2 == 0:
			# Pressed flat onto the bark: the pole tapers from r 0.168 at grade to
			# 0.091 at 7.08 m, so at 1.52 m the bark is r 0.1515. The sheet's own
			# centre touches that radius and wraps around it, instead of hovering
			# 0.13 m inside the timber as a flat card the player can see through.
			PAPER.place(parent, "WeatheredBroadside", pos + Vector3(0, 1.52, 0.152),
				Vector2(0.22, 0.26), WANTED, Vector3(0, 0, (i % 4) - 1.5), 0.004, 0.152)
	for lane in [-0.46, 0.0, 0.46]:
		_wire(parent, depot_origin + Vector3(lane, 5.58, 1.2),
			Vector3(-8.0, 6.71, 12.6 + lane * 0.60 / 0.46), iron)

static func _cylinder(parent: Node3D, pos: Vector3, top: float, bottom: float,
		height: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.radial_segments = 8
	rod.rings = 0
	rod.top_radius = top
	rod.bottom_radius = bottom
	rod.height = height
	mi.mesh = rod
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _wire(parent: Node3D, a: Vector3, b: Vector3, material: Material) -> void:
	var previous := a
	for i in range(1, 11):
		var t := i / 10.0
		var p := a.lerp(b, t) + Vector3.DOWN * (0.62 * 4.0 * t * (1.0 - t))
		var segment := _cylinder(parent, (p + previous) * 0.5, 0.012, 0.012, p.distance_to(previous), material)
		segment.quaternion = Quaternion(Vector3.UP, (p - previous).normalized())
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		previous = p
