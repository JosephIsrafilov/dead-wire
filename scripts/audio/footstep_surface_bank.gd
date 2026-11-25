class_name FootstepSurfaceBank
extends Resource

## One walkable surface's voices: the recorded one-shots of a single material.
##
## Phase B: every stream here is a registered CC0 recording cut by
## `tools/build_footstep_surface_banks.py` (or the mikeask boards for the
## office). Nothing is synthesised, so a bank is honest about what the boot
## actually landed on.

## Stable identifier used by tags, volumes and scene defaults.
@export var surface: StringName = &"dirt"
@export var streams: Array[AudioStream] = []
## Residual level trim against the office boards, measured, not guessed.
@export var volume_offset_db: float = 0.0
## Surfaces are not pitched evenly: a stone step rings slightly higher than a
## floorboard of the same take.
@export var pitch_center: float = 1.0
@export var pitch_jitter: float = 0.02

func is_playable() -> bool:
	return streams.any(func(stream: AudioStream) -> bool: return stream != null)

## One fresh walk order: every voice once, in a random order.
##
## The bag belongs to the walker, not to the bank: a bank is a shared resource,
## so two boots drawing from one bag would predict each other's next step.
## `FootstepSurfaceResolver.next_stream` owns the drawing and the seam rule.
func shuffled_bag() -> Array[int]:
	var bag: Array[int] = []
	for index in streams.size():
		bag.append(index)
	bag.shuffle()
	return bag

func stream_at(index: int) -> AudioStream:
	return streams[index] if index >= 0 and index < streams.size() else null
