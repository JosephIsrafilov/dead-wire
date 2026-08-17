# M1 Morse Playback Timebase Profile Contract
**Project:** DEAD WIRE  
**Phase:** Milestone 1 — Gate 09A (Morse Playback Timebase Profile)  
**Author:** Senior Technical Researcher  
**Status:** IMPLEMENTED & VALIDATED  

---

## 1. Executive Summary & Purpose

In **DEAD WIRE**, American Morse transmissions are defined purely in discrete integer relative units at the data and encoding levels:
- `MARK(1)` (dot), `MARK(3)` (dash), `MARK(6)` (long dash)
- `GAP(1)` (element gap), `GAP(2)` (spaced-letter gap), `GAP(3)` (letter gap), `GAP(6)` (word gap)

The `MorsePlaybackProfileData` resource establishes the physical timebase bridge: the duration of **one relative timing unit in seconds** (`seconds_per_unit`).

This resource is strictly a data container and validation model. It does **not** perform playback, scheduling, timer management, or audio synthesis.

---

## 2. Exact Public API

```gdscript
class_name MorsePlaybackProfileData
extends Resource

@export var seconds_per_unit: float = 0.10

func get_validation_errors() -> PackedStringArray
```

---

## 3. Strict Validation Contract

`get_validation_errors()` ensures that `seconds_per_unit` represents a valid, positive, finite timebase.

### Rejected Conditions:
1. `seconds_per_unit <= 0.0` (zero or negative time base)
2. `is_nan(seconds_per_unit)` (`NAN` values)
3. `is_inf(seconds_per_unit)` or `not is_finite(seconds_per_unit)` (positive or negative infinity)

Validation performs zero mutation of resource properties.

---

## 4. M1 Baseline Profile Value & Projected Durations

### Milestone 1 Baseline:
- **`seconds_per_unit = 0.10` seconds** ($100\text{ ms}$)

### Uniform Scale Application:
The exact same timebase scaling applies uniformly across all `MARK` and `GAP` events regardless of kind:
- `MARK(1)` / `GAP(1)` = $0.10\text{ s}$
- `GAP(2)` = $0.20\text{ s}$
- `MARK(3)` / `GAP(3)` = $0.30\text{ s}$
- `MARK(6)` / `GAP(6)` = $0.60\text{ s}$

### Projected Durations for Milestone 1 Messages:
| Message / Sequence | Total Relative Units | Projected Playback Duration |
| :--- | :---: | :---: |
| `E` | 1 unit | $0.10\text{ s}$ |
| `L` | 6 units | $0.60\text{ s}$ |
| `WATER` | 36 units | $3.60\text{ s}$ |
| `WATCHER` | 55 units | $5.50\text{ s}$ |
| `TRAIN 17 CLEAR EAST` | 136 units | $13.60\text{ s}$ |
| `HOLD FREIGHT UNTIL TEN` | 156 units | $15.60\text{ s}$ |

---

## 5. Architectural Invariants & Non-Scope

### 5.1 Provisional / Tunable Status
The `0.10 s` baseline is a **provisional M1 playtest tuning value** designed for initial player readability and auditory discrimination. It is **not**:
- A canonical 1894 operator transmission speed.
- A standardized Railroad Morse speed.
- Derived from a locked speed conversion formula.

### 5.2 Deterministic & Uniform Timebase
- The timebase is completely deterministic.
- Zero timing jitter, fatigue drift, or line delay is applied at the profile level.

### 5.3 Deferred Systems (Explicit Non-Scope)
- **Schedule Compiler / Runtime Scheduler:** Translating sequences to timestamped timeline arrays is deferred to Gate 09B.
- **Physical Sounder / Audio Nodes:** Sounder click generation, contact resonance, and acoustic spatialization are deferred.
- **Perception Distortion / Narrative Simulation:** Elias's subjective perceptual variations are handled downstream.
