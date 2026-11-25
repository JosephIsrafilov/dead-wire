extends Node3D
## Road closures share the existing perimeter envelope, but stop the player at visible timber.

signal approached(ru: String, en: String)

func build(street: Node3D, night: bool) -> void:
	if night:
		_gate(street, -25.25, 22.8, 5.6, true)
		_gate(street, 23.25, 22.8, 6.4, false)
		return
	_gate(street, -55.3, 22.8, 7.2, true)
	_gate(street, 53.65, 23.0, 7.0, false)

func _gate(street: Node3D, x: float, z: float, half: float, broken: bool) -> void:
	for i in 5:
		var at := z + (i - 2) * half * 0.5
		var top := 1.32 if i != 2 else 1.08
		street.rail(Vector3(x, -0.07, at), Vector3(x + 0.10, top, at - 0.11), 0.20)
	for i in 4:
		var a := z + (i - 2) * half * 0.5
		var b := a + half * 0.5
		street.rail(Vector3(x, 0.41, a), Vector3(x + 0.05, 0.47, b), 0.16)
		if broken and i == 1:
			street.rail(Vector3(x, 1.08, a), Vector3(x + 0.20, 0.61, a + 1.0), 0.13)
			street.rail(Vector3(x, 1.08, b), Vector3(x - 0.19, 0.72, b - 0.9), 0.13)
		else:
			street.rail(Vector3(x, 1.06, a), Vector3(x + 0.03, 1.12, b), 0.14)
	var body := StaticBody3D.new()
	body.position = Vector3(x, 0.65, z)
	body.add_child(_shape(Vector3(0.30, 1.3, half * 2.0 + 0.1)))
	add_child(body)
	var approach := Area3D.new()
	approach.position = Vector3(x + (1.75 if broken else -1.75), 0.8, z)
	approach.collision_layer = 0
	approach.collision_mask = 1
	approach.add_child(_shape(Vector3(3.8, 1.6, half * 2.0)))
	approach.body_entered.connect(_on_approach.bind(broken))
	add_child(approach)

func _on_approach(body: Node3D, broken: bool) -> void:
	if not body is PlayerController:
		return
	if broken:
		approached.emit("Шлагбаум сломан. Дальше дорога размыта.", "The gate is broken. The road washed out beyond it.")
	else:
		approached.emit("Дорогу за мостом закрыли. Придётся вернуться.", "They've closed the road this way. Best turn back.")

func _shape(size: Vector3) -> CollisionShape3D:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	return collider
