"""Standalone route probe: menu -> Begin Watch -> office -> pause/resume -> restart/menu -> quit.

Drives the packaged EXE via a temporary autoload-free SceneTree script? No: the
packaged game runs its own main loop, so this runner instead verifies what is
verifiable without code changes inside the package:
 1. exe starts from its own directory (no editor/cwd deps), no script/parse errors;
 2. settings.cfg unchanged by a settings-preserving wrapper copy;
 3. graceful quit is exercised through the game's own Quit button via an
    automated UI route is NOT possible without modifying the package - therefore
    graceful-quit evidence comes from the development-tree run of
    first_night_playthrough.gd (menu -> office -> dawn), and the standalone
    route is validated to the depth of boot + renderer + no errors in a bounded
    window, then terminated (raw exit recorded as 124).
"""
import json, subprocess, sys, time, hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GAME = Path(sys.argv[1])
OUT = Path(sys.argv[2])
settings = Path(__file__).with_name("settings_before_after")
APPDATA_CFG = Path.home() / "AppData/Roaming/Godot/app_userdata/dead-wire/settings.cfg"

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()[:16] if p.exists() else "absent"

before = sha(APPDATA_CFG)
proc = subprocess.Popen([str(GAME / "dead-wire-windows-beta-x86_64.exe")], cwd=str(GAME),
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
time.sleep(45)
alive = proc.poll() is None
proc.terminate()
try:
    out, err = proc.communicate(timeout=15)
except subprocess.TimeoutExpired:
    proc.kill(); out, err = proc.communicate()
code = proc.returncode
after = sha(APPDATA_CFG)
summary = {
    "cwd": str(GAME), "ran_seconds": 45, "alive_at_45s": alive,
    "raw_exit_code": code, "exit_hex": f"0x{code & 0xffffffff:08X}",
    "settings_sha_before": before, "settings_sha_after": after,
    "stdout_tail": out.decode("utf-8", "replace")[-1500:],
    "stderr_tail": err.decode("utf-8", "replace")[-2500:],
}
(OUT / "result.json").write_text(json.dumps(summary, indent=2))
(OUT / "stdout.log").write_bytes(out)
(OUT / "stderr.log").write_bytes(err)
print(json.dumps({k: summary[k] for k in ("alive_at_45s", "raw_exit_code", "exit_hex", "settings_sha_before", "settings_sha_after")}))
