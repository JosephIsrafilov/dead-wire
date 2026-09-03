# Third-Party Assets Register — DEAD WIRE

All third-party assets integrated into DEAD WIRE are verified for licensing compliance. Only CC0 / Public Domain assets with documented origins are used.

> **PSX Pipeline Note:** In accordance with the True PSX Art Pipeline, all runtime visual assets (walls, floors, furniture, fixtures) are rendered exclusively using custom hand-authored low-poly geometry and palette-quantized textures (`materials/style_tests/textures/psx/`). All external third-party models and photogrammetry textures listed below are retained solely as downloaded reference (`runtime-instanced: no`).

## Audio Provenance Record

The M1 office ambience bed introduced **no third-party audio**. Every sample under
`audio/sfx/` is synthesised in-project by `tools/generate_office_ambience.py`
(NumPy noise shaping and additive synthesis, seeded per layer, deterministic on
re-run). There is nothing here to licence, credit, or clear:

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
