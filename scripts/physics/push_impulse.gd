class_name PushImpulse
extends RefCounted

## How hard a man walking into a loose object moves it.
##
## The room had no rigid bodies at all: every prop was a StaticBody3D, so Elias
## could walk through a night shift shoulder-first and nothing in the world
## acknowledged him. This is the arithmetic behind making the few things that
## *are* loose answer to his body.
##
## The model, and why it is shaped this way:
##
## 1. **Impulse, not velocity.** A body's response to being bumped is set by the
##    impulse J it receives; its speed afterwards is J/m. So the same J moves a
##    tin cup further than a coal scuttle, which is correct and is half of what
##    makes the interaction feel real.
##
## 2. **But not by J alone.** If J were a constant, light objects would be
##    launched: J=10 N·s on a 0.12 kg mug is 83 m/s. Walking into a mug does not
##    fire it across the room. So J is made proportional to the body's own mass:
##    J = m · v · k, which cancels to a target speed of v·k regardless of mass.
##    A person wading through loose objects does push them all at roughly their
##    own pace, so that cancellation is the physically sensible behaviour, while
##    the contact still differs in energy (heavier things take more of it).
##
## 3. **Capped.** Above m = max_impulse / (v·k) the mass term is clamped, so a
##    genuinely heavy object is barely nudged instead of being handed 100 kg·m/s
##    by a shoulder. At the default numbers that threshold is 1.85 kg: a full
##    ink bottle, a coal scuttle and a chair all resist, and only small depot
##    items move freely.
##
## 4. **Spread over contact time.** `move_and_slide` reports the same collider
##    every physics frame while the capsule is touching it, so a per-frame
##    impulse of the full J would multiply by ~9 at 60 Hz and launch the prop.
##    The caller scales by delta / contact_seconds, which integrates to exactly
##    one J over the contact instead of one per frame.

## Fraction of the walker's speed an object takes on. A shoulder brush along a
## table edge, not a shove: measured against the room's 1.35 m/s walk, a mug
## ends up around 0.8 m/s, which slides or tips it about a body-length.
const TRANSFER: float = 0.6

## Hard ceiling on a single contact's impulse, in N·s. Chosen so that anything
## heavier than ~1.85 kg at walking pace is nudged rather than thrown.
const MAX_IMPULSE: float = 1.5

## How long a contact is treated as lasting, in seconds. This is the integration
## window the caller divides delta by; it is a property of a person leaning into
## a table edge, not of any particular prop.
const CONTACT_SECONDS: float = 0.15

## Below this the body is not walking, it is standing and turning. Without it a
## stationary player resting against a table would keep nudging its contents.
const MIN_SPEED: float = 0.05

## The total impulse one contact would deliver, before the per-frame split.
static func total_impulse(
	mass_kg: float,
	speed_mps: float,
	transfer: float = TRANSFER,
	max_impulse: float = MAX_IMPULSE
) -> float:
	if mass_kg <= 0.0 or speed_mps <= 0.0:
		return 0.0
	return clampf(mass_kg * speed_mps * transfer, 0.0, max_impulse)

## The impulse to apply on THIS physics frame, so that a contact lasting
## `contact_seconds` integrates to `total_impulse` exactly.
static func frame_impulse(
	mass_kg: float,
	speed_mps: float,
	delta: float,
	transfer: float = TRANSFER,
	max_impulse: float = MAX_IMPULSE,
	contact_seconds: float = CONTACT_SECONDS
) -> float:
	if delta <= 0.0 or contact_seconds <= 0.0:
		return 0.0
	var j := total_impulse(mass_kg, speed_mps, transfer, max_impulse)
	return j * minf(delta / contact_seconds, 1.0)

## The speed a body ends up at after one full contact, in m/s. Used by tests and
## by the design notes: it is the number that decides whether a prop slides,
## tips or barely rocks.
static func resulting_speed(
	mass_kg: float,
	speed_mps: float,
	transfer: float = TRANSFER,
	max_impulse: float = MAX_IMPULSE
) -> float:
	if mass_kg <= 0.0:
		return 0.0
	return total_impulse(mass_kg, speed_mps, transfer, max_impulse) / mass_kg
