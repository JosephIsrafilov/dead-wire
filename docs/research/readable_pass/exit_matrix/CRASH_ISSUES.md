# Native teardown crash investigation

## Minimal reproducer hypothesis (written before experiments)
The native crash in `tests/office/shift_director_test.gd` teardown occurs only when that suite is run after a suite that leaks resources; `tests/integration/m1_office_integration_test.gd` is the primary suspected predecessor.

## Experiments
Commands used (each wrapped suite invocation was a separate Godot process; this tests order across fresh processes, not one shared engine process):

```bash
PY='C:/Users/YUSIF/Documents/dead-wire/.venv-tools/Scripts/python.exe'
GODOT='C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
"$PY" tools/with_preserved_settings.py -- "$GODOT" --headless --audio-driver Dummy --path . --script res://tests/integration/m1_office_integration_test.gd
"$PY" tools/with_preserved_settings.py -- "$GODOT" --headless --audio-driver Dummy --path . --script res://tests/office/shift_director_test.gd
"$PY" tools/with_preserved_settings.py -- "$GODOT" --headless --audio-driver Dummy --path . --script res://tests/ui/framing_test.gd
"$PY" tools/with_preserved_settings.py -- "$GODOT" --headless --audio-driver Dummy --path . --script res://tests/office/shift_director_test.gd
"$PY" tools/with_preserved_settings.py -- "$GODOT" --headless --audio-driver Dummy --path . --script res://tests/office/shift_director_test.gd
```

Observed results:

| Run | Exit | Last lines |
|---|---:|---|
| m1_office_integration predecessor | 0 | `--- All M1 Office Full Integration Tests PASSED ---`; `WARNING: 57 ObjectDB instances were leaked at exit`; `ERROR: 11 resources still in use at exit` |
| shift_director after m1 | 0 | `--- All Shift Director Tests PASSED (132 assertions) ---`; `WARNING: 22 ObjectDB instances were leaked at exit`; `ERROR: 3 resources still in use at exit` |
| framing predecessor | 0 | `--- All Framing Tests PASSED (93 assertions) ---`; `WARNING: 21 ObjectDB instances were leaked at exit`; `ERROR: 6 resources still in use at exit` |
| shift_director after framing | 0 | `--- All Shift Director Tests PASSED (132 assertions) ---`; `WARNING: 22 ObjectDB instances were leaked at exit`; `ERROR: 3 resources still in use at exit` |
| shift_director control | 0 | `--- All Shift Director Tests PASSED (132 assertions) ---`; `WARNING: 22 ObjectDB instances were leaked at exit`; `ERROR: 3 resources still in use at exit` |

No crash wording occurred in these invocations; none exited `3221225477` / `0xC0000005`. Earlier orchestrator regression evidence reports the crash after 132 assertions, but these sequential fresh-process runs do not reproduce it.

## Diagnosis / limits
The leak-order hypothesis is not confirmed. The requested order is not actually exercised: each test script launches a separate Godot process, so predecessor resources cannot persist into the following suite. This is inconclusive about within-process suite ordering. Need a same-process subset/chain runner (or another supported mechanism) before attributing the native access violation to leak ordering. No game code changed.
