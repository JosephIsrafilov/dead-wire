"""One bounded engine command, full separate logs and raw Windows exit, settings preserved."""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from with_preserved_settings import preserve_settings

DEFAULT = "C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"

def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("args", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    command = [os.environ.get("GODOT_BIN", DEFAULT)] + (args.args[1:] if args.args[:1] == ["--"] else args.args)
    settings = Path(os.environ["APPDATA"]) / "Godot/app_userdata/dead-wire/settings.cfg"
    try:
        with preserve_settings(settings):
            result = subprocess.run(command, capture_output=True, timeout=args.timeout)
        stdout, stderr, code = result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        stdout, stderr, code = error.stdout or b"", error.stderr or b"", 124
    (args.out / "stdout.log").write_bytes(stdout)
    (args.out / "stderr.log").write_bytes(stderr)
    summary = {"command": command, "exit_code": code, "exit_hex": f"0x{code & 0xffffffff:08X}"}
    (args.out / "result.json").write_text(json.dumps(summary, indent=2), encoding="utf8")
    print(json.dumps(summary))
    print(stdout.decode("utf8", errors="replace")[-3000:])
    print(stderr.decode("utf8", errors="replace")[-1600:])
    return 0 if code == 0 else 1

if __name__ == "__main__":
    raise SystemExit(main())
