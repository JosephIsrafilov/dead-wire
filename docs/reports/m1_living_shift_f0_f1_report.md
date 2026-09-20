# M1 Living Shift — Phase F0 + F1 Report

## Phase / date / HEAD / working-tree changes

- Phase: F0 (fresh baseline) + F1 (honest interaction), first bounded pass per `docs/m1_living_shift_plan.md` §10/§14.
- Date: 2026-09-19.
- HEAD: `70a89675036eaf9fdcc742c513a12fa8c95c1c60` (matches the plan's verified base).
- Working tree: only the files listed below; untracked user dirs (`sites/`, `.serena/`, `.DS_Store`) untouched.

## Problem seen by player (baseline defects, plan §1 + code reading)

1. E on an idle routing board opened an invisible modal: `board_opened` fired, movement locked, nothing to decide (I01).
2. Escape with the board open vanished: `PauseMenu._input` unconditionally called `set_input_as_handled()` even when `pause()` declined, so the key never reached the board (I02, subscription-order dependent).
3. E on an actively written sheet opened the document viewer with the partial prefix as if it were a finished telegram; no truthful status prompt existed (I03).
4. `check_camera` had no notion of covering UI: knowledge `saw_window_event` could be assigned while a document/board hid the world (I04).

## Implemented behavior

- Idle board: `open_board()`/`_on_interacted()` are no-ops unless `is_awaiting_route && !has_submitted_this_session`. Idle prompt is truthful line status (`Routing Board — Line Status`, no [E]); idle interaction emits no `board_opened` and locks nothing.
- Escape chain: `pause()`/`resume()`/`toggle()` return whether they acted; `PauseMenu._input` marks input handled only when it did. With a document or board open, one Escape closes only that surface; the next one pauses.
- Read gate: while the current session is RECEIVING and the sheet is being written, E on the paper opens no viewer. Prompt is centralized: `Still Copying` seated, `Return to the Chair to Finish the Copy` standing; no [E] offered. Restores the normal read prompt once writing ends (VERIFYING+ behavior unchanged: inspect opens the full snapshot and verifies exactly once).
- Observation: `M1OfficeController.is_world_view_blocked()` (document, routing board, intro card, end card) is passed to `AttentionObservationTarget.check_camera(camera, ui_blocked)` and combined with the 3D occlusion ray for knowledge assignment only. Event lifetime, pending-show/hide rules and the visibility timeout are untouched: a player who never turns from the window still cannot strand the shift.

## Contract/data changes

- `RoutingBoard.open_board()` now guards on awaiting-route state (was unconditional; plan §5.2).
- `PauseMenu.pause/resume/toggle` signatures changed `void -> bool`; only caller is `_input`.
- `AttentionObservationTarget.check_camera` gained optional `ui_blocked: bool = false` (backwards compatible).
- No new singletons, managers, or event buses. No scenario data touched.

Files:

- `scripts/telegraph/ui/routing_board.gd`
- `scripts/ui/pause_menu.gd`
- `scripts/events/attention_observation_target.gd`
- `scripts/office/m1_office_controller.gd` (`is_world_view_blocked`, `_is_transcript_copy_in_progress`, `_update_transcript_prompt`, `_get_transcript_paper`, `_process` wiring, gated `_on_transcript_inspected`)
- `tests/telegraph/routing_board_test.gd` (idle no-op cases; open/close cycle updated to the new contract)
- `tests/events/window_observation_test.gd` (section 8: UI block without event cancel)
- `tests/ui/framing_test.gd` (sections 5b–5e: Escape chain with board, idle board no-op, read gate with truthful prompts, `is_world_view_blocked`)
- `tests/integration/m1_office_integration_test.gd` (prerequisite fix: dismiss the intro card, which now legitimately counts as a covering surface)

## Focused checks: commands, exit codes, outcomes

- `godot --headless --audio-driver Dummy --path . --script tests/telegraph/routing_board_test.gd` — PASSED
- `... tests/events/window_observation_test.gd` — PASSED
- `... tests/ui/framing_test.gd` — PASSED (62 assertions)
- `... tests/ui/document_viewer_test.gd` — PASSED
- `... tests/integration/m1_office_integration_test.gd` — PASSED (after intro prerequisite fix; failure was legitimate new-contract behavior)

## Full regression: suites/assertions from this run

- `GODOT_BIN=$(command -v godot) bash tools/run_all_tests.sh`: **34 suites passed, 0 failed, 1389 assertions** (baseline before changes: 34/0/1359).

## Production boot + InputMap smoke

- `godot --headless --audio-driver Dummy --path . --quit-after 120 res://scenes/office/m1_office.tscn` — exit 0.
- `godot --headless --audio-driver Dummy --path . --script res://tests/integration/main_scene_smoke_test.gd` — PASSED.

## Visual/audio evidence: paths and what was actually inspected

- None recorded this pass. F1 is interaction logic, not presentation; no timings, animations or sound were changed. Escape chains were verified through direct `_input` calls in both subscription orders (pause-first and board-first) rather than live InputMap playback.

## Open issues / untested areas

- Live-window InputMap verification of the Escape chain (real key presses in a running window) not performed; covered by direct `_input` calls only.
- Partial-active-transcript viewer gate is exercised for the RECEIVING case; the post-signal COPYING state does not exist yet and arrives with F2 per the plan.
- `COPY INCOMPLETE` terminal-partial viewer markup (plan §5.1) is F2 scope.
- Paper prompt refresh relies on `M1OfficeController._process`; a paper outside an office scene keeps its default prompt (no consumer outside the office exists today).

## Next bounded pass

- F2 in full: §3 contract (signal/copy/session completion split, COPYING state, two-cursor paper, grace/route/commit timers by t0, warnings, terminal partial, retained sheets), then the early checkpoint playtest with 2–3 fresh players.

## Status

- engineering complete (F0+F1)
- presentation pending (no runtime recording this pass; none required by the F1 contract)
- human acceptance pending (F7 protocol, §13)

## Correction pass update (2026-09-19, after review docs/reports/m1_living_shift_f1_f2_review.md)

R1–R4 from the review were applied on the F1 surface:

- **R1** — the key now reports the session's work (COPYING → "Finishing the Copy", VERIFYING → "Read the Finished Copy", AWAITING_COMMIT → "File One Copy", CONSEQUENCE → "Stand By") via `_apply_key_state_for_session` in `scripts/office/shift_director.gd`, refreshed on every `session_state_changed`. Covered in `tests/office/shift_director_test.gd` sections 10/14.
- **R2** — EMPTY/PREPARING sheets report "No Copy Yet" with no [E] and open no viewer (`_update_transcript_prompt` / `_on_transcript_inspected` in `scripts/office/m1_office_controller.gd`). Covered in `tests/ui/framing_test.gd` 5d.
- **R3** — the false-positive scalar counter was replaced with an array counter plus a positive control (idle 0, valid open exactly 1); Escape was re-verified through real engine dispatch (`Viewport.push_input`) in both node orders (`tests/ui/framing_test.gd` 5c/5f).
- **R4** — `is_world_view_blocked()` now includes the pause menu; covered in `tests/ui/framing_test.gd` 5e.

Fresh full regression after corrections: **34 suites / 1536 assertions / 0 failed** (this run). Production boot exit 0; main-scene smoke PASSED. Runtime capture with a real window and audio: 39 PASS / 0 FAIL, 14 screenshots + master WAV in `.dream-loop/playthrough_water/` — not visually inspected by the model (no image input); reviewed by the owner before the checkpoint playtest.
