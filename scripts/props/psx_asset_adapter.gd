class_name PsxAssetAdapter
extends Node3D

## Adapts a CC0 source model to the M1 look without mutating the imported
## resources: per MeshInstance a flat PSX material is built from the source
## albedo texture, muted to the room's palette, no PBR maps. Source materials
## are never edited, so re-imports stay clean and other scenes are unaffected.

@export var mute: Color = Color(0.66, 0.62, 0.56, 1.0)
@export var roughness: float = 1.0
## When false the model keeps its own materials untouched (for assets whose
## look already fits, like book covers).
@export var flatten: bool = true

func _ready() -> void:
	_apply(self)

func _apply(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if flatten:
				var flat := _flat_from_source(mi)
				if flat != null:
					mi.material_override = flat
		_apply(child)

func _flat_from_source(mi: MeshInstance3D) -> StandardMaterial3D:
	var mesh := mi.mesh
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var src := mesh.surface_get_material(0)
	var out := StandardMaterial3D.new()
	out.roughness = roughness
	out.metallic = 0.0
	out.metallic_specular = 0.0
	if src is StandardMaterial3D:
		var std := src as StandardMaterial3D
		out.albedo_texture = std.albedo_texture
		if std.albedo_texture != null:
			out.uv1_scale = std.uv1_scale
	out.albedo_color = mute
	return out
