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
	var low_resolution: bool = profile.grade_enabled
	source.size = profile.content_size if low_resolution else window_size
	source.size_2d_override = Vector2i.ZERO if low_resolution else Vector2i(1280, 720)
	source.size_2d_override_stretch = not low_resolution
	size = Vector2(source.size)
	var factor := minf(float(window_size.x) / size.x, float(window_size.y) / size.y)
	scale = Vector2.ONE * factor
	position = (Vector2(window_size) - size * factor) * 0.5
	(material as ShaderMaterial).set_shader_parameter("prescale", maxf(1.0, ceilf(factor)))
