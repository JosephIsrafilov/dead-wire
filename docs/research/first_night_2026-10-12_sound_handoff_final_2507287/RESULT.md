# RESULT — p14 targeted follow-up (2026-10-12, branch codex/hand-rebuild-handoff @ 2507287)

**Status: READY FOR SOUND DESIGNER EVALUATION.**
Human listening (sound designer, post-send), owner art approval and human playtest remain
separate downstream gates and are NOT claimed here. Crash causality stays INCONCLUSIVE
(preview-engine risk below). The p13-era report is preserved as `RESULT_p13.md`.

## Final artifact (p14 — new versioned build, p13 retained)
- ZIP: `builds/windows-beta_final/p14-dead-wire-windows-beta-25072877efe9-b6e9917015b6.zip`
- ZIP SHA-256: `5e1378705471572282f4b71b29a9480f0796e79af6ecff7815a40d59b75889b4`
- Build ID: `dead-wire-windows-beta-25072877efe9-b6e9917015b6` (revision 25072877efe9)
- EXE SHA-256: `a13b173c265f3759ae67662e655ae2f5d0576b6e24098d838f8e68bde441c35a` (identical to p13 — same verified editor + release template)
- PCK SHA-256: `fd95261c4928845fff6a4e5b999380e95ffa5ec130` (changed: 521 entries vs p13's 518 — book texture payloads + local .import)
- PCK audit: payload MD5s verified, class scripts OK, exclusions OK, 0 polyhaven entries,
  legacy footstep absent, spoiler brief absent, 13 files, CRC clean.
- Rollback: p13 (`…6dc8868431dd.zip`) and p12 (`…2ed1b969852f.zip`) retained in
  `builds/windows-beta_final/` / `builds/windows-beta/`.

## Gate results

### 1. Review bundle — DONE
`docs/research/p13_review_bundle_2507287/` — 49/49 files, 3.8 MB, write-once MANIFEST.txt
with per-file SHA-256 and origin path. Contains RESULT.md, engine/template hashes and
SHA-512 verification record, crash protocol + raw exits R1–R4, PNG parity (determinism,
engine-level pixel diff), p13 export/package logs, standalone route + 6 screenshots,
144-capture INDEX + 4 representative screenshots, corrected runs_summary, owner checklist.
No dumps/caches/keys; source evidence untouched.

### 2. ClassDB assertion — PASS (RED→GREEN proven)
- RED (frozen, 4.8-dev7): 91 PASS + `Cannot get class` + FAIL, exit 1 (regression48 log).
- Fix (test-only, intent preserved, assertion kept — not deleted/skipped): verify
  `Script.get_global_name() == "AmericanMorseEncoder"` and `Script.can_instantiate()`
  instead of `ClassDB.can_instantiate()` (script global classes are not ClassDB-registered
  in 4.8-dev7; the old check passed on 4.7.1 — the new check is green on BOTH engines).
- GREEN (4.8-dev7): exit 0, 93 PASS, 0 FAIL, on the snapshot rerun AND in the final
  regression (92 assertions, exit 0x00000000).
- Detail: `q4_final/classdb_fix_red_green.md`. Production Morse code untouched.

### 3. Books — PASS (fixed narrowly)
- Root cause: `m1_ledger_volumes.tscn` ext_resources pointed to
  `assets/third_party/polyhaven/...jpg` — excluded by the preset, so the exported runtime
  logged 6× invalid-UID + 6× "No loader found" and rendered the books untextured.
- First attempt (`include_filter` for the 6 JPGs) FAILED: Godot's exclude_filter takes
  precedence — 0 polyhaven entries landed in the PCK (evidence: first p14 export + PCK
  listing). Attempt reverted.
- Final fix: re-point the 6 ext_resources to the game-local byte-identical copies
  `assets/m1_adapted/ph_books/textures/*.jpg` (all six SHA-256 verified identical to the
  polyhaven originals; licence CC0 Poly Haven already documented in
  `docs/third_party_assets.md`; local `.ctex` payloads were already in the PCK).
  The global `assets/third_party/*` exclusion stays untouched — no bulk source inclusion.
- Runtime proof on the p14 export: 0 "No loader found", 0 invalid UID, 0 SCRIPT ERROR
  across the whole UI route. Scene sha 3a3bcecc607c55a9 → 54c2728a8ceb82a4.

### 4. Standalone incl. Restart Watch — PASS
One end-to-end run on the p14 export (fresh scratch extraction, EXE from its own folder,
OS-level background input, screenshot-verified): menu → Begin Watch → office → pause
("LINE HELD") → Leave the Post → menu → **Begin Watch again → office reloads fresh**
(restart verified; the pause menu has no dedicated Restart button — Leave the Post →
Begin the Watch is the canonical restart path and behaves correctly) → Esc →
Quit to Desktop → process exit 0, tasklist EXITED.
stderr whole-run: 111 bytes = only the catalogued class-C `7 Texture RIDs leaked` warning.
settings.cfg sha256 unchanged (627f0ee3…). Detail: `q5_p14/standalone_p14_route.md`.

### 5. New build — DONE (exactly one, p14)
Exported once from the frozen snapshot with the already-installed verified 4.8-dev7 editor
and matching release template (0 errors, `q5_p14/export_p14_final.log`); packaged once
(packager self-tests green, run before p13). No p13 overwrite; old artifacts kept.

### 6. Final regression + lint — PASS at exact baseline
- On the final tree (snapshot refreshed with both fixes; file hashes logged):
  **86 suites, 86 passed, 0 failed, 2747 assertions** (= baseline), 0 SCRIPT ERROR;
  raw exits: every suite 0x00000000 or 0x00000001 by design — **no non-0/1 exit,
  no hidden FAIL, no native crash** (regression48_final_summary.json).
- Crash-sensitive suites: american_morse_encoder 92 assertions exit 0 (the suite that
  carried the 4.7.1-era ClassDB fail and a historical 4.7.1 native crash), shift_director
  132 exit 0 (historical crash probe site), rule44_content 12 exit 0 (the preserved
  4.7.1 0xC0000005 suite).
- gdlint scripts/: clean ("no problems found", `q5_p14/lint48_final.log`).
- error_bearing_suites 19 (teardown classes B/C/D, run-variable, catalogued; not suppressed).

## Crash — unchanged disposition
No 0xC0000005 observed in any run of this follow-up (86-suite regression, export, two
standalone runs). Causal root cause remains **INCONCLUSIVE**: no reliable failing 4.7.1
control exists (MRP INCONCLUSIVE), so even an all-green 4.8 run cannot isolate PR #117991
as the unique cause. **Preview-engine risk, disclosed**: 4.8-dev7 is a development preview —
behavior deltas vs 4.7.1 were already found (ClassDB registration); a future 4.8 stable must
re-run the full gate set before any wider distribution. If the owner must stay on 4.7.1,
the historical crash evidence stands and this label becomes NOT READY.

## Owner actions
1. Deliver the p14 ZIP + hand-off briefs to the sound designer (their listening is a
   post-send deliverable, not a precondition).
2. Art approval / human playtest gates unchanged and not claimed.
3. No further engine or asset decisions required from this follow-up.

## Changed files (live dirty tree; nothing committed/staged/reset)
- `tests/telegraph/american_morse_encoder_test.gd` (ClassDB → script-global assertion)
- `assets/m1_adapted/ph_books/m1_ledger_volumes.tscn` (6 ext_resource paths → local copies)
- `docs/research/first_night_2026-10-12_beta_review_finish/q5/runs_summary.txt` (correction, prior session)
- New evidence: `…sound_handoff_final_2507287/q4_final/` (ClassDB RED→GREEN),
  `…/q5_p14/` (p14 export/package/standalone/final regression), and
  `docs/research/p13_review_bundle_2507287/` (49-file review bundle).
