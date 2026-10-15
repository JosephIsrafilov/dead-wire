extends SceneTree

## GPU sampling contract for the READABLE grade (windowed; headless refuses,
## exit 2). A one-pixel-wide stripe pattern is rendered BELOW the psx_grade
## shader inside an exact-size offscreen SubViewport; a solid UI control sits
## ABOVE it. READABLE (divisor 1) must let every adjacent screen sample differ
## where the pattern demands — the shader may not repeat one sample across a
## 2x2 cell. CLASSIC must show the enlarged cell. The final phase captures a
## frozen office frame in READABLE at 1280x720 for the before/after A/B pair.
##   godot --path . --script res://tools/readable_sampling_capture.gd

const OUT_DIR := "res://.dream-loop/readable_sampling"
const STRIPE_SHADER_SRC := "shader_type canvas_item;
void fragment() {
	float col = floor(FRAGCOORD.x);
	COLOR = vec4(vec3(mod(col, 2.0)), 1.0);
}"

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("READABLE SAMPLING: real framebuffer needed; run without --headless")
		quit(2)
		return
	await _fixture(Vector2i(1920, 1080), 1)
	await _fixture(Vector2i(1280, 720), 1)
	await _fixture(Vector2i(1920, 1080), 0)
	await _fixture(Vector2i(1280, 720), 0)
	await _office_frame()
	print("READABLE SAMPLING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _fixture(buffer: Vector2i, mode: int) -> void:
	var profile: Dictionary = ReadabilityPolicy.profile(buffer.y, mode)
	var pixel_size: int = int(profile.pixel_size)
	var vp := SubViewport.new()
	vp.size = buffer
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)

	var stripes := ColorRect.new()
	stripes.size = Vector2(buffer)
	var stripe_shader := Shader.new()
	stripe_shader.set_code(STRIPE_SHADER_SRC)
	var stripe_mat := ShaderMaterial.new()
	stripe_mat.shader = stripe_shader
	stripes.material = stripe_mat
	vp.add_child(stripes)

	var grade := ColorRect.new()
	grade.size = Vector2(buffer)
	var grade_mat := ShaderMaterial.new()
	grade_mat.shader = load("res://materials/shaders/psx_grade.gdshader")
	grade_mat.set_shader_parameter("pixel_size", float(pixel_size))
	grade_mat.set_shader_parameter("levels", profile.levels)
	grade_mat.set_shader_parameter("vignette", profile.vignette)
	grade.material = grade_mat
	vp.add_child(grade)

	# A solid control above the grade: document-style UI must stay untouched.
	var ui := ColorRect.new()
	ui.color = Color(1.0, 1.0, 1.0, 1.0)
	ui.position = Vector2(24.0, 24.0)
	ui.size = Vector2(48.0, 48.0)
	vp.add_child(ui)

	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	print("  [fixture] mode=%s buffer=%dx%d policy_pixel_size=%d image=%s"
		% ["READABLE" if mode == 1 else "CLASSIC", buffer.x, buffer.y, pixel_size,
			str(image.get_size())])
	if not check(image.get_size() == buffer, "Readback matches the requested render buffer"):
		vp.queue_free()
		return
	var row := int(buffer.y * 0.5)
	if pixel_size <= 1:
		# Every horizontally adjacent pair crosses a stripe boundary: the
		# shader must not collapse the pair to one shared sample.
		var collapsed := 0
		for x in range(0, buffer.x - 1):
			if absf(_luminance(image.get_pixel(x, row)) - _luminance(image.get_pixel(x + 1, row))) < 0.08:
				collapsed += 1
		check(collapsed == 0,
			"READABLE divisor 1 keeps every adjacent screen sample distinct (%d of %d collapsed)"
				% [collapsed, buffer.x - 1])
	else:
		# Pairs strictly inside one sampling cell share the shader's single
		# snapped sample: the enlarged cell is the CLASSIC look. The per-pixel
		# vignette can flip one quantization level (1/32) at a boundary.
		var inside_pairs := 0
		var mismatched := 0
		var x := 0
		while x + pixel_size <= buffer.x:
			for dx in range(pixel_size - 1):
				inside_pairs += 1
				if absf(_luminance(image.get_pixel(x + dx, row)) - _luminance(image.get_pixel(x + dx + 1, row))) > 0.03:
					mismatched += 1
			x += pixel_size
		check(inside_pairs > 0 and mismatched <= maxi(1, int(inside_pairs * 0.01)),
			"CLASSIC cell %d repeats one sample across the cell (%d of %d pairs beyond one level)"
				% [pixel_size, mismatched, inside_pairs])
	check(image.get_pixel(48, 48).r > 0.999 and absf(image.get_pixel(48, 48).g - 1.0) < 0.001,
		"The UI control above the grade keeps its exact color")
	vp.queue_free()
	await process_frame

func _office_frame() -> void:
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	root.add_child(office)
	for i in 5:
		await process_frame
	office.get_node("IntroCard").skip_immediately()
	office.shift_director.enabled = false
	office.session_controller.scheduler.auto_process = false
	office.get_node("LampLife").set_wick_immediate(1.0)
	office.apply_presentation_mode(1)
	root.size = Vector2i(1280, 720)
	for i in 5:
		await process_frame
	var grade := office.get_node_or_null("PSXDither/Grade") as CanvasItem
	var cell: float = 0.0
	if grade != null and grade.material is ShaderMaterial:
		cell = float((grade.material as ShaderMaterial).get_shader_parameter("pixel_size"))
	print("  [office] window=%dx%d readable cell=%.1f scale=%.3f"
		% [root.size.x, root.size.y, cell, root.scaling_3d_scale])
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var image := root.get_texture().get_image()
	if image != null:
		check(image.save_png(OUT_DIR.path_join("readable_office_720.png")) == OK,
			"Captured readable_office_720.png (%s, cell %.1f)" % [str(image.get_size()), cell])
	office.queue_free()
	await process_frame
	await process_frame

func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

func check(condition: bool, message: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)
	return condition
