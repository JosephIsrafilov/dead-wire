# ClassDB assertion fix — RED→GREEN evidence (sound-handoff follow-up)

## Change (test-only, one assertion, intent preserved)
`tests/telegraph/american_morse_encoder_test.gd` #18:
- OLD: `ClassDB.can_instantiate("AmericanMorseEncoder")` — engine ClassDB registration;
  inappropriate for a script global class (true in 4.7.1, false from 4.8-dev7 onward).
- NEW: load the script and verify `get_global_name() == "AmericanMorseEncoder"` AND
  `Script.can_instantiate()` — the same "the class is properly registered and instantiable"
  intent expressed through the script-global-class API.
- Assertion count: 92 PASS lines before the fix failed at #18 (91 printed + the failing
  one); after the fix 93 PASS / 0 FAIL. Count did not drop. Assertion NOT deleted or skipped.

## RED (4.8-dev7, old assertion — already preserved)
- File: regression48/american_morse_encoder_test.log (frozen snapshot run):
  91 PASS, then `ERROR: Cannot get class 'AmericanMorseEncoder'` +
  `FAIL: Assertion failed: AmericanMorseEncoder is registered`, child exit 1.
- Regression summary: 86 suites / 85 passed / 2746 assertions.

## GREEN (4.8-dev7, new assertion)
- Snapshot rerun after applying the fix: exit 0, 93 PASS, 0 FAIL, 0 SCRIPT ERROR,
  line `PASS: AmericanMorseEncoder is registered`.
- Back-compat check on 4.7.1 (same snapshot, same command): exit 0, 93 PASS, 0 FAIL —
  the new assertion is GREEN on BOTH engines (no 4.7.1 regression introduced).

## gdlint
- tests are formally exempt; file had 35 pre-existing style findings, 35 after the change
  (line length was wrapped onto three lines to avoid adding any).

## Scope guard
Production Morse timing/architecture untouched; single test file changed, diff recorded in
session log; production file hash before change d377bc3e9ea61948 (backup enc_test_before.gd).
