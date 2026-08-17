# M1 Visual Acceptance Correction Report

## Scope

This focused correction round changed only visual presentation, evidence
capture, and acceptance documentation. Morse timing, encoder, scheduler,
scenarios, WorldState, KnowledgeState, controls, interaction semantics, route
outcomes, WATER/WATCHER behavior, attention timings, footsteps, and final-cycle
lock were not changed.

## Confirmed Corrections

| Area | Correction |
|---|---|
| Lighting | Raised neutral-cool ambient readability, reduced desk range, added directional cold window fill, restrained board sconce, and kept stove ember local. |
| Composition | Reframed spawn and layout evidence toward player height; overview now reads desk, window, board, stove/storage, and circulation. |
| Routing Board | Kept physical frame/slate/rails/siding/fasteners/lever, reduced oversized hardware and plaques, shortened physical labels, and stopped runtime UI code from overwriting authored plaque text. |
| Window figure | Added turned body, offset head, lowered shoulder width, asymmetric arms, depth from glass, and retained no-glow event semantics. |
| Stove | Exposed the player-facing fire door, added a small ember seam, and preserved pipe, coal, shovel, and storage context. |
| Evidence | Added focused diagnostic mode, captured five diagnostic PNGs first, then 12 focused PNGs and five matched comparisons. |

## Technical Baseline

- 24 test suites, 0 failures, 876 assertions.
- Integration suite: 58 assertions.
- Presentation structure suite: 22 assertions.
- Godot editor/import scan: exit 0.
- Production headless scene: exit 0.
- D3D12 production launch: exit 0.
- 12 focused PNGs: 1280x720, unique SHA256 values.
- Real Morse Reference Card interaction and Scenario 3 event capture remained
  validated by `capture_12_evidence_shots.gd`.

## Evidence And Hashes

The rejected set is preserved at
`docs/art/m1_visual_acceptance/rejected_visual_pass/`. The focused set and
canonical copy are indexed in `docs/art/m1_visual_acceptance/README.md`, which
contains every camera transform, runtime state, brightness statistic, before
hash, and focused hash.

Focused comparison files:

- `01_spawn_hero_before_final.png`
- `02_full_room_overview_before_final.png`
- `07_north_window_figure_before_final.png`
- `09_routing_board_before_final.png`
- `10_stove_storage_before_final.png`

## Honest Status

`M1 VISUAL ACCEPTANCE CANDIDATE — AUTOMATED GATES PASS, HUMAN ACCEPTANCE PENDING`

The focused diagnostic review and 12 final PNGs were inspected in this round.
This report does not claim human acceptance has been granted.
