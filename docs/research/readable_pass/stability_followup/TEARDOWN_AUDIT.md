# A02 isolated shift_director — teardown audit (read-only)

Date: 2026-10-11. Scope: static read of `tests/office/shift_director_test.gd` and its runtime deps, plus counts from raw logs. No engine runs, no game code edits, no WER/debugger configuration.

Evidence: `repeats/shift_isolated_a02/20261011_192904_b85134ac/run_00..09.log`, `summary.json`.

## 1. Facts from raw logs (counted programmatically)

| run | exit | PASS lines | PASSED banner | ERROR (resources) | WARNING (ObjectDB) |
|---|---|---:|---|---|---|
| 00 | 0 | 132 | yes | 3 | 22 |
| 01 | 0 | 132 | yes | — | — |
| 02 | 0 | 132 | yes | 3 | 20 |
| 03 | 0 | 132 | yes | — | — |
| **04** | **0xC0000005** | 132 | yes | **—** | **—** |
| 05 | 0 | 132 | yes | — | — |
| 06 | 0 | 132 | yes | 3 | 22 |
| 07 | 0 | 132 | yes | 1 | 14 |
| 08 | 0 | 132 | yes | 3 | 22 |
| 09 | 0 | 132 | yes | — | 12 |

- Run 04 `run_04.log` is 6539 bytes, identical in size to the clean runs 01/03/05. It has the full 132 PASS lines and the PASSED banner, then nothing. No error text, no stack, no `SCRIPT ERROR`.
- ObjectDB WARNING appears in **6 of 10** runs (00, 02, 06, 07, 08, 09), not 8. REPORT.md prose ("8 of 10 runs") contradicts its own table, which lists six. The raw logs agree with the table: fix the prose.
- Resources ERROR appears in 5 runs (00, 02, 06, 07, 08), not 5 with 1-or-3 mixed as the prose implies; counts are 3,3,3,1,3.
- The crash run had **zero** leak warnings. Run 09 had 12 leaked ObjectDB and exited 0. So in this batch, leak count does not predict the crash.
- `summary.json` run 04: `runtime_errors: []`, `warnings: []`, `hex_exit: 0xc0000005`.

## 2. Windows dump availability (read-only queries)

- `%LOCALAPPDATA%/CrashDumps/` has only `Godot_v4.7.1-stable_win64.exe.16504.dmp` (2026-10-09) and `.16920.dmp` (2026-10-08). **No dump for 2026-10-11 run 04.**
- `HKLM\...\Windows Error Reporting\LocalDumps` has no Godot entry and no `DumpFolder` value, so no LocalDumps policy is configured for this exe. Default WER behaviour produced the earlier dumps; whether it produced one for run 04 is unknown from this evidence.
- Options (not executed): (a) add a LocalDumps entry for `Godot_v4.7.1-stable_win64_console.exe` (registry write, needs user approval); (b) attach a debugger/procdump to the controlled runner only with the user's OK. Neither was configured here.

## 3. Teardown path in `tests/office/shift_director_test.gd`

- L20 `_init` → `call_deferred("_run")`. The whole suite is a single coroutine (L22 `_run`).
- L25 / L114 / L260 `_fresh_office()` creates three offices. Each call frees the *previous* entries of `_live_offices` (L365–371) and then appends the new one (L381).
- **L260 `fresh_office` is the last office created by `_fresh_office`.** It is appended to `_live_offices` (L381) and never freed. `_live_offices` is only pruned at the *next* `_fresh_office()` call, and none follows.
- L325–358 "merge" office is instantiated directly from `ResourceLoader` (not via `_fresh_office`), so it is **not** in `_live_offices`. It is freed by `merge_office.queue_free()` at L358, followed immediately by `quit(0)` at L361 with no `await process_frame` in between.
- L328–329 and L346/L352/L356 use `await` inside `_run`. Any tween/callback that fires across those frames happens while the suite is still a pending coroutine.
- `set_process(false)` is called on the office, `office.shift_director`, and `session.scheduler` (L333–335, L387–388), but the audio/tween children are not stopped explicitly.
- No `_exit_tree`, no `tree_exiting` disconnect, no `NOTIFICATION_PREDELETE` anywhere in `scripts/` (grep confirmed). `ShiftDirector` (`scripts/office/shift_director.gd` L146–185) connects to session signals with no disconnect on exit.

## 4. Live engine objects that survive to `quit(0)` (static)

- **Audio players created in code:** `SounderController` `AudioStreamPlayer3D` `AudioPlayerDown/Up` (`scripts/telegraph/hardware/sounder_controller.gd` L62, L72); `OfficeAmbience` `AudioStreamPlayer` + 3 `AudioStreamPlayer3D` (`scripts/audio/office_ambience.gd` L66, L75–81). These live on `fresh_office` and are not stopped before quit. Under `--audio-driver Dummy` the mixer still runs.
- **Tweens with no bind target:** `m1_office_controller.gd` L69 `create_tween().tween_method(ambience.set_hush_db, ...)`; `unease_director.gd` L277 `_hush_tween` (killed only on re-entry); `intro_card.gd` L115–123 `_music_fade` + `tween` (chained `tween_callback(_release)`). Killed only in `_release()` / re-entry, so an unfinished tween can still be pending at quit.
- **Signal-connected audio callbacks:** `sounder_controller.gd` L91–92 connects scheduler `playback_completed` / `playback_cancelled`; L102–105 disconnects only on a re-bind path, not at exit.

## 5. Ranked hypotheses

**H1 (most consistent with the data): native race at engine shutdown with live audio players and in-flight tweens on `fresh_office`.**
- Anchors: `shift_director_test.gd` L260 (never freed) + L361 `quit(0)`; `sounder_controller.gd` L62/L72; `office_ambience.gd` L66/L75–81; `m1_office_controller.gd` L69.
- Why: the crash happened after all PASS lines, with no error text, and at 1/10. An intermittent native access violation at exit with audio objects still live fits a shutdown-order race better than a leak count. The crash run had zero leak warnings, which argues against leak-order as the trigger.
- Status: **unverified**. This is a static hypothesis.

**H2: merge office freed in the same frame as `quit(0)` (`queue_free` at L358, `quit(0)` at L361, no frame boundary).**
- Anchors: `shift_director_test.gd` L325–329, L358, L361; `_run` is a coroutine with `await` at L328–329.
- Why: an office with pending tweens or audio callbacks is freed in the same frame the engine begins shutdown. Destruction order is not guaranteed.
- Status: unverified. Cheapest to test (one line).

**H3: leak-count / predecessor-order hypothesis from CRASH_ISSUES.md.**
- Anchors: `docs/research/readable_pass/exit_matrix/CRASH_ISSUES.md` (separate processes, so no in-process predecessor), this batch's run 04 (zero warnings) vs run 09 (12 warnings, clean exit).
- Status: **weakened further**, not ruled out for a same-process chain. The existing doc already notes the order was never actually exercised in one process.

## 6. Proposed minimal controlled experiment (not run)

Goal: separate H1 from H2 without changing game code.

Runner: a scratch copy of the test that adds an explicit teardown block before `quit(0)`:
1. Free all offices in `_live_offices` plus `fresh_office`.
2. `await process_frame` twice.
3. Stop audio: `AudioServer` idle, or `stop()` on each `AudioStreamPlayer*` found under the office.
4. Then `quit(0)`.

Arms (each a fresh process, same Godot binary, `--headless --audio-driver Dummy --path ... --script`):
- **A (control):** unmodified suite. Baseline: 1/10 crash from the batch (use ≥30 runs for a useful rate).
- **B (teardown):** scratch runner with explicit free + frame wait. ≥30 runs.
- **C (audio off):** `--audio-driver Null` with unmodified suite. ≥30 runs.

Pass/fail:
- If B crashes 0/30 and A crashes ≥1/30 → H1/H2 supported (teardown ordering). Next: bisect which step matters.
- If C crashes 0/30 and A ≥1 → audio objects implicated (H1 specifically).
- If all three arms crash at similar rate → teardown is not the trigger; move to WER dump / `--verbose` capture.
- Record exit hex and last log line for each run. Use `repeat_engine_exit.py` for the process loop.

Caveat: with p≈0.1, 30 runs per arm gives low power to detect a 0-vs-1 difference reliably. Report counts with exact binomial bounds.

## 7. Not claimed

- No root cause identified. The crash site is not known from the logs; no dump exists for run 04.
- No stack trace exists. The 0xC0000005 is the process exit code only.
- No game code, test, tool, or config was modified. No WER/registry/debugger change made. No engine process was started.
- REPORT.md prose error: "8 of 10" ObjectDB should read "6 of 10" (table and raw logs agree on 6).
