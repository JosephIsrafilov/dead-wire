"""Bounded Godot regression with full logs; assertion pass is not error-free.
Usage: python tools/verify_mechanics.py [--filter substring] [--out native/path]
"""
import argparse
import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ENGINE = 'C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'

def classify(output, code):
    lines = output.splitlines()
    failures = [x for x in lines if re.match(r'^\s*FAIL:', x)]
    errors = [x for x in lines if re.match(r'^\s*(?:SCRIPT )?ERROR:', x)]
    if any(re.match(r'^\s*SCRIPT ERROR:', x) for x in lines):
        failures.append('SCRIPT ERROR: parser/runtime failure')
    warnings = [x for x in lines if re.match(r'^\s*WARNING:', x)]
    return {'exit_code': code, 'assertions': len(re.findall(r'^\s*PASS:', output, re.M)),
            'passed': code == 0 and not failures, 'failures': failures,
            'runtime_errors': errors, 'warnings': warnings}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--filter', default='')
    parser.add_argument('--out', default=str(ROOT/'docs/research/mechanics_2026-10-10/final_tests'))
    args = parser.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    engine = os.environ.get('GODOT_BIN', DEFAULT_ENGINE)
    rows = []
    for suite in sorted((ROOT/'tests').rglob('*_test.gd')):
        rel = suite.relative_to(ROOT).as_posix()
        if args.filter and args.filter not in rel:
            continue
        try:
            proc = subprocess.run([engine, '--headless', '--audio-driver', 'Dummy',
                                   '--path', str(ROOT), '--script', 'res://'+rel],
                                  capture_output=True, text=True, encoding='utf-8',
                                  errors='replace', timeout=90)
            output, code = proc.stdout+proc.stderr, proc.returncode
        except subprocess.TimeoutExpired as exc:
            output, code = str(exc.stdout)+str(exc.stderr)+'\nFAIL: suite timeout', 124
        (out/(suite.stem+'.log')).write_text(output, encoding='utf-8')
        row = {'suite':rel, **classify(output, code)}
        rows.append(row)
        print(('OK' if row['passed'] else 'FAIL'), rel, 'assertions', row['assertions'],
              'runtime_errors',len(row['runtime_errors']),flush=True)
    summary = {'suites':len(rows), 'passed':sum(x['passed'] for x in rows),
               'failed':sum(not x['passed'] for x in rows),
               'assertions':sum(x['assertions'] for x in rows),
               'error_bearing_suites':sum(bool(x['runtime_errors']) for x in rows), 'results':rows}
    (out/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in summary.items() if k!='results'},indent=2))
    return 1 if not rows or summary['failed'] else 0

if __name__ == '__main__':
    raise SystemExit(main())
