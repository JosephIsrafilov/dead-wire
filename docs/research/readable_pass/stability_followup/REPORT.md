# A02 stability follow-up — isolated shift_director repeats

Date: 2026-10-11. Engine: Godot v4.7.1 console binary (`C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`).
Harness: `tools/repeat_engine_exit.py` → `tools/with_preserved_settings.py` (settings.cfg preserved). Each engine call is a separate fresh process. No other Godot process was running at start.

## Batch 1: isolated `tests/office/shift_director_test.gd` ×10
Evidence: `repeats/shift_isolated_a02/20261011_192904_b85134ac/` (run_00..run_09.log, summary.json).

| run | exit | hex | PASS lines | assertions≥132 | runtime ERROR | ObjectDB/resource warnings | harness passed |
|---|---:|---|---:|---:|---:|---|---|
| 00 | 0 | 0x0 | 132 | yes | 1 | 22 ObjectDB / 3 resources | yes |
| 01 | 0 | 0x0 | 132 | yes | 0 | none | yes |
| 02 | 0 | 0x0 | 132 | yes | 1 | 20 ObjectDB / 3 resources | yes |
| 03 | 0 | 0x0 | 132 | yes | 0 | none | yes |
| **04** | **3221225477** | **0xC0000005** | 132 | yes | 0 | none | **no** |
| 05 | 0 | 0x0 | 132 | yes | 0 | none | yes |
| 06 | 0 | 0x0 | 132 | yes | 1 | 22 ObjectDB / 3 resources | yes |
| 07 | 0 | 0x0 | 132 | yes | 1 | 14 ObjectDB / 1 resource | yes |
| 08 | 0 | 0x0 | 132 | yes | 1 | 22 ObjectDB / 3 resources | yes |
| 09 | 0 | 0x0 | 132 | yes | 0 | 12 ObjectDB (no resource line) | yes |

Summary: harness passed 9/10. **Run 04 = native access violation `0xC0000005` (3221225477) after all 132 assertions printed `PASS` and `--- All Shift Director Tests PASSED (132 assertions) ---`.** Exit-1 from the harness is caused by run 04 alone; the visible last run (09) being green does not mean all passed.

Separately recorded (not assertion failures):
- Shutdown ERROR `resources still in use` in runs 00, 02, 06, 07, 08 (1 or 3 resources).
- Shutdown WARNING `ObjectDB instances were leaked` in 6 of 10 runs (00, 02, 06, 07, 08, 09; counted from raw logs).
- Zero `FAIL:` lines and zero `SCRIPT ERROR` lines in all 10 runs.

Run 04 is the reproducer of the native crash in isolation: it occurred in a fresh process with no predecessor suite, so the leak-order hypothesis in CRASH_ISSUES.md is further weakened (the crash does not require a predecessor).

## Stop condition
Native access violation recurred → **no further repeats and no full serial regressions (0 of 3 run)**, per instruction. Not retried until green.

## Next step (reproducer)
`python tools/repeat_engine_exit.py --suite tests/office/shift_director_test.gd --runs 10 --case shift_isolated_a02` reproduced 1/10 with the above exit. Next diagnostic (not run): capture `--verbose` on a rerun and check whether the 0xC0000005 is at teardown after the final PASS line (it appears so: last log line is the PASSED banner, and the log has no error text beyond it).

## Not claimed
- No root cause identified. No fix applied. No gameplay, scene, or asset edits. No commits.
- "Fixed", "stable", or "error-free" are not claimed for any run.
- Future human visual/FPS gate remains open; this is a headless engine-exit result, not a visual acceptance.
