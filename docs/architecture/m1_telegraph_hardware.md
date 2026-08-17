# M1 Telegraph Hardware Contract
**Project:** DEAD WIRE  
**Phase:** Milestone 1 — Gate 10 (Sounder Controller & Telegraph Hardware)  
**Author:** Senior Technical Researcher  
**Status:** IMPLEMENTED & VALIDATED  

---

## 1. Executive Summary & Purpose

The **Telegraph Hardware** layer bridges deterministic Morse scheduling with 3D spatialized audiovisual feedback in the telegraph office:
- `SounderController`: Spatialized 3D sounder unit driving down-stroke click and up-stroke clack impulses.
- `TelegraphKey`: Physical interactable brass key used for answering calls and confirming operator readiness.
- `TelegraphStation`: Desk-mounted composite assembly holding key and sounder in historical spatial relation.

---

## 2. Component Specifications

### 2.1 `SounderController`
- **Class:** `SounderController` (extends `Node3D`)
- **Audio:** Two distinct positional streams:
  - `sounder_down.wav` (metallic anvil impact transient, ~1200 Hz body)
  - `sounder_up.wav` (lighter release stop-screw clack, ~2300 Hz body)
- **Scheduler Signal Binding:**
  - `timing_event_started(MARK)` $\rightarrow$ `play_down()` (lever pulled down by electromagnet)
  - `timing_event_started(GAP)` $\rightarrow$ `play_up()` (lever released by spring against upper screw)
  - `timing_event_finished(last MARK)` $\rightarrow$ `play_up()` (terminal release upon message end)
  - `playback_completed` / `playback_cancelled` $\rightarrow$ ensures lever returns to up position.
- **Fairness & Timing Invariants:**
  - Pitch scale is strictly locked to `1.0` (zero random pitch jitter).
  - Audio playback is purely reactive and never delays or influences the scheduler clock.

### 2.2 `TelegraphKey`
- **Class:** `TelegraphKey` (extends `Node3D`)
- **Interaction Contract:** Integrates standard `Interactable` on Layer 2 with prompt `"Press Key (Answer Line)"`.
- **Feedback:** Visual depression of key lever (`-0.008m` Y translation with timed reset) and signal `key_pressed`.

---

## 3. Scenes
- [`scenes/telegraph/sounder.tscn`](file:///C:/Users/YUSIF/Documents/dead-wire/scenes/telegraph/sounder.tscn)
- [`scenes/telegraph/telegraph_key.tscn`](file:///C:/Users/YUSIF/Documents/dead-wire/scenes/telegraph/telegraph_key.tscn)
- [`scenes/telegraph/telegraph_station.tscn`](file:///C:/Users/YUSIF/Documents/dead-wire/scenes/telegraph/telegraph_station.tscn)
