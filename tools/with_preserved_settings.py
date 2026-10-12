import argparse
import json
import os
import subprocess
from contextlib import contextmanager
from pathlib import Path

@contextmanager
def preserve_settings(path):
    path = Path(path)
    existed = path.exists()
    original = path.read_bytes() if existed else None
    try:
        yield
    finally:
        if existed:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(original)
        elif path.exists():
            path.unlink()

def main():
    p = argparse.ArgumentParser()
    default = Path(os.environ['APPDATA']) / 'Godot/app_userdata/dead-wire/settings.cfg'
    p.add_argument('--settings', type=Path, default=default)
    p.add_argument('--result-json', type=Path, help='Write raw child exit details before returning')
    p.add_argument('command', nargs=argparse.REMAINDER)
    args = p.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        p.error('A child command is required after --')
    settings_existed = args.settings.exists()
    settings_original = args.settings.read_bytes() if settings_existed else None
    with preserve_settings(args.settings):
        result = subprocess.run(command, check=False)
    if args.result_json is not None:
        preserved = args.settings.exists() == settings_existed
        if preserved and settings_existed:
            preserved = args.settings.read_bytes() == settings_original
        payload = {
            'command': command,
            'returncode': result.returncode,
            'returncode_unsigned': result.returncode & 0xffffffff,
            'returncode_hex': f'0x{result.returncode & 0xffffffff:08X}',
            'settings_path': str(args.settings),
            'settings_existed_before': settings_existed,
            'settings_preserved': preserved,
        }
        args.result_json.parent.mkdir(parents=True, exist_ok=True)
        args.result_json.write_text(json.dumps(payload, indent=2) + '\n', encoding='utf-8')
    return result.returncode

if __name__ == '__main__':
    raise SystemExit(main())
