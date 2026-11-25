class_name PSXPresentationHost
extends Node

## Reusable SubViewport + sharp-bilinear + Bayer PSX grade wrapper for M2/M3 scenes.
## Keeps M1's exact visual pipeline without growing m1_office_controller.gd.

@export var enable_psx_rendering: bool = true
@export var default_preset: StringName = &"DAY_CLEAR"
@export var camera_path: NodePath = NodePath("../Player/Head/Camera3D")

const SHARP_BILINEAR_SHADER := preload("res://materials/shaders/sharp_bilinear.gdshader")
const PSX_GRADE_SHADER := preload("res://materials/shaders/psx_grade.gdshader")
const OFFICE_PRESENTATION_SCRIPT := preload("res://scripts/presentation/office_presentation.gd")

const GRADE_PRESETS: Dictionary = {
	&"NIGHT": {
		"saturation": 0.88,
		"shadow_tint": Vector3(0.004, 0.007, 0.016),
		"highlight_tint": Vector3(1.03, 0.99, 0.93),
		"crush": 0.94,
		"vignette": 0.09,
		"grain": 0.007,
		"dither_strength": 0.4,
	},
	&"DAWN": {
		"saturation": 0.82,
		"shadow_tint": Vector3(0.008, 0.012, 0.022),
		"highlight_tint": Vector3(1.00, 0.97, 0.94),
		"crush": 0.95,
		"vignette": 0.0762,
		"grain": 0.0051,
		"dither_strength": 0.3385,
	},
	&"DAY_CLEAR": {
		"saturation": 1.05,
		"shadow_tint": Vector3(0.006, 0.005, 0.010),
		"highlight_tint": Vector3(1.06, 1.01, 0.90),
		"crush": 0.98,
		"vignette": 0.0415,
		"grain": 0.0032,
		"dither_strength": 0.2523,
	},
	&"DAY_GOLDEN": {
		"saturation": 1.08,
		"shadow_tint": Vector3(0.010, 0.006, 0.012),
		"highlight_tint": Vector3(1.10, 0.98, 0.84),
		"crush": 0.97,
		"vignette": 0.0485,
		"grain": 0.0038,
		"dither_strength": 0.2831,
	},
	&"SALOON_WARM": {
		"saturation": 1.02,
		"shadow_tint": Vector3(0.014, 0.007, 0.003),
		"highlight_tint": Vector3(1.08, 0.97, 0.82),
		"crush": 0.96,
		"vignette": 0.0554,
		"grain": 0.0051,
		"dither_strength": 0.2954,
	},
	&"DUSK": {
		"saturation": 0.90,
		"shadow_tint": Vector3(0.012, 0.008, 0.020),
		"highlight_tint": Vector3(1.04, 0.92, 0.85),
		"crush": 0.94,
		"vignette": 0.0692,
		"grain": 0.0057,
		"dither_strength": 0.3385,
	},
}

var _presentation_mode: int = 1
var _active_preset: StringName = &"DAY_CLEAR"
var _window_state: Dictionary = {}
var _container: SubViewportContainer = null
var _grade_layer: CanvasLayer = null
var _grade_rect: ColorRect = null
var _reparenting: bool = false

func _ready() -> void:
	_active_preset = default_preset
	_presentation_mode = GameSettings.load_settings().presentation_mode
	_ensure_grade_layer()
	if enable_psx_rendering:
		_apply_psx_settings()
		_create_presentation_viewport.call_deferred()
	else:
		apply_grade_preset(_active_preset)

func _ensure_grade_layer() -> void:
	var host := get_parent()
	_grade_layer = get_node_or_null("PSXDither") as CanvasLayer
	if _grade_layer == null and host != null:
		_grade_layer = host.get_node_or_null("PSXDither") as CanvasLayer
	if _grade_layer == null:
		_grade_layer = CanvasLayer.new()
		_grade_layer.name = "PSXDither"
		_grade_layer.layer = 10
		add_child(_grade_layer)
	_grade_rect = _grade_layer.get_node_or_null("Grade") as ColorRect
	if _grade_rect == null:
		_grade_rect = ColorRect.new()
		_grade_rect.name = "Grade"
		_grade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = PSX_GRADE_SHADER
		_grade_rect.material = mat
		_grade_layer.add_child(_grade_rect)

func apply_presentation_mode(mode: int) -> void:
	_presentation_mode = clampi(mode, 0, 2)
	_apply_psx_scale()

func apply_grade_preset(preset: StringName) -> void:
	_active_preset = preset if GRADE_PRESETS.has(preset) else &"DAY_CLEAR"
	_apply_psx_scale()

func _apply_psx_settings() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	_apply_psx_scale()
	var window := get_window()
	if window != null and not window.size_changed.is_connected(_apply_psx_scale):
		window.size_changed.connect(_apply_psx_scale)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.use_debanding = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

func _apply_psx_scale() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var window := get_window()
	var height := window.size.y if window != null and window.size.y > 0 else 720
	var profile := ReadabilityPolicy.profile(height, _presentation_mode)
	if _container != null and is_instance_valid(_container) and window != null:
		_container.configure(window.size, profile)
	vp.scaling_3d_scale = profile.scale
	if _grade_rect != null:
		_grade_rect.visible = enable_psx_rendering and profile.grade_enabled
		if _grade_rect.material is ShaderMaterial:
			var mat := _grade_rect.material as ShaderMaterial
			var preset_data: Dictionary = GRADE_PRESETS.get(_active_preset, GRADE_PRESETS[&"DAY_CLEAR"])
			ReadabilityPolicy.apply_grade_to_material(mat, profile, preset_data)
			mat.set_shader_parameter("color_saturation", float(preset_data["saturation"]))
			mat.set_shader_parameter("shadow_tint", preset_data["shadow_tint"])
			mat.set_shader_parameter("highlight_tint", preset_data["highlight_tint"])
			mat.set_shader_parameter("shadow_crush_factor", float(preset_data["crush"]))

func _create_presentation_viewport() -> void:
	var host := get_parent()
	if host == null or not is_inside_tree() or not host.is_inside_tree():
		return
	if DisplayServer.get_name() == "headless":
		_apply_psx_scale()
		return
	var window := get_window()
	if window == null:
		return
	for prop in ["content_scale_size", "content_scale_mode", "content_scale_aspect", "content_scale_stretch"]:
		_window_state[prop] = window.get(prop)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var container := SubViewportContainer.new()
	container.set_script(OFFICE_PRESENTATION_SCRIPT)
	container.name = "OfficePresentation"
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	var output_mat := ShaderMaterial.new()
	output_mat.shader = SHARP_BILINEAR_SHADER
	container.material = output_mat
	var source := SubViewport.new()
	source.name = "OfficeFrame"
	source.own_world_3d = true
	source.handle_input_locally = true
	source.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.attach_source(source)
	window.add_child(container)
	_container = container
	var was_current := get_tree().current_scene == host
	_reparenting = true
	host.reparent(source)
	_reparenting = false
	if was_current:
		get_tree().current_scene = container
	var cam := get_node_or_null(camera_path) as Camera3D
	if cam != null:
		cam.make_current()
	_apply_psx_settings()

func _exit_tree() -> void:
	if _reparenting:
		return
	var container := _container
	_container = null
	var window := get_window() if is_inside_tree() else null
	if window != null:
		if window.size_changed.is_connected(_apply_psx_scale):
			window.size_changed.disconnect(_apply_psx_scale)
		for prop in _window_state:
			window.set(prop, _window_state[prop])
	if container != null and is_instance_valid(container):
		container.queue_free()
