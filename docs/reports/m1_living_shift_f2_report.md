# M1 Living Shift — Phase F2 Report

## Phase / date / HEAD / working-tree changes

- Phase: F2 (complete writing and consequence contract), per `docs/m1_living_shift_plan.md` §10 F2, implementing §3, §4.2, terminal partial from §5.1, minimal lapsed/route facts from §7.
- Date: 2026-09-19.
- HEAD: `70a89675036eaf9fdcc742c513a12fa8c95c1c60` (uncommitted working tree on top; F0+F1 report covers the earlier interaction pass).
- Working-tree changes: the files listed below; user's untracked dirs untouched.

## Problem seen by player (baseline defects fixed by this phase)

1. The paper "completed" when the signal ended (`reveal_transcript()` at `transmission_finished`), so standing up mid-message or losing the hand for a moment never mattered: the sheet was always instantly perfect at t0.
2. `copied_*` was recorded at signal end, not when ink actually finished; a player who left the desk still "copied" the telegram.
3. No COPYING state: grace, commit deadline and route deadline each counted from different moments (commit from verification, route from verification), and inspecting reset nothing while a half-written sheet could be read as a finished telegram.
4. A routing lapse recorded the *incorrect* world fact ("held in error"/"cleared in error") — no order sent was indistinguishable from a wrong order.
5. `has_submitted`/`filed_` duplication: the director recorded `filed_*` on every `session_completed`, so a lapsed slot could be re-counted; closing sign counted one lapse as both defaulted and misdirected.
6. Sheet ownership: an old terminal sheet could pass verification for a *new* session's scenario through the shared inspect listener.
7. Standing at the key started ink with nobody in the chair; sit/stand during a message had no effect on the sheet at all.

## Implemented behavior

**Session (§3.2/§3.3/§3.5):**
- New `COPYING` state between t0 and physical copy completion; skipped when the sheet is already complete at t0.
- Three distinct events, each exactly once: `transmission_finished` (objective signal end, guarded by active-schedule ownership so calls/nags/closing never fake t0), `copy_finished` (paper's last physical glyph, re-emitted by session for the current scenario only), `session_completed` (terminal resolution, unchanged).
- One post-signal clock `_post_signal_elapsed` starting at t0, advanced once per tick, read by grace, commit deadline, warnings, and (via the director) the route deadline. Commit deadline now runs from t0 through COPYING/VERIFYING/AWAITING_COMMIT; inspecting or sitting never restarts it; expired-at-input submissions are rejected at the door.
- Unfinished-copy grace (20 s default) starts at t0 on an incomplete sheet, is cancelled the instant the copy completes, and on expiry closes the sheet and resolves the slot through the same lapse path as a deadline.
- Deadline warnings: grace warning ~5 s before grace (replaces the later commit warning while a grace is live), commit warning ~10 s before commit. Both ride the existing call sign on the same sounder when the line is idle and wait (without extending anything) when it is not; guidance shows "Finish the copy — the sender is waiting" / "The sender is about to release the line".
- `reset_session` keeps terminal sheets (the night's record stays on the desk) and closes an abandoned live sheet as an honest partial with `incomplete_copy_<id>` recorded; the sheet survives until the next telegram physically replaces it. Watch reset remains the scene reload through the title menu.

**Routing/commit outcomes (§3.6):**
- `RoutingOutcome {CORRECT, INCORRECT, LAPSED}` replaces the boolean; a lapse records the scenario's `routing_lapsed_world_fact` (`train_17_no_order_sent` / `freight_no_order_sent`) and `routing_lapsed_knowledge_fact` (`lapsed_<id>`), never the incorrect fact.
- Accepted actions record what was actually sent: `route_clear_east_<id>`/`route_hold_<id>` plus `filed_<id>`; lapsed records `lapsed_<id>`. The director no longer writes `filed_*`/`lapsed_*` itself.
- `copied_<id>` moved to `copy_finished` (director listener); `incomplete_copy_<id>` recorded whenever a live sheet is closed (grace, deadline lapse, or reset of an abandoned session).
- Terminal counters counted exactly once via the outcome event: LAPSED → `routes_defaulted`, INCORRECT → `routes_misdirected`; `_lapsed_slot` removed. Closing `OS 17` no longer double-counts a lapse.

**Paper (§4.2):**
- Explicit `PaperState` machine: EMPTY/PREPARING/COPYING/COPYING_PAUSED/READY_TO_INSPECT/INCOMPLETE_CLOSED.
- Two cursors: `available_glyphs` (signal-authorized, only grows) and `written_glyphs` (physical ink). Hand entry gate (0.18 s) before any ink; authored pace in the continuous seated path; bounded backlog catch-up at 3.5 glyphs/s after entry gaps, frame hitches and returns; each glyph: nib reaches contact point first, ink second.
- `suspend()`/`resume_writing()` freeze and re-enter without resetting cursors; `close_incomplete()` is terminal — the partial prefix survives and never reopens, in this session or any later one.
- `copy_finished(scenario_id)` emitted exactly once on the last glyph; `reveal_transcript()` remains an authoring shortcut that production never calls (session no longer calls it at t0).

**Seat (§4.1 minimal lifecycle):**
- `sit_completed` signal fires when the sit transition physically finishes (or immediately for zero-duration/authored cases); `stood` is stand-start.
- Office glue: stand (or answering while standing) suspends the sheet; sit-completed resumes it. The signal, deadlines and grace continue through stand/return untouched.

**Director:**
- Route deadline starts at t0 (`_on_transmission_finished`) for routing scenarios and reads the session's elapsed; nags read the same clock. `is_route_deadline_expired()` gates the office's route submission so an expired deadline rejects a late lever throw.

**Duty sheet:** `incomplete_copy_<id>` → `COPY INCOMPLETE` status, ordered after lapsed/filed so the terminal outcome a slot ended on is never masked.

## Contract/data changes

- `TelegraphSessionController`: new `COPYING` state, `RoutingOutcome` enum, signals `copy_finished`, `deadline_warning`; `routing_resolved(action, outcome)` (breaking); exports `unfinished_copy_grace_seconds`, `commit_warning_seconds`, `copy_grace_warning_seconds`; `notify_operator_stood/seated`; `advance_post_signal`; active-schedule ownership; reset semantics above.
- `TelegraphScenarioData`: `routing_lapsed_world_fact`, `routing_lapsed_knowledge_fact` (empty-compatible defaults; filled for both M1 routing scenarios).
- `TranscriptPaper`: state machine, two cursors, `advance_paper(delta)` presentation tick, `copy_finished` signal, suspend/resume/close_incomplete, `get_paper_scenario_id`.
- `OperatorSeat`: `sit_completed` signal.
- `ShiftDirector`: t0 route deadline, outcome counters, `copied_` on copy_finished, warning-on-wire with pending defer, `is_route_deadline_expired`.
- `M1OfficeController`: stand/sit glue, read gate extended to COPYING (partial sheets never open the viewer; INCOMPLETE_CLOSED opens the honest `— COPY INCOMPLETE —` snapshot), deadline warning in guidance, route submission deadline gate.
- No new singletons, managers or event buses; no Morse timing changes; GDD invariants (Listener does not touch props, stores separation) preserved.

Files: `scripts/telegraph/session/telegraph_session_controller.gd`, `scripts/telegraph/session/telegraph_scenario_data.gd`, `scripts/telegraph/ui/transcript_paper.gd`, `scripts/player/operator_seat.gd`, `scripts/office/shift_director.gd`, `scripts/office/m1_office_controller.gd`, `scripts/telegraph/ui/duty_sheet.gd`, `data/scenarios/m1_scenario_1_baseline.tres`, `data/scenarios/m1_scenario_2_attention.tres`, plus tests and `tools/first_night_playthrough.gd` (bounded wait for the post-t0 copy drain).

## Focused checks: commands, exit codes, outcomes

- `godot --headless --audio-driver Dummy --path . --script tests/telegraph/transcript_paper_test.gd` — PASSED (45 assertions; rewritten for the two-cursor contract: entry gate, authored pace, suspend/resume, exactly-once copy_finished, terminal partial never reopens).
- `... tests/telegraph/telegraph_session_controller_test.gd` — PASSED (~90 assertions; new W01–W08/O01–O05/O04 sections: t0/COPYING, grace lapse facts, stand/return round trip, old-sheet no-verify, service-signal-is-not-t0, warning exactly-once, late-input rejection).
- `... tests/telegraph/telegraph_scenario_data_test.gd` — PASSED (lapse fields + compatible empty defaults).
- `... tests/telegraph/duty_sheet_test.gd` — PASSED (25; COPY INCOMPLETE ordering).
- `... tests/office/shift_director_test.gd` — PASSED (99; t0 deadline, nag on shared clock, lapse-is-not-misroute).
- `... tests/office/atmosphere_test.gd` — PASSED (44; interleaved scheduler/paper ticks).
- `... tests/integration/night_recovery_test.gd` — 0 failures across file_water/file_watcher/lapsed/missed.
- `... tests/integration/m1_office_integration_test.gd` — PASSED.

## Full regression: suites/assertions from this run

- `GODOT_BIN=$(command -v godot) bash tools/run_all_tests.sh`: **34 suites passed, 0 failed, 1470 assertions** (F1 baseline: 34/0/1389).

## Production boot + InputMap smoke

- Headless production boot `--quit-after 120 res://scenes/office/m1_office.tscn` — exit 0.
- `main_scene_smoke_test.gd` — 9/9 PASS.

## Visual/audio evidence: paths and what was actually inspected

- None recorded this pass. F2 is logic/contract; all timing values (grace 20 s, catch-up 3.5 glyph/s, warnings 10/5 s) are start settings for playtest per §0.3. The physical sheet-feed animation, smooth seat transition and lever/stamp acknowledgments are F3 scope.

## Open issues / untested areas

- Real-window InputMap verification of stand/return during live writing (covered by direct notify calls and interleaved ticks only).
- `tools/first_night_playthrough.gd` updated for the post-t0 drain but not executed with a real window this pass.
- The captured-call edge (warning deferred while a nag plays) is implemented but only exercised implicitly; no dedicated assertion.
- F2 early checkpoint playtest (2–3 fresh players, §10) not yet performed — required before F3 polish per the plan.

## Next bounded pass

- F2 checkpoint playtest, then F3: physical seat transition, sheet feed on new telegram, lever/stamp acknowledgments, retained board, ledger NIGHT ENTRIES.

## Status

- engineering complete (F2)
- presentation pending (no runtime recording; F3 owns the physical presentation)
- human acceptance pending (early checkpoint + F7)

## Correction pass update (2026-09-19, after review docs/reports/m1_living_shift_f1_f2_review.md)

R5–R9 from the review were applied; F3 scope (sheet feed, smooth body path, ledger polish) was not started, per the review's instruction.

**Implemented and tested:**

- **R5** — `WriterRig` gained real `suspend()`/`resume_writing()` (preserves `_last_glyph_index` and the arm pose; returns to the pose it left instead of re-initializing) and a deterministic entry clock `advance_presentation(delta)`. The paper's ink gate is now the rig's actual readiness (`is_ready_to_write()`), not an independent 0.18 s timer; `set_writing_progress` refuses glyph updates while the rig is ENTER. Covered in `tests/telegraph/transcript_paper_test.gd` (enter partial/full, index preserved through suspend/resume, no re-init).
- **R6** — `TranscriptPaper.max_glyphs_per_tick` (default 1): a hitch may authorize many glyphs, but each presentation tick reveals at most one, so every glyph keeps its own contact point in its own rendered frame. Covered in the same suite (hitch reveals exactly +1, next tick +1).
- **R7** — `OperatorSeat.is_settled()` (seated AND transition finished). Answering mid-sit still starts the signal, but the sheet waits in COPYING_PAUSED until `sit_completed` resumes it. Covered in `tests/ui/framing_test.gd` 5d-2.
- **R8** — one deadline warning per scenario (`_deadline_warning_fired`): a grace warning silences the later commit warning even after the copy completes. The deferred warning is validity-checked (`_warning_still_relevant`) and dropped on resolution/slot change/closing; slot resets clear it. Warnings and nags merge within `warning_nag_merge_seconds` in both orders (one wire call). Covered in `tests/telegraph/telegraph_session_controller_test.gd` 11b and `tests/office/shift_director_test.gd` 14/17 (including the warning+nag single-call case on a fresh office).
- **R9** — `DocumentViewer.set_live_footer(text)`: the deadline warning updates the open document's footer in place (no reopen, no scroll reset, no body change) and restores the original footer when the situation resolves. Driven from `M1OfficeController._process`. Covered in `tests/ui/framing_test.gd` 5d-3 via the real grace-warning path with the real session clock.

**Fresh numbers from this run** (not copied from the previous report): focused suites all PASS (transcript_paper, session_controller, scenario_data, duty_sheet, shift_director, atmosphere, window_observation, routing_board, document_viewer, framing, both integration suites); full regression **34 suites / 1536 assertions / 0 failed**; production boot exit 0; main-scene smoke PASSED.

**Runtime evidence:** real-window capture run of the full night (`tools/first_night_playthrough.gd -- --capture`): 39 PASS / 0 FAIL, 14 screenshots + 48 kHz stereo master WAV in `.dream-loop/playthrough_water/`, covering seated receive of all three messages (WATCHER ink while WATER sounds), transcript inspection, InputMap routing, physical commit, window consequence, handover, ending and restart. The model cannot view images/audio; the owner must review the recording before the checkpoint playtest.

**Untested in this pass:** stand/return and late-return-after-grace were not recorded in the real-window capture (the capture tool has no branch for them; headless suites cover the logic); the audibility of the grace warning behind an open document with real speakers is owner-reviewed, not model-verified.
