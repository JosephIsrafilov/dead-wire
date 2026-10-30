# PSX props pass — lamp, chair, clock, board, window, door, table

**Date:** 2026-10-20.
**Pipeline:** Blender 5.2 bpy (`tools/build_office_props_blender.py`) → GLB → Godot
(`tools/import_office_props.gd`) → `.res` with a nearest-filtered 256px atlas.
Same pipeline as the desk/bookcase/cabinet and the potbelly stove.

## What was replaced

| Prop | Before | After | Tris |
|---|---|---|---:|
| Oil lamp | CSG cylinders/spheres + an additive glass tube that read as a light bulb | Stepped brass fount on a turned foot, burner gallery, wick wheel, faceted glass chimney | 544 + 100 |
| Chair | Third-party Poly Haven chair overlaid on the CSG blockout (two chairs interpenetrating) | Turned octagonal legs on foot beads, planked seat with seams, crest rail, five spindles | 1 108 |
| Clock | Flat CSG sticker on the wall | Cornice, stiles, faceted brass bezel, open pendulum trunk | 1 000 |
| Train-order board | CSG boxes with raised "rail" strips | Slate in a moulded frame, corner blocks, painted track diagram, lever base/stops, indicator dial | 1 152 |
| North window | Flat frame of CSG boxes: no reveal, no sill depth | Jamb lining through the wall, architrave with a bead, sash set inside the reveal, projecting sill with a nose, exterior drip head and ledge | 948 |
| South door | Four flat CSG panels on one box | Ledge-and-braced plank door: six boards with joints, two ledges, a diagonal brace, iron nails, kick plate with rivets and rust, a knot fallen out of a board, chipped latch stile, hand-worn patch | 476 + 960 + 100 |
| Filing table | Poly Haven `wooden_table_02` — the last third-party furniture in the room | Square tapered legs jointed into an apron, working drawer on the approach side, H-stretcher, moulded top at 0.80 m | 1 140 |
| Floor | 128px clean-boarding tile at uv scale 2.5×3.0 — 0.6 m "boards" and bright seams | New worn 256px tile at 10.8×8.6 (0.14 m boards, dark seams, nails with rust runs, a knot, a split board) plus a worn-board patch on the traffic line | 872 (patch) |
| South-wall fittings | Flat CSG boxes: a 0.38 × 0.82 slab of soot-coloured paint for the coat, a bare frame, a black rectangle for the hatch | Coat rack with a hanging tapered coat (collar, sleeves with cuffs, placket, brass buttons, rubbed strap patch, dragged hem, a pulled thread) and a hat on the hook; a baize notice board with four pinned notices and a torn corner; a service hatch with a worn counter sill; a two-pocket message tray with slips in it | 1 700 (all four) |
| West-wall line | Two iron bars and two plain cylinders for insulators | Glass bell insulators with a skirt-belly-groove-cap profile, iron pins, rust stains down the wall, and a two-run wire with real sag between the pins | 576 |

The CSG blockouts stay in their scenes as **invisible witnesses**: `DeskTop`,
`OrganizerBottom`, `Seat`, `ChairSolid`, `BoardSurface`, `StationClockCase`,
`FrameLeft/Right/Top`, `Threshold` and the frame boxes are what the tests, the
collision shapes and the anchor lookups were written against, so they keep their
names, transforms and sizes.

Two node names did change, with the tests updated in the same pass:
`PhFilingTable` → `FilingTable` (it is no longer a Poly Haven instance), and the
door's `Doorknob` kept its name but its visual moved to an authored mesh parented
under it, so `office_door.gd`'s rattle still turns the knob.

## Ageing, specifically

The brief for this pass was that nothing in the room is new. The wear is authored,
not a filter, and it sits where wear actually lands:

- **Door** — the kick plate at the bottom is dented and rusting from its rivets; a
  grime band darkens the boards where boots and wet coats reach; one plank has
  lost its knot, leaving a real recess with a dark core; the latch stile is
  splintered from years of catching on the strike; there is a hairline split; and
  a palm-sized patch beside the handle has worn back to bare wood.
- **Window** — chipped paint bites out of the sill nose with bare wood under them,
  a scuffed strip where forms and hands rest, grime in the corners, a split up the
  jamb, and nail heads with a rust run below one of them.
- **Floor** — the tile itself carries uneven board tones, dark seams, nails with
  rust runs, a knot and a split board; six boards on the door-to-desk line are
  reproduced as geometry — 2 mm proud, with the shrunk gap on one side and nails
  standing up.
- **Sound follows the wear**: two creak anchors (`CreakAnchorWornBoard`,
  `CreakAnchorSplitBoard`) sit on the worn boards, so the creak comes from where
  the floor is damaged rather than from a generic point in the room.
- **The south wall is lived in, not staged**: the notice board is baize with the
  register card in the middle and four notices pinned round it, plus a torn
  corner still tacked up — a board nobody clears. The coat rack has an empty
  second hook, so it is a rack someone uses rather than a prop with one coat
  glued to it.
- **The counter is worn where elbows go**: the service hatch sill has a pale
  hollow in the middle and a scuffed strip along its edge, with a rust run from
  one nail down the casing.

## Four defects this pass had to fix, and why

1. **The coat read as a totem.** First attempt was four boxes of different
   widths; the steps across the chest were visible and the sleeves were the same
   depth as the body. It is now tapered cylinder masses (collar, chest, waist,
   skirt, sleeves, cuffs), so the silhouette narrows and widens like cloth.
2. **The coat's own details were buried inside it.** The placket, buttons and
   rubbed patches were placed at z = 2.17 while the coat's front face is at
   2.076, so none of them rendered. They now sit 4–8 mm proud of that plane.
3. **The rack board stuck out either side of the coat** and the fitting read as
   a cross. The board is 0.30 wide instead of 0.50 — just wide enough to carry
   its hooks.
4. **The register card was a big blank orange rectangle** with three lines of
   type lost in the middle — the "UI placeholder on an oversized backing"
   problem the art audit had already flagged. The card is now 0.19 × 0.13 (a
   postcard) and the board around it carries the notices.

## Two things that looked "strange" and why

1. **The window read as a box bolted onto the wall.** The sash had been pushed out
   to local z = 0.12, 6 cm proud of the wall face, with nothing between the reveal
   and the glass. The sash now sits inside the reveal at the room face, and the
   glass plane moved with it (0.12 → 0.038).
2. **A second moon hung under the real one.** The night glass was a mirror —
   roughness 0.06 with metallic_specular 0.9 — so it returned a hard image of the
   desk lamp. Old single-pane glass is dirty and wavy: roughness is now 0.62 and
   specular 0.12, which leaves a soft edge glow instead of a bright disc.


## The style rules this pass holds

- **Every surface is a flat-shaded facet.** No subdivision, no smooth normals.
- **Round things are 8–14 sided.** A lamp shade in this room is a polygon.
- **The palette is the room's own**, quantised to 8 steps so the nearest filter
  never shows a gradient.
- **No metal shading on props.** A metallic surface with no reflection probe goes
  black here (the old lamp's brass fount rendered as a black bulb), and PSX has no
  metal to lose — the atlas carries the brass colour.

## Three defects this pass had to fix, and why

1. **The lamp's own housing clipped to flat white.** It stands 6 cm from its
   2.6-energy light. No atlas value survives that, so `oil_lamp_static` alone gets a
   pre-darkened housing albedo (`_build_material` in the importer): the near light
   brings it *up to* brass instead of past it. Measured effect at the desk view:
   9 768 → 1 321 clipped pixels, and the fount gained a visible highlight.
2. **Additive glass stacked to pure white.** The chimney was additively blended
   against the blown-out night window. It is now `BLEND_MODE_MIX` at alpha 0.16 —
   low, because the tube has no caps and both walls draw.
3. **The pigeonhole forms lost every facet.** The desk's paper tile sat at 196 and
   clipped under the same lamp. It is now 118 (`build_office_furniture_blender.py`),
   plus a dimmed albedo on the paper surface in `import_office_furniture.gd`.

## A defect the window pass exposed in the table

`CopyCommitDesk`'s own collision ends at y = 0.80, and its option plates were
authored to rest on that plane. The Poly Haven table it stood on was 0.768 m tall,
so the plates had been floating 3 cm in the air. The authored table's top is now at
0.80, and `office_door_test` gained one assertion that pins the two together
(`table top meets the commit desk bearing surface`) — 3118 → 3119 assertions.

## Verification

- Focused suites green: spatial 31, desk_geometry 26, atmosphere 93, presentation 23,
  office_door 44, framing 93, routing_board 34, route_acceptance 49,
  routing_board_overlay 17, instrument_art 72.
- Full regression: **105 suites passed / 1 failed, 3119 assertions**. The one failure is
  `tests/telegraph/amendment_contract_test.gd` ("Correct amendment still does not reveal
  grading in knowledge"), which comes from an uncommitted edit in
  `scripts/telegraph/session/telegraph_session_controller.gd` that predates this pass and
  is not touched by it.
- Boot smoke: exit 0, no errors (the usual `2 resources still in use at exit`).
- Frames: `.dream-loop/prop_review/{before,final,v4,w1..w3,wear}/`, `.dream-loop/overview/`.
  The before/after pairs, the door and floor wear close-ups and the room views are
  copied into `frames/` beside this file, because `.dream-loop/` is outside git.
- Two suites (`missed_call_test`, `duty_sheet_test`) failed once during a full run and
  passed when re-run alone and in the next full run — the documented teardown flake,
  not a regression from this pass.

## Open item

`gdlint` cannot run on this host at all — single-file mode fails with
`Cannot create a file when that file already exists` on files this pass never touched
(e.g. `scripts/office/lamp_life.gd`), and directory mode reports the same 63 failures.
That is an environment defect, not a lint result; it needs re-checking on a host where
gdlint works before anyone claims "lint clean" for this pass.
