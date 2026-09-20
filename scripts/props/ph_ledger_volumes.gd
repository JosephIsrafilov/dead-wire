class_name PhLedgerVolumes
extends Node3D

## The adapted ledger set: a derived export of four encyclopedia volumes from
## the Poly Haven set (CC0). The derived scene owns its nodes; the 67k-tri
## source is referenced only by the derive tool, never by the runtime room.
## Volumes are spaced as spines on a shelf with a slight working lean.

@export var spine_spacing: float = 0.036
@export var spine_tilt_degrees: float = 6.0

const DERIVED_PATH := "res://assets/m1_adapted/ph_books/m1_ledger_volumes.tscn"

func _ready() -> void:
	var derived: PackedScene = load(DERIVED_PATH)
	if derived == null:
		return
	var inst := derived.instantiate()
	add_child(inst)
	var offset := 0.0
	for vol in _meshes(inst):
		vol.position = Vector3(offset, 0.0, 0.0)
		vol.rotation = Vector3(0.0, 0.0, deg_to_rad(spine_tilt_degrees))
		offset += spine_spacing

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
		out.append_array(_meshes(child))
	return out
