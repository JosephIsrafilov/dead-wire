@tool
extends SceneTree

## Derives the runtime ledger scene from the Poly Haven encyclopedia set:
## picks four volumes, saves them as a standalone PackedScene with correct
## ownership. The 67k-tri source set is never referenced by production after
## this export — the room instantiates only the derived scene.

const SET_PATH := "res://assets/m1_adapted/ph_books/book_encyclopedia_set_01.gltf"
const OUT_PATH := "res://assets/m1_adapted/ph_books/m1_ledger_volumes.tscn"
const SPINE_COUNT := 4

func _init() -> void:
	var set_scene: PackedScene = load(SET_PATH)
	if set_scene == null:
		push_error("source set missing")
		quit(1)
		return
	var source: Node = set_scene.instantiate()
	root.add_child(source)

	var volumes: Array[MeshInstance3D] = []
	_collect(source, volumes)
	print("source volumes: ", volumes.size())

	var root_node := Node3D.new()
	root_node.name = "M1LedgerVolumes"
	root.add_child(root_node)

	var step: int = maxi(1, volumes.size() / SPINE_COUNT)
	var kept: int = 0
	for i in SPINE_COUNT:
		var idx: int = mini(i * step, volumes.size() - 1)
		var vol := volumes[idx]
		if vol == null or vol.get_parent() == root_node:
			continue
		var previous_parent := vol.get_parent()
		previous_parent.remove_child(vol)
		vol.name = "LedgerVolume%d" % (kept + 1)
		vol.owner = null
		root_node.add_child(vol)
		vol.owner = root_node
		kept += 1

	var packed := PackedScene.new()
	var err := packed.pack(root_node)
	if err != OK:
		push_error("pack failed: %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT_PATH)
	print("derived scene saved: ", OUT_PATH, " volumes: ", kept)
	source.queue_free()
	root_node.queue_free()
	quit(0 if err == OK else 1)

func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			out.append(child as MeshInstance3D)
		_collect(child, out)
