# Owner approval request (ONE, specific) — engine with #117991

To verify and ship a fix for the engine-side GDScript shutdown UAF (crash 0xC0000005,
RVA +0x547AF6, GDScriptLanguage::finish), I need an engine that contains PR #117991
(merged for 4.8). Two options; please pick one or decline both:

## Option A (recommended): official Godot 4.8 beta/rc Windows build
- Source: github.com/godotengine/godot-builds (official, tagged preview channel).
- Size: ~120 MB engine zip + ~1.3 GB export templates for that version (templates already
  on disk are 4.7.1 and will NOT match a 4.8 engine — mismatched templates produce broken exports).
- Installed to: a NEW versioned directory `C:\Users\YUSIF\Desktop\Godot_4.8_<tag>\` (no system
  change, existing 4.7.1 untouched and remains default).
- Purpose: run frozen-control A/B (unpatched 4.7.1 vs patched 4.8) on the saved crash suite and
  the MRP; if 4.8 survives N runs that kill 4.7.1, the fix is verified for this project and the
  beta export moves to the 4.8 engine+templates.
- Risk: 4.8 is pre-release; gameplay-affecting engine changes are possible and would need their
  own regression pass.

## Option B: local source build of 4.7.1 + cherry-picked 0dd6299f
- Source: godot repo at tag 4.7.1-stable + the 5-line patch; SCons Windows build.
- Cost: build toolchain (Python/SCons/MSVC already present? to be checked), 1-4 h compile,
  then same template mismatch problem (4.7.1 templates match, but a custom engine changes the
  version string; official templates usually still load, needs verification).
- Installed to: `C:\Users\YUSIF\Desktop\Godot_4.7.1_uaf_fix\` (new dir, no system change).
- Purpose: identical A/B verification with minimal version drift.

Declining both leaves the crash OPEN with the current bounded diagnostic report; the beta ZIP
stays NOT READY TO SEND. I will not download, install, or build anything until you choose.
