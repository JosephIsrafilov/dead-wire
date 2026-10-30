extends SceneTree

## Which UV actually lands on which atlas tile?
##
## The prop atlas is addressed by hand here (the coat is not in the exported
## mesh any more, so no importer flips anything for it). Blender's UV origin is
## bottom-left and Godot's texture origin is top-left, so a tile index taken
## straight from the generator's TILES table samples the wrong row unless the V
## is flipped. This prints the real colour at each candidate so the correct V is
## measured instead of assumed.
##
##   godot --headless --audio-driver Dummy --path . --script tools/atlas_probe.gd

## name -> (tx, ty) exactly as tools/build_office_props_blender.py declares it
const TILES := {
	"dark_wood": [0, 0], "mid_wood": [1, 0], "brass": [2, 0], "iron": [3, 0],
	"paper": [0, 1], "enamel": [1, 1], "leather": [2, 1], "glass": [3, 1],
	"slate": [0, 2], "baize": [1, 2], "worn_wood": [2, 2], "stained_wood": [3, 2],
	"rust": [0, 3], "knot_wood": [1, 3], "wool": [2, 3], "dust": [3, 3],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var tex := load("res://assets/textures/office_props_v1/props_atlas_256.png") as Texture2D
	if tex == null:
		print("NO ATLAS")
		quit(1)
		return
	var img := tex.get_image()
	print("atlas %dx%d" % [img.get_width(), img.get_height()])
	print("--- colour at the centre of each tile, using the GENERATOR's UV directly ---")
	for name in TILES:
		var tile: Array = TILES[name]
		var u := (float(tile[0]) * 64.0 + 32.0) / 256.0
		var v := (float(tile[1]) * 64.0 + 32.0) / 256.0
		var c := img.get_pixel(int(u * 255.0), int(v * 255.0))
		print("  %-13s uv(%.3f, %.3f) -> rgb %3d %3d %3d" % [
			name, u, v, int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)])
	print("--- same tiles with V FLIPPED (1-v) ---")
	for name in TILES:
		var tile: Array = TILES[name]
		var u := (float(tile[0]) * 64.0 + 32.0) / 256.0
		var v := 1.0 - (float(tile[1]) * 64.0 + 32.0) / 256.0
		var c := img.get_pixel(int(u * 255.0), int(v * 255.0))
		print("  %-13s uv(%.3f, %.3f) -> rgb %3d %3d %3d" % [
			name, u, v, int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)])
	quit(0)
