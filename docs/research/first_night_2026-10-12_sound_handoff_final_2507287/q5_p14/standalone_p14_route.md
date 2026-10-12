# p14 standalone acceptance — full route incl. Restart Watch (2026-10-12 follow-up)

Artifact: `builds/windows-beta_final/p14-dead-wire-windows-beta-25072877efe9-b6e9917015b6.zip`
SHA-256 `5e1378705471572282f4b71b29a9480f0796e79af6ecff7815a40d59b75889b4`
EXE `a13b173c265f3759…` (unchanged from p13 — same engine/templates), PCK `fd95261c4928845…`
Build ID dead-wire-windows-beta-25072877efe9-b6e9917015b6; 521 PCK entries; 13 ZIP files; CRC clean.

## Method
One end-to-end run per artifact (no repeat-to-green). Fresh extraction of the export
directory into scratch outside the repo; the EXE ran from its own folder; UI driven by
OS-level background input with a fresh screenshot after every step.

## Route walked (each step screenshot-verified)
1. Boot → main menu (DEAD WIRE / BLACK CREEK STATION — APRIL 1894 / Begin the Watch,
   Options, Quit). ✔
2. Begin the Watch → office loads (night window, EAST DIVISION TRAIN ORDERS board,
   [W A S D] Move / [E] Inspect / [Esc] Pause). ✔
3. Esc → pause "LINE HELD" (Return to the Wire / Leave the Post / Quit to Desktop). ✔
4. Leave the Post → main menu, clean. ✔
5. **Begin the Watch again → office RELOADS in a fresh state** (Restart Watch equivalent:
   no stale visuals, HUD hints back, board rendered). ✔ — this is the additionally
   requested step; the pause menu has no separate "Restart Watch" button, restart is
   reached via Leave the Post → Begin the Watch and behaves correctly.
6. Esc → Quit to Desktop → process exits (tasklist EXITED), exit code 0. ✔

## Runtime error check (the books fix)
- stderr after the whole route: 111 bytes, content is ONLY the known class-C warning
  `WARNING: 7 RIDs of type "Texture" were leaked.` (catalogued, non-blocking).
- 0 `SCRIPT ERROR`, 0 `Parse Error`, **0 `No loader found`**, 0 `invalid UID`, 0 polyhaven
  mentions. In p13 the same route produced 6× invalid-UID warnings + 6× "No loader found"
  for the six polyhaven book textures — that defect is now gone.
- settings.cfg sha256 unchanged across the run: 627f0ee303322c9b.

## Fix that produced this (narrow, no global exclusion changes)
`assets/m1_adapted/ph_books/m1_ledger_volumes.tscn` — the six `ext_resource` Texture2D paths
were re-pointed from `res://assets/third_party/polyhaven/A05_.../textures/*.jpg` to the
game-local, byte-identical copies at `res://assets/m1_adapted/ph_books/textures/*.jpg`
(all six verified SHA-256 identical to the polyhaven originals; the local `.ctex` payloads
were already inside the PCK). Chosen over adding an `include_filter` because Godot's
exclude_filter takes precedence: the first attempt (include_filter for the polyhaven JPGs)
produced 0 polyhaven entries in the PCK and did not fix the runtime errors. The global
`assets/third_party/*` exclusion remains untouched — no third-party sources were bulk-added.
Before sha 3a3bcecc607c55a9 → after 54c2728a8ceb82a4.