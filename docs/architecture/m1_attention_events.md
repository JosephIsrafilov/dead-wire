# M1 Attention Events & Spatial Observation Contract
**Project:** DEAD WIRE  
**Phase:** Milestone 1 — Gates 16 & 18 (Attention Events & Window Observation)  
**Author:** Senior Technical Researcher  
**Status:** IMPLEMENTED & VALIDATED  

---

## 1. Executive Summary & Purpose

Attention events in **DEAD WIRE** create psychological pressure and perceptual split-focus during telegraph operation without violating player fairness or breaking strict state separation.

---

## 2. Event Types & Behaviors

### 2.1 False Attention Event: `DoorAttentionSource` (South Door)
- **Audio:** 3 directional footsteps on wood floor located at the station entrance.
- **Trigger:** Time-stamped during Morse transmission playback (Scenario 2 at $t = 4.0\text{s}$).
- **Fairness:**
  - Distinct spatial positioning and lower volume ($-6\text{ dB}$).
  - Never interrupts, delays, or hitches the Morse sounder schedule.
- **Narrative Rule:** The door never physically opens; the presence remains unseen.

### 2.2 Genuine Attention Event: `AttentionObservationTarget` (North Window)
- **Visuals:** Subtle exterior figure silhouette and pale light shimmer outside the window.
- **Duration:** Active for a discrete observation window (e.g. $5.0\text{s}$).
- **Observation Mathematics:**
  $$\vec{d} = \text{target\_pos} - \text{cam\_pos}$$
  $$\theta = \arccos\left(\frac{\vec{f}_{\text{cam}} \cdot \vec{d}}{\|\vec{d}\|}\right) \le 45^\circ$$
  $$\text{Raycast}(\text{cam\_pos} \to \text{target\_pos}) = \text{Clear LoS}$$

---

## 3. Strict State Separation Invariant

| Scenario Outcome | `WorldState.window_event_occurred` | `KnowledgeState.saw_window_event` |
| :--- | :--- | :--- |
| **Player focused on desk / looking away** | `true` | `false` |
| **Player obstructed behind column/wall** | `true` | `false` |
| **Player turns to window within $45^\circ$ FOV** | `true` | `true` |

The world event occurs objectively regardless of player awareness, but the player's subjective knowledge is updated exclusively when direct observation is achieved.
