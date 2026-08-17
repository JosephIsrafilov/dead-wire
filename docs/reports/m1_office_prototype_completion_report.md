# DEAD WIRE — M1 Office Prototype Completion Report
**Milestone:** Milestone 1 (Office Prototype Playtest Build)  
**Status:** M1 VISUAL ACCEPTANCE CANDIDATE — AUTOMATED GATES PASS, HUMAN ACCEPTANCE PENDING  
**Godot Version:** 4.7.1-stable (Console / Headless)  
**Workspace:** `C:\Users\YUSIF\Documents\dead-wire`  
**Test Results:** 24 Test Suites | 0 Failures | 876 Assertions Passed  

---

## 1. Executive Summary

The Milestone 1 Office Prototype for **DEAD WIRE** has completed automated technical implementation and verification. The project features:
- Historical 1894 American Morse audio playback with distinct down/up armature clicks.
- Physical investigative anchors (routing board, 18-character reference card, dispatch ledger).
- Unified modal `DocumentViewer` for crisp aged parchment inspection without pausing audio or attention events.
- Physical aperture geometry around the North Window and South Door with genuine line-of-sight checks.
- Spatial attention events (3 directional footsteps outside the south door, silhouette observation outside the north window).
- Physical layout checks for furniture collision, player clearance, interaction reachability, line of sight, and attention-zone separation.
- Strict layer separation proving the core narrative hook (`WATER` audio vs `WATCHER` transcript).
- 100% automated regression coverage across 24 test suites (876 assertions passed).

---

## 2. Architecture & Layer Separation Invariant

```text
       ┌───────────────────────────────┐
       │     TRANSMISSION SCENARIO     │
       └──────────────┬────────────────┘
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
 ┌──────────────┐            ┌──────────────┐
 │ TRUE MESSAGE │            │   WRITTEN    │
 │ (Canonical)  │            │  TRANSCRIPT  │
 └──────┬───────┘            └──────┬───────┘
        │                           │
        ▼                           ▼
 ┌──────────────┐            ┌──────────────┐
 │    MORSE     │            │  TRANSCRIPT  │
 │   SOUNDER    │            │    PAPER     │
 │ (Down/Up)    │            │  (Elias Pad) │
 └──────────────┘            └──────────────┘
```

- **True Signal Layer:** Encoded strictly with 18 confirmed 1894 American Morse characters (`A, C, D, E, F, G, H, I, L, N, O, R, S, T, U, W, 1, 7`), zero International Morse, zero jitter.
- **Elias Perception Layer:** Subjective internal reception.
- **Written Transcript Layer:** Physical paper text displayed on the desk pad and readable via `DocumentViewer`.
- **Player Verification Layer:** The player compares auditory evidence against paper evidence and ledger rules to execute routing decisions on the East Wall board without artificial hand-holding or reload-on-error.

---

## 3. Automated Test Suite Scoreboard

| # | Test Suite | Scope / Gate | Assertions | Result |
|---|:---|:---|:---:|:---:|
| 1 | `tests/integration/m1_office_integration_test.gd` | Full M1 E2E Playtest Integration | 58 | **PASS** |
| 2 | `tests/office/m1_presentation_structure_test.gd` | Presentation Geometry & Unmirrored Orientation | 22 | **PASS** |
| 3 | `tests/ui/document_viewer_test.gd` | Modal Document Viewer & Movement Lock | 15 | **PASS** |
| 4 | `tests/events/attention_timeline_test.gd` | Hitch-Proof Attention Timeline Signals | 11 | **PASS** |
| 5 | `tests/debug/debug_inspector_telemetry_test.gd` | F3 Live Telemetry & Inspector | 5 | **PASS** |
| 6 | `tests/events/window_observation_test.gd` | Window Observation LoS / State Separation | 18 | **PASS** |
| 7 | `tests/events/door_attention_test.gd` | Directional Door Footsteps (3 Steps) | 14 | **PASS** |
| 8 | `tests/telegraph/investigative_anchors_test.gd` | Morse Card & Dispatch Ledger | 13 | **PASS** |
| 9 | `tests/telegraph/routing_board_test.gd` | East Wall Routing Board & Input Events | 18 | **PASS** |
| 10 | `tests/telegraph/telegraph_session_controller_test.gd` | Session State Machine & Routing | 20 | **PASS** |
| 11 | `tests/telegraph/telegraph_scenario_data_test.gd` | Scenarios 1, 2, 3 Data Validation | 17 | **PASS** |
| 12 | `tests/telegraph/transcript_paper_test.gd` | Automatic Transcript Paper Inspection | 17 | **PASS** |
| 13 | `tests/telegraph/sounder_controller_test.gd` | Spatial Sounder & Down/Up Clicks | 15 | **PASS** |
| 14 | `tests/telegraph/telegraph_hardware_test.gd` | Telegraph Key & Station Scene | 17 | **PASS** |
| 15 | `tests/telegraph/morse_runtime_scheduler_test.gd` | Runtime Scheduler & Signal Timing | 31 | **PASS** |
| 16 | `tests/telegraph/morse_schedule_compiler_test.gd` | Pure Morse Schedule Compiler | 39 | **PASS** |
| 17 | `tests/telegraph/morse_playback_profile_test.gd` | Morse Playback Timebase Profile | 29 | **PASS** |
| 18 | `tests/telegraph/american_morse_encoder_test.gd` | American Morse String Encoder | 92 | **PASS** |
| 19 | `tests/telegraph/american_morse_alphabet_data_test.gd` | Alphabet Resource & Units | 263 | **PASS** |
| 20 | `tests/telegraph/morse_timing_model_test.gd` | Morse Timing Data Structures | 38 | **PASS** |
| 21 | `tests/telegraph/transmission_data_test.gd` | Transmission Data Resource | 40 | **PASS** |
| 22 | `tests/state/state_separation_test.gd` | WorldState vs KnowledgeState Separation | 29 | **PASS** |
| 23 | `tests/debug/debug_inspector_test.gd` | Debug Inspector F3 Toggle & Sorting | 25 | **PASS** |
| 24 | `tests/office/m1_spatial_metrics_test.gd` | Physical Layout, Collision, Reachability, and Line-of-Sight Gate | 30 | **PASS** |
| **TOTAL** | **24 Suites** | **Milestone 1 Automated Verification** | **876** | **100% PASS** |

---

## 4. Playtest Controls & Verification Checklist

To run an interactive manual playtest:
1. Launch Godot console on the project:
   ```cmd
   C:\Users\YUSIF\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe --path C:\Users\YUSIF\Documents\dead-wire --scene res://scenes/office/m1_office.tscn
   ```
2. **First-Person Controls:**
   - `W / A / S / D`: Move operator Elias Crane around the office.
   - `Mouse`: Look around (First-person camera; click window to capture mouse).
   - `E`: Interact with highlighted objects (Key, Paper, Reference Card, Ledger, Routing Board).
   - `Esc` / `E`: Put down open document or close Routing Board.
   - `1` / `2`: Select track switch route when inspecting the open Routing Board in `AWAITING_ROUTE`.
   - `F3`: Toggle Live Debug Telemetry Inspector overlay.

---

## 5. Visual Acceptance Evidence

- Canonical final captures: `docs/art/m1_visual_acceptance/final/`.
- Rejected baseline archive: `docs/art/m1_visual_acceptance/rejected_visual_pass/`.
- Focused comparisons: `docs/art/m1_visual_acceptance/comparison_focused/`.
- Evidence index, cameras, runtime states, brightness, and SHA256: `docs/art/m1_visual_acceptance/README.md`.
- Capture runner: `res://capture_12_evidence_shots.gd`; validates real Morse-card
  interaction, Scenario 3 window activation, PNG dimensions, reloadability, and
  unique SHA256 digests.
- Historical provenance and no-new-runtime-asset record:
  `docs/art/m1_historical_reference_board.md` and `docs/third_party_assets.md`.
- Full correction and hash record:
  `docs/reports/m1_visual_acceptance_correction_report.md`.

## 6. Focused Round Changed Files

- `scenes/office/m1_office.tscn`
- `scenes/telegraph/routing_board.tscn`
- `scenes/office/window_observation_event.tscn`
- `scenes/style_tests/props/corner_stove.tscn`
- `scripts/telegraph/ui/routing_board.gd`
- `capture_12_evidence_shots.gd`
- `tests/integration/m1_office_integration_test.gd`
- `tests/office/m1_presentation_structure_test.gd`
- `docs/art/m1_visual_acceptance/README.md`
- `docs/art/m1_visual_acceptance/rejected_visual_pass/.gdignore`
- `docs/art/m1_visual_acceptance/focused_round/diagnostic_review.md`
- `docs/art/m1_visual_acceptance/focused_round/*.png`
- `docs/art/m1_visual_acceptance/final/*.png`
- `docs/art/m1_visual_acceptance/comparison_focused/*.png`
- `docs/reports/m1_visual_acceptance_correction_report.md`
- `docs/art/m1_historical_reference_board.md`
