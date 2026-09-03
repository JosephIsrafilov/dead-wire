# M1 Historical Reference Board: 1894 American Railroad Telegraph Office

## Design Intent

M1 represents a compact night-shift depot office in 1894. The room is a
functional operating space, not a museum recreation: the operator must be able
to work the wall board, and turn toward separate north-window and south-door events.

## Architectural Direction

- **Room envelope:** narrow timber depot office with a plank floor, low ceiling,
  plaster upper walls, timber wainscoting, heavy trim, and a south door.
- **Trackside observation:** a north sash window gives the operator a discrete
  view outside the room. The event silhouette remains beyond the glass and is
  visually distinct from the idle night field.
- **Materials:** worn dark wood for floor and furniture, muted plaster for upper
  walls, olive slate for the route board, warm lamp/stove accents, and cool blue
  exterior light.
- **Lighting:** a localized oil-lamp pool makes the desk legible while the rest
  of the office falls away into low light. The window is cooler; the stove adds
  a small amber counterpoint.

## Furniture And Work Zones

- **West desk:** telegraph key, sounder, transcript, reference card, ledger,
  oil lamp, and an independent wooden chair arranged for one seated operator.
- **East route board:** framed slate board with line/siding rails and a physical
  lever. Route keys appear only in screen-space UI while the board is open and
  a route is awaited.
- **South storage and heat:** a potbelly stove, cabinet, bookcase, and door form
  a distinct attention direction from the desk and window.
- **Circulation:** no full waiting-room divider; the room preserves a usable
  crossing path between desk, board, window, and door.

## Historical Reference Matrix

These sources are art-direction research only. No photograph, scan, model,
texture, audio recording, or source-specific design is redistributed or loaded
by the game.

| Source | Evidence used | M1 application | Rights/runtime status |
|---|---|---|---|
| Flint Hills Special, [CRIP depot interior](https://flinthillsspecial.com/2016/10/23/alta-vista/crip-depot-interior-copy/) | Compact depot-office scale, timber finish, working storage | Narrow room hierarchy, desk/storage relationship, practical work surfaces | Link-only reference; not copied or packaged |
| State Library of South Australia, [telegraph history and station equipment](https://stories.slsa.sa.gov.au/kookaburra-sits-on-the-telegraph-wire/) | Period telegraph equipment and office context | Telegraph desk, sounder, paper workflow and work-worn cues; not a claim of United States provenance | Link-only reference; not copied or packaged |
| Library of Congress, [catalog record 2017847048](https://www.loc.gov/item/2017847048/) | U.S. historic built-environment catalog context | Timber-station/depot reference check; room remains a fictional composite | Link-only reference; no image or metadata embedded at runtime |
| Pope 1874/1891 and Potter 1870, recorded in `docs/research/american_morse_1894_source_audit.md` | American Morse timing, alphabet topology, sounder practice | 18-character reference card, sounder/transcript scenario, 1894 period boundary | Text research only; no external media introduced |
| `docs/third_party_assets.md` | Runtime asset provenance | Confirms all first-pass M1 scene geometry and materials are in-project authored | No new third-party runtime asset |

## Implementation Record

> **Status note (2026-09-03):** This historical board is superseded for regression status. The current baseline is 30 suites, 0 failures, 1171 assertions.

- Production scene: `res://scenes/office/m1_office.tscn`.
- Low-poly PSX texture suite: `materials/style_tests/textures/psx/` (11 authored textures, nearest-neighbor filtering, 128x128 floorboards, 128x128 wainscoting, plaster, ceiling boards, metals, brass, slate, paper, night sky).
- New architecture/materials: hand-authored Godot CSG/primitives and local `.tres` materials.
- No new third-party runtime models, textures, or audio were introduced for the redesign.
- Canonical visual evidence: `docs/art/m1_visual_acceptance/final/` (16 canonical 1280x720 PNGs).
- Matched before/final pairs: `docs/art/m1_visual_acceptance/comparison/` (8 matched 2560x720 side-by-side PNGs).
- Current verification baseline: 30 automated test suites, 0 failures, 1171 assertions.

- Focused evidence: `docs/art/m1_visual_acceptance/focused_round/`.
- Focused comparisons: `docs/art/m1_visual_acceptance/comparison_focused/`.
- Evidence index and SHA256 record: `docs/art/m1_visual_acceptance/README.md`.
- Current verification: 30 suites, 0 failures, 1171 assertions; integration 58;
  presentation structure 22.
- Changed files are listed in `docs/reports/m1_office_prototype_completion_report.md`.
- Current visual status remains `M1 VISUAL ACCEPTANCE CANDIDATE - AUTOMATED GATES
  PASS, HUMAN ACCEPTANCE PENDING`; no human acceptance is claimed here.
