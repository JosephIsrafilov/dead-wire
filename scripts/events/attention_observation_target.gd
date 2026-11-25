class_name AttentionObservationTarget
extends Node3D

signal event_started()
signal visibility_started()
signal event_observed()
signal event_expired()

@export var max_view_angle_degrees: float = 45.0
@export var max_distance: float = 18.0
## The silhouette's AABB is grown by this margin before the frustum test, so
## a figure a hair outside the frame still counts as watched (conservative
## = honest: it never pops in or out while nearly visible).
@export var watch_margin: float = 0.15
## Fallback silhouette radius when the indicator carries no geometry.
const FALLBACK_WATCH_RADIUS: float = 0.6
@export var world_fact_id: StringName = &"window_event_occurred"
@export var knowledge_fact_id: StringName = &"saw_window_event"

@export var world_state: WorldStateStore = null
@export var knowledge_state: KnowledgeStateStore = null

## GDD §10 two-stage placement, Stage 1.1.
##
## Night 1 puts this figure in two places, never both: Stage A out at the old
## mine fence when Miller knocks at the yard door, and Stage B three to four
## metres beyond the bay window in Silence 3 while the wick chars. One node does
## both, because it is one figure and the room should not be able to show two.
enum Stage { CLOSE_WINDOW = 0, FAR_FENCE = 1 }

## Off by default so fixtures and the title diorama place the node by hand. The
## office turns it on: a Stage A that silently happened at Stage B's position is
## exactly the bug the two positions exist to prevent.
@export var use_stage_positions: bool = false
## Stage A: the far fence by Milepost 4, 6.8 m beyond the glass.
## y = 0.965, not 0.96: the yard's ground surface is at 0.02 and the soles are
## authored at -0.945, so the extra five millimetres put his boots exactly on the
## yard instead of a hair through it.
@export var far_stage_position: Vector3 = Vector3(-1.42, 0.965, -11.4)
## Stage B: ~2.8 m beyond the glass, in the aperture from the seated view.
@export var close_stage_position: Vector3 = Vector3(-1.08, 0.965, -3.86)

## The uncanny hold: after this long of being looked at, the head ticks over.
@export var stare_hold_seconds: float = 1.8
## How far the tick moves it. Small enough to be mistaken for attention.
@export var stare_tick_degrees: float = 4.0
const STARE_TURN_SECONDS := 0.80

var is_active: bool = false
var is_observed: bool = false
## Set while the pane in front of the figure is a mirror of the lit room
## (WindowGlassMirror): looking at it then is not seeing the yard (plan 3.7).
var view_obscured: bool = false
## What KnowledgeState learns if the current appearance is seen.
var _knowledge_fact_now: StringName = &""
var _remaining_duration: float = 0.0
var _pending_duration: float = 0.0

var _stage: Stage = Stage.CLOSE_WINDOW
## A stage change requested while the figure is on screen: GDD §10 says the
## Listener never does anything a watcher could catch, so a move waits for the
## figure to be hidden rather than happening in front of a camera.
var _pending_stage: int = -1
var _stage_applied_position: Vector3 = Vector3.ZERO
var _has_stage_position: bool = false

## Head and hat share one pivot and are always written together. The base tilt is
## authored in the scene (twenty degrees on Z) and cached here, so the stare tick
## is a delta on the authored pose rather than a second opinion about it.
var _head: Node3D = null
var _hat: Node3D = null
var _head_base_rotation: Vector3 = Vector3.ZERO
var _base_captured: bool = false
var _stare_hold: float = 0.0
var _stare_ticked: bool = false
var _was_framed: bool = false

## A figure that blinks into existence in front of the player is a bug, not a
## scare. Appearances and disappearances are held until the player is not looking
## at the window, so the figure is always something that was already there.
var _pending_show: bool = false
var _pending_hide: bool = false

var visual_indicator: Node3D = null

func _ready() -> void:
	_capture_figure_nodes()
	reset_state()

## Head, hat and the authored base pose are read once. Everything the stare does
## is a delta from `_head_base_rotation`, so a scene that authors a different list
## (the title diorama poses its own) keeps it.
func _capture_figure_nodes() -> void:
	var vi := get_visual_indicator()
	if vi == null:
		return
	_head = vi.get_node_or_null("Head") as Node3D
	_hat = vi.get_node_or_null("HatBrim") as Node3D
	if _head != null:
		_head_base_rotation = _head.rotation
		_base_captured = true
	_apply_stage_position()

func get_visual_indicator() -> Node3D:
	if visual_indicator == null:
		visual_indicator = get_node_or_null("VisualIndicator") as Node3D
	return visual_indicator

## GDD §10, Stage 1.1: the figure has two places on Night 1 and moves between
## them only while nothing is looking. A request made while the indicator is on
## screen is held; reset_state() (which hides it) applies it.
##
## This is the same rule the appearance itself follows, for the same reason: the
## Listener does not do anything a watcher could catch, so a teleport the player
## could have seen never happens.
func set_stage(stage: int) -> void:
	_stage = stage as Stage
	if not use_stage_positions:
		_apply_stage_position()
		return
	if _is_being_watched() or _indicator_visible():
		_pending_stage = stage
		return
	_pending_stage = -1
	_apply_stage_position()

func get_stage() -> int:
	return int(_stage)

func get_stage_position(stage: int = -1) -> Vector3:
	var which := _stage if stage < 0 else (stage as Stage)
	return close_stage_position if which == Stage.CLOSE_WINDOW else far_stage_position

func _indicator_visible() -> bool:
	var vi := get_visual_indicator()
	return vi != null and vi.visible

func _apply_stage_position() -> void:
	if not use_stage_positions:
		return
	var target := get_stage_position()
	position = target
	_stage_applied_position = target
	_has_stage_position = true

## A stage request that was held because the figure was on screen lands here, and
## only here - immediately before the figure is allowed to be shown. Order
## matters: the caller asked for "Stage A, then appear", and both halves wait on
## the same "nobody is looking" condition, so the position must be flushed before
## the appearance and never after it.
func _flush_pending_stage() -> void:
	if _pending_stage < 0:
		return
	_stage = _pending_stage as Stage
	_pending_stage = -1
	_apply_stage_position()

## After an uninterrupted stare, turn at a constant rate and hold the pose.
## If focus breaks mid-turn, freeze that pose instead of snapping back in view.
func advance_stare(delta: float, watched: bool) -> void:
	if delta <= 0.0:
		return
	if not _watched_for_stare(watched):
		if _stare_hold < stare_hold_seconds:
			_stare_hold = 0.0
		return
	if _stare_ticked:
		return
	_stare_hold += delta
	var travel := clampf((_stare_hold - stare_hold_seconds) / STARE_TURN_SECONDS, 0.0, 1.0)
	if travel > 0.0:
		_write_head_tilt(deg_to_rad(stare_tick_degrees) * travel)
	_stare_ticked = travel >= 1.0

func _watched_for_stare(watched: bool) -> bool:
	if not watched or not is_active or view_obscured:
		return false
	if _stage == Stage.FAR_FENCE:
		return false
	return _indicator_visible()

## One write, both nodes. Head and HatBrim are a single joint here: a hat that
## lags its head by a frame is a hat sliding on a skull.
func _write_head_tilt(delta_deg: float) -> void:
	if not _base_captured:
		return
	var rotation_z := _head_base_rotation.z + delta_deg
	if _head != null:
		_head.rotation.z = rotation_z
	if _hat != null:
		_hat.rotation.z = rotation_z

func reset_state() -> void:
	is_active = false
	is_observed = false
	_remaining_duration = 0.0
	_pending_duration = 0.0
	_pending_show = false
	_pending_hide = false
	_stare_hold = 0.0
	_stare_ticked = false
	_was_framed = false
	_write_head_tilt(0.0)
	var vi := get_visual_indicator()
	if vi != null:
		vi.visible = false
	# A move that was held because the figure was on screen happens here, now
	# that it is not.
	if _pending_stage >= 0:
		_stage = _pending_stage as Stage
		_pending_stage = -1
		_apply_stage_position()

## `world_fact` / `knowledge_fact` name what WorldState records for this
## appearance and what KnowledgeState learns if it is seen; empty means the
## target's own facts (the filing consequence).
func trigger_event(duration: float = 5.0, world_fact: StringName = &"",
		knowledge_fact: StringName = &"") -> void:
	is_active = true
	is_observed = false
	_knowledge_fact_now = knowledge_fact if not knowledge_fact.is_empty() else knowledge_fact_id
	# The event can be queued while the player is looking at the window. Its
	# lifetime must begin when the figure is actually visible, otherwise a
	# watched trigger can expire entirely off-screen.
	_remaining_duration = 0.0
	_pending_duration = maxf(duration, 0.0)

	_pending_show = true
	_pending_hide = false
	_resolve_pending_visibility()

	var world := _get_world_state()
	var fact := world_fact if not world_fact.is_empty() else world_fact_id
	if world != null and not fact.is_empty():
		world.set_fact(fact, true)

	event_started.emit()

func cancel_pending_appearance() -> void:
	if _pending_show:
		reset_state()

## Low-level cone API for fixtures that drive positions and forwards by hand;
## production observation goes through check_camera, which frames the whole
## silhouette (see _silhouette_in_frustum) before it grants knowledge.
func evaluate_observation(camera_global_pos: Vector3, camera_forward: Vector3, is_occluded: bool = false) -> bool:
	if not is_active or is_observed or is_occluded:
		return false
	# Nothing can be seen that has not actually appeared yet.
	var indicator := get_visual_indicator()
	if indicator != null and not indicator.visible:
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
		return _mark_observed()

	return false

## Records the one observation the event will ever make: the knowledge fact
## and the event_observed signal, in the same order the cone path always used.
func _mark_observed() -> bool:
	is_observed = true
	var knowledge := _get_knowledge_state()
	var fact := _knowledge_fact_now if not _knowledge_fact_now.is_empty() else knowledge_fact_id
	if knowledge != null and not fact.is_empty():
		knowledge.learn(fact)
	event_observed.emit()
	return true

## A full-screen UI surface (document, board, cards) hides the world without
## cancelling the event: the figure keeps its pending/appearance rules, only the
## assignment of knowledge is gated while the player cannot actually see.
## Observation means the same thing visibility means: the silhouette is in the
## frame, the view is unobstructed, and the player is not reading a document.
func check_camera(camera: Camera3D, ui_blocked: bool = false) -> bool:
	if camera == null or not is_active or is_observed:
		return false
	# Nothing can be seen that has not actually appeared yet.
	var indicator := get_visual_indicator()
	if indicator != null and not indicator.visible:
		return false
	if ui_blocked or view_obscured:
		return false
	if not _silhouette_in_frustum(camera):
		return false

	var cam_pos := camera.global_position if camera.is_inside_tree() else camera.position
	# Raycast line-of-sight to the figure's SILHOUETTE, not to its origin: walls
	# between the player and the window keep the event pending without granting
	# knowledge.
	#
	# The origin is the bottom of the figure — the hem of the coat, at ankle
	# height. A sight line aimed there leaves the window aperture low and to one
	# side, so once the figure stands back in the yard the ray clips the frame
	# while its head and shoulders are plainly visible through the glass, and
	# the event would never be observed. The thing the player sees is the whole
	# shape, so the whole shape is what the ray is aimed at.
	var space_state := get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() != null else null
	if space_state != null and not _silhouette_is_visible_through(space_state, camera, cam_pos):
		return false

	return _mark_observed()

## Can the camera actually SEE the shape, or is a wall in the way?
##
## Three rays, not one: the silhouette's centre and its two upper corners —
## head and shoulder height. A single centre ray is a fragile test. The figure
## stands in the yard, so a line from the chair to its middle passes very close
## to the window frame; the old single ray to the figure's ORIGIN (its hem, at
## ankle height) went under the sill entirely, and the event could never be
## observed at all.
##
## What the player sees through a window is a head and a pair of shoulders in
## the aperture. If any of those is unobstructed, he has seen the figure, and
## that is what this asks. Walls still block: every ray is a real raycast
## against the world collision layer.
func _silhouette_is_visible_through(space_state: PhysicsDirectSpaceState3D, camera: Camera3D, cam_pos: Vector3) -> bool:
	var bounds := _watched_aabb()
	var probes: Array[Vector3] = [bounds.get_center()]
	# Head and shoulders: the upper corners, pulled in a little so a probe is
	# never exactly on the AABB face.
	var inset := bounds.size * 0.15
	probes.append(Vector3(bounds.position.x + inset.x, bounds.end.y - inset.y, bounds.get_center().z))
	probes.append(Vector3(bounds.end.x - inset.x, bounds.end.y - inset.y, bounds.get_center().z))

	# Exclude all collision objects in the camera's parent chain (the player's
	# own capsule, most of all).
	var exclude_rids: Array[RID] = []
	var p: Object = camera
	while p is Node:
		if p is CollisionObject3D:
			exclude_rids.append((p as CollisionObject3D).get_rid())
		p = (p as Node).get_parent()

	for target_pos in probes:
		var query := PhysicsRayQueryParameters3D.create(cam_pos, target_pos)
		query.collision_mask = 1 # layer 1: solid walls / environment
		query.exclude = exclude_rids
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			return true
		var hit_collider: Object = result.get("collider", null)
		if hit_collider == null or hit_collider == self:
			return true
	return false

func _process(delta: float) -> void:
	var watched := _is_being_watched()
	# An appearance can wait off-camera to be discovered. Once framed, it
	# cannot survive the next turn away, even if its hold time is not up.
	if use_stage_positions and _indicator_visible():
		if _was_framed and not watched:
			var was_active := is_active
			reset_state()
			if was_active:
				event_expired.emit()
			return
		_was_framed = watched
	# Pending visibility is not time on screen. Do not consume the hold while the
	# player is watching the blocked reveal; _resolve_pending_visibility() starts
	# the real lifetime once the figure can be shown.
	if is_active and _remaining_duration > 0.0:
		_remaining_duration -= delta
		if _remaining_duration <= 0.0:
			is_active = false
			_pending_hide = true
			_pending_show = false
			event_expired.emit()
	_resolve_pending_visibility()
	advance_stare(delta, watched and _is_directly_in_view())

## A peripheral silhouette still counts as watched but cannot provoke the turn.
func _is_directly_in_view() -> bool:
	if not is_active or _stage != Stage.CLOSE_WINDOW or _head == null:
		return false
	if view_obscured or not _indicator_visible():
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var to_head := camera.global_position.direction_to(_head.global_position)
	if (-camera.global_basis.z).dot(to_head) < cos(deg_to_rad(12.0)):
		return false
	return _silhouette_is_visible_through(get_world_3d().direct_space_state, camera, camera.global_position)

## Applies a queued appearance or disappearance, but only while the player has
## their back to it. With no camera in the scene — as in tests — it applies at
## once.
func _resolve_pending_visibility() -> void:
	if not _pending_show and not _pending_hide:
		return
	var vi := get_visual_indicator()
	if vi == null:
		return
	if _is_being_watched():
		return

	if _pending_show:
		_flush_pending_stage()
		vi.visible = true
		_pending_show = false
		_remaining_duration = _pending_duration
		_pending_duration = 0.0
		visibility_started.emit()
	elif _pending_hide:
		vi.visible = false
		_pending_hide = false
		_flush_pending_stage()

## Watched means the figure's silhouette touches the camera frustum: the
## figure exists only between observations, so any part of it on screen —
## head above the frame edge, arm at the corner — holds appearance and
## disappearance. The old 45° cone on the origin let the figure blink in and
## out while fully or partially framed; the frustum test cannot. The test is
## conservative in the player's favour: the AABB counts as outside only when
## every corner is beyond one frustum plane. Occlusion is deliberately NOT
## considered here — walls hiding the figure still hold its state; only the
## knowledge assignment (check_camera) cares about line of sight.
func _is_being_watched() -> bool:
	if not is_inside_tree():
		return false
	var viewport := get_viewport()
	if viewport == null:
		return false
	var camera := viewport.get_camera_3d()
	if camera == null or not camera.is_inside_tree():
		return false
	return _silhouette_in_frustum(camera)

## The shared silhouette predicate: the figure's whole box — grown by the
## watch margin — intersects the camera frustum, within max_distance.
func _silhouette_in_frustum(camera: Camera3D) -> bool:
	var to_target := global_position - camera.global_position
	if to_target.length() > max_distance or to_target.length() < 0.001:
		return false

	var bounds := _watched_aabb()
	var frustum: Array[Plane] = camera.get_frustum()
	for plane in frustum:
		if _aabb_fully_behind_plane(bounds, plane):
			return false
	return true

## The world-space box of the whole silhouette — union of every geometry
## child's AABB, head and hat included — grown by the watch margin. Without
## geometry, a sphere's box around the figure's position stands in.
func _watched_aabb() -> AABB:
	var indicator := get_visual_indicator()
	if indicator == null:
		return _fallback_watch_aabb()
	var bounds := AABB()
	var found := false
	for child in _geometry_descendants(indicator, []):
		var local: AABB = child.get_aabb()
		if local.size.length_squared() <= 0.000001:
			continue
		for corner in _aabb_corners(local):
			var world_corner: Vector3 = child.global_transform * corner
			if not found:
				bounds = AABB(world_corner, Vector3.ZERO)
				found = true
			else:
				bounds = bounds.expand(world_corner)
	if not found:
		return _fallback_watch_aabb()
	return bounds.grow(watch_margin)

func _fallback_watch_aabb() -> AABB:
	var center: Vector3 = global_position if is_inside_tree() else position
	return AABB(center - Vector3.ONE * FALLBACK_WATCH_RADIUS,
		Vector3.ONE * FALLBACK_WATCH_RADIUS * 2.0).grow(watch_margin)

func _geometry_descendants(node: Node, accumulator: Array) -> Array:
	for child in node.get_children():
		if child is GeometryInstance3D:
			accumulator.append(child)
		if child is Node:
			_geometry_descendants(child, accumulator)
	return accumulator

func _aabb_corners(bounds: AABB) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			for z in [bounds.position.z, bounds.end.z]:
				corners.append(Vector3(x, y, z))
	return corners

## Conservative outside test: the box is behind a frustum plane only when
## every one of its corners is.
func _aabb_fully_behind_plane(bounds: AABB, plane: Plane) -> bool:
	for corner in _aabb_corners(bounds):
		if not plane.is_point_over(corner):
			return false
	return true

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
