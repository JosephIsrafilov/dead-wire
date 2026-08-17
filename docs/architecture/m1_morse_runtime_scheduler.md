# M1 Morse Runtime Scheduler Contract
**Project:** DEAD WIRE  
**Phase:** Milestone 1 — Gate 09C (Runtime Morse Scheduler)  
**Author:** Senior Technical Researcher  
**Status:** IMPLEMENTED & VALIDATED  

---

## 1. Executive Summary & Purpose

The `MorseRuntimeScheduler` is a scene-local Node responsible for executing a pre-compiled `MorsePlaybackScheduleData`. It tracks elapsed playback time against absolute schedule timestamps and emits sequential lifecycle signals as `MARK` and `GAP` events begin and finish.

The scheduler remains strictly decoupled from audio synthesis, paper transcription, and narrative state.

---

## 2. Exact Public API & Signals

```gdscript
class_name MorseRuntimeScheduler
extends Node

enum State {
	IDLE,
	PLAYING,
	COMPLETED
}

signal playback_started(schedule: MorsePlaybackScheduleData)
signal timing_event_started(event: MorseScheduledEvent)
signal timing_event_finished(event: MorseScheduledEvent)
signal playback_completed(schedule: MorsePlaybackScheduleData)
signal playback_cancelled(schedule: MorsePlaybackScheduleData, elapsed_seconds: float)

@export var auto_process: bool = true

func start(schedule: MorsePlaybackScheduleData) -> bool
func cancel() -> void
func reset() -> void
func advance_time(delta: float) -> void

func get_playback_state() -> State
func is_playing() -> bool
func get_active_schedule() -> MorsePlaybackScheduleData
func get_current_event() -> MorseScheduledEvent
func get_current_event_index() -> int
func get_elapsed_seconds() -> float
func get_total_duration_seconds() -> float
```

---

## 3. Timing Invariants & Execution Guarantees

1. **Absolute Timestamp Tracking:**
   - Playback is tracked via monotonic `elapsed_seconds`.
   - No chained accumulative relative timer nodes are used, guaranteeing zero cumulative drift.
2. **Frame-Hitch In-Order Processing:**
   - If a frame hitch or delta jump occurs (e.g. `delta = 1.0s`), all expired events between $t$ and $t + \Delta t$ are processed in exact sequential order: `started` followed by `finished`.
   - Every event in the schedule triggers exactly one `timing_event_started` and one `timing_event_finished`.
3. **Deterministic Test Seam:**
   - With `auto_process = false`, test suites can call `advance_time(delta)` directly to verify complete playback cycles instantaneously and deterministically without real-time wall-clock waits.
4. **State Machine Transitions:**
   - `IDLE` $\xrightarrow{\text{start(valid)}} \text{PLAYING}$
   - `PLAYING` $\xrightarrow{\text{cancel()}} \text{IDLE}$
   - `PLAYING` $\xrightarrow{t \ge \text{total\_duration}} \text{COMPLETED}$
   - `COMPLETED` / `IDLE` $\xrightarrow{\text{reset()}} \text{IDLE}$
   - Attempting `start()` while in `PLAYING` returns `false` and performs no action.
