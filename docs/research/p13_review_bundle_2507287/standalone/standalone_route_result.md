# Standalone p13 packaged route — real UI run (2026-10-12, sound_handoff_final_2507287)

## Method
Real desktop UI automation via background computer-use (no input rerouting inside the game,
no package modification): clicks/keys posted to the game window from outside; every step
verified by fresh screenshot capture. Game run from its own extracted directory outside the
repo; settings.cfg hash checked before/after.

## Route walked (all steps verified by screenshot)
1. Boot from scratch-extracted ZIP (D3D12 Forward+, RTX 3070 laptop) — main menu rendered:
   DEAD WIRE / tagline / BLACK CREEK STATION — APRIL 1894 / Begin the Watch / Options / Quit. ✔
2. Options panel opens from menu — all sliders present (sensitivity, head movement,
   Master, Room ambience, Telegraph, Foley, Contextual thoughts, IMAGE/READING profile
   CLEAN — full resolution, FOV, reading size). ✔
3. Begin the Watch — office loads: night window (moon/mountains), wall chart,
   EAST DIVISION TRAIN ORDERS board (MAIN/SIDING/HOLD/CLEAR EAS), [WASD][E][Esc] hints. ✔
4. Esc → pause: "LINE HELD — Black Creek Station — Night Watch", full settings panel,
   buttons Return to the Wire / Leave the Post / Quit to Desktop. ✔
5. Esc again → resumes to office view (same scene, hints visible). ✔
6. Esc → Leave the Post → back to main menu, clean (no stale office visuals). ✔
7. Quit (menu) → process exits, tasklist confirms EXITED, exit code 0 (bash background job). ✔

## Exit-time evidence
- stdout: 157 B — engine banner only (4.8.dev7.official.c971f93e7, D3D12 Forward+).
- stderr: 0 SCRIPT ERROR, 0 Parse Error.
- settings.cfg sha256 before/after route: 627f0ee303322c9b (unchanged).
- Raw logs: standalone_p13/run_stdout.log, run_stderr.log (copied to this folder).
- Earlier bounded graceful probe on this same package (graceful_probe2.py, PID-filtered):
  WM_CLOSE → exit 0x00000000, both streams clean, settings unchanged (standalone_graceful/).

## Residual warnings catalogued (from the route run stderr)
- 6× invalid-UID warnings + 6× "No loader found" for
  assets/third_party/polyhaven/.../book_encyclopedia_set_01_*.jpg referenced by
  res://assets/m1_adapted/ph_books/m1_ledger_volumes.tscn. CAUSE: the preset excludes
  assets/third_party/* but still ships the .tscn that references those textures. The books
  render without covers (engine falls back to path-based loading, which fails at runtime in
  an export). PRE-EXISTING vs p12? p12's recorded boot evidence (q6/standalone) never loaded
  the office scene, so the same defect cannot be excluded there; not introduced by 4.8 —
  the exclusion list and .tscn are unchanged. Disposition: cosmetic/visual (books render
  untextured); catalogued as non-blocking for the sound-designer evaluation, flagged to
  owner as a packaging hygiene item (either ship polyhaven book textures or exclude the
  .tscn). NOT silently patched now (asset decision = owner).
- 7 Texture RID leaked at exit (class C, catalogued in q3_evidence/shutdown_classes.md).

## Statement
The real clean-extracted UI route main menu → options → office → pause → resume →
leave post → menu → quit IS verified for package p13 by recorded automation evidence.
This does not imply art approval, human playtest, or listening review — those remain
owner/sound-designer gates.
