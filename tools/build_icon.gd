extends SceneTree

## Plan 9.1: the game's own icon. Rasterises icon.svg (a telegraph pole under
## a cold moon, one wire snapped) at the sizes Windows asks for and writes
## icon.ico (PNG frames, which every Windows since Vista reads), plus 256 px
## and 32 px previews.
##
##   godot --headless --path . --script tools/build_icon.gd

const SIZES := [16, 24, 32, 48, 64, 128, 256]
const ICO_PATH := "res://icon.ico"
const PREVIEW_PATH := "res://.dream-loop/icon/icon_256.png"

func _initialize() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	var frames: Array[PackedByteArray] = []
	for size in SIZES:
		var image := Image.new()
		if image.load_svg_from_string(svg, float(size) / 128.0) != OK:
			printerr("FAIL: icon.svg does not rasterise at %d" % size)
			quit(1)
			return
		frames.append(image.save_png_to_buffer())
		if size == 256 or size == 32:
			DirAccess.make_dir_recursive_absolute(PREVIEW_PATH.get_base_dir())
			image.save_png(PREVIEW_PATH.replace("256", str(size)))
	var file := FileAccess.open(ICO_PATH, FileAccess.WRITE)
	file.store_16(0)
	file.store_16(1)
	file.store_16(SIZES.size())
	var offset := 6 + 16 * SIZES.size()
	for index in SIZES.size():
		var size: int = SIZES[index]
		file.store_8(0 if size >= 256 else size)
		file.store_8(0 if size >= 256 else size)
		file.store_8(0)
		file.store_8(0)
		file.store_16(1)
		file.store_16(32)
		file.store_32(frames[index].size())
		file.store_32(offset)
		offset += frames[index].size()
	for frame in frames:
		file.store_buffer(frame)
	file.close()
	print("ICON %d frames, %d bytes" % [SIZES.size(), offset])
	quit(0)
