class_name TitleMood
extends Control

## Live 3D station diorama behind the FORM 19 menu.
## Renders TitleBackdrop3D inside an isolated SubViewport through our 5-bit
## Bayer PSX grade shader, keeping menu typography razor-sharp above it.

signal sounder_pulse()

const BACKDROP_SCENE := preload("res://scenes/ui/title_backdrop_3d.tscn")
const PSX_GRADE_SHADER := preload("res://materials/shaders/psx_grade.gdshader")
const FALLBACK_TEXTURE := preload("res://assets/textures/title/title_window.png")

var _container: SubViewportContainer = null
var _viewport: SubViewport = null
var _backdrop: TitleBackdrop3D = null
var _grade_rect: ColorRect = null
var _fade_overlay: ColorRect = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_live_diorama()
	_build_dark_veil()
	_build_fade_overlay()

func _build_live_diorama() -> void:
	_container = SubViewportContainer.new()
	_container.name = "DioramaFrame"
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.stretch_shrink = 2
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)

	_viewport = SubViewport.new()
	_viewport.name = "DioramaViewport"
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = Vector2i(640, 360)
	_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_taa = false
	_viewport.use_debanding = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_container.add_child(_viewport)

	_backdrop = BACKDROP_SCENE.instantiate() as TitleBackdrop3D
	if _backdrop != null:
		_viewport.add_child(_backdrop)
		_backdrop.sounder_pulse.connect(func() -> void: sounder_pulse.emit())

	var grade_layer := CanvasLayer.new()
	grade_layer.layer = 1
	_viewport.add_child(grade_layer)
	_grade_rect = ColorRect.new()
	_grade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PSX_GRADE_SHADER
	mat.set_shader_parameter("pixel_size", 1.0)
	mat.set_shader_parameter("levels", 32.0)
	mat.set_shader_parameter("color_saturation", 0.88)
	mat.set_shader_parameter("shadow_tint", Vector3(0.004, 0.007, 0.016))
	mat.set_shader_parameter("highlight_tint", Vector3(1.03, 0.99, 0.93))
	mat.set_shader_parameter("shadow_crush_factor", 0.94)
	mat.set_shader_parameter("vignette", 0.24)
	mat.set_shader_parameter("grain", 0.024)
	mat.set_shader_parameter("dither_strength", 1.25)
	_grade_rect.material = mat
	grade_layer.add_child(_grade_rect)

func _build_dark_veil() -> void:
	var shade := TextureRect.new()
	shade.name = "MenuVeil"
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.01, 0.01, 0.014, 0.0))
	gradient.set_color(1, Color(0.01, 0.01, 0.014, 0.88))
	gradient.add_point(0.46, Color(0.01, 0.01, 0.014, 0.20))
	gradient.add_point(0.62, Color(0.01, 0.01, 0.014, 0.68))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

func _build_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "EnterFade"
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)

func _input(event: InputEvent) -> void:
	if _backdrop == null or not (event is InputEventMouseMotion):
		return
	var rect := get_viewport_rect().size
	if rect.x <= 1.0 or rect.y <= 1.0:
		return
	var pos := (event as InputEventMouseMotion).position
	var norm := Vector2(
		(pos.x / rect.x) * 2.0 - 1.0,
		(pos.y / rect.y) * 2.0 - 1.0
	)
	_backdrop.set_mouse_normalized(norm)

func get_backdrop() -> Texture2D:
	if _viewport != null:
		return _viewport.get_texture()
	return FALLBACK_TEXTURE

func get_backdrop_3d() -> TitleBackdrop3D:
	return _backdrop

func set_options_open(open: bool) -> void:
	if _backdrop != null:
		_backdrop.set_options_open(open)

func advance_mood(delta: float) -> void:
	if _backdrop != null:
		_backdrop.advance_visual(delta)

func play_enter_transition(duration: float = 0.36) -> void:
	if _backdrop != null:
		_backdrop.play_enter_transition()
	if _fade_overlay != null and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(_fade_overlay, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
