extends SceneTree

## Extracts the engine's bundled fallback font into a project resource, so
## every critical Label3D renders with ONE embedded font instead of whatever
## the host machine's fallback happens to be. The fallback font ships with
## Godot itself (same license as the engine's bundled font); no OS font is
## copied.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var font := ThemeDB.fallback_font
	if font == null or not font is FontFile or (font as FontFile).data == null:
		printerr("EXTRACT: fallback font has no embeddable data")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://assets/fonts")
	var err := ResourceSaver.save(font, "res://assets/fonts/deadwire_body.res")
	if err != OK:
		printerr("EXTRACT: save failed with %s" % err)
		quit(1)
		return
	var reloaded := load("res://assets/fonts/deadwire_body.res") as FontFile
	print("EXTRACT: saved, reload ok=", reloaded != null, " face_count=", reloaded.get_face_count() if reloaded != null else 0)
	quit(0)
