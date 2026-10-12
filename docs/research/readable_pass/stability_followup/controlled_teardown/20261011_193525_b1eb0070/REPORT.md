# Controlled teardown experiment — shift_director isolated crash

Date: 2026-10-11. Godot v4.7.1 console, `--headless --audio-driver Dummy`, each run a fresh process via `tools/with_preserved_settings.py`.

## Arms
- **control**: `tests/office/shift_director_test.gd` as it stood in the working tree (uncommitted; this is NOT git HEAD). Frozen copy: `control_source.gd.snapshot`, SHA256 93102bcca9189bc55df33596377a52c5c7642dcbc185e5cd7a32a872d357042b, 28172 bytes, identical to the live file at snapshot time.
- **diagnostic**: now `tools/repro/shift_exit_reproducer.gd` (moved out of `tests/office/` so test discovery no longer picks it up; the batch ran it from its original path, bytes unchanged, SHA256 b88fd1031b314fa6f3140870bb33e2d1685c9cb4feb5af007878b050a4a78027). Only difference is the block replacing the single `merge_office.queue_free()` before `quit(0)`:
  stop playing AudioStreamPlayer* under each office, remove and free every `_live_offices` entry plus the merge office, clear `_live_offices`, then `await process_frame` twice before the PASSED banner and `quit(0)`. All 132 assertions untouched.
  Note: `_fresh_office` still frees earlier offices as before; the last `fresh_office` is now freed at teardown (the audit's L260 finding). No `OfficeAmbience.stop()` was called; players were stopped generically.

## Results (exit code as returned by the child process; PASS = `  PASS:` lines)
| arm | runs | exit codes | PASS | banner | runtime FAIL | runs w/ ERROR (resources) | runs w/ ObjectDB warning |
|---|---:|---|---|---|---:|---:|---:|
| control | 10 | 0x0 ×10 | 132 ×10 | 10/10 | 0 | 7/10 | 7/10 |
| diagnostic | 10 | 0x0 ×10 | 132 ×10 | 10/10 | 0 | 6/10 | 6/10 |

- No native crash (0xC0000005) occurred in either arm.
- No SCRIPT ERROR / parse errors in either arm. Only shutdown `resources still in use` and `ObjectDB instances leaked` lines, in the same runs in both arms.
- Logs: `control/run_0..9.log`, `diagnostic/run_0..9.log` (unique per batch, under this folder). Diagnostic exits and counts: `diagnostic/summary.json`.

## Evidence strength
- The original crash was 1/10 (`repeats/shift_isolated_a02/20261011_192904_b85134ac`, run 04). Control 0/10 does **not** reproduce it. At p≈0.1, P(0 crashes in 10) ≈ 0.35, so this batch is uninformative about the crash rate.
- Diagnostic 0/10 does **not** show the teardown change fixes it, for the same reason.
- Upper bound on the per-arm crash rate after 0/10 (exact binomial, computed in Python): two-sided 95% Clopper-Pearson ≈ 30.8%; one-sided 95% ≈ 25.9%. The earlier "~31%" is the two-sided figure.
- Shutdown noise differs by run (control 7/10 runs, diagnostic 6/10 runs; per-run membership is not identical, e.g. control run_1 has ObjectDB warnings, diagnostic run_1 does not). Noise is not a crash signal in either arm.
- Both arms are identical in crash outcome, so there is no evidence here that explicit free + two-frame wait changes anything.
- Hypotheses H1/H2 in TEARDOWN_AUDIT.md remain **unverified**. Need ≥30 runs per arm (per audit plan) and a dump or verbose capture to test them. No Null-driver arm was run (driver not verified).

## Not done
- No game code, scene, or original test edits. No commits. No registry/WER/settings change. No full regression.
- Parent `stability_followup/REPORT.md` corrected: ObjectDB warning count is 6 of 10 per raw logs (was "8 of 10").
- Discovery: `shift_exit_reproducer` moved out of `tests/office/`; `*_test.gd` discovery returns 78 suites with it absent (was 79).
