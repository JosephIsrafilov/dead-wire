# M1 Morse Schedule Compiler Contract
**Project:** DEAD WIRE  
**Phase:** Milestone 1 — Gate 09B (Pure Schedule Compiler)  
**Author:** Senior Technical Researcher  
**Status:** IMPLEMENTED & VALIDATED  

---

## 1. Executive Summary & Purpose

In **DEAD WIRE**, the Morse pipeline progresses from relative timing units to absolute timestamps through pure functional compilation:
```text
MorseSequenceData (Integer units)
       +
MorsePlaybackProfileData (seconds_per_unit)
       ↓ (MorseScheduleCompiler)
MorsePlaybackScheduleData (Continuous timeline array of MorseScheduledEvent)
```

The `MorseScheduleCompiler` is a stateless, deterministic compiler. It builds a timestamped schedule without relying on engine ticks, timers, or scene nodes.

---

## 2. Exact Public APIs

### 2.1 `MorseScheduledEvent`
```gdscript
class_name MorseScheduledEvent
extends RefCounted

var event_index: int = 0
var kind: MorseTimingEvent.Kind = MorseTimingEvent.Kind.MARK
var duration_units: int = 0
var start_seconds: float = 0.0
var duration_seconds: float = 0.0
var end_seconds: float = 0.0
```

### 2.2 `MorsePlaybackScheduleData`
```gdscript
class_name MorsePlaybackScheduleData
extends RefCounted

var events: Array[MorseScheduledEvent] = []
var total_duration_seconds: float = 0.0

func get_validation_errors() -> PackedStringArray
```

### 2.3 `MorseScheduleCompiler`
```gdscript
class_name MorseScheduleCompiler
extends RefCounted

func get_compilation_errors(
	sequence: MorseSequenceData,
	profile: MorsePlaybackProfileData
) -> PackedStringArray

func compile(
	sequence: MorseSequenceData,
	profile: MorsePlaybackProfileData
) -> MorsePlaybackScheduleData
```

---

## 3. Strict Compilation & Validation Invariants

1. **Validation Rejections:**
   - Null or invalid `MorseSequenceData`.
   - Null or invalid `MorsePlaybackProfileData`.
   - Any negative, infinite, or `NAN` timing values.
2. **Timeline Continuity:**
   - The first scheduled event starts at `0.0` seconds.
   - For every event $i > 0$, `events[i].start_seconds == events[i-1].end_seconds`.
   - `events[i].end_seconds == events[i].start_seconds + events[i].duration_seconds`.
   - `total_duration_seconds == events[-1].end_seconds`.
3. **Alternation & Boundary Invariants:**
   - `events[0].kind == MARK`
   - `events[-1].kind == MARK`
   - Events strictly alternate between `MARK` and `GAP`.
4. **Data Isolation:**
   - `compile()` instantiates fresh `MorsePlaybackScheduleData` and `MorseScheduledEvent` objects.
   - Zero mutation is performed on input sequences or profiles.

---

## 4. Golden Compilation Totals (at `seconds_per_unit = 0.10`)

| Sequence / Message | Total Units | Scheduled Event Sequence | Total Scheduled Duration |
| :--- | :---: | :--- | :---: |
| `ET` | 7 | `MARK(0.00..0.10), GAP(0.10..0.40), MARK(0.40..0.70)` | **0.70 s** |
| `E T` | 10 | `MARK(0.00..0.10), GAP(0.10..0.70), MARK(0.70..1.00)` | **1.00 s** |
| `WATER` | 36 | 13 events | **3.60 s** |
| `WATCHER` | 55 | 17 events | **5.50 s** |
| `TRAIN 17 CLEAR EAST` | 136 | 45 events | **13.60 s** |
| `HOLD FREIGHT UNTIL TEN` | 156 | 51 events | **15.60 s** |

---

## 5. Explicit Non-Scope
- **No SceneTree / Node integration:** Pure RefCounted data structures.
- **No Timers / Clocks:** Scheduling timestamps are purely mathematical floats.
- **No Audio Playback:** Sounder playback execution is deferred to subsequent gates.
