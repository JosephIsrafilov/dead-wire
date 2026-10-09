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
		if not check(material.albedo_texture != null and material.albedo_texture.resource_path == expected,
				"%s uses its versioned candidate texture" % names[i]):
			office.free()
			return
		if not check(material.albedo_texture.get_size() == Vector2(128, 128),
				"%s uses the 128px grid" % names[i]): return
		if not check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
				"%s uses nearest filtering" % names[i]): return
		if not check(not material.normal_enabled, "%s has no new normal map" % names[i]): return
		var image := material.albedo_texture.get_image()
		image.convert(Image.FORMAT_RGB8)
		var quantized := true
		for byte in image.get_data():
			var level := int(round(float(byte) * 31.0 / 255.0))
			if byte != int(round(float(level) * 255.0 / 31.0)):
				quantized = false
				break
		if not check(quantized, "%s has 32 levels per channel" % names[i]): return
	if not check(wall.uv1_scale.is_equal_approx(Vector3.ONE * 1.6),
			"Wallpaper keeps the original stripe scale"): return
	if not check(wall.albedo_color.is_equal_approx(Color(0.78, 0.76, 0.72)),
			"Wallpaper keeps its original material tint"): return
	if not check(felt.roughness >= 0.995 and felt.specular_mode == BaseMaterial3D.SPECULAR_DISABLED,
			"Baize remains fully matte"): return
	if not check(felt.albedo_color.is_equal_approx(Color(0.05, 0.1, 0.07)),
			"Baize keeps its original tint"): return
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
