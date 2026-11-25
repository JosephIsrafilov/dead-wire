class_name FootstepSurfaceConfig
extends Resource

## The walkable materials of FORM 19, in the order the resolver consults them.
##
## Phase B: a surface is a bank of real CC0 recordings, not a filter sweep. The
## resolver picks one by this contract, highest priority first:
##
##   1. an explicit override (a scripted scene beat, `FootstepSurfaceResolver.set_override`)
##   2. the collider under the boot carrying meta `footstep_surface` (or a
##      `surface_<name>` group); the Phase B name `surface` is still read
##   3. a `FootstepSurfaceZone` volume the player is standing in (highest zone priority)
##   4. the context default — indoor boards in the office/room, outdoor dirt in town
##
## A tagged collider outranks a zone because a deck laid over the road is what the
## boot actually touches; zones exist for ground with no body of its own (the
## ballast bed, a carpet over boards). Anything a scene does not tag still sounds
## like the room it is in, so no scene has to be rewritten to get this.

@export var banks: Array[FootstepSurfaceBank] = []
## Used when no zone and no collider tag applies while indoors.
@export var indoor_surface: StringName = &"wood_office"
## Used when no zone and no collider tag applies while outdoors.
@export var outdoor_surface: StringName = &"dirt"
## Last resort when a context surface has no bank at all.
@export var fallback_surface: StringName = &"wood_office"

func bank(surface: StringName) -> FootstepSurfaceBank:
	for candidate in banks:
		if candidate != null and candidate.surface == surface:
			return candidate
	return null

func has_surface(surface: StringName) -> bool:
	return bank(surface) != null

func context_surface(indoor: bool) -> StringName:
	var wanted := indoor_surface if indoor else outdoor_surface
	return wanted if has_surface(wanted) else fallback_surface
