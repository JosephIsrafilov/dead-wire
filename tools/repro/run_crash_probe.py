"""Run one bounded, preserved-settings shift-director crash probe."""
import argparse
import hashlib
import json
import os
import platform
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GODOT = r"C:/Users/YUSIF/Desktop/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
SUITE = "tests/office/shift_director_test.gd"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=Path("docs/research/first_night_2026-10-11/crash_probe"))
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", DEFAULT_GODOT))
    parser.add_argument("--timeout", type=float, default=120.0)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    out = (ROOT / args.out / f"{stamp}_{uuid.uuid4().hex[:8]}").resolve()
    out.mkdir(parents=True, exist_ok=False)
    stdout_path = out / "stdout.log"
    stderr_path = out / "stderr.log"
    result_path = out / "result.json"
    settings = Path(os.environ.get("APPDATA", str(Path.home()))) / "Godot/app_userdata/dead-wire/settings.cfg"
    wrapper = ROOT / "tools/with_preserved_settings.py"
    command = [
        sys.executable, str(wrapper), "--settings", str(settings),
        "--result-json", str(result_path), "--", args.godot,
        "--verbose", "--headless", "--audio-driver", "Dummy",
        "--path", str(ROOT), "--script", "res://" + SUITE,
    ]
    timed_out = False
    try:
        completed = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=args.timeout)
        returncode = completed.returncode
        stdout_path.write_bytes(completed.stdout)
        stderr_path.write_bytes(completed.stderr)
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        returncode = 124
        stdout_path.write_bytes(exc.stdout or b"")
        stderr_path.write_bytes((exc.stderr or b"") + b"\nprobe timeout\n")

    raw = json.loads(result_path.read_text(encoding="utf-8")) if result_path.exists() else {}
    result = {
        "captured_at_utc": datetime.now(timezone.utc).isoformat(),
        "command": command,
        "timeout_seconds": args.timeout,
        "timed_out": timed_out,
        "returncode": raw.get("returncode", returncode),
        "returncode_unsigned": raw.get("returncode_unsigned", returncode & 0xffffffff),
        "returncode_hex": raw.get("returncode_hex", f"0x{returncode & 0xffffffff:08X}"),
        "settings": raw,
        "artifacts": {"stdout": stdout_path.name, "stderr": stderr_path.name, "result": result_path.name},
        "sha256": {
            "engine": sha256(Path(args.godot)) if Path(args.godot).is_file() else None,
            "test": sha256(ROOT / SUITE),
        },
        "platform": {
            "system": platform.system(),
            "release": platform.release(),
            "version": platform.version(),
            "machine": platform.machine(),
            "processor": platform.processor(),
            "python": platform.python_version(),
        },
    }
    result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"EVIDENCE {out}")
    return 1 if timed_out else (0 if result["returncode"] == 0 else 1)


if __name__ == "__main__":
    raise SystemExit(main())
