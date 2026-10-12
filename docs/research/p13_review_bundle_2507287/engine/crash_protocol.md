# Frozen crash-validation protocol — Godot 4.8-dev7 (declared BEFORE any run)

Date: 2026-10-12. Session: sound_handoff_final_2507287.
Owner-approved path: Option A only (official 4.8-dev7, SHA-512 verified, setup_record.md).

## What is already fixed evidence (NOT re-run)
- 4.7.1 historical: 3 dumps, AV 0xC0000005 at RVA +0x547AF6, read of s->self() inside
  GDScriptLanguage::finish cleanup.
- 4.7.1 final_regression_2: rule44_content_test.gd exit 3221225477 after 12/12 PASS.
  Preserved. NOT re-run on 4.7.1 to chase a crash.
- Official MRP (#117975 zip) on 4.7.1: exit 0, does not reproduce → INCONCLUSIVE.

There is therefore NO reliable concurrent failing control available. Per the protocol this
makes any clean treatment result INCONCLUSIVE as to causal mechanism — even if every run
below is green.

## Prespecified serial run set (one factor changed: engine 4.7.1 -> 4.8-dev7)
All runs: frozen snapshot C:\Users\YUSIF\.hermes\cache\scratch\dw48_snapshot (no .godot carried
over from live tree, imported fresh by 4.8), same flags, same script args as the 4.7.1 runs,
through tools/with_preserved_settings.py, raw child exit recorded unsigned-hex.

R1  4.8 headless focused: tests/telegraph/rule44_content_test.gd        (the 4.7.1 crasher)
R2  4.8 headless focused: tests/office/shift_director_test.gd            (historical probe site)
R3  4.8 headless focused: rule44_content_test.gd again, serial repeat     (max 2 reps total)
MAX focused runs = 3. No further repeats regardless of outcome.

R4  4.8 windowed standalone-equivalent boot of the production scene, 1 run.

If any run yields 0xC0000005: preserve raw log + exit, STOP this protocol, report as blocker.
No run is repeated to obtain green.

## Comparison factors held constant
Project inputs (snapshot of live tree at 2507287, clean), renderer/audio flags identical to the
corresponding 4.7.1 invocation, test command identical, settings.cfg hash checked before/after.

## Explicitly out of scope
Building a patched 4.7.1; compiler/toolchain; debugger/SDK; WER/registry; dump upload;
source replacement; distribution of any diagnostic candidate.

## Label rule
- Any observed 0xC0000005 → FAIL, blocker, candidate NOT READY.
- All clean → INCONCLUSIVE on causality (no failing control). Stability of the candidate
  still gates READY: a demonstrably stable frozen candidate with no observed crash in the
  final required full regression is required for READY FOR SOUND DESIGNER EVALUATION.