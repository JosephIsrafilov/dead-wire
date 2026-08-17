# M1 Visual Acceptance Correction Report

## Scope

Two visual-only correction rounds were applied to the production M1 office.
Gameplay scripts, scenario data, state separation, interaction semantics,
line-of-sight checks, controls, routing outcomes, and final lock behavior were
not changed.

## Corrections

| Round | Observed defect | Correction |
|---|---|---|
| 1 | Flat, over-warm room; abstract window figure; interface-like board | Added cold window direction, authored period storytelling props, physical board rails/lever/frame, low-poly human silhouette, and localized stove cues |
| 2 | Shadow floor obscured required evidence; board labels billboarded; stove/board lacked local readability | Raised neutral-cool ambient floor, added restrained window bounce and board-sconce spill, increased ember visibility, and oriented physical labels toward the board face |

## Evidence

`capture_12_evidence_shots.gd` captures the production
`res://scenes/office/m1_office.tscn` scene at 1280x720 with the production
player camera. It validates the real Morse reference-card interaction and
Scenario 3 window-event activation before saving the related frames.

| Evidence | Final SHA256 |
|---|---|
| `01_spawn_hero.png` | `be0ba14944a198cef330feb4cd0ffabce7897dc61434d50df54aeaf0c37a88d3` |
| `02_full_room_overview.png` | `c261d8a0b898e8ee9a85ecd12d2472e45ffcb8a821b10a5224a1585a6e243f24` |
| `03_operator_workstation.png` | `dddaab6163efee576f8e268743ae765cf3ec79c9aed569f44400e5b9004fdc12` |
| `04_chair_clearance.png` | `b90cbeeb1ca2757c9661d301eb1be10291274b3fa3e70eb857f0eb55e72bec98` |
| `05_telegraph_equipment.png` | `5c5e82d20382b56409462f9bf4e06f0eb4e74bdb864a0925eae5487c7ddbb043` |
| `06_north_window_idle.png` | `100f95b7bb140317478517dffe56ba5f065f6031e261cee33e7e3db0a1a20a22` |
| `07_north_window_figure.png` | `c8643dd60a4799725d50e57de54da1f8236f7d8c8104a83256ee2f20334681cc` |
| `08_south_door.png` | `cc2c2dd3d8d8389109c409d39c2ebccaad1e72e470a1f78b9dee82a7a6bea66c` |
| `09_routing_board.png` | `1d67282a4452b74aee6c45236791ee2a4318c18fb6abb12d32030a822ff83929` |
| `10_stove_storage.png` | `f2eff302a5a214af35b5d478bd84e802c4ddc09fff775f9f03777e4829289a04` |
| `11_real_morse_document.png` | `6534bbd154bd32d8221ddfe91de635ed7f6ae50777d49580c26e4cd236e8bf6f` |
| `12_scenario3_debug_telemetry.png` | `7c65c0b5c71ac7439acc2064adddf57e6d0080afd25b0caa30098ae28ff10d58` |

The current comparison set pairs `01_spawn_hero`, `02_full_room_overview`,
`07_north_window_figure`, and `09_routing_board` between `before/` and
`final/` with unchanged capture transforms.

## Status

`M1 VISUAL ACCEPTANCE CANDIDATE — AUTOMATED GATES PASS, HUMAN ACCEPTANCE PENDING`
