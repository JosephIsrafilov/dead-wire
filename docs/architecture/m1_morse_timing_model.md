# Morse Timing Model (Gate 08A) — DEAD WIRE Architecture

## Overview

The Morse timing system in **DEAD WIRE** is built upon a fundamental invariant:

```text
TIMING = DATA
TIMBRE = CHARACTER
```

This model is strictly focused on **timing primitives**. It contains no audio data, no timbre configurations, no pitch values, and no character mapping (American Morse alphabet).

---

## Architectural Principles

1. **Relative Units as Pure Data:**
   - Timing is represented entirely in integer relative units (`duration_units: int`).
   - Units are unitless scalars representing relative duration (e.g. 1 unit mark, 3 units mark, 1 unit gap).
   - Real-world time conversion (`seconds`, `WPM`, `BPM`) does not exist in the data model; timing conversion is exclusively the responsibility of downstream playback schedulers.

2. **MARK and GAP Equality:**
   - `MARK` (circuit closed / sounder energized) and `GAP` (circuit open / sounder released) are both discrete data events stored in the sequence.
   - Silence / spacing is treated as first-class structured data, not an implicit property or omitted interval.

3. **Timbre Isolation:**
   - Timbre (click sound, metallic clack, resonator resonance, sounder mechanical traits) belongs to the sounder hardware / audio layer.
   - The timing data model does not describe or reference pitch, tone, volume, or acoustic character.

4. **Alphabet Independence (Deferred to Gate 08B):**
   - The timing model does not know about ASCII characters, letter boundaries, or American Morse translation tables.
   - Mapping letters/words to `MorseSequenceData` will be handled by a dedicated mapping layer in Gate 08B.

5. **Deterministic Signal Timing (No Random Jitter in Primitives):**
   - Critical telegraph signals and canonical sequences must be deterministic data.
   - Imperfections, operator quirks, or line noise must never corrupt the underlying timing model itself.

---

## Data Schema

### MorseTimingEvent

```gdscript
class_name MorseTimingEvent
extends Resource

enum Kind {
    MARK,
    GAP,
}

@export var kind: Kind = Kind.MARK
@export var duration_units: int = 1

func get_validation_errors() -> PackedStringArray
```

- `duration_units` must be strictly positive (`> 0`).
- `kind` must be a valid enum value (`MARK` or `GAP`).

### MorseSequenceData

```gdscript
class_name MorseSequenceData
extends Resource

@export var events: Array[MorseTimingEvent] = []

func get_validation_errors() -> PackedStringArray
func total_duration_units() -> int
```

- Sequence must be non-empty.
- Sequence must start with `MARK` and end with `MARK`.
- Consecutive events must strictly alternate between `MARK` and `GAP`.
- Null events are strictly invalid.
- `total_duration_units()` computes the sum of durations of all events in the sequence.
