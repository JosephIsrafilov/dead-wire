# Third-Party Assets Register — DEAD WIRE

All third-party assets integrated into DEAD WIRE are verified for licensing compliance. Only CC0 / Public Domain assets with documented origins are used.

> **Owner policy update — 2026-09-19 (currently in force):** adapted external CC0 / Public Domain models, textures and audio are authorized for runtime use. See the runtime integration record at the bottom of this file for what is actually instanced in production.

> **Historical PSX pipeline note (superseded by the policy above, kept for provenance):** at the time this section was written, all runtime visual assets were hand-authored low-poly geometry and the entries below were reference-only (`runtime-instanced: no`). This describes the past state, not the current scene.

## Audio Provenance Record

**Historical note (pre-2026-09-19):** at the time of writing, the ambience bed
introduced no third-party audio; every sample listed in this section was
synthesised in-project by `tools/generate_office_ambience.py`. Some of these
have since been joined by selected CC0 foley — see the runtime record below;
the synthesised beds themselves are unchanged.

| File | Source | Length |
|---|---|---|
| `audio/sfx/ambience/room_tone.wav` | `render_room_tone()` | 24.0 s stereo loop |
| `audio/sfx/ambience/wind_window.wav` | `render_window_wind()` (`--only wind_window`) | 53.0 s mono loop |
| `audio/sfx/ambience/stove_fire.wav` | `render_stove_fire()` (`--only stove_fire`) | 41.0 s mono loop |
| `audio/sfx/foley/clock_tick.wav` | `render_clock_tick()` | 0.13 s mono one-shot |
| `audio/sfx/foley/clock_tock.wav` | `render_clock_tock()` (`--only clock_tock`) | 0.15 s mono one-shot |
| `audio/sfx/ambience/wire_sing.wav` | `render_wire_sing()` (`--only wire_sing`) | 37.0 s mono loop |
| `audio/sfx/foley/register_whir.wav` | `render_register_whir()` (`--only register_whir`) | 6.0 s mono loop |
| `audio/sfx/foley/board_door.wav`, `board_window.wav` | `render_board()` (`--only boards`) | 0.62 s / 0.36 s mono one-shots |
| `audio/sfx/ambience/outside_headframe.wav`, `outside_switch.wav`, `outside_couplings.wav` | `render_headframe_groan()`, `render_switch_points()`, `render_couplings()` (`--only outside`) | 3.2 / 1.5 / 3.4 s mono one-shots |
| `audio/sfx/foley/footstep_wood_1..5.wav` | `tools/generate_beta_footstep.py --variants` | 0.16–0.21 s mono one-shots |
| `audio/sfx/foley/cup_clink_2/3.wav`, `bottle_knock_2/3.wav` | `tools/generate_action_foley.py` (fifth pass, appended) | 0.30–0.40 s mono one-shots |

**Music (third-party, temporary):** `audio/music/temp/long_note_one.mp3` — "Long Note
One", Kevin MacLeod (incompetech.com), CC BY 4.0. Attribution in
`audio/music/temp/ATTRIBUTION.txt`, on the intro card, and in
`docs/beta/THIRD_PARTY_NOTICES.md`. Intro-only; must ship with its attribution
or be replaced (plan 7.12).

**Open item:** `sounder_down.wav`, `sounder_up.wav`, and `footstep_wood.wav`
predate this register and their origin is not documented anywhere in the
repository. Their provenance must be established — or they must be regenerated —
before any public release.

---

## M1 Historical Redesign Record

The M1 historical office redesign introduced no new third-party runtime assets.
The changed room envelope, desk, chair, stove, cabinet, bookcase collision,
routing board, window figure, and materials are authored in-project using Godot
CSG/primitive geometry and local `.tres` materials. The historical reference
links used for art direction are documented separately in
`docs/art/m1_historical_reference_board.md`; they are not packaged or rendered
at runtime.

---

## 1. Kenney Furniture Kit

- **Asset Name:** Furniture Kit
- **Author / Organization:** Kenney (AssetNL - https://kenney.nl)
- **Source URL:** https://kenney.nl/assets/furniture-kit
- **License:** Creative Commons Zero (CC0 1.0 Universal / Public Domain)
- **Commercial Use Allowed:** Yes
- **Attribution Required:** No (Credited voluntarily)
- **Download Date:** 2026-08-14
- **Source / Archive Hash:** `4e5264b971a8bc5048d08cb5ee0fa096df322f87a32dbb8f0ca4cecbbe8a12e2` (Archive hash recorded during download; archive not retained in repository)
- **Runtime-Instanced:** No (Replaced by handcrafted PSX low-poly props: `psx_chair.tscn`, `psx_bookcase.tscn`, `psx_side_table.tscn`)
- **Reference Files & SHA256:**
  - `res://models/third_party/kenney_chair.glb`: `C8A11EEC93E89E31250BA91AFC1B8D56C3BEC7AE86640FD1239F595FF4180883`
  - `res://models/third_party/kenney_desk.glb`: `0164FE828F028B321730FB8C74502E353583F751BE74DA1682D42FFF7D3C5A42`
  - `res://models/third_party/kenney_bookcaseClosed.glb`: `9D210448DE5E1179541DA895450BBC7A39F4CD673D677654CD6B134E4EA0E047`
  - `res://models/third_party/kenney_bookcaseOpen.glb`: `750702218D68C062B15DFEF6AB06A4014D1CFA8BD05F02E57C53B7E13BEC157C`
  - `res://models/third_party/kenney_books.glb`: `B8DC56E5D29F6FC1F4727FCCB1B9642627FEE9942C48060A00034E98DF02701C`
  - `res://models/third_party/kenney_sideTable.glb`: `8227810584F7D37582E4E9EC821C56F1DC54B99C88A8DC74242EA3B7402BC472`

---

## 2. Poly Haven — Vintage Oil Lamp

- **Asset Name:** Vintage Oil Lamp
- **Author / Organization:** Monsta3D (Poly Haven - https://polyhaven.com)
- **Source URL:** https://polyhaven.com/a/vintage_oil_lamp
- **License:** Creative Commons Zero (CC0 1.0 Universal / Public Domain)
- **Commercial Use Allowed:** Yes
- **Attribution Required:** No (Credited voluntarily)
- **Download Date:** 2026-08-14
- **Runtime-Instanced:** No
- **Budget Compliance Note:** Official source geometry (~7K tris) rejected from runtime spike because it exceeds the style-guide budget (50–800 tris for props); retained only as downloaded reference. The runtime test scene instances a custom CSG low-poly proxy (`res://scenes/style_tests/props/oil_lamp_lowpoly.tscn`, ~160 tris).
- **Source Files & SHA256:**
  - `vintage_oil_lamp_1k.gltf`: `ae570b98ea30b0337f62d8e7f551c03a05de00b238f3fac8f1ca5a1f1dbd1add`
  - `vintage_oil_lamp.bin`: `4064065c8e288beaa58639c139c801db337bfc6183e73378a9177157f0587167`
  - `vintage_oil_lamp_diff_1k.jpg`: `a96cc1383fb056618eca80a0cf4ae192286c8752f8e83cb52f9fec02ca94a471`
  - `vintage_oil_lamp_arm_1k.jpg`: `004b7b6238632e4fc9e2ad7e76529caa292cfd96f5a42d6564531207f25c3e92`
- **Reference Files & SHA256:**
  - `res://models/third_party/vintage_oil_lamp/vintage_oil_lamp_1k.gltf`: `40295D996F9F0BDD1205D3AC24497A546E298009B7D2F913B9E8B672930F1300`
  - `res://models/third_party/vintage_oil_lamp/vintage_oil_lamp.bin`: `4064065C8E288BEAA58639C139C801DB337BFC6183E73378A9177157F0587167`
  - `res://models/third_party/vintage_oil_lamp/textures/vintage_oil_lamp_diff_1k.jpg`: `94385713E4452B6CA05B3C52649921A98B3AF1A64728F9D33EC629BE29B6F866`
  - `res://models/third_party/vintage_oil_lamp/textures/vintage_oil_lamp_arm_1k.jpg`: `8133843A50E59628DE9674FC8DF1C3B28FCE9AF9D42F2BF477743952C670DBA6`

---

## 3. Poly Haven — Wood Floor Worn (Texture Reference)

- **Asset Name:** Wood Floor Worn
- **Author / Organization:** Dimitrios Savva (Poly Haven - https://polyhaven.com)
- **Source URL:** https://polyhaven.com/a/wood_floor_worn
- **License:** Creative Commons Zero (CC0 1.0 Universal / Public Domain)
- **Commercial Use Allowed:** Yes
- **Attribution Required:** No
- **Download Date:** 2026-08-14
- **Source SHA256:** `db386853009b92b9edd7255b35c9f7b0d4b7de16837a7a9da8422148754bc758`
- **Runtime-Instanced:** No (Replaced by `res://materials/style_tests/textures/psx/psx_floor_boards_128.png`)
- **Reference File & SHA256:**
  - `res://materials/style_tests/textures/wood_floor_worn_diff.png`: `9A1DA3EC93B19493D5CB378D964812A73A5BB97AA04FDA9B80AD6ECE56816CF6`

---

## 4. Poly Haven — Worn Plaster Wall (Texture Reference)

- **Asset Name:** Worn Plaster Wall
- **Author / Organization:** Dimitrios Savva (Poly Haven - https://polyhaven.com)
- **Source URL:** https://polyhaven.com/a/worn_plaster_wall
- **License:** Creative Commons Zero (CC0 1.0 Universal / Public Domain)
- **Commercial Use Allowed:** Yes
- **Attribution Required:** No
- **Download Date:** 2026-08-14
- **Source SHA256:** `f769bee35504ff713e89e89d2b64c1eb3c373dd184973ac8706310f19fd63efe`
- **Runtime-Instanced:** No (Replaced by `res://materials/style_tests/textures/psx/psx_wall_plaster_128.png`)
- **Reference File & SHA256:**
  - `res://materials/style_tests/textures/worn_plaster_wall_diff.png`: `7B393E3D12E1B6DD96886D5CD26BCE0163AF1D70D438AC504D55617E66E664E9`

---

## 5. Poly Haven — Weathered Brown Planks (Texture Reference)

- **Asset Name:** Weathered Brown Planks
- **Author / Organization:** Dimitrios Savva (Photography), Rico Cilliers (Processing) (Poly Haven - https://polyhaven.com)
- **Source URL:** https://polyhaven.com/a/weathered_brown_planks
- **License:** Creative Commons Zero (CC0 1.0 Universal / Public Domain)
- **Commercial Use Allowed:** Yes
- **Attribution Required:** No
- **Download Date:** 2026-08-14
- **Source SHA256:** `94833feda44e025a9139f7b5723ea84e4f0258d3b54939a79e1013c133085e29`
- **Runtime-Instanced:** No. Removed from `timber_trim.tres` and `desk_wood.tres` on 2026-10-23 (M1_FINISH_PLAN 1.4). Both use the first-party `assets/textures/worn_warmth/wood_128_v1.png`, nearest with mipmaps, world triplanar at 192 texels/m. The source photograph remains reference-only.
- **Reference File & SHA256:**
  - `res://materials/style_tests/textures/weathered_brown_planks_diff.png`: `D4E0FC5EE65045896B99860530C54CD76B65B18BB9DF974BB51525259962939B`

---

## 6. ambientCG — Paper 001 (Texture Reference)

- **Asset Name:** Paper 001
- **Author / Organization:** Lennart Demes (ambientCG - https://ambientcg.com)
- **Source URL:** https://ambientcg.com/view?id=Paper001
- **License:** Creative Commons Zero (CC0 1.0 Universal / Public Domain)
- **Commercial Use Allowed:** Yes
- **Attribution Required:** No
- **Download Date:** 2026-08-14
- **Source / Archive SHA256:** `5be094ffad8a6343ed96ec728e6eda3d84ae542cd2b16c32bc2ad67bb57a0013`
- **Runtime-Instanced:** No (Replaced by `res://materials/style_tests/textures/psx/psx_paper_64.png`)
- **Reference File & SHA256:**
  - `res://materials/style_tests/textures/paper_worn_diff.png`: `AA72FA07905379AF376CE7A7211D5FEC761D6D87FE240FAF5550C39E43A37275`


---

# Asset Quality Pass 2026-09-19 — runtime integration record

Actual downloads, adaptations and production instances from the V0–V7 pass.
Every "runtime-instanced" row below is wired into `scenes/office/m1_office.tscn`.

# Third-party assets — DEAD WIRE M1

All selected assets are CC0/Public Domain with verifiable sources. Originals
live under `assets/third_party/<provider>/<asset>/` (with `license.json` per
asset and SHA-256 manifests); game exports under `assets/m1_adapted/<asset>/`.
Downloaded-but-unwired packs are never packaged as runtime references.

| ID | Asset | License | Runtime use | Status |
|---|---|---|---|---|
| A02_wooden_table_02 | wooden_table_02 | CC0 | scenes/props/m1/ph_table.tscn (kept, not instanced) — retired from m1_office on 2026-10-20 when the authored Blender filing table replaced PhFilingTable | reference-only |
| A03_painted_wooden_cabinet_02 | painted_wooden_cabinet_02 | CC0 | scenes/props/m1/ph_cabinet.tscn (kept, not instanced) — retired from m1_office on 2026-10-20 when the authored Blender cabinet replaced StorageCabinet | reference-only |
| A04_painted_wooden_chair_01 | painted_wooden_chair_01 | CC0 | scenes/props/m1/ph_chair.tscn -> m1_office Chair/PhChairVisual (hidden 2026-10-20: the authored PSX chair carries the node; the overlay rendered a second, smoother chair through it) | reference-only |
| A05_book_encyclopedia_set_01 | book_encyclopedia_set_01 | CC0 | derived export assets/m1_adapted/ph_books/m1_ledger_volumes.tscn -> scripts/props/ph_ledger_volumes.gd -> m1_office PhLedgerVolumes | runtime-instanced (derived export) |
| A07_vintage_oil_lamp | vintage_oil_lamp | CC0 | NOT instanced: DeskSetup/OilLamp is the authored PSX lamp `oil_lamp_lowpoly.tscn` -> assets/models/office_props_v1/oil_lamp_static.res + lamp_glass_static.res (see section 2) | reference-only |
| — (authored) | office_furniture_v1 | original, first-party | assets/models/office_furniture_v1/{desk,bookcase,cabinet}_static.res -> DeskSetup / Bookcase / StorageCabinet in m1_office; the CSG blockouts stay as invisible collision witnesses | runtime-instanced (authored) |
| — (authored) | office_props_v1 | original, first-party | assets/models/office_props_v1/{oil_lamp,chair,clock,board,window,door_casing,door_leaf,door_knob,table,floor_wear}_static.res + lamp_glass_static.res -> DeskSetup/OilLamp, Chair, OfficeStorytellingProps/AuthoredClockCase, scenes/telegraph/routing_board.tscn, scenes/style_tests/props/{window_north,door_south}.tscn, m1_office FilingTable/FloorWear; the CSG blockouts stay as invisible collision/anchor witnesses | runtime-instanced (authored) |
| — (authored) | psx_floor_boards_256.png | original, first-party | materials/style_tests/textures/psx/psx_floor_boards_256.png; retained source for psx_floor_worn_128.png (generated by `tools/build_worn_floor.py`) | source-only (authored) |
| — (authored) | psx_floor_worn_128.png | original, first-party | materials/style_tests/textures/psx/psx_floor_worn_128.png -> floor_wood_planks.tres -> m1_office Floor; BOX 128px derivative of the retained authored 256px source; lossless mipmaps, ~229 texels/m | runtime-instanced (authored) |
| A08_paper001 | view?id=Paper001 | CC0 | downloaded, not yet wired into paper materials (paper_log.tres kept) | downloaded |
| S01_impact_sounds | impact-sounds | CC0 | lever_stop.ogg (RoutingBoard.LeverSfx at the stop), ink_stamp_cc0.ogg (foley Stamp), chair | runtime-instanced |
| S03_paper_sounds | various-paper-sound-effects | CC0 | paper_sound_-_2.mp3 -> audio/sfx/foley/paper_sheet.mp3 (foley Paper on viewer open/close) | runtime-instanced |

## Details

### A02_wooden_table_02
- source: https://polyhaven.com/a/wooden_table_02
- author: Poly Haven
- license: CC0
- adaptation: uniform 0.85 scale; flat PSX material via psx_asset_adapter (albedo from source diff, roughness 1)
- status: runtime-instanced

### A03_painted_wooden_cabinet_02
- source: https://polyhaven.com/a/painted_wooden_cabinet_02
- author: Poly Haven
- license: CC0
- adaptation: uniform 0.72 scale (2.57 m source -> 1.85 m station bookpress); muted paint
- status: runtime-instanced

### A04_painted_wooden_chair_01
- source: https://polyhaven.com/a/painted_wooden_chair_01
- author: Poly Haven
- license: CC0
- adaptation: farmhouse white muted to worn depot paint; authored CSG visuals hidden, collision preserved
- status: runtime-instanced

### A05_book_encyclopedia_set_01
- source: https://polyhaven.com/a/book_encyclopedia_set_01
- author: Poly Haven
- license: CC0
- adaptation: a derived game export `assets/m1_adapted/ph_books/m1_ledger_volumes.tscn` (the 4 selected volumes, own materials, correct owners) was produced by `tools/derive_ledger_volumes.gd`; `scripts/props/ph_ledger_volumes.gd` instances ONLY that export. The 67k-tri source set is never instantiated at runtime and no node cleanup or reparenting happens in play (the previous owner-inconsistent warnings are gone from the boot log).
- status: runtime-instanced (derived export; source pack stays reference-only)

### A07_vintage_oil_lamp
- source: https://polyhaven.com/a/vintage_oil_lamp
- author: Poly Haven
- license: CC0
- adaptation: none
- status: reference-only. The production desk lamp (`scenes/style_tests/props/desk_setup.tscn` -> `OilLamp`) is the authored PSX lamp `oil_lamp_lowpoly.tscn`, built from `tools/build_office_props_blender.py` into `assets/models/office_props_v1/{oil_lamp,lamp_glass}_static.res` (a stepped brass fount on a turned foot, a faceted glass chimney and a wick wheel, 724 + 100 tris). The Poly Haven geometry was never wired into the scene. Any earlier "runtime-instanced (pre-existing)" claim was wrong and is corrected here.

### A08_paper001
- source: https://ambientcg.com/view?id=Paper001
- author: ambientCG
- license: CC0
- adaptation: none yet
- status: downloaded

### S01_impact_sounds
- source: https://kenney.nl/assets/impact-sounds
- author: Kenney
- license: CC0
- adaptation: selected 3 of 130; original filenames recorded in manifest_audio_art.json
- status: runtime-instanced

### S03_paper_sounds
- source: https://opengameart.org/content/various-paper-sound-effects
- author: Luckius
- license: CC0
- adaptation: selected 1 of 4 paper_sound_* (crushed/ripped excluded)
- status: runtime-instanced

## Fonts (added 2026-09-26)

Both OFL 1.1; license text shipped beside each file. OFL permits bundling in a
commercial game; the fonts may not be sold on their own. Downloaded from the
official `google/fonts` repository (`raw.githubusercontent.com/google/fonts/main/ofl/...`).

| Asset | File | License | Use |
|---|---|---|---|
| IM FELL English Roman — Igino Marini | `assets/fonts/imfell/IMFeENrm28P.ttf` (+ `OFL.txt`) | SIL OFL 1.1 (Reserved Font Name "IM FELL") | all printed text: 3D labels (`_apply_embedded_body_font`), UI theme `assets/fonts/deadwire_theme.tres`, document viewer |
| Cedarville Cursive — Kimberly Geswein | `assets/fonts/cedarville/Cedarville-Cursive.ttf` (+ `OFL.txt`) | SIL OFL 1.1 | Elias's handwriting: transcript sheet labels, transcript in the document viewer |

## Project-generated assets (added 2026-09-26)

No third-party content; deterministic generators live in `tools/`.

| Asset | Generator |
|---|---|
| `audio/sfx/telegraph/sounder_down.wav`, `sounder_up.wav` | `tools/generate_sounder.py` |
| `audio/sfx/foley/pen_scratch.wav`, `key_click.wav`, `door_hinge.wav`, `sheet_slide.wav` | `tools/generate_action_foley.py` |
| `assets/models/operator/hand_v3.res`, `cuff_v3.res`, `forearm_v3.res` | `tools/build_writer_hand.gd` |
| `materials/style_tests/textures/psx/psx_wallpaper_stripe_128.png` | `tools/build_wallpaper.gd` |
| `materials/style_tests/textures/psx/form_night_copy.png`, `card_morse_stock.png` | `tools/build_paper_forms.gd` (IM FELL, OFL) |
| `audio/sfx/foley/wick_turn.wav` | `tools/generate_action_foley.py` |


## Worn warmth derivatives — 2026-10-08

This current runtime record supersedes the historical reference-only/downloaded descriptions
for the particular wood/paper texture derivatives below; it does not instance new models.
No new third-party download succeeded in this pass. Existing originals remain unchanged.

| Derived runtime texture | Provenance / license | SHA256 |
|---|---|---|
| `assets/textures/worn_warmth/wallpaper_128_v1.png` | Project-authored derivative | `47d5fd1b1b92e2ef57753a21598483a680de0d33babbbe12029e03ab1c4f9f73` |
| `assets/textures/worn_warmth/wood_128_v1.png` | Poly Haven weathered_brown_planks — CC0 | `9dc4451c2496054e0e7f49cd45862e664bed11165b2a078c6818a3c9d21a9611` |
| `assets/textures/worn_warmth/baize_128_v1.png` | Project-authored derivative | `9ebf32d4cef555e575820ac6a2a9a95458aeb5559eeebc8fa505e2365a8b57b6` |
| `assets/textures/worn_warmth/paper_128_v1.png` | ambientCG Paper001 — CC0 | `d962917b9b4ac6f845f6a2d001d8f39ceb97b54d77699461464dd06aef615cd1` |

Sources:
- Wood: https://polyhaven.com/a/weathered_brown_planks ; existing `materials/style_tests/textures/weathered_brown_planks_diff.png`.
- Paper: https://ambientcg.com/view?id=Paper001 ; existing `materials/style_tests/textures/paper_worn_diff.png`.
- ambientCG license: https://docs.ambientcg.com/license/ (CC0; modification and commercial distribution permitted).
- Wallpaper: existing authored `psx_wallpaper_stripe_128.png`, generated by `tools/build_wallpaper.gd`.
- Baize: original deterministic `cloth_source()` in `tools/build_worn_warmth.py`; no downloaded or AI content.

Runtime wiring: `m1_wall_plaster.tres`, `m1_wainscot_wood.tres`, `paper_log.tres`, and
`BlotterFelt` in `scenes/office/m1_office.tscn`. All derivatives are 128px albedos only.
Source hashes and recipes: `docs/art/state_2026-10-08/worn_warmth/derived_manifest.json`
and `tools/build_worn_warmth.py`. Unchanged printed forms are not covered by these replacements.

The new `assets/third_party/ambientcg/worn_warmth/metadata.json` and `LICENSE_SOURCE.txt`
record a search for Fabric030/Paper003/Wood051, not downloaded/used assets (archive requests failed HTTP 403).
Visual acceptance remains pending; see `03_local_asset_integration.md` in the art directory.

## Authored telegraph instrument pass — 2026-10-10

`assets/models/instruments_v1/` contains seven Blender-authored GLB assemblies and their
Godot ArrayMesh derivatives: key static/lever, sounder static/armature, register static/spool/stylus.
`assets/textures/instruments_v1/instrument_atlas_256.png` is an original deterministic six-tile
atlas (wood, brass, iron, coil, ebonite, paper), not a downloaded museum photograph or texture.
Builder: `tools/build_instruments_blender.py`; importer: `tools/import_instruments.gd`.
Editable source: `docs/art/state_2026-10-10/instruments/sources/dead_wire_instruments_v1.blend`.
Total authored triangles:3332. Runtime references only the seven `.res` meshes and shared atlas.

Museum catalogue text was consulted for material/mechanism plausibility, not copied as assets:
- https://americanhistory.si.edu/collections/object/nmah_706904 — key/sounder combination, ca1890.
- https://americanhistory.si.edu/collections/object/nmah_712418 — wood/brass frame, paired electromagnet.
- https://americanhistory.si.edu/collections/object/nmah_706654 — clockwork register/stylus mechanism.

These are stylized period-plausible instruments, not historically exact museum replicas.
No museum images, brand logos, paid generation or third-party meshes were integrated.
Artistic acceptance remains owner-review pending; automatic integration checks are not a visual verdict.

## Timing evidence font — mechanics pass

Courier Prime Regular is bundled unchanged at `assets/fonts/courierprime/CourierPrime-Regular.ttf`,
with `OFL.txt` shipped beside it. Copyright2015 The Courier Prime Project Authors; SIL OFL1.1.
Downloaded from the official Google Fonts repository:
https://raw.githubusercontent.com/google/fonts/main/ofl/courierprime/CourierPrime-Regular.ttf
https://raw.githubusercontent.com/google/fonts/main/ofl/courierprime/OFL.txt

Used only for the tape/reference timing table in DocumentViewer, replacing host-dependent SystemFont
fallback. Period letterpress and Elias handwriting remain unchanged. No modern sans face added.

## First-night font roles (2026-10-11)

- Noto Sans variable font: Google Fonts ofl/notosans/NotoSans[wdth,wght].ttf, bundled as assets/fonts/noto/NotoSans.ttf; SIL OFL 1.1 in adjacent OFL.txt. Source: https://github.com/google/fonts/tree/main/ofl/notosans . No longer used by the game UI (2026-10-30); kept for tools.
- Old Standard TT Regular/Bold: Google Fonts ofl/oldstandardtt/OldStandard-Regular.ttf and OldStandard-Bold.ttf, bundled under assets/fonts/oldstandard/; adjacent SIL OFL 1.1. Source: https://github.com/google/fonts/tree/main/ofl/oldstandardtt . Period-inspired styling, not a certified 1890 railway face. Since 2026-10-30 the UI theme, prompts and Elias's thoughts print in it; the whisper caption uses IM Fell.
- Courier Prime retained for American Morse timing and whitespace. No implicit system fallback intended.

### Beta sound provenance closure — 2026-10-11

The earlier open sounder item is superseded: tools/generate_sounder.py regenerated both runtime files byte-identically. SHA256 sounder_down: 937b0e802a3a4e050e4134cb8d1daf4465113dcf37e8d378e63437cad1edd7f5; sounder_up: 21abfe483cb0a9f4ef6157430b04d4c7960804add4d324d1b36c308bf44847d1. These are deterministic project-authored synthesis.

Unknown legacy footstep_wood.wav is retained for rollback but no longer referenced by runtime scripts/scenes. Runtime uses project-authored audio/sfx/foley/footstep_wood_beta.wav from tools/generate_beta_footstep.py (independent seeded RNG). Temporary synthesis, not final recorded Foley.

Register winding: audio/sfx/foley/register_wind.wav appended to tools/generate_action_foley.py without changing prior RNG order. Wick uses wick_turn.wav; feed uses sheet_slide.wav; pickup uses paper_turn.wav.


## Tailored hanging coat — owner-selected B (2026-11-01)

Project-authored low-poly geometry and procedural wool texture, created in Blender through MCP.
No downloaded meshes, paid generation or third-party textures were used.
Runtime asset: `assets/models/office_props_v1/coat_tailored.glb` and its extracted
`coat_tailored_Wool_B_peat.png`. The original Blender file and authoring script are in
`docs/art/state_2026-11-01/coat/sources/` (excluded from Godot import with `.gdignore`).
The garment has 2004 triangles, including lining, cuff rims, pockets and horn buttons.
Owner selected the warm-grey B material; motion acceptance is separate.
