"""Graceful-quit probe: close the game window and record the raw child exit."""
import ctypes, subprocess, sys, time, hashlib, json
from pathlib import Path
game = Path(sys.argv[1]); out = Path(sys.argv[2])
user32 = ctypes.windll.user32
proc = subprocess.Popen([str(game / "dead-wire-windows-beta-x86_64.exe")], cwd=str(game),
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
print("pid", proc.pid)
time.sleep(25)
alive = proc.poll() is None
# WM_CLOSE = graceful request; the game's own quit path handles it
res = user32.PostMessageW(proc.__dict__.get('hwnd', 0) or 0, 0x0010, 0, 0)
enum = ctypes.windll.user32
hwnd = enum.FindWindowW(None, None)
found = []
EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
def cb(h, l):
    pid = ctypes.c_ulong()
    user32.GetWindowThreadProcessId(h, ctypes.byref(pid))
    if pid.value == proc.pid:
        found.append(h)
    return True
user32.EnumWindows(EnumWindowsProc(cb), 0)
print("windows for pid:", found)
for h in found:
    user32.PostMessageW(h, 0x0010, 0, 0)   # WM_CLOSE
try:
    outb, errb = proc.communicate(timeout=40)
    code = proc.returncode
except subprocess.TimeoutExpired:
    proc.kill(); outb, errb = proc.communicate(); code = proc.returncode
summary = {"alive_at_25s": alive, "raw_exit_code": code, "exit_hex": f"0x{code & 0xffffffff:08X}",
           "graceful_close_sent": bool(found)}
(out / "result.json").write_text(json.dumps(summary, indent=2))
(out / "stderr.log").write_bytes(errb)
print(json.dumps(summary))
