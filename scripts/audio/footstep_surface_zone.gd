class_name FootstepSurfaceZone
extends Area3D

## A patch of ground that is a different material from the collider under it:
## the cinder strip between the rails, a carpet over boards, the mud at the
## trough. The resolver asks every zone whether the foot is inside; the tagged
## collider still wins, because the deck is what the boot actually touches.
##
## Zones carry no collision response of their own — they are read, not walked on.

@export var surface: StringName = &"dirt"
## Higher wins when two zones overlap (a carpet on a boards deck, mud on dirt).
## Not named `priority`: that shadows a built-in member on Area3D's ancestors.
@export var zone_priority: int = 0

func _ready() -> void:
	add_to_group(&"footstep_zones")
	# Also searchable as geometry of its surface, so a test (or a debugging
	# query) can ask the scene which materials it declares.
	if surface != &"":
		add_to_group(StringName("surface_" + String(surface)))
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

## Cheap local test: the foot is inside one of this zone's boxes.
func contains_world_point(world_position: Vector3) -> bool:
	var local := to_local(world_position)
	for owner_index in get_shape_owners():
		if is_shape_owner_disabled(owner_index):
			continue
		var owner_transform := shape_owner_get_transform(owner_index)
		var point: Vector3 = owner_transform.affine_inverse() * local
		for shape_index in shape_owner_get_shape_count(owner_index):
			var shape := shape_owner_get_shape(owner_index, shape_index) as BoxShape3D
			if shape == null:
				continue
			var half: Vector3 = shape.size * 0.5
			if absf(point.x) <= half.x and absf(point.y) <= half.y and absf(point.z) <= half.z:
				return true
	return false
