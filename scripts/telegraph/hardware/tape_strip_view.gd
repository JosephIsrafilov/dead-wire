class_name TapeStripView
extends Node3D

## The register's paper, moving (plan 4.5).
##
## The strip that leaves the register is drawn from the register's own record:
## each MARK is a dash as long as it lasted, each GAP clean paper. The newest
## ink is at the stylus and older ink is carried out toward the coil, which
## grows over the night. It reads MARK/GAP kinds and durations through the
## register's public record and nothing else - the register still knows no
## text, and neither does this.

## Pixels of strip per second of wire time; the visible strip is a few seconds.
const PIXELS_PER_SECOND: float = 40.0
const ROWS: int = 256
const COIL_BASE_RADIUS: float = 0.012
const COIL_MAX_RADIUS: float = 0.03

@export var register_path: NodePath = ^"../.."
@export var coil_path: NodePath = ^"../TapeCoil"
## Where the strip lies, in the register body's space, and how big it is.
@export var strip_size: Vector2 = Vector2(0.014, 0.09)
@export var strip_position: Vector3 = Vector3(0.0, 0.0011, 0.1)
@export var refresh_hz: float = 15.0

var _register: TapeRegisterController = null
var _coil: Node3D = null
var _image: Image = null
var _texture: ImageTexture = null
var _since_refresh: float = 0.0
var _last_total: float = -1.0

## One row per pixel along the strip, 1 where there is ink. Row 0 is at the
## stylus; rows count back in wire time.
static func render_rows(events: Array[TapeInkEvent], px_per_second: float, rows: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(rows)
	out.fill(0)
	var back := 0.0
	for i in range(events.size() - 1, -1, -1):
		var ink := events[i]
		var start := back
		back += maxf(ink.duration_seconds, 0.0)
		if ink.kind != MorseTimingEvent.Kind.MARK:
			continue
		var first := int(floor(start * px_per_second))
		var last := int(ceil(back * px_per_second)) - 1
		for row in range(maxi(first, 0), mini(last, rows - 1) + 1):
			out[row] = 1
		if first >= rows:
			break
	return out

## The take-up coil: paper wound on paper, square-root growth, never past the tray.
static func coil_radius(total_seconds: float) -> float:
	return minf(COIL_BASE_RADIUS + 0.0006 * sqrt(maxf(total_seconds, 0.0)), COIL_MAX_RADIUS)

func _ready() -> void:
	_register = get_node_or_null(register_path) as TapeRegisterController
	_coil = get_node_or_null(coil_path) as Node3D
	_image = Image.create(4, ROWS, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0.86, 0.82, 0.72, 1.0))
	_texture = ImageTexture.create_from_image(_image)
	var strip := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = strip_size
	var material := StandardMaterial3D.new()
	material.albedo_texture = _texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.95
	plane.material = material
	strip.mesh = plane
	strip.position = strip_position
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)

func _process(delta: float) -> void:
	_since_refresh += delta
	if _since_refresh < 1.0 / maxf(refresh_hz, 1.0):
		return
	_since_refresh = 0.0
	refresh()

func refresh() -> void:
	if _register == null or _image == null:
		return
	var events := _register.get_record()
	var total := 0.0
	for ink in events:
		total += ink.duration_seconds
	if is_equal_approx(total, _last_total):
		return
	_last_total = total
	var rows := render_rows(events, PIXELS_PER_SECOND, ROWS)
	var paper := Color(0.86, 0.82, 0.72, 1.0)
	var ink_colour := Color(0.08, 0.07, 0.09, 1.0)
	for row in ROWS:
		# The plane's v runs from the register (0) toward the exit (1).
		var inked := rows[row] == 1
		for column in 4:
			var dash := inked and column in [1, 2]
			_image.set_pixel(column, row, ink_colour if dash else paper)
	_texture.update(_image)
	if _coil != null:
		var radius := coil_radius(total)
		_coil.scale = Vector3(radius / COIL_BASE_RADIUS, 1.0, radius / COIL_BASE_RADIUS)
