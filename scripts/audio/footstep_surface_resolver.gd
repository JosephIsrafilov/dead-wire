class_name FootstepSurfaceResolver
extends Node

## Decides what the boot landed on, from evidence, in this order:
##
##   1. an explicit override (a scripted beat asking for a surface)
##   2. the collider under the foot, or an ancestor, carrying meta
##      `footstep_surface` (legacy: `surface`) or a `surface_<name>` group —
##      the tagged deck, bridge, stone bank
##   3. a `FootstepSurfaceZone` volume containing the foot, highest priority first
##   4. the context default: indoor boards or outdoor dirt
##
## Tagged geometry outranks a zone because a deck laid over the road is the
## thing actually under the boot. Zones exist for ground that has no separate
## collider of its own (the cinder strip between the rails, a carpet over boards).

signal surface_changed(surface: StringName)

const ZONE_GROUP := &"footstep_zones"
## Canonical meta name a collider declares its material with. Keyed bare, so a
## scene file reads `metadata/footstep_surface = &"rail"`.
const TAG_META := &"footstep_surface"
## The Phase B name, still read so geometry tagged before the rename keeps its
## voice. `tag()` writes both, so either reader sees the same material.
const TAG_META_LEGACY := &"surface"
const PRIORITY_META := &"footstep_surface_priority"
const PRIORITY_META_LEGACY := &"surface_priority"
const TAG_GROUP_PREFIX := "surface_"

@export var config: FootstepSurfaceConfig
@export var indoor: bool = true
## A scene's own default material: the saloon's pine, the boarding room's boards.
@export var context_surface: StringName = &""
@export var probe_collision_mask: int = 0xFFFFFFFF
## The down-ray starts this far above the foot and looks this far below it.
@export var probe_rise: float = 0.30
@export var probe_depth: float = 0.45
## Radius of the fallback sphere, so a wide boot still finds the plank edge.
@export var probe_radius: float = 0.16

var ground_surface_at: Callable

var _override: StringName = &""
var _current: StringName = &""
## Per-surface bag and the two most recently played indices.
## Per surface, so stepping off a deck and back resumes that deck's own order
## instead of consuming the order of the material in between.
var _walk: Dictionary = {}

func _ready() -> void:
	if config == null:
		config = FootstepSurfaceConfig.new()
	_current = context_default()

func set_indoor(value: bool) -> void:
	if indoor == value:
		return
	indoor = value
	refresh()

func set_context_surface(surface: StringName) -> void:
	context_surface = surface
	refresh()

## Ask for a surface explicitly; an empty name clears it.
func set_override(surface: StringName) -> void:
	_override = surface
	refresh()

func clear_override() -> void:
	set_override(&"")

func get_current_surface() -> StringName:
	return _current

## The material a boot at `world_position` is standing on.
func surface_at(world_position: Vector3, world: World3D = null, exclude: Array[RID] = []) -> StringName:
	return resolve_at(world_position, world, exclude)["surface"]

## Material and bank in one probe: the player asks once per step, not twice.
func resolve_at(world_position: Vector3, world: World3D = null,
		exclude: Array[RID] = []) -> Dictionary:
	var surface := _override
	if surface == &"" and config != null:
		surface = _tagged_surface_at(world_position, world, exclude)
		if surface == &"" or not config.has_surface(surface):
			var zone := _zone_surface_at(world_position)
			if zone == &"" and ground_surface_at.is_valid():
				zone = ground_surface_at.call(world_position)
			surface = zone if zone != &"" and config.has_surface(zone) else context_default()
	var bank := bank_for(surface)
	if bank != null and not bank.is_playable():
		bank = null
	return {"surface": surface, "bank": bank}

func context_default() -> StringName:
	if config == null:
		return &""
	if context_surface != &"" and config.has_surface(context_surface):
		return context_surface
	return config.context_surface(indoor)

func bank_for(surface: StringName) -> FootstepSurfaceBank:
	return config.bank(surface) if config != null else null

## The next voice on this surface: a shuffled bag drawn one voice at a time.
##
## A bag gives a bank of 3 the only honest distribution it has — every voice
## once per three steps, no repeats — while a random draw with a single "not the
## last one" check still doubles a voice up inside a short walk. The bag refills
## when drawn out; across a refill neither of the last two voices repeats.
##
## With fewer than three voices the guarantee weakens honestly: two voices
## alternate; one voice repeats because it is all there is.
func next_stream(bank: FootstepSurfaceBank) -> AudioStream:
	if bank == null:
		return null
	var count := bank.streams.size()
	if count == 0:
		return null
	var state: Dictionary = _walk.get(bank.surface, {})
	if state.is_empty():
		state = {"bag": bank.shuffled_bag(), "last": -1, "penultimate": -1}
		_walk[bank.surface] = state
	var bag: Array = state["bag"]
	if bag.is_empty():
		bag = bank.shuffled_bag()
		var last: int = state["last"]
		var older: int = state["penultimate"] if count >= 3 else -1
		if count >= 2:
			_move_allowed_voice(bag, 0, last, older)
		if count >= 3:
			_move_allowed_voice(bag, 1, last, -1)
		state["bag"] = bag
	var index: int = bag.pop_front()
	state["penultimate"] = state["last"]
	state["last"] = index
	return bank.stream_at(index)

func _move_allowed_voice(bag: Array, slot: int, last: int, older: int) -> void:
	for i in range(slot, bag.size()):
		var voice: int = bag[i]
		if voice == last or voice == older:
			continue
		bag[i] = bag[slot]
		bag[slot] = voice
		return

## Forget every bag: called when the walker teleports, respawns or a scene
## restarts, so a fresh walk does not continue an order from the last life.
func reset_walk() -> void:
	_walk.clear()

## Recompute the context surface and tell listeners when the ear context moved.
func refresh() -> void:
	var next := context_default()
	if next == _current:
		return
	_current = next
	surface_changed.emit(next)

## Declare the material of a collider (a CSG floor, a static deck, an Area).
## Builders usually tag before the node enters the tree, so the searchable group
## is added on entry; the meta is set immediately either way.
##
## Both meta names are written: `footstep_surface` is canonical, `surface` is the
## Phase B spelling kept alive so anything still reading it (a hand-tagged scene,
## an older tool) sees the same material. The group name is unchanged.
static func tag(node: Node, surface: StringName) -> void:
	if node == null or surface == &"":
		return
	node.set_meta(TAG_META, surface)
	node.set_meta(TAG_META_LEGACY, surface)
	var group := StringName(TAG_GROUP_PREFIX + String(surface))
	if node.is_inside_tree():
		node.add_to_group(group)
		return
	node.tree_entered.connect(func() -> void: node.add_to_group(group), CONNECT_ONE_SHOT)

## The material a node declares directly, or through a nearby ancestor.
## Canonical meta wins over the legacy spelling; a `surface_<name>` group is the
## last resort, so a node hand-tagged either way and grouped still resolves.
static func tag_of(node: Node) -> StringName:
	var current := node
	for _level in 4:
		if current == null:
			return &""
		for key in [TAG_META, TAG_META_LEGACY]:
			if current.has_meta(key):
				return StringName(str(current.get_meta(key)))
		for group in current.get_groups():
			var name := String(group)
			if name.begins_with(TAG_GROUP_PREFIX):
				return StringName(name.trim_prefix(TAG_GROUP_PREFIX))
		current = current.get_parent()
	return &""

## Declare how a tagged collider ranks against another when both are in a probe.
static func set_priority(node: Node, priority: int) -> void:
	if node == null:
		return
	node.set_meta(PRIORITY_META, priority)
	node.set_meta(PRIORITY_META_LEGACY, priority)

static func priority_of(node: Node) -> int:
	if node == null:
		return 0
	if node.has_meta(PRIORITY_META):
		return int(node.get_meta(PRIORITY_META))
	if node.has_meta(PRIORITY_META_LEGACY):
		return int(node.get_meta(PRIORITY_META_LEGACY))
	return 0

func _tagged_surface_at(world_position: Vector3, world: World3D, exclude: Array[RID]) -> StringName:
	var space := _space(world)
	if space == null:
		return &""
	# A ray straight down is the honest answer: it finds the plank, deck or rail
	# the boot is actually over, not whatever volume overlaps the capsule.
	var ray := PhysicsRayQueryParameters3D.create(
		world_position + Vector3.UP * probe_rise, world_position - Vector3.UP * probe_depth)
	ray.collision_mask = probe_collision_mask
	ray.exclude = exclude
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		var surface := tag_of(hit.get("collider") as Node)
		if surface != &"":
			return surface
	# A hole between two planks or a lip at a riser: fall back to a small sphere.
	var shape := SphereShape3D.new()
	shape.radius = probe_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, world_position + Vector3.UP * (probe_radius * 0.5))
	query.collision_mask = probe_collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude
	var found := &""
	var best_priority := -2147483648
	for overlap in space.intersect_shape(query, 8):
		var collider := overlap.get("collider") as Node
		var candidate := tag_of(collider)
		if candidate == &"":
			continue
		var priority := priority_of(collider)
		if priority > best_priority:
			best_priority = priority
			found = candidate
	return found

func _zone_surface_at(world_position: Vector3) -> StringName:
	if not is_inside_tree():
		return &""
	var found := &""
	var best_priority := -2147483648
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(ZONE_GROUP):
		var zone := node as FootstepSurfaceZone
		if zone == null or zone.surface == &"" or not zone.contains_world_point(world_position):
			continue
		var distance := zone.global_position.distance_to(world_position)
		if zone.zone_priority > best_priority or (zone.zone_priority == best_priority and distance < best_distance):
			best_priority = zone.zone_priority
			best_distance = distance
			found = zone.surface
	return found

func _space(world: World3D) -> PhysicsDirectSpaceState3D:
	if world != null:
		return world.direct_space_state
	if not is_inside_tree():
		return null
	var viewport := get_viewport()
	if viewport == null or viewport.world_3d == null:
		return null
	return viewport.world_3d.direct_space_state
