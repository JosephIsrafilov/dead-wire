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

static func load_settings() -> GameSettings:
	var settings := GameSettings.new()
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return settings

	settings.mouse_sensitivity = float(config.get_value(SECTION, "mouse_sensitivity", settings.mouse_sensitivity))
	settings.head_bob_enabled = bool(config.get_value(SECTION, "head_bob_enabled", settings.head_bob_enabled))
	settings.master_volume_db = float(config.get_value(SECTION, "master_volume_db", settings.master_volume_db))
	settings.ambience_volume_db = float(config.get_value(SECTION, "ambience_volume_db", settings.ambience_volume_db))
	return settings

func save() -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION, "head_bob_enabled", head_bob_enabled)
	config.set_value(SECTION, "master_volume_db", master_volume_db)
	config.set_value(SECTION, "ambience_volume_db", ambience_volume_db)
	return config.save(CONFIG_PATH)

## Pushes the current values at the things they control.
func apply(player: PlayerController) -> void:
	if player != null:
		player.mouse_sensitivity = mouse_sensitivity
		player.head_bob_enabled = head_bob_enabled

	_set_bus_db("Master", master_volume_db)
	_set_bus_db("Ambience", ambience_volume_db)

static func _set_bus_db(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, value)
