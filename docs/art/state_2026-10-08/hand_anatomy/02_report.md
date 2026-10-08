# DEAD WIRE — hand anatomy pass: what changed and what it proves

Date: 2026-10-08. Executed against `docs/plans/next/2026-10-08_HAND_ANATOMY_BRIEF.md`.
Scope kept: hand / cuff / sleeve meshes, the generator, `transcript_paper.tscn`,
`writer_hand_test`. No movement controller, room, HUD, audio, scenarios or new WAVs.

## Result

- `writer_hand_test` — **19 assertions, all green** (was 18; +1 named-part surface check).
- Full regression — **39 suites / 1934 assertions, 0 FAIL**.
- `gdlint scripts/` — clean.
- Boot smoke — **0 errors** (one pre-existing warning: 6 ObjectDB instances at exit).
- Generator is **idempotent**: a second run produces byte-identical `hand_v3.res` and
  `transcript_paper.tscn` (no cumulative drift).
- Before/after frames: `docs/art/state_2026-10-08/hand_anatomy/{before,after}/`.
- Defect measurements: `01_defects_measured.md` in the same folder.

## The defects, before → after (measured, not eyeballed)

| Metric | Before | After | Adult right hand |
|---|---|---|---|
| wrist → grip | 148.1 mm | **101.6 mm** | ~100 mm |
| wrist → knuckles (palm) | 98.4 mm | **74.0 mm** | ~74 mm |
| thumb CMC → tip | 134.7 mm (rooted at the sleeve) | **~74 mm** (rooted on the thenar) | 65–75 mm |
| tucked ring/little arc ÷ chord | 1.67 / 1.91 | arc-based, no loop | ~1.0 |
| fingertip cap | hemisphere (0.55 × r) | pad (0.28 × r) + nail plane | — |
| surfaces | 1 (all parts welded) | **6 named** (palm/index/middle/ring/little/thumb) | — |

Root cause of the old shape was **not** the smoothing alone: the hand was posed
~50 mm too far from the pen, which forced a 98 mm palm and a thumb that had to
grow 135 mm from the wrist to reach the grip. Uniform Catmull-Rom on 41/12/5 mm
knots then added a 2–2.5 mm overshoot loop on top. Both are fixed; the smoothing
hypothesis was confirmed by measuring the deviation, not assumed.

## Generator changes (`tools/build_writer_hand.gd`)

1. **Pose from anatomy** — `WRIST_OFF`, `KNUCKLE_DIR`, `PALM_LEN` are now named
   constants the test reads too, so generator and test cannot drift apart.
2. **Centripetal Catmull-Rom** (α = 0.5) replaces uniform — cannot cusp or loop.
3. **Arc-based fingers** (`_finger_chain`) — three phalanges laid on a circular
   arc, segment lengths 45/30/25 %, tip segment along the shaft's radial so the
   pad and its low cap face the barrel.
4. **One surface per part** — a contact can be attributed to the part it comes
   from, not guessed from a direction (the brief required this once topology
   changed).
5. **Nail planes** (`_nail`) — a bounded quad on the dorsal side, not a painted tip.
6. **Palm** — 17→12 mm thick, thenar mass on the thumb side, shallow knuckle ridge.
7. **Clearance guard** (`_clear_point` / `_clamp_vertex`) — the generator enforces
   the test's own contract: above the grip the shaft must run clear (≥1.5 mm), and
   no hand vertex may ever enter the barrel. The guard shapes control points before
   smoothing and clamps the emitted vertices (ellipse points and cap apexes too),
   so a future pose tweak cannot silently pass the generator and fail the test.
   It uses the **real Shaft node's frame** — the same one the test measures in.

## Test changes (`tests/telegraph/writer_hand_test.gd`)

- Grip contacts are attributed **per named surface**; the old direction-only
  attribution is gone (it could not tell a curled middle finger from a thumb in
  the same angular sector).
- Fixed a **latent brittleness in the test's own calibration**: the shaft is a
  hexagonal prism, so a point at `bottom_radius` off-axis can sit on a flat face
  and read outside. Calibration now uses the inradius and insets off the cap
  plane. Tolerances were **not** raised.
- `_colors` now reads all surfaces (the hand has 6, not 1).

## Visual acceptance

Looked at all six turntable angles and the three production writing frames, in
neutral light and in the office. The hand now reads as a right hand: a palm with
a knuckle ridge and thenar, three fingers closing on the barrel, a thumb from the
thenar, the ring/little tucked with no loop, and a bounded nail. The visible
"loop" seen on the earlier `t5_front_low` is gone. The sleeve no longer fills the
frame as a black tube.

## Remaining limitations (honest)

- At the extreme macro angle the back of the hand is still a fairly smooth mass —
  individual finger definition is soft. This is the low-poly budget, not a defect
  the brief asked to remove.
- The generator rewrites `transcript_paper.tscn` (Pen transform +
  `elbow_offset_rig`) by design; the scene is modified alongside the mesh.
- `_clear_point` is a **shaping** guard and `_clamp_vertex` is the **hard**
  guarantee; if a future pose change needs more than the guard's budget, the
  clamp will flatten geometry rather than fail the test. Worth watching if the
  grip is re-posed again.
- Debug probes left in `tools/` (`debug_hand_*.gd`, `debug_upper_zone.gd`,
  `debug_grip_band.gd`) are covered by `.git/info/exclude` and are not part of
  the change.
- Nothing committed, per the brief.
