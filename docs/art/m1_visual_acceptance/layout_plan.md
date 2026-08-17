# M1 Visual Acceptance Layout Plan

## Current Layout

```text
NORTH
  [north window]                         [routing board]
  desk + lamp + telegraph       open floor                 E
  chair
  cabinet                                  stove + bookcase
  [south door]
SOUTH
```

The existing circulation is mechanically valid, but the desk, window, stove,
and board do not yet form a readable hierarchy. The lamp dominates the whole
room with a uniform warm wash; the north aperture does not carry enough cold
light. The cabinet and stove side has no visual destination. The route board
reads as a lit interface rather than a working railway object.

## Target Layout

```text
NORTH
  [cold window / exterior]                [physical route board]
  desk, key, sounder, papers     crossing path             E
  chair / worn working patch
  message tray + cabinet                  stove, coal, tools
  [door / boot-worn threshold]     coat hook + duty notice
SOUTH
```

## Sightlines And Player Path

| View or path | Intent | Constraint retained |
|---|---|---|
| Spawn -> desk | Lamp, key, papers, north-window direction and room depth are visible together | Spawn remains clear at `(0, 0, 0)` |
| Desk -> north window | Player leaves the work light for cold exterior uncertainty | Window stays a physical aperture |
| Desk -> south door | Door remains a separate attention commitment | Door event remains south of the room |
| Desk -> Routing Board | Board requires a turn and short crossing | Board stays on east wall |
| Routing Board -> desk | Operator can reorient to the working zone | Existing 0.70 m crossing stays clear |
| Door -> window | Opposed threat zones read across the room | No furniture moved into central path |
| Stove/storage | Human survival zone is visible without acting as a second desk | Stove, cabinet, and bookcase do not overlap |
| Chair clearance | Chair is visibly pulled from the desk and upright | It remains separate from DeskSetup and interaction rays |

## Light Zones

| Zone | Source | Purpose |
|---|---|---|
| Desk | Local warm oil lamp | Work, telegraph details, document readability |
| Window | Cool north-facing exterior source | Directional night contrast and silhouette readability |
| Stove | Very low ember | Heat cue, not room fill |
| Board | Spill from desk/window only | Physical object, not glowing UI |
| Shadows | Low neutral-cool ambient | Preserve silhouettes without orange-black collapse |

## Event Boundaries

- `WindowObservationEvent` remains outside the north aperture at the existing
  event position. It is only made readable through a replacement low-poly
  human silhouette; timing, line-of-sight and KnowledgeState behavior stay
  unchanged.
- `DoorAttentionSource` remains outside the south door.
- All interactive NodePaths remain unchanged. Decorative props use collision
  only where they are furniture-sized and never cover interaction Areas.
