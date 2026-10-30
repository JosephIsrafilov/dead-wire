class_name WindowGlassMirror
extends Node

## Lamp against window (owner's decision, plan 3.7).
##
## A lit room behind a night pane turns the pane into a mirror: with the wick
## up the glass shows the warm room and the lamp, and the yard is hard to make
## out; turn the lamp down and the yard comes through. Putting a face to the
## glass (leaning in, near the window) does the same. So the player chooses:
## light to work by, or a view of the yard.
##
## The Listener never touches the lamp; only the wick and the player's own head
## drive this. Reflection comes from the room's existing probe — no second
## camera, no SSR.

@export var office: Node = null
## How close the camera has to be to the glass for a lean to count.
@export var lean_reach: float = 1.1

var yard_visibility_now: float = 1.0

var _glass: CSGShape3D = null
var _material: StandardMaterial3D = null
var _lamp: LampLife = null
var _player: PlayerController = null

## 0..1: how much of the yard comes through the pane. Falls with the wick
## (a lamp turned down below ~0.3 leaves the glass clear) and rises with a lean
## at the glass.
static func yard_visibility(wick: float, lean_at_glass: float) -> float:
	var mirror := smoothstep(0.3, 1.0, clampf(wick, 0.0, 1.0))
	mirror *= 1.0 - 0.75 * clampf(lean_at_glass, 0.0, 1.0)
	return 1.0 - 0.85 * mirror

## Clear night glass at visibility 1, a dark warm mirror at 0.
static func apply_to(material: StandardMaterial3D, visibility: float) -> void:
	var m := 1.0 - clampf(visibility, 0.0, 1.0)
	var clear := Color(0.34, 0.44, 0.58, 0.16)
	# The lamp lights the pane itself: a lit room shows its own warm glow in
	# the glass, and that glow is what hides the yard.
	var dark_mirror := Color(0.24, 0.17, 0.11, 0.93)
	material.albedo_color = clear.lerp(dark_mirror, m)
	material.metallic = lerpf(0.0, 0.45, m)
	material.roughness = lerpf(0.72, 0.24, m)
	material.metallic_specular = lerpf(0.07, 0.6, m)

func _ready() -> void:
	if office == null:
		office = get_parent()
	if office == null:
		return
	_glass = office.get_node_or_null("NorthWindow/NightGlass") as CSGShape3D
	_lamp = office.get_node_or_null("LampLife") as LampLife
	_player = office.get_node_or_null("Player") as PlayerController
	if _glass != null and _glass.material is StandardMaterial3D:
		# A private copy: the shared glass resource is not rewritten per frame.
		_material = (_glass.material as StandardMaterial3D).duplicate() as StandardMaterial3D
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.material = _material

## Smallest change in visibility worth touching the material for. Every write
## marks the CSG pane dirty and queues a rebuild, so a steady wick must cost
## nothing.
const VISIBILITY_STEP: float = 0.01

var _applied_visibility: float = -1.0

func _process(_delta: float) -> void:
	if _material == null:
		return
	var wick := _lamp.wick if _lamp != null else 1.0
	yard_visibility_now = yard_visibility(wick, _lean_at_glass())
	if absf(yard_visibility_now - _applied_visibility) < VISIBILITY_STEP:
		return
	_applied_visibility = yard_visibility_now
	apply_to(_material, yard_visibility_now)

func _lean_at_glass() -> float:
	if _player == null or _player.camera == null or _glass == null:
		return 0.0
	var distance := _player.camera.global_position.distance_to(_glass.global_position)
	var nearness := 1.0 - smoothstep(lean_reach * 0.5, lean_reach, distance)
	return _player.get_lean_weight() * nearness
