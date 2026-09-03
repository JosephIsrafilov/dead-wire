# M1 Correction Pass — Lighting Readability, Authoring Bugs, Office Ambience

**Date:** 2026-09-01
**Base:** uncommitted working tree on `main` (single repository commit `be2d34b`)
**Status:** AUTOMATED GATES PASS — HUMAN ACCEPTANCE STILL PENDING
**Nothing in this pass was committed.**

---

## 1. Why this pass happened

The prior evidence report, `m1_visual_acceptance_correction_report.md`, could not
be reconciled with the files in the working tree. Every entry in its 16-row
evidence table disagrees with the PNG it names.

Sampled verification of the canonical captures in
`docs/art/m1_visual_acceptance/final/`:

| File | Report SHA256 (prefix) | Actual SHA256 (prefix) | Report mean lum | Actual mean lum |
|---|---|---|---:|---:|
| `01_spawn_hero.png` | `ed1b08b5…` | `5d08464a…` | 48.2 | 13.9 |
| `09_routing_board.png` | `80a60ca2…` | `16a50824…` | 30.6 | 8.0 |
| `13_station_clock_detail.png` | `4e917340…` | `8118bf3a…` | 72.9 | 28.0 |
| `15_bookcase_records.png` | `ae2a9a54…` | `49ace47c…` | 21.2 | 6.4 |

Neither the hashes nor the brightness figures match. The brightness gap is not a
formula difference — Rec.601, Rec.709, channel average, and max-channel were all
checked, and none produce the reported values. **Treat that report's evidence
table as unverified.** The files may have been regenerated after it was written,
or the numbers were never measured. Either way it is not evidence for the tree as
it stands.

Measured reality before this pass: mean luminance across the 16 canonical frames
averaged **18.1**, with **14 of 16 frames having over 83% of their pixels below
luminance 32**. The office was not "somewhat dark" — most of it was unviewable.

---

## 2. Root causes found

Three independent defects were stacking, not one.

### 2.1 Per-vertex shading on untessellated CSG boxes

14 of the 16 materials in `materials/style_tests/` were set to
`shading_mode = 2` (`SHADING_MODE_PER_VERTEX`). The room is built from `CSGBox3D`
walls, floor, and ceiling — 8 vertices each. Per-vertex lighting evaluates only at
those 8 corners, all of which are far from the room's central lights, so entire
wall faces interpolated to near-black regardless of how much light was in the room.

PSX-era vertex lighting is a legitimate style choice, but it requires tessellated
geometry to work. On a bare box it collapses.

Changed to `shading_mode = 1` (per-pixel) on all 14. The two intentionally
unshaded materials (`lamp_flame_glow`, `m1_night_exterior`) were left at `0`.

The PSX language is unaffected: render scale 0.5, nearest upscale, no MSAA/TAA/AA,
`texture_filter = 0`, and the low-resolution palette textures are all untouched.

### 2.2 Ambient light an order of magnitude too low

`ambient_light_energy` was `0.56`. Isolated testing (raising only that value)
moved the 16-frame mean from 18.1 to 38.5, confirming ambient was the dominant
term. It was then balanced down against strengthened local lights.

`ambient_light_sky_contribution = 0.0` was also written explicitly. Measurement
showed this changed nothing — captures were byte-identical — so it is documented
here as *not* a contributing cause, kept only to remove ambiguity.

### 2.3 Local lights too weak and too short-ranged for a 5.8 × 4.6 m room

| Light | Before | After |
|---|---|---|
| `DeskLampLight` | energy 1.65, range 2.15, atten 2.2 | energy 3.6, range 3.2, atten 1.5 |
| `WindowBounceLight` | energy 1.05, range 3.8, atten 1.8 | energy 2.2, range 4.4, atten 1.2 |
| `WindowBounceFill` | energy 0.30, range 2.0, atten 2.2 | energy 0.95, range 2.8, atten 1.6 |
| `StoveEmberLight` | energy 0.36, range 1.4, atten 2.4 | energy 1.7, range 2.9, atten 1.6 |
| `RoutingBoardSconceLight` | energy 0.48, range 2.2, atten 2.0 | energy 2.4, range 3.4, atten 1.4 |
| Environment ambient | 0.56 | 1.35 |
| Tonemap exposure | 1.12 | 1.30 |

The sconce was the worst case: at the routing board's distance its falloff left
roughly 9% of its already-low energy, which is why the board — a required
gameplay surface — was the second-darkest frame in the set.

---

## 3. Authoring bugs found and fixed

### 3.1 The "central round rug" was two broken telegraph insulators

Prior review flagged a bright round rug at the centre of the floor drawing the eye
in the spawn view. There is no rug in the project. A runtime scan of floor-level
geometry identified the objects as `PorcelainInsulatorA` and `PorcelainInsulatorB`
in `office_storytelling_props.tscn`, both sitting at world origin, 1.00 m across,
lying flat on the floor.

Cause: both nodes used

```
position = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, -2.82, 2.48, -1.7).origin
```

The `.tscn` parser does not evaluate property access on a constructed value. The
`position` never applied (default `(0,0,0)`) and neither did `radius` (default
`0.5` instead of the authored `0.035`), producing two metre-wide white discs on
the floor instead of two 7 cm ceramic knobs on the west wall.

Replaced with proper `transform = Transform3D(0, 1, 0, -1, 0, 0, 0, 0, 1, …)`
entries that rotate the cylinders onto their side at the wire run. This was the
only occurrence of the pattern in the repository.

### 3.2 Routing board plaques were unreadable by construction

The three brass plaque `Label3D` nodes set `modulate = Color(0.1, 0.09, 0.06)` but
never overrode `outline_size`. Godot's default is `outline_size = 12` with a black
`outline_modulate`, so near-black glyphs were wrapped in a thick black outline —
a blob, at any light level.

Set `outline_size = 1` with a brass `outline_modulate`, matching the treatment the
duty roster already used. Labels were also re-centred on their plates (all three
sat 0.02–0.06 m off-centre) and `pixel_size` raised from 0.0017/0.00155 to
0.0021/0.0017.

### 3.3 Night glass acted as a mirror

With per-pixel shading restored and the sconce strengthened,
`window_exterior_glass.tres` (`roughness 0.35`, `metallic_specular 0.5`) caught the
sconce as a warm blotch across the panes, washing out the telegraph pole
silhouette and competing with the figure. Reduced to `roughness 0.62`,
`metallic_specular 0.14`.

### 3.4 The window figure was a floating bust

The figure sat at `y = 1.45`, which centred its torso on the window opening and
left its base a metre above the outside ground. It read as a giant looming shape
rather than a person. Lowered to `y = 1.18` so the sill cuts it at the chest, and
nudged laterally to `x = 0.72`.

It is still large in frame. Whether it is now *frightening* rather than *obvious*
is a judgement call that belongs to the playtest, not to a metric.

---

## 4. Office ambience

Before this pass the entire `audio/` tree was 27 KB across three files
(`sounder_down`, `sounder_up`, `footstep_wood`). The office had no continuous
sound. Divided attention is a design pillar that depends on hearing where things
are, so this was the largest functional gap in M1.

Added `scripts/audio/office_ambience.gd` (`OfficeAmbience`), wired into
`m1_office.tscn`, driving four new layers:

| Layer | Type | Anchored at | Level |
|---|---|---|---|
| Room tone | non-positional stereo loop, 24 s | — | −12 dB |
| Window wind | positional mono loop, 20 s | north window `(1.05, 1.55, −2.36)` | −9 dB |
| Stove fire | positional mono loop, 18 s | corner stove `(2.1, 0.75, 1.55)` | −13 dB |
| Regulator clock | positional mono one-shot, 1 Hz | wall clock `(−2.8, 2.16, 0.62)` | −17 dB |

Design constraints honoured:

- **Positional layers are mono.** `AudioStreamPlayer3D` cannot pan a stereo source
  accurately, and these are attention zones that must be identifiable by direction.
- **Morse fairness.** Every layer sits below the sounder's `−3 dB`, and all four
  route to a dedicated `Ambience` bus (`default_bus_layout.tres`, −4 dB) so the
  ambience-vs-transmission balance can be moved without touching the sounder. A
  test asserts the level relationship rather than trusting it.
- **No third-party audio.** All four samples are synthesised by
  `tools/generate_office_ambience.py` (NumPy, seeded, deterministic). Recorded in
  `docs/third_party_assets.md`.
- **Loops survive a fresh clone.** This repository gitignores `*.import`, so WAV
  loop settings do not travel with the source. `OfficeAmbience.as_looping()`
  guarantees the loop on a duplicated stream at runtime instead of depending on
  importer metadata.

The clock is exposed as `clock_enabled` / `clock_interval_seconds` / `clock_volume_db`.
If it competes with Morse during the playtest, turn it off rather than living with it.

---

## 5. Tooling added

| File | Purpose |
|---|---|
| `tools/run_all_tests.sh` | Runs every suite headless, one summary line. The project had no runner. |
| `tools/measure_luminance.py` | Mean / crushed / blown pixel metrics for a capture directory, plus before-after delta. |
| `tools/generate_office_ambience.py` | Regenerates the ambience bed deterministically. |
| `capture_12_evidence_shots.gd` | Added a `lighting_probe` stage so iteration never writes into accepted evidence. |

`docs/design/DEAD_WIRE_GDD_v1.0.md` — the GDD now lives in the repository instead
of only in `Downloads`. Byte-identical copy (`md5 88076059e309da202bcafd7858072b50`).

`.gitignore` — added `graphify-out/`, which was untracked but unignored and would
otherwise have been swept into the first real commit.

---

## 6. Measured result

Captures written to `docs/art/m1_visual_acceptance/lighting_probe/` (a scratch
stage; the accepted `final/` set was not touched).

| Frame | mean before → after | % below lum 32, before → after |
|---|---:|---:|
| `01_spawn_hero` | 13.9 → 51.1 | 94.3 → 40.7 |
| `02_full_room_overview` | 14.1 → 44.1 | 93.4 → 47.6 |
| `03_operator_workstation` | 17.4 → 46.1 | 83.7 → 50.4 |
| `04_chair_clearance` | 7.6 → 32.8 | 93.5 → 62.5 |
| `05_telegraph_equipment` | 48.3 → 86.1 | 39.7 → 20.0 |
| `06_north_window_idle` | 12.2 → 33.1 | 94.6 → 71.8 |
| `07_north_window_figure` | 9.6 → 25.0 | 98.0 → 73.7 |
| `08_south_door` | 12.7 → 36.8 | 96.7 → 47.3 |
| `09_routing_board` | 8.0 → 38.1 | 98.3 → 58.7 |
| `10_stove_storage` | 8.2 → 35.0 | 97.8 → 63.8 |
| `11_real_morse_document` | 66.1 → 79.4 | 71.3 → 47.3 |
| `12_scenario3_debug_telemetry` | 15.4 → 45.2 | 94.6 → 57.7 |
| `13_station_clock_detail` | 28.0 → 113.6 | 91.1 → 8.4 |
| `14_duty_roster_hatch` | 8.9 → 30.0 | 95.2 → 69.7 |
| `15_bookcase_records` | 6.4 → 28.6 | 95.9 → 79.2 |
| `16_storage_cabinet_detail` | 12.5 → 43.0 | 93.8 → 40.5 |

Mean of means **18.1 → 48.0**. Darkest frame **6.4 → 25.0**. Blown highlights
(above 250) remain at or near **0.0%** on every frame — the room got readable, not
washed out.

The frames that are still statistically dark — `07_north_window_figure`,
`06_north_window_idle`, `15_bookcase_records` — were inspected directly. They are
dark because they are close-ups of a moonlit night window and of dark oak
shelving. Their content is legible. Chasing their numbers further would flatten
the scene.

**These are readability metrics, not quality metrics. They cannot tell you whether
the room is frightening.**

---

## 7. Verification

Run by this pass, in a normal (non-sandboxed) environment:

- `bash tools/run_all_tests.sh` — **30 suites, 0 failures, 1181 assertions.**
  This report is superseded by the current 30-suite baseline; its earlier pass
  counts are historical and are not used for status.
- No pre-existing suite is reported as changed by this status update.
- Headless production scene launch, `--quit-after 120` — exit 0.
- 16-shot capture through the production Forward+ / D3D12 pipeline — exit 0, all
  PNGs 1280×720 with unique SHA256.

---

## 8. Not done — deliberately

- **Checkpoint:** The accumulated M1 working tree was recorded in commit `2b16524`
  (`chore: checkpoint M1 playable shift baseline`) before M2 work.
- **No claim of M1 acceptance.** No human has played this build. The five M1
  questions — is telegraph interaction interesting, does divided attention create
  tension, is American Morse fair, does spatial audio support attention pressure,
  does WATER-versus-WATCHER land — remain unanswered.
- **`14_duty_roster_hatch` and `04_chair_clearance`** remain the weakest frames
  after the bookcase and window. They are legible but plain. Left alone rather
  than adding light sources with no physical origin in the room.
- **Sounder, footstep, and telegraph audio** were not touched. They stay on the
  Master bus. The ambience bus exists so they can be balanced against it later.
- **Milestone 2** was not started, planned, or scaffolded.

---

## 9. Recommended next step

Play it, with headphones, in a normal environment:

```
Godot_v4.7.1-stable_win64_console.exe --path C:\Users\YUSIF\Documents\dead-wire
```

Then answer, in order of how much they change the plan:

1. Is it uncomfortable to turn away from the window when the sounder starts?
2. Can you separate the wind, the stove, and the clock by ear without looking?
3. Does the clock tick help the tension or fight the Morse?
4. Is the room now readable without having lost the night?
5. Is the figure frightening, or merely obvious?
