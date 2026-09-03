# M1 Visual Acceptance Correction Report — Historical Art-Direction Rebuild

## Scope

This comprehensive art-direction rebuild transformed the M1 office from a stark CSG prototype box into a believable, inhabited late-19th-century (1894) American railway telegraph office at night, while rigorously adhering to the low-resolution PSX visual language (320x180 internal framebuffer upscaled to 1280x720, nearest-neighbor texture filtering, palette quantization, affine wood/metal textures).

All gameplay systems, Morse timing, encoder, scheduler, scenarios, WorldState, KnowledgeState, controls, interaction semantics, route outcomes, WATER/WATCHER behavior, attention timings, footsteps, and final-cycle lock remain 100% intact and verified across 24 test suites.

## Confirmed Rebuild & Art Corrections

| Area | Rebuild Changes |
|---|---|
| **PSX Texture Pipeline** | Generated 11 period-authentic 1890s PSX textures (128x128 floorboards with cut nails and staggered butt joints, 128x128 vertical beadboard oak wainscoting, aged lime/horsehair plaster, whitewashed ceiling boards, natural wood grain, cast iron, brushed brass, slate chalkboard, mountain night sky vista, 1894 railroad telegraph paper). Zero untextured prototype surfaces. |
| **Room Architecture** | Added 4 dark timber ceiling rafters (`CeilingBeam1..4`), removed crude black floor seam boxes, enlarged the north night sky backdrop for seamless window coverage, and integrated dark oak baseboards and wainscot chair rails. |
| **Lighting Hierarchy** | Balanced multi-point lighting hierarchy: warm desk oil-lamp focal pool (`Color(1.0, 0.72, 0.44)`), cold directional moonlight window spot (`Color(0.45, 0.60, 0.90)`), soft corner stove ember glow (`Color(0.90, 0.32, 0.08)`), east wall dispatch sconce (`Color(0.88, 0.78, 0.58)`), and balanced neutral ambient fill (`Color(0.42, 0.48, 0.58)`). |
| **Desk & Station Hardware** | Rebuilt operator workstation with rear pigeonhole organizer, pen tray, inkwell with brass cap, brass-mounted Western Union Morse key with trunnions and binding posts, twin-coil sounder with arched brass anvil on walnut base, aged telegraph pad, Morse cardstock, and leather ledger. |
| **4-Panel Victorian Door** | Added authentic raised casing, floor threshold, antique brass escutcheon plate, doorknob, keyhole, and iron hinges. |
| **Potbelly Stove & Hearth** | Added 4 curved cast-iron legs, zinc hearth pad, potbelly belly ring, firebox door with glowing ember seam, vertical pipe rising to a 90° elbow entering the wall chimney flue, and coal scuttle with shovel. |
| **Multi-Pane Sash Window** | Added double-hung sash framing with check rail, deep wooden sill, apron molding, and brass sash lock. |
| **Routing Switchboard** | Rebuilt with heavy dark oak molding frame, brass corner brackets, dark olive-slate chalkboard surface, brass track rails, cast-iron switch throw lever with turned wood grip, and brass station/line plaques. |
| **Window Silhouette** | Rebuilt eerie silhouette of a figure in a slouch hat and long duster coat standing in the cold moonlight outside the window with zero artificial lights, strictly preserving event detection semantics. |
| **Storytelling Props** | Station regulator wall clock with pendulum box, ceramic insulator telegraph wire runs, coat rack with hanging coat and hat, south wall duty roster board, and service ticket hatch. |

## Technical & Automated Verification

- **24 Test Suites**: 24/24 PASSED (0 failures, 0 errors, 876 assertions).
- **Integration Suite**: 58 assertions PASS.
- **Presentation Structure Suite**: 22 assertions PASS.
- **Spatial Metrics Suite**: PASS (zero furniture intersections, player clearance paths verified, desk document separation preserved, chair orientation and contact verified).
- **Godot Headless/Console Launch**: Exit Code 0.
- **16 Canonical Final PNGs**: Rendered at 1280x720 via production Forward+ (D3D12) engine pipeline with unique SHA256 hashes.
- **8 Matched Before/Final Comparisons**: 2560x720 side-by-side comparison PNGs in `docs/art/m1_visual_acceptance/comparison/`.
- **Reference Card & Scenario 3 Verification**: Validated by `capture_12_evidence_shots.gd`.

## 16 Canonical Evidence Inventory

| PNG | Mean Lum | Below 32 % | Canonical Final SHA256 |
|---|---:|---:|---|
| `01_spawn_hero.png` | 48.2 | 32.2% | `ed1b08b53e12645ddf9c37983e4dc7234f4f64e168b8da6e35a30b5a1a8db423` |
| `02_full_room_overview.png` | 46.6 | 37.2% | `d1cbc3ba68124804bcc34eda5287047e003c6e2ffd45ed6b73f42b3bc07b84ff` |
| `03_operator_workstation.png` | 32.0 | 66.9% | `898a77e771cfc52b955daaa3bbfed1cd0f1ce2ea520a2a3321dbd2152c13672c` |
| `04_chair_clearance.png` | 27.1 | 62.5% | `0c3818a6d1e1c1caedad9dc2974de8498250f2e04ff6f8f6ce4fbc815cfcce32` |
| `05_telegraph_equipment.png` | 56.3 | 36.3% | `29a346e7311a82b513b2478d46060da43cb1920887caf39c6a4408367c24846e` |
| `06_north_window_idle.png` | 27.5 | 74.3% | `6599b1677c9e2953836c17391a5fa0a819529c9473d1d3c3dec3d1b848c146db` |
| `07_north_window_figure.png` | 25.7 | 77.5% | `a9227f16c667dd535fda3ae58b989bcdf6f704157d21d7c36777a9a052d229c5` |
| `08_south_door.png` | 36.9 | 56.0% | `4d081431f81578cb3d6c05ec969f2142f112511f72392faa23632cccc3c3b13e` |
| `09_routing_board.png` | 30.6 | 77.2% | `80a60ca2889b8b1e4e681dc85394addc304a79eff90b4d5b1c2889ac12fcca8d` |
| `10_stove_storage.png` | 35.8 | 59.4% | `d57a942eef0b84958f15914853f932f536f6f39e116f86e895b1f192a1c83977` |
| `11_real_morse_document.png` | 75.3 | 49.7% | `76acf99d2827a361c7f174153179b8ca34f6a29be3e84a9faa555729ae578e3d` |
| `12_scenario3_debug_telemetry.png` | 39.2 | 55.4% | `9af41b42792c6185262cde14c0384299718ca97a5bf1ba7c2d953f963d9cfbf3` |
| `13_station_clock_detail.png` | 72.9 | 15.2% | `4e91734d03013f1344ff698f18bcffa208fd8abdd5b95545f5051dc451cf1cf2` |
| `14_duty_roster_hatch.png` | 31.6 | 72.1% | `ad2d579006c1c309e224ebd3b2c509500012d95bb968bfd894a69f476c3fcddf` |
| `15_bookcase_records.png` | 21.2 | 84.0% | `ae2a9a543581c2a23c16e961759406e03fb878063acceb52149d85c0806d8739` |
| `16_storage_cabinet_detail.png` | 31.5 | 58.4% | `c1e766d20fc923a0a1a8fa376d5d4122da0a58447267cbc388281ab1996f7d9e` |

## Visual Acceptance Status

M1 VISUAL ACCEPTANCE CANDIDATE — AUTOMATED GATES PASS, HUMAN ACCEPTANCE PENDING

