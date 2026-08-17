# M1 Investigative Anchors & Routing Board Contract
**Project:** DEAD WIRE  
**Phase:** Milestone 1 — Gate 13 (Routing Board, Morse Reference & Ledger)  
**Author:** Senior Technical Researcher  
**Status:** IMPLEMENTED & VALIDATED  

---

## 1. Executive Summary & Purpose

In **DEAD WIRE**, the player must reason through uncertainty using physical, stable **Investigative Anchors** located within the telegraph office:
1. **`RoutingBoard` (East Wall):** Physical track-switch interface for executing routing decisions (`CLEAR EAST` / `HOLD`).
2. **`MorseReferenceCard` (Desk/Wall):** Physical reference card displaying exclusively the 18 M1 American Morse alphabet characters and spaced-letter gap notation.
3. **`DispatchLedger` (Desk):** Station ledger detailing procedural rules for train dispatch and special night freight.

---

## 2. Component Specifications

### 2.1 `RoutingBoard`
- **Class:** `RoutingBoard` (extends `Node3D`)
- **Location:** East wall (forces player to turn away from the desk and door/window zones).
- **Actions:** `"CLEAR EAST"`, `"HOLD"`.
- **Invariants:**
  - Emits `routing_action_selected(action)`.
  - Rejects duplicate action submissions within the same session.
  - Implements `Interactable` contract.

### 2.2 `MorseReferenceCard`
- **Class:** `MorseReferenceCard` (extends `Node3D`)
- **Location:** Operator desk.
- **Content:** Exact historical representations for `A, C, D, E, F, G, H, I, L, N, O, R, S, T, U, W, 1, 7`.
- **Invariants:**
  - Zero International Morse code.
  - Visual spacing distinction for spaced letters (`C, O, R`).
  - No auto-decoding or hints.

### 2.3 `DispatchLedger`
- **Class:** `DispatchLedger` (extends `Node3D`)
- **Location:** Operator desk.
- **Content:** Priority routing for scheduled passenger train 17 and Rule 44 hold requirements for unverified freight.

---

## 3. Scenes
- [`scenes/telegraph/routing_board.tscn`](file:///C:/Users/YUSIF/Documents/dead-wire/scenes/telegraph/routing_board.tscn)
- [`scenes/telegraph/morse_reference_card.tscn`](file:///C:/Users/YUSIF/Documents/dead-wire/scenes/telegraph/morse_reference_card.tscn)
- [`scenes/telegraph/dispatch_ledger.tscn`](file:///C:/Users/YUSIF/Documents/dead-wire/scenes/telegraph/dispatch_ledger.tscn)
