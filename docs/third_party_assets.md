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
| `audio/sfx/ambience/wind_window.wav` | `render_window_wind()` | 20.0 s mono loop |
| `audio/sfx/ambience/stove_fire.wav` | `render_stove_fire()` | 18.0 s mono loop |
| `audio/sfx/foley/clock_tick.wav` | `render_clock_tick()` | 0.13 s mono one-shot |

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
- **Runtime-Instanced:** No (Replaced by `res://materials/style_tests/textures/psx/psx_dark_wood_64.png`)
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
| A02_wooden_table_02 | wooden_table_02 | CC0 | scenes/props/m1/ph_table.tscn -> m1_office PhFilingTable (south-wall service table) | runtime-instanced |
| A03_painted_wooden_cabinet_02 | painted_wooden_cabinet_02 | CC0 | scenes/props/m1/ph_cabinet.tscn -> m1_office PhCabinetVisual (replaces StorageCabinet visu | runtime-instanced |
| A04_painted_wooden_chair_01 | painted_wooden_chair_01 | CC0 | scenes/props/m1/ph_chair.tscn -> m1_office Chair/PhChairVisual (OperatorSeat anchors, Chai | runtime-instanced |
| A05_book_encyclopedia_set_01 | book_encyclopedia_set_01 | CC0 | derived export assets/m1_adapted/ph_books/m1_ledger_volumes.tscn -> scripts/props/ph_ledger_volumes.gd -> m1_office PhLedgerVolumes | runtime-instanced (derived export) |
| A07_vintage_oil_lamp | vintage_oil_lamp | CC0 | NOT instanced: DeskSetup/OilLamp is the authored CSG proxy oil_lamp_lowpoly.tscn (~160 tris, see section 2) | reference-only |
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
- status: reference-only. The production desk lamp (`scenes/style_tests/props/desk_setup.tscn` -> `OilLamp`) is the authored CSG proxy `oil_lamp_lowpoly.tscn`; the Poly Haven geometry was never wired into the scene. Any earlier "runtime-instanced (pre-existing)" claim was wrong and is corrected here.

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
