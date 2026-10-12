# Option A engine setup record (2026-10-12, sound-handoff-final session)

## Approved scope (owner, recorded in task)
Official Godot 4.8-dev7 editor + exactly matching export templates. Two assets, ~1.417 GiB.
Godot 4.7.1 stays untouched as rollback. No compilation, no extra SDKs.

## Downloads (verified BEFORE extraction/launch)
Staging dir: `C:\Users\YUSIF\Downloads\godot48dev7_staging\`

| artifact | size (bytes) | SHA-512 (official prefix, matches SHA512-SUMS.txt) |
|---|---:|---|
| Godot_v4.8-dev7_win64.exe.zip | 84,919,369 | 7b6dd16fd56a03ff8d0ae51ec242602db6ac5310b351cacbb6d4e3877feedec4… |
| Godot_v4.8-dev7_export_templates.tpz | 1,436,879,719 | 12864a077912175e7c51ff54b7ca11ba716d35706e9d52010095961e369c02ac… |

Combined = 1,521,799,088 bytes = ~1.417 GiB — inside approved scope. Both SHA-512 values
match the official SHA512-SUMS.txt byte-for-byte (verified with sha512sum before extraction).

## Installation (final paths)
- Editor: `C:\Users\YUSIF\Desktop\Godot_4.8_dev7\Godot_v4.8-dev7_win64.exe` (console twin alongside)
  - editor binary SHA-256 (prefix): `ffeea622b211379a98612ee7bc0ee9c1…`
  - `--version` output: `4.8.dev7.official.c971f93e7` — matches release-announced source commit c971f93e7e76b0ef919bf6009e7b868bea04db7f
- Templates: `C:\Users\YUSIF\AppData\Roaming\Godot\export_templates\` — version.txt = `4.8.dev7`
  - windows_release_x86_64.exe SHA-256 prefix: `b538554df997ea699122d5b31f2ea892…`
  - windows_debug_x86_64.exe SHA-256 prefix: `c3287ae1c7fad6f6f2e0e09b0ebbb132…`
  - console twins present for both; both Windows debug/release identities confirmed present

## Rollback
Godot 4.7.1 stable (`C:\Users\YUSIF\Desktop\Godot_v4.7.1-stable_win64.exe\…`, engine
a13da4feb) and its templates remain installed and untouched. Old p12 ZIP retained at
`builds/windows-beta/dead-wire-windows-beta-f82939d9995e-2ed1b969852f.zip`
(SHA-256 prefix ff1eda2fe816aff1).

## Patch presence
Release provenance: commit c971f93e7 contains `base_cache = Ref<GDScript>();` (TOOLS_ENABLED)
and `base = Ref<GDScript>();` in `GDScript::clear()` per upstream PR #117991 (verified by owner
at approval time). Engine self-report `4.8.dev7.official.c971f93e7` confirms this is the same
source commit. Patch presence ≠ proven fix for DEAD WIRE; causal validation is a separate gate.

## Disk
163 GB free before setup; post-setup delta ~2.2 GB (both artifacts + extracted).
