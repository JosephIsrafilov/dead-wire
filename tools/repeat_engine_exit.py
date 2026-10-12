# tools/repeat_engine_exit.py
import argparse
import json
import os
import subprocess
import uuid
from datetime import datetime
from pathlib import Path
from verify_mechanics import classify
from with_preserved_settings import preserve_settings

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = 'C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'

def as_text(value):
    if isinstance(value, bytes):
        return value.decode('utf-8', errors='replace')
    return value or ''

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--suite', default='tests/office/shift_director_test.gd')
    p.add_argument('--runs', type=int, default=10)
    p.add_argument('--case', default='headless_dummy')
    p.add_argument('--windowed', action='store_true')
    p.add_argument('--driver', choices=['project', 'd3d12', 'vulkan'], default='project')
    p.add_argument('--audio-driver', default='Dummy')
    p.add_argument('--minimum-assertions', type=int, default=132)
    p.add_argument('--timeout', type=float, default=90)
    p.add_argument('--out', default='docs/research/readable_pass/exit_matrix')
    args = p.parse_args()
    if args.runs < 1 or args.timeout <= 0:
        p.error('Runs and timeout must be positive')
    if not args.windowed and args.driver != 'project':
        p.error('Driver comparison requires --windowed; headless does not exercise that renderer')
    case = ''.join(c for c in args.case if c.isalnum() or c in '_-') or 'case'
    batch = datetime.now().strftime('%Y%m%d_%H%M%S') + '_' + uuid.uuid4().hex[:8]
    out = ROOT / args.out / case / batch
    out.mkdir(parents=True, exist_ok=False)
    settings = Path(os.environ['APPDATA']) / 'Godot/app_userdata/dead-wire/settings.cfg'
    command = [os.environ.get('GODOT_BIN', DEFAULT)]
    if not args.windowed:
        command += ['--headless']
    command += ['--audio-driver', args.audio_driver]
    if args.driver != 'project':
        command += ['--rendering-driver', args.driver]
    command += ['--path', str(ROOT), '--script', 'res://' + args.suite]
    rows = []
    with preserve_settings(settings):
        for i in range(args.runs):
            try:
                r = subprocess.run(command, capture_output=True, text=True,
                                   encoding='utf-8', errors='replace', timeout=args.timeout)
                text, code = r.stdout + r.stderr, r.returncode
            except subprocess.TimeoutExpired as ex:
                text = as_text(ex.stdout) + as_text(ex.stderr) + '\n  FAIL: engine timeout\n'
                code = 124
            row = {'run': i, 'case': case, 'command': command,
                   'hex_exit': hex(code & 0xffffffff), **classify(text, code)}
            if row['assertions'] < args.minimum_assertions:
                row['passed'] = False
                row['failures'].append('Too few completed assertions')
            (out / f'run_{i:02d}.log').write_text(text, encoding='utf-8')
            rows.append(row)
            print({k: row[k] for k in ['run','case','exit_code','passed','assertions','hex_exit']}, flush=True)
    (out / 'summary.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
    print('EVIDENCE', out)
    return 1 if any(not x['passed'] for x in rows) else 0

if __name__ == '__main__':
    raise SystemExit(main())
