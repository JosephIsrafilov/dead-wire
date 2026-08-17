class_name PSXStyleRuntime
extends Node3D

@export var enable_psx_rendering: bool = true
@export_range(0.25, 1.0, 0.05) var render_scale: float = 0.5

func _ready() -> void:
	if not enable_psx_rendering:
		return
	apply_psx_settings()

func apply_psx_settings() -> void:
	var vp: Viewport = get_viewport()
	if not vp:
		return
	
	# Set 3D buffer render scale (0.5 = authentic PSX half-resolution)
	vp.scaling_3d_scale = clampf(render_scale, 0.25, 1.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	
	# Disable modern anti-aliasing to preserve crisp pixel edges
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.use_debanding = false
