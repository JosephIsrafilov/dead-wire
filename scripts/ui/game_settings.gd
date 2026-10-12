class_name GameSettings
extends RefCounted

## Player-facing options, stored outside the project so they survive a rebuild.
##
## Head bob in particular has to be a player choice rather than a designer's: the
## research is consistent that some players need it for the room to read as a
## space at all, and others get motion sick from the same amount. Shipping it as
## an exported constant is not good enough.

const CONFIG_PATH: String = "user://settings.cfg"
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

static func load_settings(path: String = CONFIG_PATH) -> GameSettings:
	var settings := GameSettings.new()
	var config := ConfigFile.new()
	if config.load(path) != OK:
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

func save(path: String = CONFIG_PATH) -> Error:
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
	return config.save(path)

## Pushes the current values at the things they control.
func apply(player: PlayerController) -> void:
	sanitize()
	if player != null:
		player.mouse_sensitivity = mouse_sensitivity
		player.head_bob_enabled = head_bob_enabled
		var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
		if camera != null:
			camera.fov = vertical_fov
		var office := player.get_parent()
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

static func _set_bus_db(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, value)