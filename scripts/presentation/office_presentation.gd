extends SubViewportContainer

## One low-resolution frame, including every CanvasLayer, reaches the window.
## The container also maps pointer input back into that frame.
var source: SubViewport

## Input reaches the office through this container, so it stays awake while the
## tree is paused (Escape must still resume); the frame and the office stop.
func attach_source(frame: SubViewport) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	frame.process_mode = Node.PROCESS_MODE_PAUSABLE
	# A SubViewport built in code does not read the project's shadow atlas
	# setting; without this the lamp casts through a smaller atlas than the
	# window used to give it. The quality preset picks the size (plan 10.3).
	frame.positional_shadow_atlas_size = GameSettings.load_settings().shadow_atlas_size()
	# Nor does it listen: with its own world, every positional sound in the
	# office (sounder, clock, pen, steps) is heard only through this frame.
	frame.audio_listener_enable_3d = true
	add_child(frame)
	source = frame

func configure(window_size: Vector2i, profile: Dictionary) -> void:
	var safe_window := Vector2i(maxi(window_size.x, 1), maxi(window_size.y, 1))
	var low_resolution: bool = profile.grade_enabled
	var target_size: Vector2i = profile.content_size if low_resolution else safe_window
	source.size = Vector2i(maxi(target_size.x, 1), maxi(target_size.y, 1))
	source.size_2d_override = Vector2i.ZERO if low_resolution else Vector2i(1280, 720)
	source.size_2d_override_stretch = not low_resolution
	var safe_source := Vector2(float(source.size.x), float(source.size.y))
	size = safe_source
	var factor := minf(float(safe_window.x) / safe_source.x, float(safe_window.y) / safe_source.y)
	scale = Vector2.ONE * factor
	position = (Vector2(safe_window) - safe_source * factor) * 0.5
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("prescale", maxf(1.0, ceilf(factor)))
