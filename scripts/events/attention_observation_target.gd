class_name AttentionObservationTarget
extends Node3D

signal event_started()
signal event_observed()
signal event_expired()

@export var max_view_angle_degrees: float = 45.0
@export var max_distance: float = 10.0
@export var world_fact_id: StringName = &"window_event_occurred"
@export var knowledge_fact_id: StringName = &"saw_window_event"

@export var world_state: WorldStateStore = null
@export var knowledge_state: KnowledgeStateStore = null

var is_active: bool = false
var is_observed: bool = false
var _remaining_duration: float = 0.0

var visual_indicator: Node3D = null

func _ready() -> void:
	reset_state()

func get_visual_indicator() -> Node3D:
	if visual_indicator == null:
		visual_indicator = get_node_or_null("VisualIndicator") as Node3D
	return visual_indicator

func reset_state() -> void:
	is_active = false
	is_observed = false
	_remaining_duration = 0.0
	var vi := get_visual_indicator()
	if vi != null:
		vi.visible = false

func trigger_event(duration: float = 5.0) -> void:
	is_active = true
	is_observed = false
	_remaining_duration = duration

	var vi := get_visual_indicator()
	if vi != null:
		vi.visible = true

	var world := _get_world_state()
	if world != null and not world_fact_id.is_empty():
		world.set_fact(world_fact_id, true)

	event_started.emit()

func evaluate_observation(camera_global_pos: Vector3, camera_forward: Vector3, is_occluded: bool = false) -> bool:
	if not is_active or is_observed or is_occluded:
		return false

	var target_pos := global_position if is_inside_tree() else position
	var to_target := (target_pos - camera_global_pos)
	var distance := to_target.length()

	if distance > max_distance or distance < 0.001:
		return false

	to_target = to_target.normalized()
	var angle_rad := camera_forward.normalized().angle_to(to_target)
	var max_angle_rad := deg_to_rad(max_view_angle_degrees)

	if angle_rad <= max_angle_rad:
		is_observed = true
		var knowledge := _get_knowledge_state()
		if knowledge != null and not knowledge_fact_id.is_empty():
			knowledge.learn(knowledge_fact_id)
		event_observed.emit()
		return true

	return false

func check_camera(camera: Camera3D) -> bool:
	if camera == null or not is_active:
		return false

	var cam_pos := camera.global_position if camera.is_inside_tree() else camera.position
	var cam_fwd := -camera.global_transform.basis.z if camera.is_inside_tree() else -camera.transform.basis.z

	# Raycast line-of-sight check
	var is_occluded := false
	var space_state := get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() != null else null
	if space_state != null:
		var target_pos := global_position if is_inside_tree() else position
		var query := PhysicsRayQueryParameters3D.create(cam_pos, target_pos)
		query.collision_mask = 1 # layer 1: solid walls / environment

		# Exclude all collision objects in camera's parent chain (e.g. player capsule)
		var exclude_rids: Array[RID] = []
		var p: Object = camera
		while p is Node:
			if p is CollisionObject3D:
				exclude_rids.append((p as CollisionObject3D).get_rid())
			p = (p as Node).get_parent()
		query.exclude = exclude_rids

		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			var hit_collider: Object = result.get("collider", null)
			if hit_collider != null and hit_collider != self:
				is_occluded = true

	return evaluate_observation(cam_pos, cam_fwd, is_occluded)

func _process(delta: float) -> void:
	if is_active:
		_remaining_duration -= delta
		if _remaining_duration <= 0.0:
			is_active = false
			var vi := get_visual_indicator()
			if vi != null:
				vi.visible = false
			event_expired.emit()

func _get_world_state() -> WorldStateStore:
	if world_state != null:
		return world_state
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		return get_tree().root.get_node_or_null("WorldState") as WorldStateStore
	var curr: Node = get_parent()
	while curr != null:
		var ws := curr.get_node_or_null("WorldState") as WorldStateStore
		if ws != null:
			return ws
		curr = curr.get_parent()
	return null

func _get_knowledge_state() -> KnowledgeStateStore:
	if knowledge_state != null:
		return knowledge_state
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		return get_tree().root.get_node_or_null("KnowledgeState") as KnowledgeStateStore
	var curr: Node = get_parent()
	while curr != null:
		var ks := curr.get_node_or_null("KnowledgeState") as KnowledgeStateStore
		if ks != null:
			return ks
		curr = curr.get_parent()
	return null
