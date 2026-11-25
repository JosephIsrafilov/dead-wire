extends SceneTree
## A unit board run with contact shade along its foot and the chair rail.
## Its world-space wood grain stays at a consistent scale across wall runs.

const OUT := "res://assets/models/office_props_v1/wainscot_panel.res"
const HEIGHTS: Array[float] = [-0.5, -0.43, -0.31, 0.31, 0.43, 0.5]
const OCCLUSION: Array[float] = [0.54, 0.77, 1.0, 1.0, 0.82, 0.67]

func _initialize() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for normal: Vector3 in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
		var edge := Vector3.UP.cross(normal) * 0.5
		var centre := normal * 0.5
		for band in HEIGHTS.size() - 1:
			var low := centre + Vector3.UP * HEIGHTS[band]
			var high := centre + Vector3.UP * HEIGHTS[band + 1]
			_vertex(tool, low - edge, normal, Vector2(0, HEIGHTS[band] + 0.5), OCCLUSION[band])
			_vertex(tool, high - edge, normal, Vector2(0, HEIGHTS[band + 1] + 0.5), OCCLUSION[band + 1])
			_vertex(tool, high + edge, normal, Vector2(1, HEIGHTS[band + 1] + 0.5), OCCLUSION[band + 1])
			_vertex(tool, low - edge, normal, Vector2(0, HEIGHTS[band] + 0.5), OCCLUSION[band])
			_vertex(tool, high + edge, normal, Vector2(1, HEIGHTS[band + 1] + 0.5), OCCLUSION[band + 1])
			_vertex(tool, low + edge, normal, Vector2(1, HEIGHTS[band] + 0.5), OCCLUSION[band])
	for normal: Vector3 in [Vector3.UP, Vector3.DOWN]:
		var across := Vector3.RIGHT * 0.5
		var depth := normal.cross(across)
		var centre := normal * 0.5
		var corners := [centre - across - depth, centre - across + depth,
			centre + across + depth, centre + across - depth]
		var uv := [Vector2.ZERO, Vector2.DOWN, Vector2.ONE, Vector2.RIGHT]
		for index: int in [0, 1, 2, 0, 2, 3]:
			_vertex(tool, corners[index], normal, uv[index], 0.67)
	tool.generate_tangents()
	tool.index()
	var err := ResourceSaver.save(tool.commit(), OUT)
	print("Wainscot shade mesh save: ", err)
	quit(0 if err == OK else 1)

func _vertex(tool: SurfaceTool, point: Vector3, normal: Vector3, uv: Vector2, occlusion: float) -> void:
	tool.set_normal(normal)
	tool.set_uv(uv)
	tool.set_color(Color(occlusion, occlusion, occlusion))
	tool.add_vertex(point)
