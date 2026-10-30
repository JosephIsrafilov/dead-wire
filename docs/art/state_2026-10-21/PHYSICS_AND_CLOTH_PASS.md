# Physics and cloth — pass report

Date: 2026-10-21, Asia/Baku. Owner request:

> «а что если физику добавить? игра совсем без физики и тд изучи посчитай и сделай»
> «про физику так же имею ввиду пальто чтоб красиво висело»

Both parts are done: the room now has rigid bodies that respond to the operator's
body, and the coat is a live cloth simulation rather than a sculpted shell.

---

## 1. What "no physics" actually meant

Measured before touching anything:

| fact | value | source |
|---|---|---|
| physics engine | **Jolt** | `project.godot` §physics |
| `RigidBody3D` in the whole project | **0** | scene grep |
| `CharacterBody3D` | 1 (the player) | `player.tscn` |
| `StaticBody3D` / `Area3D` | 20+ | scene grep |
| player capsule | r 0.35, h 1.80 | `player.tscn` |
| player walk | 1.35 m/s, accel 4.5, decel 8.0 | `player_controller.gd` |

So the engine and the player's own gravity were already there. What was missing
is that **nothing in the world could be moved**. Elias collided with the room and
the room never answered. In Godot 4 a `CharacterBody3D` does not push a
`RigidBody3D` on its own — `move_and_slide` reports the contact and stops — so
this had to be written, not enabled.

## 2. The shove, calculated

The model is `scripts/physics/push_impulse.gd`, and the arithmetic is the whole
design:

```
J_total = clamp(m · v · 0.6,  0,  1.5 N·s)
J_frame = J_total · min(delta / 0.15, 1)
```

Four decisions, each with a reason:

**J is proportional to mass, not constant.** A constant J launches light objects:
10 N·s on a 0.12 kg mug is 83 m/s. Making J = m·v·k cancels to a target speed of
v·k regardless of mass, which is what actually happens when a person wades
through loose objects — everything gets moved at roughly his own pace, while the
energy each takes differs.

**Capped at 1.5 N·s.** Above m = 1.5 / (1.35 · 0.6) = **1.85 kg** the mass term
stops binding, so heavier things resist. Numbers at the game's own walk speed:

| object | mass | impulse | resulting speed |
|---|---|---|---|
| enamel cup | 0.12 kg | 0.097 N·s | **0.810 m/s** |
| ink bottle | 0.20 kg | 0.162 N·s | **0.810 m/s** |
| coal scuttle | 3.0 kg | 1.5 N·s (capped) | **0.500 m/s** |
| a chair | ~6 kg | 1.5 N·s (capped) | **0.250 m/s** |

**Spread over a contact window.** `move_and_slide` reports the same collider every
frame, so a per-frame J would multiply by ~9 at 60 Hz. The caller divides by a
0.15 s contact, which integrates to exactly one shove over nine frames — asserted
in the test (`0.1620` integrated vs `0.1620` expected).

**A downward bias of 0.15.** The contact point is usually above the object's
centre of mass, so a purely horizontal push slides a mug instead of tipping it.

## 3. Loose props

`scripts/physics/loose_prop.gd` — a `RigidBody3D` with two rules that make it safe
in a room built almost entirely from static geometry:

1. **It rests until touched.** The authored pose is captured on load and the body
   is put to sleep; without it Jolt settles it by a few millimetres and a cup
   visibly twitches on spawn.
2. **It can be put back.** `reset_to_rest()` restores the authored transform, so a
   cup kicked under the table is not lost for the rest of the watch.

Two instances, `scenes/office/loose_props.tscn`: an enamel cup (120 g, lying on
its side) and an ink bottle (200 g, upright) on open floor between the desk and
the routing board — on the lane the operator crosses to set a route, and
deliberately **not** on the filing table, where an extra body would steal the
interaction ray from the commit plates.

Both had to be authored at equilibrium. The cup was first placed at a 10° lean,
which is not a resting pose: Jolt tipped it flat on the first physics step and it
jumped on load. It is now rotated 90° about Z with its centre one radius above
the floor.

## 4. The coat is cloth

This is the part the request was really about ("*чтоб красиво висело*").

### Why it could not stay authored geometry

The coat was baked into `wall_props_static.glb`. It could be the right shape and
nothing else: it could not sway when Elias walked past, could not settle, and
could not hang differently from the pose it was modelled in. A sculpture of a
coat on a hook is exactly what it was.

It is now `scripts/office/hanging_coat.gd`: a **Verlet particle grid**, 8 rings
down × 12 columns around = 96 particles, with the collar row pinned to the hook.
The authored profile table moved into the script, so the simulation keeps the
shoulders, waist and flare the room already had — it is only allowed to *hang*
the garment, not redesign it.

Constraints, in order of how much they define the silhouette:

| constraint | pairs | why |
|---|---|---|
| vertical (structural) | 84 | carries the weight, stops it stretching into a rag |
| ring (structural) | 96 | holds the circumference |
| **ring bend** | 96 | **holds the section — the constraint without which it collapses** |
| shear (both diagonals) | 168 | stops the grid folding along its own axes |
| bend (skip two rings) | 72 | softer; creases where cloth creases |

### The collapse, and how it was found

The first version had no ring-bend constraint and the coat flattened into a
ribbon. `tools/coat_probe.gd` made that a measurement instead of an opinion:

| | authored | first version, +60 frames | after ring bend |
|---|---|---|---|
| hem width | 0.397 m | **0.207 m** | **0.400 m** |
| hem depth | 0.178 m | 0.219 m | 0.178 m |

The ring kept roughly its *perimeter* while its *width halved* — it was folding at
every vertex, which a chain of adjacent-column links freely permits. Linking
columns two apart pins the curvature: an ellipse and a folded line have very
different two-apart chords even at equal perimeter. The same probe now shows the
coat holding 0.399 m through 300 steps and coming to rest.

### Sleeves

Not part of the grid: a sleeve is a tube on its own axis, and stitching one into
the body needs a topology the simulation does not have. They are tapered tubes
parented to the widest particles of the shoulder ring, so they swing with the coat
instead of being pinned to the wall.

### A real UV bug, found by measuring

The coat painted itself olive-brown. `tools/atlas_probe.gd` printed the atlas
colour at each candidate UV and settled it: the props atlas is addressed in
**Blender** space in the generator, where V runs bottom-up, and Godot's textures
run top-down. The generator's `(2,3)` cell reads `rgb 104 80 40` using its own V
and `rgb 64 56 48` with V flipped — and `64 56 48` is precisely the wool colour
the atlas palette declares. The coat had been sampling a neighbouring tile.

The same probe caught a second defect: the sleeves sampled **one texel** for their
whole surface, so they came out whatever colour that texel happened to be —
bright orange against a dark coat.

### Sway

`disturb(origin, velocity)` weights the push by distance and by row, so the coat
swings from the shoulder rather than sliding as a slab. A body passing at the
game's walk speed moves the hem **5.5 cm** (asserted), and it settles again in
about 7 s. A body that is standing still does nothing — leaning next to a coat is
not wind.

## 5. The physics is audible

Silent physics reads as a bug: a cup skitters across the floor and the room says
nothing, so the eye and the ear disagree and the object stops feeling real. Three
samples were added to `tools/generate_action_foley.py`, which is deterministic
and project-owned, so there is no licensing question and no downloaded asset:

| sample | what it is | how it is synthesised |
|---|---|---|
| `cup_clink` | enamel on bare boards | high ringing partial (1650/2480 Hz) over two wooden knocks |
| `bottle_knock` | squat glass, duller and heavier | low partials (420/880) and a double rock |
| `cloth_rustle` | heavy hung wool | band-passed noise 180–1900 Hz, envelope beaten at 3.1 Hz |

Measured levels: peak 0.18 / 0.20 / 0.31, RMS 0.030 / 0.034 / 0.049 — quiet by
design, in line with the existing foley, and well under the sounder so they can
never mask Morse (GDD §7).

Placement, all positional:

- **Prop impacts** are emitted by `LooseProp.impacted(strength)`, where `strength`
  is the **speed the collision removed**, not an absolute velocity. Reading
  absolute velocity would tick on the initial settle, because a body resting on
  the floor also reports contacts. Below 0.35 m/s it is sliding, not an impact.
  Volume scales with strength (`-22 dB` … `-11 dB`).
- **Cloth rustles** are emitted by `HangingCoat.rustled(strength)`, throttled to
  one per 0.45 s so one shove through the cloth is one sound rather than one per
  frame.

**A position bug caught by probing.** The coat node's transform is identity and
its particles are in world coordinates, so `coat.global_position` is the world
origin. The rustle source was parented there and would have played from the
**middle of the floor**. `get_hang_position()` now returns the centroid of the
middle ring, and the source is re-placed as the coat swings. Verified with
`tools/physics_audio_probe.gd`:

```
ClothRustle   stream=cloth_rustle.wav   -23.0 dB   at (-0.35, 1.7, 2.2)
```

## 6. The door moves the coat

`OfficeDoor.door_opened` disturbs the coat from the door's position, so opening
the south door pulls at the cloth on the hall rack 1.25 m away.

This is deliberately the **only** autonomous-ish motion in the system, and it is
not autonomous: it fires because a real object moved, with a visible cause. The
coat never moves by itself — GDD §10 holds, the Listener never touches objects,
and nothing here pretends to be it. A zero-strength draft is asserted to be a
no-op.

## 7. A new watch repairs the room

`reset_to_rest()` existed from the first pass but nothing called it, which meant
a cup kicked under the filing table would be gone for the rest of the game.
`M1OfficeController.load_scenario_by_index(0)` — the path a fresh watch already
uses to wipe the routing board and the dawn evidence — now resets every loose
prop too.

## 8. Verification

- `tests/physics/cloth_and_props_test.gd` — **34 assertions**, all pass:
  the shove arithmetic, the impulse ceiling, contact integration, props resting
  and restoring, **a real capsule walking into a prop (8.3 cm of travel)**, the
  coat keeping its authored silhouette, the pinned collar, the sway, the
  re-settle, the still body, **the rustle and its throttle**, **the draft and its
  zero-strength no-op**, and the hang position.
- `tools/physics_audio_probe.gd` — 3 physics sources bound, both props listening.
- Full regression: **108 suites / 3254+ assertions**.
- `scripts/` — `gdlint`: **0 problems**.
- Production boot: clean.

Known non-regressions, all reproduced with all assertions passing and only a
nonzero shutdown exit:

- `tests/telegraph/amendment_contract_test.gd` — fails from an uncommitted
  pre-existing edit in `scripts/telegraph/session/telegraph_session_controller.gd`.
- `tests/office/wire_guard_test.gd` — 7/8 runs clean, every assertion passes.
- `tests/telegraph/duty_sheet_test.gd`, `tests/office/missed_call_test.gd`,
  `tests/guidance/wind_guidance_test.gd` — the same teardown family, measured at
  7/3 on the untouched baseline before this pass.

## 9. What this pass deliberately did not do

- **No physics authority.** No rigid body can reach the session, the tape, the
  register, the shift or the door. Props are props.
- **The door is still animated, not hinged.** Giving it a real hinge would break
  the door-attention timing that the horror layer depends on.
- **The chair is still static.** It is the seat anchor; making it rigid would move
  the seat out from under the sit transition.
- **No ragdolls, no destruction, no soft bodies beyond the one garment.**
- The coat is the only simulated cloth. Papers, the tape and the curtains (there
  are none) stay as they are.
