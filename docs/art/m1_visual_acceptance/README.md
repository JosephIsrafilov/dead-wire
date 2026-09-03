# M1 Visual Acceptance Evidence — Historical Art-Direction Rebuild

## Locations

- Rejected baseline: `docs/art/m1_visual_acceptance/before/` (and archived `rejected_visual_pass/`)
- Canonical final: `docs/art/m1_visual_acceptance/final/`
- Matched before/final comparisons: `docs/art/m1_visual_acceptance/comparison/`

All canonical PNGs are 1280x720 rendered through the production Forward+ (D3D12) engine pipeline. Runtime state is the production `res://scenes/office/m1_office.tscn` scene. The capture runner validates the real Morse Reference Card interaction, Scenario 3 window event, reloadability, dimensions, and unique SHA256 values.

## Visual Rebuild Summary

The M1 depot office was rebuilt from a flat, stark prototype into an authentic, inhabited late-19th-century (1894) American railway telegraph office:
1. **Floor & Ceiling Architecture**: Hand-authored 128x128 wide pine floor plank texture (`psx_floor_boards_128.png`) with organic grain, staggered butt joints, and square-cut iron nails; 4 exposed dark timber ceiling beams (`CeilingBeam1..4`) supporting whitewashed pine ceiling planks (`psx_ceiling_boards_128.png`).
2. **Wall Envelope & Trim**: Dark oak beadboard wainscoting (`psx_wainscot_128.png`) on the lower 1.05m topped with a molded chair rail; horsehair/lime plaster texture (`psx_wall_plaster_128.png`) on upper walls.
3. **Victorian Sash Window**: Multi-pane double-hung sash window with check rail, deep wooden sill, apron molding, and brass sash lock overlooking a moonlit mountain ridge with telegraph pole and wires (`psx_window_night_64.png`).
4. **4-Panel Victorian Door**: Sturdy timber door with raised casing, floor threshold, antique brass escutcheon plate, doorknob, keyhole, and iron hinges.
5. **Segmental Potbelly Stove**: 4-legged cast-iron stove with potbelly belly ring, zinc hearth pad, firebox door with glowing ember seam, and vertical pipe rising to a 90° elbow entering the wall chimney flue.
6. **Telegraph Desk & Workstation**: Heavy 1890s operator desk with rear pigeonhole organizer, pen tray, inkwell with brass cap, brass-mounted Western Union Morse key, twin-coil sounder, dispatch ledger, and aged telegraph pad.
7. **Routing Switchboard**: Heavy dark oak molding frame with brass corner brackets, dark olive-slate chalkboard surface, brass track rails, cast-iron switch throw lever with turned wood grip, and brass station/line plaques.
8. **Window Silhouette**: Eerie silhouette of a figure in a slouch hat and long duster coat standing in the cold moonlight outside the trackside window.

Status: `M1 VISUAL ACCEPTANCE CANDIDATE — AUTOMATED GATES PASS, HUMAN ACCEPTANCE PENDING`.

## Camera And Runtime State

| PNG | Camera position | Camera target | FOV | Runtime state | Proves |
|---|---|---|---:|---|---|
| `01_spawn_hero.png` | `(0.0, 1.65, 1.5)` | `(-1.2, 0.85, -1.0)` | 72° | Spawn | Desk, lamp, window, depth, rafters, floorboards |
| `02_full_room_overview.png` | `(-2.25, 1.65, 1.75)` | `(0.6, 0.85, -0.2)` | 78° | Spawn | Circulation, room envelope, stove, board, rug |
| `03_operator_workstation.png` | `(-1.16, 1.34, -0.6)` | `(-2.35, 0.73, -0.63)` | 68° | Spawn | Desk materials, paperwork, inkwell, organizer |
| `04_chair_clearance.png` | `(-0.58, 1.0, -0.04)` | `(-1.72, 0.43, -0.6)` | 65° | Spawn | Spindle-back chair, floor clearance, leg stretchers |
| `05_telegraph_equipment.png` | `(-1.68, 1.12, -0.94)` | `(-2.38, 0.75, -0.92)` | 55° | Spawn | Brass Morse key, binding posts, sounder base |
| `06_north_window_idle.png` | `(0.62, 1.5, -1.25)` | `(1.05, 1.55, -2.36)` | 62° | Idle window | Multi-pane sash, deep sill, brass lock, night vista |
| `07_north_window_figure.png` | `(0.62, 1.5, -1.25)` | `(0.72, 1.58, -2.62)` | 62° | Scenario 3 active | Figure silhouette (slouch hat, duster coat), cold moonlight |
| `08_south_door.png` | `(-1.6, 1.55, -0.3)` | `(-1.6, 1.05, 2.36)` | 65° | Spawn | 4-panel Victorian door, casing, escutcheon, hinges |
| `09_routing_board.png` | `(1.45, 1.42, -0.85)` | `(2.7, 1.34, -0.85)` | 60° | `AWAITING_ROUTE` | Slate surface, brass rails, throw lever, brass plaques |
| `10_stove_storage.png` | `(0.18, 1.55, -0.1)` | `(2.25, 0.9, 1.32)` | 70° | Spawn | Potbelly stove, hearth pad, chimney pipe, coal scuttle |
| `11_real_morse_document.png` | `(0.0, 1.65, 0.0)` | `(-1.75, 0.8, -0.9)` | 68° | Card open | Production Morse reference card overlay |
| `12_scenario3_debug_telemetry.png` | `(0.0, 1.65, 0.0)` | `(-1.75, 0.8, -0.9)` | 68° | Scenario 3 + F3 | Production debug inspector telemetry (WATER vs WATCHER) |
| `13_station_clock_detail.png` | `(-1.95, 2.05, 0.62)` | `(-2.84, 2.05, 0.62)` | 54° | Spawn | Station regulator clock, pendulum box, wire runs |
| `14_duty_roster_hatch.png` | `(1.2, 1.45, 0.8)` | `(1.9, 1.45, 2.28)` | 65° | Spawn | South wall duty roster board, service ticket hatch |
| `15_bookcase_records.png` | `(1.4, 1.25, 0.45)` | `(2.62, 0.95, 0.45)` | 58° | Spawn | Oak bookcase, molded cornice, station ledger folios |
| `16_storage_cabinet_detail.png` | `(-1.4, 1.25, 1.4)` | `(-2.58, 0.95, 1.4)` | 58° | Spawn | Upper pigeonhole storage cabinet, station forms |

## Brightness And SHA256 Metrics

`Mean Lum` is mean grayscale luminance [0–255]; `Below 32 %` is the percentage of pixels below luminance 32.

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

## Matched Before/Final Comparisons (Side-by-Side)

All comparison images are located in `docs/art/m1_visual_acceptance/comparison/` (2560x720):
- `01_spawn_hero_before_final.png`
- `02_full_room_overview_before_final.png`
- `03_operator_workstation_before_final.png`
- `05_telegraph_equipment_before_final.png`
- `07_north_window_figure_before_final.png`
- `08_south_door_before_final.png`
- `09_routing_board_before_final.png`
- `10_stove_storage_before_final.png`


## Launch

```powershell
& "C:\Users\YUSIF\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe" `
  --path "C:\Users\YUSIF\Documents\dead-wire" `
  --scene "res://scenes/office/m1_office.tscn"
```
