# M1 Office Redesign Audit

## Current State (Phase 0)
Based on an audit of `scenes/office/m1_office.tscn`.

### Architecture & Scale
- **Room Dimensions**: Approximately 5.8m (X/Width) by 4.6m (Z/Depth). Ceiling height is 2.9m.
- **Walls**: Standard 4 walls using `style_tests` plaster materials.
- **Features**: 
  - One north-facing window at `x=1.1, z=-2.36`.
  - One south-facing door at `x=-1.6, z=2.36`.
- **Trim**: Standard baseboards and chair rails applied to all walls.

### Furniture & Prop Layout
- **Player Start**: Center of the room `(0, 0, 0)`.
- **Desk Area**: Positioned on the West Wall `(x=-2.15, z=-0.8)`. Contains the Telegraph Station, Transcript Paper, Morse Reference Card, and Dispatch Ledger.
- **Routing Board**: Positioned on the East Wall `(x=2.86, z=-0.9)`.
- **Storage**: Cabinet in the SW corner, Bookcase on the East wall.
- **Heating**: Corner Stove in the SE corner.
- **Events**: Window Observation and Door Attention properly positioned outside their respective portals.

### Identified Issues for Redesign
1. **Placeholder Assets**: Everything relies on `scenes/style_tests/` and generic CSG geometry. This lacks the historical authenticity of an 1894 railroad depot.
2. **Layout & Flow**: The player has to constantly run between the West wall (Desk) and East wall (Routing Board). While this creates a mechanical gameplay loop, the space lacks the functional realism of a real telegraph office where equipment was often clustered around a central operating table or bay window.
3. **Lighting**: Flat, generic omni lights. Needs realistic source lighting (oil lamps, moonlight from window, stove glow).
4. **Historical Inaccuracies**: Typical depot offices featured bay windows (for line-of-sight down tracks), a ticket window/counter, waiting area separation, and specific standardized Western Union equipment setups.

## Redesign Goals
- Rebuild architecture with proper period-accurate materials (beadboard, heavy timber, specific wallpaper or distressed plaster).
- Re-layout the room to reflect an 1894 American railroad telegraph office.
- Replace CSG primitives and placeholder props with final historical assets (CC0/PD).
- Maintain existing event transforms (Door/Window) to preserve the proven timing and LoS tests, or carefully migrate them.
