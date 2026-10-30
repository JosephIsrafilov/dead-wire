extends SceneTree
## Every pinned paper on the night register board keeps its ink.
##
## The board's failure mode is silent: a Label3D whose paper moved in the
## Blender generator but not in the .res renders its text floating on bare
## baize, and nothing in the game complains. That happened once already — the
## mesh was rebuilt, Godot served a stale imported .glb, and the ink and the
## paper disagreed on screen while the AABB checks both said OK.
##
## So this asserts the two things that actually have to hold, measured against
## the scene as it loads:
##   1. Each notice's ink sits inside its own paper rectangle.
##   2. The papers are distributed over the baize, not clustered in one band
##      (the "unfinished display case" read).
##
##   godot --headless --audio-driver Dummy --path . --script tests/office/notice_board_layout_test.gd

## label node name -> [centre x, centre y, width, height] of its paper, copied
## from PINNED in tools/build_office_props_blender.py. Deliberately duplicated:
## if the generator moves a paper without this table moving too, the test fails,
## which is the whole point.
const PAPERS := {
	"NoticeTimetableText": [1.420, 1.700, 0.200, 0.220],
	"NoticeCircularText": [1.830, 1.710, 0.210, 0.190],
	"NoticeMemoText": [1.400, 1.400, 0.190, 0.170],
	"NoticeRuleText": [1.840, 1.410, 0.180, 0.200],
}

## The baize rectangle the papers must stay inside.
const BAIZE_X0 := 1.270
const BAIZE_X1 := 1.970
const BAIZE_Y0 := 1.250
const BAIZE_Y1 := 1.850

var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Starting Notice Board Layout Test Suite ---")
	var office := load("res://scenes/office/m1_office.tscn").instantiate() as M1OfficeController
	if not _a(office != null, "The office scene instantiates"): return
	root.add_child(office)
	for _i in 6:
		await process_frame

	var props := office.get_node_or_null("OfficeStorytellingProps")
	if not _a(props != null, "The south-wall fittings are in the office"): return

	var centres: Array[Vector2] = []
	for label_name in PAPERS:
		var label := props.get_node_or_null(label_name) as Label3D
		if not _a(label != null, "%s exists on the board" % label_name): return
		var paper: Array = PAPERS[label_name]
		var centre := Vector2(float(paper[0]), float(paper[1]))
		centres.append(centre)

		# The paper itself must be on the baize.
		var px0: float = centre.x - float(paper[2]) * 0.5
		var px1: float = centre.x + float(paper[2]) * 0.5
		var py0: float = centre.y - float(paper[3]) * 0.5
		var py1: float = centre.y + float(paper[3]) * 0.5
		if not _a(px0 >= BAIZE_X0 and px1 <= BAIZE_X1 and py0 >= BAIZE_Y0 and py1 <= BAIZE_Y1,
				"%s's paper sits inside the baize (x %.3f..%.3f, y %.3f..%.3f)"
					% [label_name, px0, px1, py0, py1]): return

		# The ink must be on its own paper, not merely on the board. The
		# Label3D is rotated 180 degrees about Y, so its AABB is mapped into
		# world space before comparing.
		var aabb := label.get_aabb()
		var gt := label.global_transform
		var corner_a := gt * aabb.position
		var corner_b := gt * (aabb.position + aabb.size)
		var ix0 := minf(corner_a.x, corner_b.x)
		var ix1 := maxf(corner_a.x, corner_b.x)
		var iy0 := minf(corner_a.y, corner_b.y)
		var iy1 := maxf(corner_a.y, corner_b.y)
		if not _a(ix0 >= px0 and ix1 <= px1 and iy0 >= py0 and iy1 <= py1,
				"%s's ink stays on its own paper (ink x %.3f..%.3f y %.3f..%.3f, paper x %.3f..%.3f y %.3f..%.3f)"
					% [label_name, ix0, ix1, iy0, iy1, px0, px1, py0, py1]): return

		# Ink that is much smaller than its paper reads as a fleck in a frame.
		var ink_area: float = (ix1 - ix0) * (iy1 - iy0)
		var paper_area: float = float(paper[2]) * float(paper[3])
		if not _a(ink_area / paper_area >= 0.12,
				"%s's ink fills a usable share of its paper (%.0f%%)"
					% [label_name, 100.0 * ink_area / paper_area]): return

	# The papers must be spread over the baize, not stacked in one horizontal
	# band: the layout that read as an unfinished display case had every slip
	# within 30 cm of the same y.
	var min_y := centres[0].y
	var max_y := centres[0].y
	var min_x := centres[0].x
	var max_x := centres[0].x
	for c in centres:
		min_y = minf(min_y, c.y)
		max_y = maxf(max_y, c.y)
		min_x = minf(min_x, c.x)
		max_x = maxf(max_x, c.x)
	if not _a(max_y - min_y >= 0.25,
			"The notices span the baize vertically, not one band (%.3f m)" % (max_y - min_y)): return
	if not _a(max_x - min_x >= 0.35,
			"The notices span the baize horizontally (%.3f m)" % (max_x - min_x)): return

	# The register card keeps its own clear space: no notice may overlap it.
	var card := Rect2(1.620 - 0.095, 1.550 - 0.065, 0.190, 0.130)
	for label_name in PAPERS:
		var paper: Array = PAPERS[label_name]
		var rect := Rect2(float(paper[0]) - float(paper[2]) * 0.5,
			float(paper[1]) - float(paper[3]) * 0.5, float(paper[2]), float(paper[3]))
		if not _a(not rect.intersects(card),
				"%s does not cover the night register card" % label_name): return

	office.queue_free()
	await process_frame
	print("--- All Notice Board Layout Tests PASSED (%d assertions) ---" % _assertions)
	quit(0)

func _a(condition: bool, description: String) -> bool:
	if condition:
		_assertions += 1
		print("  PASS: ", description)
		return true
	printerr("  FAIL: ", description)
	quit(1)
	return false
