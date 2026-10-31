class_name GameSettings
extends RefCounted

## Player-facing options, stored outside the project so they survive a rebuild.
##
## Head bob in particular has to be a player choice rather than a designer's: the
## research is consistent that some players need it for the room to read as a
## space at all, and others get motion sick from the same amount. Shipping it as
## an exported constant is not good enough.

const CONFIG_PATH: String = "user://settings.cfg"
## The test runner points this at a scratch file so suites start from defaults
## and never overwrite the player's own settings.
const PATH_OVERRIDE_ENV: String = "DEAD_WIRE_SETTINGS_PATH"
const SECTION: String = "options"

var mouse_sensitivity: float = 0.003
var head_bob_enabled: bool = true
var master_volume_db: float = 0.0
var ambience_volume_db: float = -4.0
var telegraph_volume_db: float = 0.0
var foley_volume_db: float = 0.0
var contextual_thoughts_enabled: bool = true
var presentation_mode: int = 1
var vertical_fov: float = 65.0
var text_scale: float = 1.2
## Room exposure multiplier (plan 2.16). A dark room on a dark monitor is a
## black screen; the player sets this once at first launch.
var brightness: float = 1.0
var brightness_calibrated: bool = false
## Display and control options (plan 6.8).
var fullscreen: bool = false
var vsync: bool = true
## 0 = no limit.
var max_fps: int = 0
var invert_y: bool = false
## Captions for non-wire sounds (plan 6.9), off unless the player wants them.
var sound_captions: bool = false
const FPS_LIMITS: Array[int] = [0, 30, 60, 120, 144]
## The image/reading/display options a "Default" press restores.
const DEFAULTS := {
	"presentation_mode": 1, "vertical_fov": 65.0, "text_scale": 1.2, "brightness": 1.0,
	"fullscreen": false, "vsync": true, "max_fps": 0, "invert_y": false,
}

func restore_defaults() -> void:
	for key in DEFAULTS:
		set(key, DEFAULTS[key])

static func config_path() -> String:
	var override := OS.get_environment(PATH_OVERRIDE_ENV)
	return override if not override.is_empty() else CONFIG_PATH

static func load_settings(path: String = "") -> GameSettings:
	var settings := GameSettings.new()
	var config := ConfigFile.new()
	if config.load(path if not path.is_empty() else config_path()) != OK:
		return settings

	settings.mouse_sensitivity = float(config.get_value(SECTION, "mouse_sensitivity", settings.mouse_sensitivity))
	settings.head_bob_enabled = bool(config.get_value(SECTION, "head_bob_enabled", settings.head_bob_enabled))
	settings.master_volume_db = float(config.get_value(SECTION, "master_volume_db", settings.master_volume_db))
	settings.ambience_volume_db = float(config.get_value(SECTION, "ambience_volume_db", settings.ambience_volume_db))
	settings.telegraph_volume_db = float(config.get_value(SECTION, "telegraph_volume_db", settings.telegraph_volume_db))
	settings.foley_volume_db = float(config.get_value(SECTION, "foley_volume_db", settings.foley_volume_db))
	settings.contextual_thoughts_enabled = bool(config.get_value(
		SECTION, "contextual_thoughts_enabled", settings.contextual_thoughts_enabled
	))
	settings.presentation_mode = int(config.get_value(SECTION, "presentation_mode", settings.presentation_mode))
	settings.vertical_fov = float(config.get_value(SECTION, "vertical_fov", settings.vertical_fov))
	settings.text_scale = float(config.get_value(SECTION, "text_scale", settings.text_scale))
	settings.brightness = float(config.get_value(SECTION, "brightness", settings.brightness))
	settings.brightness_calibrated = bool(config.get_value(SECTION, "brightness_calibrated", false))
	settings.fullscreen = bool(config.get_value(SECTION, "fullscreen", settings.fullscreen))
	settings.vsync = bool(config.get_value(SECTION, "vsync", settings.vsync))
	settings.max_fps = int(config.get_value(SECTION, "max_fps", settings.max_fps))
	settings.invert_y = bool(config.get_value(SECTION, "invert_y", settings.invert_y))
	settings.sound_captions = bool(config.get_value(SECTION, "sound_captions", settings.sound_captions))
	settings.sanitize()
	return settings

## Clamps every numeric option to its bounds; non-finite values fall back to default.
func sanitize() -> void:
	mouse_sensitivity = clampf(mouse_sensitivity if is_finite(mouse_sensitivity) else 0.003, 0.0005, 0.008)
	master_volume_db = clampf(master_volume_db if is_finite(master_volume_db) else 0.0, -40.0, 6.0)
	ambience_volume_db = clampf(ambience_volume_db if is_finite(ambience_volume_db) else -4.0, -40.0, 6.0)
	telegraph_volume_db = clampf(telegraph_volume_db if is_finite(telegraph_volume_db) else 0.0, -40.0, 6.0)
	foley_volume_db = clampf(foley_volume_db if is_finite(foley_volume_db) else 0.0, -40.0, 6.0)
	presentation_mode = clampi(presentation_mode, 0, 2)
	vertical_fov = clampf(vertical_fov if is_finite(vertical_fov) else 65.0, 55.0, 85.0)
	text_scale = clampf(text_scale if is_finite(text_scale) else 1.2, 1.0, 1.5)
	brightness = clampf(brightness if is_finite(brightness) else 1.0, 0.6, 1.8)
	if max_fps not in FPS_LIMITS:
		max_fps = 0

func save(path: String = "") -> Error:
	sanitize()
	var config := ConfigFile.new()
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "head_bob_enabled", head_bob_enabled)
	config.set_value(SECTION, "master_volume_db", master_volume_db)
	config.set_value(SECTION, "ambience_volume_db", ambience_volume_db)
	config.set_value(SECTION, "telegraph_volume_db", telegraph_volume_db)
	config.set_value(SECTION, "foley_volume_db", foley_volume_db)
	config.set_value(SECTION, "contextual_thoughts_enabled", contextual_thoughts_enabled)
	config.set_value(SECTION, "presentation_mode", presentation_mode)
	config.set_value(SECTION, "vertical_fov", vertical_fov)
	config.set_value(SECTION, "text_scale", text_scale)
	config.set_value(SECTION, "brightness", brightness)
	config.set_value(SECTION, "brightness_calibrated", brightness_calibrated)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "vsync", vsync)
	config.set_value(SECTION, "max_fps", max_fps)
	config.set_value(SECTION, "invert_y", invert_y)
	config.set_value(SECTION, "sound_captions", sound_captions)
	return config.save(path if not path.is_empty() else config_path())

## Pushes the current values at the things they control.
func apply(player: PlayerController) -> void:
	sanitize()
	if player != null:
		player.mouse_sensitivity = mouse_sensitivity
		player.invert_y = invert_y
		player.head_bob_enabled = head_bob_enabled
		var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
		if camera != null:
			camera.fov = vertical_fov
		player.base_fov = vertical_fov
		var office := player.get_parent()
		_apply_brightness(office)
		var captions := office.get_node_or_null("SoundCaptions") if office != null else null
		if captions is SoundCaptions:
			(captions as SoundCaptions).enabled = sound_captions
		var guidance := office.get_node_or_null("NightGuidance") if office != null else null
		if guidance != null:
			for property in guidance.get_property_list():
				if property.name == "enabled":
					guidance.set("enabled", contextual_thoughts_enabled)
					break

	_set_bus_db("Master", master_volume_db)
	_set_bus_db("Ambience", ambience_volume_db)
	_set_bus_db("Telegraph", telegraph_volume_db)
	_set_bus_db("Foley", foley_volume_db)
	# Attention events (the steps beyond the door) follow the Foley setting.
	_set_bus_db("Events", foley_volume_db)
	apply_display()

## Window mode, VSync and the frame limit. Only what differs is touched, so a
## repeated apply never flickers the window; a headless run has no window.
func apply_display() -> void:
	Engine.max_fps = max_fps
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var wanted := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode() != wanted:
		DisplayServer.window_set_vsync_mode(wanted)

## Scales the room's authored exposure (kept as metadata so repeated applies
## never compound). The interface is not touched.
func _apply_brightness(office: Node) -> void:
	var env_node := office.get_node_or_null("WorldEnvironment") as WorldEnvironment if office != null else null
	if env_node == null or env_node.environment == null:
		return
	var environment := env_node.environment
	if not environment.has_meta(&"authored_exposure"):
		environment.set_meta(&"authored_exposure", environment.tonemap_exposure)
	environment.tonemap_exposure = float(environment.get_meta(&"authored_exposure")) * brightness

static func _set_bus_db(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, value)