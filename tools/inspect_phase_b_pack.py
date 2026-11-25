"""Read the exported beta PCK and report which footstep audio actually ships."""
import importlib.util
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("pkg", "tools/package_windows_beta.py")
pkg = importlib.util.module_from_spec(spec)
sys.modules["pkg"] = pkg
spec.loader.exec_module(pkg)

pck = Path(".dream-loop/export_phaseb/dead-wire-windows-beta-x86_64.pck")
entries = [e.path.removeprefix("res://") for e in pkg.read_pck_directory(pck)]
print("total entries:", len(entries))
surface = [p for p in entries if "foley/surfaces/" in p or ".godot/imported/" in p and "_" in p and "footstep" in p]
surf_only = [p for p in entries if "foley/surfaces/" in p]
print("surface wav entries:", len(surf_only))
for p in sorted(surf_only)[:6]:
    print("   ", p)
legacy = [p for p in entries if "footstep_wood.wav" in p]
print("legacy footstep_wood present:", legacy)
print("recorded boards:", len([p for p in entries if "footstep_boards_" in p]))
print("config:", [p for p in entries if "footstep_surfaces.tres" in p])
print("third_party leak:", [p for p in entries if "third_party" in p][:3])
print("synthetic wood variants:", [p for p in entries if "footstep_wood_" in p and "beta" not in p][:4])
