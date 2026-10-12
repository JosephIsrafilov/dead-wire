# 4.8-dev7 finding: global class list registration differs (REGRESSION-48-01)

## Symptom
4.8-dev7 full regression: 85/86 suites OK, 2746 assertions, 0 SCRIPT ERROR.
One FAIL: tests/telegraph/american_morse_encoder_test.gd line 221 —
`ClassDB.can_instantiate("AmericanMorseEncoder")` → ERROR "Cannot get class", can_instantiate=false.

## Isolation (this session, frozen snapshot)
- Direct instantiation works: `AmericanMorseEncoder.new()` OK.
- ProjectSettings.get_global_class_list() CONTAINS the correct entry
  (base RefCounted, path res://scripts/telegraph/morse/american_morse_encoder.gd, size 60).
- GDScript.get_instance_base_type() returns RefCounted correctly.
- ClassDB.class_exists("AmericanMorseEncoder") = false on 4.8-dev7;
  the same check on 4.7.1 (historical full regressions, same suite) passed.

## Interpretation
In 4.8-dev7, non-tool global GDScript classes are no longer registered into ClassDB the way
4.7.1 did (dev-cycle engine change, unrelated to PR #117991 or the crash). The TEST asserts an
engine-registration detail, not game behavior; the encoder itself works (91 PASS in the same
suite, all functional assertions green).

## Disposition per frozen protocol
This is a NEW 4.8 behavior difference, not a game defect. Two honest options:
(a) keep suite as-is and record 85/86 on 4.8 as the known engine-registration delta;
(b) owner-approved test change: replace the ClassDB assertion with an equivalent that tests
    what the game actually relies on (script loads, base type, instantiation), keeping
    assertion count equal or higher.
NOT done unilaterally: modifying a frozen test to turn 86/86 green would weaken the suite.
Recorded as blocker-adjacent finding; reported to owner in the final table.

## Evidence
- snapshot builds/regression48/summary.json (suites 86, passed 85, failed 1, assertions 2746,
  error_bearing 22)
- builds/regression48/american_morse_encoder_test.log (91 PASS, 1 FAIL, ClassDB ERROR)
- isolation probes in this session transcript (tools_cdb_probe/2/3 outputs)
