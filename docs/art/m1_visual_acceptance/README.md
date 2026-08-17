# M1 Visual Acceptance Evidence

## Locations

- Rejected baseline: `docs/art/m1_visual_acceptance/rejected_visual_pass/`
- Focused round: `docs/art/m1_visual_acceptance/focused_round/`
- Canonical final: `docs/art/m1_visual_acceptance/final/`
- Matched focused comparisons: `docs/art/m1_visual_acceptance/comparison_focused/`

All canonical PNGs are 1280x720. Runtime state is the production
`res://scenes/office/m1_office.tscn` scene. The capture runner validates the
real Morse Reference Card interaction, Scenario 3 window event, reloadability,
dimensions, and unique SHA256 values.

## Visual Review

The focused diagnostic set was reviewed before the 12-shot capture. Desk lamp
is a local warm focal point; window fill is cool and spatial; stove, fire door,
ember, pipe, storage, floor, and props are readable. The routing board is a
physical framed slate object with rails, siding divergence, lever, fasteners,
and short physical labels. The window figure has a turned, asymmetric pose and
keeps event visibility semantics. Status: `M1 VISUAL ACCEPTANCE CANDIDATE -
AUTOMATED GATES PASS, HUMAN ACCEPTANCE PENDING`.

## Camera And Runtime State

| PNG | Camera position | Camera target | Runtime state | Proves |
|---|---|---|---|---|
| `01_spawn_hero.png` | `(0.0, 1.65, 1.5)` | `(-1.2, 0.85, -1.0)` | spawn | desk, lamp, window, depth |
| `02_full_room_overview.png` | `(-2.25, 1.65, 1.75)` | `(0.6, 0.85, -0.2)` | spawn | circulation and room composition |
| `03_operator_workstation.png` | `(-1.16, 1.34, -0.6)` | `(-2.35, 0.73, -0.63)` | spawn | desk materials and papers |
| `04_chair_clearance.png` | `(-0.58, 1.0, -0.04)` | `(-1.72, 0.43, -0.6)` | spawn | chair and floor clearance |
| `05_telegraph_equipment.png` | `(-1.68, 1.12, -0.94)` | `(-2.38, 0.75, -0.92)` | spawn | telegraph hardware |
| `06_north_window_idle.png` | `(0.62, 1.5, -1.25)` | `(1.05, 1.55, -2.36)` | idle window | aperture and cold night fill |
| `07_north_window_figure.png` | `(0.62, 1.5, -1.25)` | `(0.72, 1.58, -2.62)` | Scenario 3 event active | figure silhouette and natural pose |
| `08_south_door.png` | `(-1.6, 1.55, -0.3)` | `(-1.6, 1.05, 2.36)` | spawn | door leaf, frame, knob, floor |
| `09_routing_board.png` | `(1.45, 1.42, -0.85)` | `(2.7, 1.34, -0.85)` | `AWAITING_ROUTE`, board open | railway board and route choices |
| `10_stove_storage.png` | `(0.18, 1.55, -0.1)` | `(2.25, 0.9, 1.32)` | spawn | stove, pipe, ember, storage |
| `11_real_morse_document.png` | `(0.0, 1.65, 0.0)` | `(-1.75, 0.8, -0.9)` | reference card open | production document viewer |
| `12_scenario3_debug_telemetry.png` | `(0.0, 1.65, 0.0)` | `(-1.75, 0.8, -0.9)` | Scenario 3 and F3 telemetry | WATER/WATCHER separation |

## Brightness And SHA256

`mean` is mean luminance; `below32` is the percentage of scene pixels below
luminance 32.

| PNG | mean | below32 | Before SHA256 | Focused SHA256 |
|---|---:|---:|---|---|
| `01_spawn_hero.png` | 39.8 | 39.0% | `be0ba14944a198cef330feb4cd0ffabce7897dc61434d50df54aeaf0c37a88d3` | `495c3862d83627c9066d5df389fa3a8bb82d2a5d2df6d324593ae5109275b89b` |
| `02_full_room_overview.png` | 38.4 | 37.5% | `c261d8a0b898e8ee9a85ecd12d2472e45ffcb8a821b10a5224a1585a6e243f24` | `bfecef765b8239ff1485c71413e157e2ad13affaaa2def8ea4ecae44f6f6395e` |
| `03_operator_workstation.png` | 36.5 | 58.6% | `dddaab6163efee576f8e268743ae765cf3ec79c9aed569f44400e5b9004fdc12` | `c7653cb5af9383769db5d88bf3aacb5ce351d517c565aa0ed6a019e7f701d328` |
| `04_chair_clearance.png` | 28.8 | 65.0% | `b90cbeeb1ca2757c9661d301eb1be10291274b3fa3e70eb857f0eb55e72bec98` | `0aca982fd526101958f06c51a1448de35e0ad74447b8d0b2918510b3a9440766` |
| `05_telegraph_equipment.png` | 57.9 | 28.3% | `5c5e82d20382b56409462f9bf4e06f0eb4e74bdb864a0925eae5487c7ddbb043` | `1c20f43dea850c9aff41d2c1446ccebfefbe4f046c6b179537cf699b13756c1f` |
| `06_north_window_idle.png` | 25.2 | 81.9% | `100f95b7bb140317478517dffe56ba5f065f6031e261cee33e7e3db0a1a20a22` | `bc1e2face510cebeb1b646c9fed4bed72c343c0bbe92af3a79f3e5eb1bdbb2d8` |
| `07_north_window_figure.png` | 25.0 | 80.0% | `c8643dd60a4799725d50e57de54da1f8236f7d8c8104a83256ee2f20334681cc` | `49388b6d1e7910b6c6c84f82a56a6e56310916ae104d8d7af7737afc42406d1a` |
| `08_south_door.png` | 34.2 | 50.3% | `cc2c2dd3d8d8389109c409d39c2ebccaad1e72e470a1f78b9dee82a7a6bea66c` | `e78c3c062810bb14655b49598e1919c5fa13b7cce4a4c0e38199a5d33d4d4913` |
| `09_routing_board.png` | 34.3 | 60.5% | `1d67282a4452b74aee6c45236791ee2a4318c18fb6abb12d32030a822ff83929` | `83705f1a06432df9e83b0685d62c219296960be5a790ff22a683bb281819c7fa` |
| `10_stove_storage.png` | 30.9 | 64.8% | `f2eff302a5a214af35b5d478bd84e802c4ddc09fff775f9f03777e4829289a04` | `c4103562c2e98edbea64237ae0ea417ecf716d3b710981ba4beaa958e05422d6` |
| `11_real_morse_document.png` | 74.3 | 61.6% | `6534bbd154bd32d8221ddfe91de635ed7f6ae50777d49580c26e4cd236e8bf6f` | `9761e52f99493b68fe5abb442a6a9893b478025a398a1ecd775710214b5dc8c5` |
| `12_scenario3_debug_telemetry.png` | 35.6 | 60.0% | `7c65c0b5c71ac7439acc2064adddf57e6d0080afd25b0caa30098ae28ff10d58` | `b2c486fab84710a140784579a388f165c13587debfba17478908ab0a25b72a34` |

## Launch

```powershell
& "C:\Users\YUSIF\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe" `
  --path "C:\Users\YUSIF\Documents\dead-wire" `
  --scene "res://scenes/office/m1_office.tscn"
```
