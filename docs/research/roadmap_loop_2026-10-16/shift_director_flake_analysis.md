# shift_director_test teardown flake — root-cause analysis (ROADMAP loop, 2026-10-16)

## Observations

Two failed full regressions in this cycle, identical runner summary:

```
suites passed: 97   failed: 1   assertions: 2862
failed suites: tests/office/shift_director_test.gd
```

- during task 0.4 (run A; details truncated by operator `tail -3` — process lesson, see below);
- during task 0.5 (run A2, same signature).

Manual repro of the EXACT runner invocation
(`--headless --audio-driver Dummy --path <windows-path> --script res://tests/office/shift_director_test.gd`,
output captured through a pipe), 5 consecutive runs, unmodified tree:

| run | exit | PASS lines captured |
|-----|------|---------------------|
| 1 | 0 | 132 |
| 2 | 0 | 132 |
| 3 | **139** | **132** |
| 4 | 0 | 132 |
| 5 | **139** | **132** |

Logs: `repro_run_1_green.log`, `repro_run_3_crash.log`, `repro_run_5_crash.log`.

## Analysis

1. **The crash happens at engine teardown, after all 132 assertions pass.**
   Crashed runs (exit 139 = SIGSEGV) still captured the complete output including
   `--- All Shift Director Tests PASSED (132 assertions) ---`. This is the
   documented godot#117991 class (`GDScriptLanguage::finish` / `GDScript::clear`
   releases base before `s->next()`), applicability to this binary confirmed in
   `docs/research/first_night_2026-10-12_crash_review/`. Historic records match:
   exit 5 / 139 / 3221225477 (0xC0000005) "after 132 shift assertions".

2. **CORRECTION to the run-A journal note:** the failed full runs show
   `assertions: 2862` (= 2994 − 132) NOT because the suite printed 0 PASS lines,
   but because `run_all_tests.sh` adds a suite's assertion count to the total
   only when the suite passes (line 75-77). The earlier inference
   "lost pipe-buffered stdout / crash before output" was wrong; the repro proves
   output survives the crash. The run_A.log note is marked superseded.

3. **Not caused by any loop task.** Occurrence 1 happened on a tree whose only
   deltas were a comment and ignore rules; occurrence 2 on a tree identical to
   the previous green run (0.5 changes nothing on disk — `git gc` is .git-internal).
   The repro ran on the same unmodified tree and crashed 2/5. Frequency in full
   runs this cycle: 3 of 9 (≈33%; the third failure, 0.5 attempt 2, is preserved
   in full as `full_run_05_attempt2_fail_exit139.log` — runner line
   `FAIL tests/office/shift_director_test.gd exit 139`), consistent with the
   40% repro sample.

4. **Status: OPEN, engine-level.** Not fixed, not fixable in GDScript per the
   crash review (speculative project-side fixes were rejected there). The real
   decision is ROADMAP 0.8 (✋ owner): stay on 4.7.1 (crash on exit) or move
   everything to 4.8-dev7. Until then a full-run failure of
   `shift_director_test` with all 132 PASS captured and exit 139/0xC0000005 is
   this known flake: record it, rerun the full regression for the green gate,
   and reference this file. Counts of error-bearing suites are run-variable;
   this suite is never to be declared fixed on the strength of green repeats.

## Process lesson (feeds task 0.6)

The runner prints FAIL details only to stdout (`head -8` of fail/error lines)
and the operator truncated them twice with `tail -3`. Task 0.6 (runner rework)
should additionally save the full output of every FAILED suite to a file so
flake evidence survives without manual capture.
