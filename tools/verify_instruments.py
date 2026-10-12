"""Run all Godot suites with saved full logs and bounded execution.
This reports actual failures; it does not waive known flaky/erroring suites.
"""
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path('C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
OUT = ROOT / 'docs/art/state_2026-10-10/instruments/verification'
OUT.mkdir(parents=True, exist_ok=True)
results = []
for suite in sorted((ROOT / 'tests').rglob('*_test.gd')):
    relative = suite.relative_to(ROOT).as_posix()
    try:
        proc = subprocess.run([str(ENGINE), '--headless', '--audio-driver', 'Dummy', '--path', str(ROOT),
                               '--script', 'res://' + relative], capture_output=True, text=True,
                              encoding='utf-8', errors='replace', timeout=120)
        output = proc.stdout + proc.stderr
        code = proc.returncode
    except subprocess.TimeoutExpired as exc:
        output = str(exc.stdout) + str(exc.stderr)
        code = 124
    (OUT / (suite.stem + '.log')).write_text(output, encoding='utf-8')
    passed = len(re.findall(r'^\s*PASS:', output, re.M))
    fail_lines = [line for line in output.splitlines() if 'FAIL:' in line]
    errors = [line for line in output.splitlines() if line.startswith(('ERROR:', 'SCRIPT ERROR:'))]
    success = code == 0 and not fail_lines
    result = {'suite':relative, 'exit_code':code, 'assertions':passed, 'passed':success,
              'fail_lines':fail_lines, 'error_lines':errors}
    results.append(result)
    print(('OK' if success else 'FAIL'), relative, 'exit', code, 'assertions', passed, flush=True)
summary = {'suites':len(results), 'passed':sum(r['passed'] for r in results),
           'failed':sum(not r['passed'] for r in results),
           'assertions_in_passed_suites':sum(r['assertions'] for r in results if r['passed']),
           'assertions_in_all_suites':sum(r['assertions'] for r in results), 'results':results}
(OUT / 'regression.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k != 'results'},indent=2))
raise SystemExit(1 if summary['failed'] else 0)
