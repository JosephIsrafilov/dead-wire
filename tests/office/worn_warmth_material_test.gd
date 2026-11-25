extends SceneTree
## M1's restrained albedos preserve readable working materials; not a visual acceptance.
## godot --headless --audio-driver Dummy --path . --script tests/office/worn_warmth_material_test.gd

var _passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/office/m1_office.tscn") as PackedScene
	var office := scene.instantiate() as Node3D
	var felt := (office.get_node("DeskBlotter") as CSGBox3D).material as StandardMaterial3D
	var wall := load("res://materials/style_tests/m1_wall_plaster.tres") as StandardMaterial3D
	var wood := load("res://materials/style_tests/m1_wainscot_wood.tres") as StandardMaterial3D
	var paper := load("res://materials/style_tests/paper_log.tres") as StandardMaterial3D
	var names := ["wallpaper", "wood", "baize", "paper"]
	var materials := [wall, wood, felt, paper]
	for i in names.size():
		var material := materials[i] as StandardMaterial3D
		var expected := "res://assets/textures/worn_warmth/%s_128_v1.png" % names[i]
		if i == 0:
			expected = "res://assets/textures/office_wear/wallpaper_b.png"
		elif i == 1:
			expected = "res://assets/textures/office_surfaces/beadboard_albedo.png"
		elif i == 2:
			expected = "res://assets/textures/office_surfaces/blotter_albedo.png"
		if not check(material.albedo_texture != null and material.albedo_texture.resource_path == expected,
				"%s uses its versioned candidate texture" % names[i]):
			office.free()
			return
		var dimension := 256 if i == 1 or i == 2 else 128
		if not check(material.albedo_texture.get_size() == Vector2(dimension, dimension),
				"%s uses the intended PSX texture grid" % names[i]): return
		if not check(material.texture_filter == (BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				if i < 3 else BaseMaterial3D.TEXTURE_FILTER_NEAREST),
				"%s uses nearest filtering with minification for room surfaces" % names[i]): return
		if not check(material.normal_enabled == (i < 3) and
				(i == 3 or (material.normal_texture != null and material.roughness_texture != null)),
				"%s has the material maps appropriate to its surface" % names[i]): return
		var image := material.albedo_texture.get_image()
		image.convert(Image.FORMAT_RGB8)
		image.clear_mipmaps()
		var quantized := true
		for byte in image.get_data():
			var level := int(round(float(byte) * 31.0 / 255.0))
			if byte != int(round(float(level) * 255.0 / 31.0)):
				quantized = false
				break
		if i == 0:
			# Owner-selected B is a contrast derivative, not the former quantized candidate.
			var repair := office.get_node("OfficeWear/WallpaperRepair") as MeshInstance3D
			var repair_material := repair.material_override as StandardMaterial3D
			if not check(repair_material.albedo_texture == wall.albedo_texture,
				"The repair and wall share the selected wallpaper instead of stale stock"): return
		elif i == 3 and not check(quantized, "%s has 32 levels per channel" % names[i]): return
		elif i in [1, 2] and not check(not quantized, "%s keeps detail before PSX grading" % names[i]): return
	if not check(wall.uv1_scale.is_equal_approx(Vector3.ONE * 1.6),
			"Wallpaper keeps the original stripe scale"): return
	if not check(wall.albedo_color.is_equal_approx(Color(0.78, 0.76, 0.72)),
			"Wallpaper keeps its original material tint"): return
	if not check(felt.roughness >= 0.995 and felt.specular_mode == BaseMaterial3D.SPECULAR_DISABLED,
			"Baize remains fully matte"): return
	if not check(felt.albedo_color == Color.WHITE, "Baize uses the palette in its authored texture"): return
	var face := load("res://materials/style_tests/form_night_copy.tres") as StandardMaterial3D
	if not check(face.albedo_texture.resource_path.begins_with("res://materials/style_tests/textures/psx/"),
			"Printed copy form is not replaced by blank stock"): return
	office.free()
	print("--- Worn Warmth Material Tests PASSED (%d assertions) ---" % _passed)
	quit(0)

func check(ok: bool, description: String) -> bool:
	print(("  PASS: " if ok else "  FAIL: ") + description)
	if ok:
		_passed += 1
	else:
		quit(1)
	return ok
