# DEAD WIRE — hand anatomy: defects measured before the fix

Date: 2026-10-08. Diagnostic pass for `docs/plans/next/2026-10-08_HAND_ANATOMY_BRIEF.md`.
All numbers come from `tools/debug_hand_*.gd` probes run against the working copy
(uncommitted hand pass over `310b194`), not from reading the code.

## Baseline

- `bash tools/run_all_tests.sh` → **39 suites / 1933 assertions, 0 FAIL** (writer_hand_test: 18 assertions).
- Before/after frames preserved: `docs/art/state_2026-10-07/hand_pass/`.

## The five defects, as numbers

Probe: `tools/debug_hand_landmarks.gd`, `debug_hand_frame.gd`, `debug_hand_profile.gd`,
`debug_hand_overshoot.gd`, `debug_hand_anatomy.gd`.

### D1 — the hand is posed too far from the pen (root cause of D2)

```
wrist -> grip            148.1 mm   (adult right hand: ~100 mm)
knuckle ridge -> grip     60.1 mm   (adult: ~25-30 mm)
wrist -> knuckles         98.4 mm   (adult palm: ~74 mm)
```
The wrist is 148 mm from the grip. A real hand writing a tripod grip has the wrist
one hand-length (~100 mm) from the pen. This single number forces the other two:
the palm is drawn 98 mm long and the thumb is rooted at the sleeve.

### D2 — the thumb is a 135 mm tube rooted at the wrist, not a thumb

```
t_base -> t_tip   134.7 mm   (adult thumb: ~65 mm)
t_base -> t_mcp    63.6 mm   (proximal phalanx; adult: ~35 mm)
t_base -> knuckles  89.3 mm
```
`t_base` is `wrist + thumb_side*0.022 + fwd*0.012` — i.e. it starts at the sleeve,
not on the thenar. The thumb's real CMC sits on the thenar ~30 mm along the palm
and ~26 mm out on the thumb side; from there the grip is ~76 mm away, which a
65-70 mm thumb can actually reach. Measured distance from a plausible CMC to the
grip: **120 mm** in the current pose — unreachable, which is why the generator had
to fake it with a long tube.

### D3 — Catmull-Rom overshoot on uneven knots

Uniform Catmull-Rom with knots 41 / 12 / 5 mm (ring & little) has a huge parameter
jump. Measured arc/chord:

```
index               knots 19.6, 24.3, 19.1 mm   arc/chord 1.29   deviation 1.70 mm
middle              knots 14.4, 25.1, 18.8 mm   arc/chord 1.05   deviation 1.09 mm
thumb               knots 63.6, 43.7, 29.8 mm   arc/chord 1.02   deviation 1.64 mm
tucked (ring)       knots 41.0, 12.1,  5.1 mm   arc/chord 1.67   deviation 2.49 mm
tucked (little)     knots 35.4, 12.0,  5.1 mm   arc/chord 1.91   deviation 1.93 mm
```
The tucked fingers loop because the smoothed path is 67-91 % longer than the chord
and departs 2-2.5 mm from the control polyline. The index's 1.29 is a real bulge
too. So the brief's hypothesis is confirmed **by geometry comparison**, not assumed.

### D4 — caps are hemispheres, not fingertips

`_cap()` puts the apex `0.55 x radius` past the end ring for every part. For a
7 mm finger that is a 3.85 mm dome — a ball tip. There is no nail plane; the nail
is only a colour rule (`t > 0.72 and dorsal > 0.45`), which on a short distal
phalanx paints the whole tip.

### D5 — the palm is a smooth block

Cross-sections run 31 → 46 mm across and 21 → 12 mm thick, so the palm is 42 mm
thick at the wrist (a real palm is ~25-30 mm) and has no knuckle ridge or thenar.
The knuckle heads sit in a 60 mm ridge inside a 92 mm palm, so the fingers bunch
in the middle of a slab.

## Fix order (from the brief)

1. pose: wrist/palm reach (D1) — makes the thumb possible;
2. thumb rooted on the thenar (D2);
3. finger phalanges + even arc-length rings (D3);
4. fingertip domes + bounded nail planes (D4);
5. palm cross-section + knuckle ridge + thenar (D5);
6. cuff/sleeve silhouette only if it still dominates after 1-5.
