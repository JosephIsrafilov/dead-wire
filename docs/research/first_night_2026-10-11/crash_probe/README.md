# Bounded native crash probe

This directory is reserved for the one controlled `shift_director_test.gd` probe. It is
not a production fix and must not be used to infer that the shutdown/resource errors or
the historical native crash are resolved.

## Scope

- `tools/with_preserved_settings.py` remains the only settings owner. Its existing CLI
  is unchanged; `--result-json PATH` is optional.
- The result sidecar is written before the wrapper exits through `SystemExit`, retaining
  the child's signed return code, unsigned 32-bit value, and eight-digit hex value.
- `tools/repro/run_crash_probe.py` runs exactly one unmodified `shift_director_test.gd`
  command with `--verbose --headless --audio-driver Dummy`, through the preservation
  wrapper. It stores stdout and stderr separately and adds SHA-256 values for the test
  and engine plus platform information.
- The probe does not alter registry/WER/debugger settings, apply a teardown patch, or
  run a second attempt. The parent process is the only serializer.

## Command (not run by this change)

```powershell
rtk .venv-tools/Scripts/python.exe tools/repro/run_crash_probe.py
```

Optional engine override:

```powershell
$env:GODOT_BIN = 'C:\path\to\Godot_v4.7.1-stable_win64_console.exe'
rtk .venv-tools/Scripts/python.exe tools/repro/run_crash_probe.py
```

Each invocation creates a fresh timestamp-and-UUID subdirectory, so prior evidence is never overwritten. A timed-out run records partial stdout/stderr and a timeout result; no stale sidecar can be mistaken for that run.`n`nExpected outputs after an explicitly authorized probe run:

- `stdout.log`
- `stderr.log`
- `result.json`

## Prior evidence inspected

`docs/research/first_night_2026-10-11/implementation_a/shift_control_verbose.log`
ends after the `132 assertions` success banner, while its companion
`shift_control_verbose_exit.txt` contains `-1`. The prior report records the unresolved
historical Windows native code as a possibility, not as proof: the exact child code was
not preserved. This sidecar closes only that observability gap.

