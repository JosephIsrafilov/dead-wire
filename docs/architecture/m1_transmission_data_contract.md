# TransmissionData Contract — DEAD WIRE

## Core Separation of Narrative & Simulation Layers

DEAD WIRE relies on a strict separation between objective reality, protagonist perception, and physical records. `TransmissionData` is a pure data-driven Resource that models telegraph messages across three completely independent layers:

```text
TRUE MESSAGE
Canonical objective text of the transmission.

ELIAS PERCEPTION
What Elias Crane subjectively hears or perceives.

WRITTEN TRANSCRIPT
What is physically committed to paper in the office.
```

---

## Architectural Invariants

1. **Strict Three-Layer Independence:**
   - `true_message`, `elias_perception`, and `written_transcript` are stored in distinct memory fields.
   - Mutating one layer (e.g. modifying `written_transcript`) **never** alters or syncs with `true_message` or `elias_perception`.
   - Modifying `elias_perception` **never** alters `true_message` or `written_transcript`.

2. **No Automatic Synthesis or Silent Fallbacks:**
   - No layer is automatically computed, normalized, or deduced from another.
   - An empty or missing value in one layer is **not** silently substituted by the value of another layer.

3. **Message Text vs. Physical Signal:**
   - `true_message` stores the canonical textual character string (e.g. `"ALPHA"`).
   - It is intentionally **not** named `true_signal`, because the physical signal model in later milestones will represent discrete temporal timing sequences of `MARK` and `GAP` pulses according to American Morse timing rules.

4. **Zero Runtime & State Coupling:**
   - `TransmissionData` is an isolated `Resource`.
   - It does not access, query, or mutate `WorldState` or `KnowledgeState`.
   - It does not spawn nodes, audio streams, sounders, schedulers, or timers.

5. **Validation Contract:**
   - `get_validation_errors() -> PackedStringArray` reports validation issues (e.g. empty `transmission_id`, empty `true_message`, empty `elias_perception`, or empty `written_transcript`).
   - Validation is non-destructive: it performs read-only checks without normalizing or altering the stored strings.

---

## Resource Schema

```gdscript
class_name TransmissionData
extends Resource

@export var transmission_id: StringName
@export_multiline var true_message: String
@export_multiline var elias_perception: String
@export_multiline var written_transcript: String

func get_validation_errors() -> PackedStringArray
```

---

## Example Neutral Fixture

```text
[resource]
transmission_id = &"test_distinct_layers"
true_message = "ALPHA"
elias_perception = "BRAVO"
written_transcript = "CHARLIE"
```
