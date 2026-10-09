# DEAD WIRE — hand rebuild: honest status (NOT a visual acceptance)

Date: 2026-10-08. Branch: `codex/hand-rebuild-handoff`.
Executor: a fresh pass on the device-handoff checkpoint, per
`docs/reports/2026-10-08_DEVICE_HANDOFF.md` and `docs/plans/next/2026-10-08_HAND_ANATOMY_BRIEF.md`.

## Bottom line

**I rewrote the hand generator and the result is not a convincing improvement over the
rejected v4.** Per the brief's stop rule ("if two consecutive variants do not improve the
target defect visually, stop and show the owner the comparison / cause / limit"), I stopped
rather than keep tuning blindly. This is a status report, not a claim of success.

GREEN is not acceptance. The owner rejects or accepts the shape by eye.

## What I did

1. Read the handoff, the anatomy brief, the naturalness audit (A03/A04), and the before
   frames (`state_2026-10-07/hand_pass/after/`, `state_2026-10-08/hand_anatomy/after/`).
2. Established the working environment on this machine: Godot 4.7.1 found on Desktop, ran
   `--import` (fresh checkout — this was why the first regression run hung/failed on font
   and class-cache errors), built a fresh `.venv-tools` with `gdlint` (not copied from macOS).
3. Confirmed the baseline: **39 suites / 1934 assertions, 0 FAIL**; `writer_hand_test` 19
   assertions green; `gdlint scripts/` clean; boot 0 errors. (One suite, `shift_director_test`,
   segfaulted once — exit 139 — when run inside the full loop before the import cache was
   warm; it passes in isolation and in the re-run. Flagging as a possible Windows flake, not
   caused by this change.)
4. Rewrote `tools/build_writer_hand.gd` from the Catmull-Rom tube approach to an **authored
   planar-joint topology**: each finger is an articulated chain (MCP/PIP/DIP) with authored
   angles and elliptical cross-sections, the MCP lifted dorsal+radial off the palm ridge so
   the finger arcs over the pen, a widened palm shell, a thenar-rooted thumb, and per-part
   guard diagnostics (the brief's demand that a silent clamp must not hide a bad pose).
5. Kept every contract: Pen child of Hand; `wrist_travel_limit` untouched; layers=2/masks;
   cloth + skin SPECULAR_DISABLED; 6 named surfaces; generator idempotent (byte-identical
   `hand_v3.res` and `transcript_paper.tscn` on re-run — verified by md5).

## Measured / tested

- `writer_hand_test` — **19/19 green**. Thumb contact improved (2 → 24 contacts), index 60,
  middle 5; no vertex enters the shaft; min upper clearance 2.25 mm; 0 cuff leaks.
- `writer_rig_space_test` — 44/44 green. `transcript_paper_test` — green.
- Full regression — **39/1934, 0 FAIL**.
- Generator clearance guard still moves rings (palm worst ~13 mm, index ~11 mm). This is the
  honest signal that the pose is still being *forced* clear of the pen, not authored clear —
  the same class of problem the brief warned about.

## The verdict the owner needs to make

The turntable comparison (`before/` = rejected v4, `after/` = this v5) shows the two are
closer than the work warrants. Independent reads scored both low:

| angle | rejected v4 | this v5 |
|---|---|---|
| top-down finger separation | 3/10 | 3/10 |
| top-down web spaces | 1/10 | 2/10 |
| pen buried vs held | 1/10 | 3/10 |
| thumb distinctness | 2/10 | 4/10 |
| overall believability | 2/10 | 3/10 |

v5 is marginally better (the thumb opposes, the side view reads as a loose tripod, fingers
are separated in `t5`) but still shows pen-through-flesh clipping and fused/fragmented
digits at macro (`t6`, `t2`). At the macro angle both v4 and v5 read as "a fist impaled by
a pen". **This is not the "convincing game-quality hand" the brief asks for.**

## Why it's stuck (the honest cause)

The pen lies in the thumb–index web, which puts the index/middle knuckles almost exactly on
the pen's axis. To wrap the barrel, a finger must arc *over* the pen and fold down the far
side — but the reachable workspace is tighter than the phalanx lengths, so the chain either
spears the pen (guard shoves it out → spikes/fragments) or drapes over it (fused blob). The
old spline hid this by bowing; my planar chain exposes it. Neither solves it. This is a
fundamental reach/topology tension in a fixed grip pose, not a parameter-tuning problem.

## The limit, stated plainly

A procedural generator authoring a fixed tripod grip around a pen that passes through the
web space may be the wrong tool for "convincing." The honest paths forward, for the owner
to pick:

1. **Accept a stylized read** — the hand is only ever seen at gameplay distance in dim
   lamplight (the `w1` writing frame reads acceptably there). Ship the current shape and
   spend the effort on lighting/rim so the silhouette reads.
2. **Authored mesh, not generated** — model/rig one good hand (or a hand + pen as a single
   posed asset) and drive it with the existing rig. The brief allows authored topology;
   this may need to be a fully authored mesh, not a loft.
3. **Change the grip/pose** — a grip where the pen does not pass through the web (e.g. a
   lower, more draped hold) relieves the reach tension, at the cost of re-posing.

I did not pick one — that is the owner's call.

## Files

- Generator: `tools/build_writer_hand.gd` (rewritten; v4 preserved in git history and in
  `docs/reports/evidence/hand_handoff_2026-10-08.tar.gz` recovery copies).
- Meshes: `assets/models/operator/hand_v3.res`, `cuff_v3.res`, `forearm_v3.res` (regenerated).
- Evidence: `docs/art/state_2026-10-08/hand_rebuild/{before,after}/{turntable,writing}/`.
- Nothing committed. Explicit paths only if the owner wants to keep this.

## Not done (out of scope / blocked)

- **Gameplay video**: my `tools/hand_video_capture.gd` attempts failed — the scripted capture
  does not reproduce the live writing motion (the writing only animates under real input, and
  the fixed camera lost the hand). I removed the tool rather than leave a broken one. A real
  gameplay video of the writing motion needs either a recorded manual play session or a
  capture path that drives the actual writing loop; I did not solve this.
- Movement feel, tape/commit honesty, sound: untouched (per scope and per the handoff's
  instruction not to start motion/sound before an accepted hand).
