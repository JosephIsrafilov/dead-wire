"""Graceful-quit probe v2 (diagnostic tooling only; one bounded run per protocol).

Fixes vs q4b/graceful_probe.py:
- windows enumerated per-PID (EnumWindows + GetWindowThreadProcessId filter),
  never FindWindowW(None, None);
- PostMessageW results recorded per hwnd;
- BOTH stdout and stderr captured to files;
- exe SHA-256, cwd, settings.cfg sha256 before/after recorded;
- raw unsigned child exit code recorded.
"""
import ctypes
import ctypes.wintypes as wt
import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path

game_dir = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
exe = game_dir / "dead-wire-windows-beta-x86_64.exe"
out_dir.mkdir(parents=True, exist_ok=True)
settings = Path(r"C:\Users\YUSIF\AppData\Roaming\Godot\app_userdata\dead-wire\settings.cfg")
WM_CLOSE = 0x0010


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else "ABSENT"


user32 = ctypes.windll.user32
EnumWindowsProc = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)


def windows_of(pid: int) -> list:
    found = []

    def cb(hwnd, lparam):
        wpid = wt.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(wpid))
        if wpid.value == pid and user32.IsWindowVisible(hwnd):
            buf = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(hwnd, buf, 256)
            found.append((hwnd, buf.value))
        return True

    user32.EnumWindows(EnumWindowsProc(cb), 0)
    return found


before = sha(settings)
proc = subprocess.Popen([str(exe)], cwd=str(game_dir),
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
time.sleep(25)
alive = proc.poll() is None
wins = windows_of(proc.pid) if alive else []
posted = []
for hwnd, title in wins:
    ok = user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)
    posted.append({"hwnd": int(hwnd), "title": title, "posted": bool(ok)})
try:
    outb, errb = proc.communicate(timeout=60)
except subprocess.TimeoutExpired:
    proc.kill()
    outb, errb = proc.communicate()
code = proc.returncode & 0xFFFFFFFF
after = sha(settings)
(out_dir / "stdout.log").write_bytes(outb)
(out_dir / "stderr.log").write_bytes(errb)
result = {
    "exe": str(exe),
    "exe_sha256": hashlib.sha256(exe.read_bytes()).hexdigest(),
    "cwd": str(game_dir),
    "alive_at_25s": alive,
    "windows_found": [{"title": t, "hwnd": int(h)} for h, t in wins],
    "post_results": posted,
    "raw_exit_code": proc.returncode,
    "exit_hex": f"0x{code:08X}",
    "graceful_close_sent": len(posted) > 0,
    "settings_sha_before": before[:16],
    "settings_sha_after": after[:16],
    "stdout_bytes": len(outb),
    "stderr_bytes": len(errb),
    "stdout_script_errors": outb.decode("utf-8", "replace").count("SCRIPT ERROR"),
    "stderr_script_errors": errb.decode("utf-8", "replace").count("SCRIPT ERROR"),
}
(out_dir / "result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result, indent=2))