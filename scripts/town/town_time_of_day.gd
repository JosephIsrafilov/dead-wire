class_name TownTimeOfDay
extends Node

## Drives Black Creek's sky, sun, fog, streetlamps, window glow, PSX grade,
## and ambient wind/bird audio across DAWN, DAY_CLEAR, DAY_GOLDEN, and DUSK.

const PRESET_NIGHT_APPROACH := &"NIGHT_APPROACH"
const PRESET_DAWN := &"DAWN"
const PRESET_DAY_CLEAR := &"DAY_CLEAR"
const PRESET_DAY_GOLDEN := &"DAY_GOLDEN"
const PRESET_DUSK := &"DUSK"

const NIGHT_WIND_LOOP := preload("res://audio/sfx/ambience/wind_window.wav")
const DAWN_WIND_STREAM := preload("res://audio/sfx/town/dawn_mountain_wind.wav")
const DAY_AMBIENCE_STREAM := preload("res://audio/sfx/town/day_town_ambience.wav")

@export var world_env: WorldEnvironment = null
@export var sun_light: DirectionalLight3D = null
@export var psx_host: PSXPresentationHost = null
@export var ambient_player: AudioStreamPlayer = null

var current_preset: StringName = PRESET_DAY_CLEAR
var _bell_rung_in: StringName = &""

func apply_preset(preset: StringName, architecture_root: Node3D = null) -> void:
	current_preset = preset
	if psx_host != null:
		var grade_preset := &"NIGHT" if preset == PRESET_NIGHT_APPROACH else preset
		psx_host.apply_grade_preset(grade_preset)
	_apply_environment(preset)
	_apply_sun(preset)
	_apply_town_lights(preset, architecture_root)
	if architecture_root != null:
		var life := architecture_root.get_node_or_null("StreetLife")
		if life != null:
			life.apply_preset(preset)
	_apply_ambience(preset)

func _apply_environment(preset: StringName) -> void:
	if world_env == null or world_env.environment == null:
		return
	if not world_env.environment.has_meta(&"town_env_unique"):
		world_env.environment = world_env.environment.duplicate(true) as Environment
		world_env.environment.set_meta(&"town_env_unique", true)
	var env := world_env.environment
	env.volumetric_fog_enabled = false
	var sky_mat: ProceduralSkyMaterial = null
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	match preset:
		PRESET_NIGHT_APPROACH:
			env.ambient_light_color = Color(0.24, 0.31, 0.42)
			env.ambient_light_energy = 0.24
			env.tonemap_exposure = 1.06
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_DEPTH
			env.fog_depth_begin = 3.5
			env.fog_depth_end = 30.0
			env.fog_light_color = Color(0.11, 0.16, 0.24)
			env.fog_density = 0.95
			env.fog_sky_affect = 0.78
			if sky_mat != null:
				sky_mat.sky_top_color = Color(0.03, 0.05, 0.09)
				sky_mat.sky_horizon_color = Color(0.10, 0.14, 0.20)
				sky_mat.sky_curve = 0.18
				sky_mat.ground_bottom_color = Color(0.03, 0.04, 0.06)
				sky_mat.ground_horizon_color = Color(0.08, 0.11, 0.15)
		PRESET_DAWN:
			env.ambient_light_color = Color(0.48, 0.56, 0.65)
			env.ambient_light_energy = 0.28
			env.tonemap_exposure = 1.05
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_DEPTH
			env.fog_depth_begin = 10.0
			env.fog_depth_end = 56.0
			env.fog_light_color = Color(0.46, 0.54, 0.62)
			env.fog_density = 0.82
			env.fog_sky_affect = 0.48
			if sky_mat != null:
				sky_mat.sky_top_color = Color(0.20, 0.27, 0.36)
				sky_mat.sky_horizon_color = Color(0.56, 0.63, 0.69)
				sky_mat.sky_curve = 0.14
				sky_mat.ground_bottom_color = Color(0.15, 0.17, 0.20)
				sky_mat.ground_horizon_color = Color(0.42, 0.47, 0.52)
		PRESET_DAY_GOLDEN:
			env.ambient_light_color = Color(0.92, 0.82, 0.66)
			env.ambient_light_energy = 0.38
			env.tonemap_exposure = 1.10
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_DEPTH
			env.fog_depth_begin = 55.0
			env.fog_depth_end = 240.0
			env.fog_light_color = Color(0.86, 0.80, 0.68)
			env.fog_density = 0.35
			env.fog_sky_affect = 0.08
			if sky_mat != null:
				sky_mat.sky_top_color = Color(0.20, 0.44, 0.76)
				sky_mat.sky_horizon_color = Color(0.92, 0.84, 0.68)
				sky_mat.sky_curve = 0.07
				sky_mat.ground_bottom_color = Color(0.28, 0.23, 0.18)
				sky_mat.ground_horizon_color = Color(0.75, 0.66, 0.52)
		PRESET_DUSK:
			env.ambient_light_color = Color(0.54, 0.50, 0.60)
			env.ambient_light_energy = 0.26
			env.tonemap_exposure = 1.04
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_DEPTH
			env.fog_depth_begin = 18.0
			env.fog_depth_end = 110.0
			env.fog_light_color = Color(0.52, 0.46, 0.56)
			env.fog_density = 0.65
			env.fog_sky_affect = 0.25
			if sky_mat != null:
				sky_mat.sky_top_color = Color(0.16, 0.20, 0.34)
				sky_mat.sky_horizon_color = Color(0.72, 0.52, 0.46)
				sky_mat.sky_curve = 0.12
				sky_mat.ground_bottom_color = Color(0.16, 0.14, 0.16)
				sky_mat.ground_horizon_color = Color(0.44, 0.36, 0.34)
		_:
			env.ambient_light_color = Color(0.82, 0.86, 0.92)
			env.ambient_light_energy = 0.36
			env.tonemap_exposure = 1.04
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_DEPTH
			# Colorado's 1890 sky is high, thin and cold: the veil starts further
			# out than a humid valley's and stays grey-blue instead of white.
			env.fog_depth_begin = 78.0
			env.fog_depth_end = 330.0
			env.fog_light_color = Color(0.52, 0.63, 0.75)
			env.fog_density = 0.30
			env.fog_sky_affect = 0.0
			if sky_mat != null:
				sky_mat.sky_top_color = Color(0.043, 0.196, 0.470)
				sky_mat.sky_horizon_color = Color(0.545, 0.678, 0.804)
				sky_mat.sky_curve = 0.28
				sky_mat.ground_bottom_color = Color(0.26, 0.235, 0.196)
				sky_mat.ground_horizon_color = Color(0.560, 0.652, 0.722)
				sky_mat.sun_angle_max = 8.0
				sky_mat.sun_curve = 0.30

func _apply_sun(preset: StringName) -> void:
	if sun_light == null:
		return
	match preset:
		PRESET_NIGHT_APPROACH:
			sun_light.light_color = Color(0.45, 0.56, 0.76)
			sun_light.light_energy = 0.16
			sun_light.rotation_degrees = Vector3(-28.0, 48.0, 0.0)
		PRESET_DAWN:
			sun_light.light_color = Color(0.72, 0.80, 0.88)
			sun_light.light_energy = 0.42
			sun_light.rotation_degrees = Vector3(-16.0, 62.0, 0.0)
		PRESET_DAY_GOLDEN:
			sun_light.light_color = Color(1.0, 0.83, 0.58)
			sun_light.light_energy = 1.42
			sun_light.rotation_degrees = Vector3(-24.0, -52.0, 0.0)
		PRESET_DUSK:
			sun_light.light_color = Color(0.88, 0.62, 0.50)
			sun_light.light_energy = 0.48
			sun_light.rotation_degrees = Vector3(-12.0, -70.0, 0.0)
		_:
			sun_light.light_color = Color(1.0, 0.92, 0.78)
			sun_light.light_energy = 1.40
			sun_light.rotation_degrees = Vector3(-40.0, 140.0, 0.0)

func _apply_town_lights(preset: StringName, architecture_root: Node3D) -> void:
	if architecture_root == null:
		return
	_ring_chapel_bell(preset, architecture_root)
	var is_night := preset == PRESET_NIGHT_APPROACH
	var lamps_lit := is_night or preset == PRESET_DAWN or preset == PRESET_DUSK
	for node in architecture_root.find_children("*", "Node3D", true, false):
		if node.is_in_group(&"town_oil_flame"):
			(node as Node3D).visible = lamps_lit
		elif node.is_in_group(&"town_night_only"):
			(node as Node3D).visible = is_night
	for node in architecture_root.find_children("*", "Light3D", true, false):
		if node.is_in_group(&"town_night_lamp"):
			(node as Light3D).visible = lamps_lit
	var day_win := load("res://assets/textures/town_v1/window_panes_day_64.png") as Texture2D
	var lit_win := load("res://assets/textures/town_v1/window_panes_lit_64.png") as Texture2D
	for node in architecture_root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.is_in_group(&"town_operator_bay"):
			var bay := mi.material_override as StandardMaterial3D
			bay.emission_enabled = lamps_lit
			bay.emission = Color(0.94, 0.57, 0.26)
			bay.emission_energy_multiplier = 0.46
		elif mi.is_in_group(&"town_saloon_window") or mi.is_in_group(&"town_porch_window"):
			var mat := mi.material_override as StandardMaterial3D
			if mat == null:
				continue
			# At Night/Dawn: Saloon is closed & dark; Depot/Boarding House windows glow warmly.
			var show_warm := false
			if mi.is_in_group(&"town_porch_window"):
				show_warm = lamps_lit
			elif mi.is_in_group(&"town_saloon_window"):
				show_warm = (preset == PRESET_DAY_CLEAR or preset == PRESET_DAY_GOLDEN or preset == PRESET_DUSK)
			mat.albedo_texture = lit_win if show_warm else day_win
			mat.emission_enabled = show_warm
			if is_night:
				mat.emission = Color(1.0, 0.72, 0.34)
				mat.emission_energy_multiplier = 1.15
			else:
				mat.emission = Color(0.90, 0.64, 0.26) if lamps_lit else Color(0.68, 0.46, 0.18)
				mat.emission_energy_multiplier = 0.75 if lamps_lit else 0.30

func _ring_chapel_bell(preset: StringName, architecture_root: Node3D) -> void:
	# Noon and dusk only: a Colorado camp chapel rang the Angelus, not the hours.
	# DUSK is the evening call, DAY_CLEAR stands in for the 11:30-noon beat the
	# HUD clock shows, so a player who looks up from the street hears it once.
	var should_ring := preset == PRESET_DUSK or preset == PRESET_DAY_CLEAR
	if not should_ring or _bell_rung_in == preset:
		return
	var chapel := architecture_root.get_node_or_null("HillsideBackdrop/chapel_steeple/ChapelBell")
	if chapel == null:
		chapel = architecture_root.find_child("ChapelBell", true, false)
	var bell := chapel as AudioStreamPlayer3D
	if bell == null:
		return
	_bell_rung_in = preset
	if DisplayServer.get_name() != "headless":
		bell.play()

func _apply_ambience(preset: StringName) -> void:
	if ambient_player == null:
		return
	var target_stream: AudioStream = DAY_AMBIENCE_STREAM
	if preset == PRESET_NIGHT_APPROACH:
		target_stream = NIGHT_WIND_LOOP
	elif preset == PRESET_DAWN or preset == PRESET_DUSK:
		target_stream = DAWN_WIND_STREAM
	if ambient_player.stream != target_stream:
		ambient_player.stream = target_stream
	if not ambient_player.playing and DisplayServer.get_name() != "headless":
		ambient_player.play()
