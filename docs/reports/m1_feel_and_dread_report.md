# M1 — Feel & Dread Pass

**Date:** 2026-09-01
**Trigger:** first owner playtest of the shift slice
**Status:** AUTOMATED GATES PASS — NOT YET RE-PLAYTESTED
**Nothing committed.**

---

## 1. What the playtest reported, and what was actually wrong

Three complaints. All three were real, and one of them had a root cause nobody had named.

### "I fall out when I go through the door"

`scenes/style_tests/props/door_south.tscn` contained **no collision of any kind** — no
`StaticBody3D`, no `use_collision` on a single one of its nineteen CSG boxes. The south wall has
a deliberate 1.0 m doorway gap (`SouthWall_Left` spans x −2.9…−2.1, `SouthWall_Right` −1.1…2.9),
the floor ends at z = 2.3, and the door sits at z = 2.36. The player walked through a shut door
and off the edge of the world.

### "Almost no animations, feels raw, doesn't feel real"

```
grep -r "create_tween\|AnimationPlayer\|Tween" scripts/ scenes/
→ no matches
```

**The project contained zero animation.** Every state change in the game was an instant flip.
Most damningly, `scenes/telegraph/sounder.tscn` has an `ArmatureBar` mesh and nothing anywhere
drove it: the object the entire design points at clicked audibly while standing perfectly still.

The player controller was still the deliberately minimal greybox spec from GDD §26 — velocity
snapped to full speed or zero, no bob, no sway, no settle. It was never upgraded after the
greybox evaluation it was written for. That is why the office read as a debug camera flying
around a diorama.

### "Why is there a chair if I can't sit on it?"

`psx_chair.tscn` was six CSG boxes and a collision body. No interaction, no seat logic.

Fair question, and the answer turned the chair into the pressure mechanic — see §4.

---

## 2. Research

Two searches, on first-person feel and on dread without jump scares. What actually shaped the
work:

- Head bob must be **subtle, translation-based rather than rotation-based, scaled by state, and
  toggleable**. Too much causes sickness; none at all breaks the sense of occupying a space.
  Indie horror routinely overdoes it.
- **Sitting down is specifically named as a good place for a little sway** — it hides what would
  otherwise be robotic camera movement.
- Keep visible acceleration minimal. Floaty first-person movement reads as "an ice level",
  especially with small interaction targets, which this room is full of.
- **Silence beats constant sound.** A continuous bed conditions the player and dulls fear; placed
  silence makes them distrust their own ears.
- Dread lives in negative space and pacing — the canonical example being *"a floorboard creaking
  exactly two seconds after the player stops moving."*
- **Calibrated disempowerment**: a player who can leave is not frightened.

Sources: [First-Person 3Cs: Camera](https://playtank.io/2023/05/12/first-person-3cs-camera/),
[Building Character Feel in a First Person Game](https://gamedesignframework.net/building-character-feel-in-a-first-person-game/),
[Mastering Camera Design](https://www.wayline.io/blog/mastering-camera-design-game-feel),
[Creating Dread](https://www.cgmagonline.com/articles/features/creating-dread-design-decisions-behind-horror-games/),
[The Art of Engineering Fear](https://morbidlybeautiful.com/the-art-of-engineering-fear-through-structured-game-design/),
[Psychological Horror Game Design](https://altheragames.com/en/blog/psychological-horror-game-design),
[When Buildings Dream](https://drwedge.uk/2025/05/04/when-buildings-dream-horror-game-design/)

---

## 3. The door

- The leaf, jambs and doorway now carry a `StaticBody3D` on collision layer 1. A test fires a ray
  straight through the doorway and fails if anything ever gets through again.
- The leaf was re-parented under a hinge pivot at the jamb so it can actually swing — the same
  class of fix the clock hands needed.
- New `scripts/office/office_door.gd`: locked for the whole watch. Trying it turns the knob, knocks
  the leaf against the jamb, and does not open. Prompt reads `Locked — You Are On Shift`.
- On `ShiftDirector.shift_closed` it unlocks. Opening swings the leaf over 1.2 s and clears the
  doorway collision.
- A landing was built beyond the door — floor, two side walls, back wall, ceiling — so the way out
  leads somewhere instead of into the void.
- Stepping through fires `ShiftEndCard`: fade to black, then Elias's own record of the night. The
  record is the duty sheet, which reads KnowledgeState and nothing else, so a player who missed
  traffic walks out holding an incomplete account and is never told what he actually did.
- A backstop in the controller returns the player to spawn below y = −2. Insurance, not the fix.

---

## 4. The chair — now the pressure mechanic

`scripts/player/operator_seat.gd`. **The key only works from the chair.** Standing at the desk
shows `Sit to Work the Key` and the key is dead.

That one rule is what converts the shift from a sequence of events into a wager. Every trip to
the routing board, the ledger, the duty sheet or the window now costs about a second of sitting
down again, and the wire does not care where you are. GDD §3.2 in a single interaction.

- Sitting locks walking but **not** looking — the operator can turn and look over his shoulder,
  clamped to a ±115° arc. He cannot spin on the spot.
- The camera drops to a seated eye height over 0.8 s, slightly past the seat and back up. Weight,
  not a lerp.
- **Any movement key stands him up.** No new binding, and it is what a player reaches for.
- The chair's collision is disabled while occupied so it cannot shove the player's own capsule.
- Verified against the real interaction ray: seated, all four desk objects are in reach — key
  1.37 m, transcript 1.26 m, ledger 1.54 m, reference card 1.30 m, inside the 2.2 m ray. The
  chair's own trigger does not hijack the ray.

To keep this discoverable without a HUD, the duty sheet's standing orders now open with it.

---

## 5. A body instead of a camera

All in `scripts/player/player_controller.gd`, all exported, all deliberately restrained.

| | |
|---|---|
| Acceleration | 14 m/s² in, 18 m/s² out. Tight, not floaty. |
| Head bob | 1.8 cm vertical, lateral at 45% of that, **phased on distance walked** rather than time so it stays in step with the feet when speed changes |
| Idle breathing | 5 mm at 0.21 Hz — the cheapest possible "I have a body" cue |
| Step settle | small downward translation on starting and stopping, no rotation |
| Urgency | while the wire is calling, bob ×1.35 and breathing rate ×2.1. The one place the camera editorialises |
| FOV | 75 → 80 |

Walking and looking are now lockable independently: the document viewer freezes both, the chair
freezes only the feet. A test asserts total head travel stays under 50 mm in every state,
including urgent — comfort is a gate, not a hope.

---

## 6. Things that now move

The project went from zero animations to these, all procedural, which suits CSG geometry and the
PSX language.

1. **The sounder armature** drops onto the anvil on every mark and lifts on every gap. Driven per
   frame rather than by a tween, because a message is dozens of marks a second. This is the single
   most important animation in the game and it did not exist.

2. **The transcript writes live.** `TranscriptPaper.begin_writing()` plus
   `set_writing_progress()`, paced off the Morse schedule's own elapsed time. The player now
   watches `WATCHER` appear on the pad **while `WATER` is still coming out of the sounder.**
   Previously the finished text was dumped after the message ended, which hid the one moment the
   entire design exists for.

3. **The telegraph key** throws on a spring — fast down, slower back, slight bounce. It used to
   jump to an 8 mm offset and sit there on a 150 ms timer, which read as a glitch.

4. **The window figure no longer pops.** Appearances and disappearances are held until the player
   is not looking at the window, so the figure is always something that was already there.
   Observation is refused while it has not visibly appeared, so nobody gets credit for seeing
   nothing.

5. **The routing board lever throws** when a route is set, one way for CLEAR EAST and the other
   for HOLD, with the switch marker sliding. Setting a route was previously answered by nothing
   moving at all.

6. **Documents fade and scale up** over 0.14 s instead of teleporting into view.

7. **The clock pendulum swings**, one beat per second, matching the escapement tick the ambience
   already emits.

---

## 7. Living light and placed silence

`scripts/office/lamp_life.gd` — the oil lamp flickers ±8% on two incommensurate sine rates so the
pattern never repeats, and the flame mesh scales with it. The stove breathes ±13% much more
slowly. Tests assert neither ever guts out or flares past its depth: the flicker must never
become the thing the player is watching.

`scripts/office/unease_director.gd` — two techniques straight out of the research:

- **The delayed creak.** Stop moving, and about two seconds later a floorboard settles somewhere
  else in the room. Not every time — 45% — never twice from the same spot, with a nine-second
  cooldown, and it only re-arms after the operator has actually moved again. Standing still
  forever does not turn it into a metronome. Three creak samples are synthesised with a stick-slip
  warble, because timber grips and releases rather than sliding smoothly in pitch.
- **Silence before the wire.** The ambience bus ducks 26 dB for ~2 s before the first call of each
  message and recovers over 1.6 s, so the sounder always breaks silence rather than competing with
  wind.

Neither is the Listener. GDD §10 holds: nothing here moves an object, and a settling timber
building is a complete explanation on its own.

---

## 8. A bug the new tests caught

`_setup_armature()` re-read the armature's rest position every time it was called, including from
`play_up()`. After a strike it would have treated the *dropped* position as the new rest, and the
armature would have walked down into the anvil one mark at a time over a message. Caught by the
first atmosphere test, fixed by capturing rest exactly once.

---

## 9. Verification

```
bash tools/run_all_tests.sh
  30 suites, 0 failures, 1171 assertions
```

The current regression baseline is 30 suites / 1171 assertions. The historical
counts from earlier passes are superseded and are not used for status. New:

- `tests/player/player_body_test.gd` (39) — lock separation, decay, comfort ceiling on all head
  motion, bob toggle, yaw clamp, fall recovery, the full sit/stand contract and the key gate
- `tests/office/office_door_test.gd` (32) — doorway solidity by raycast, floor beyond the door,
  locked prompt, rattle-without-opening, unlock on shift close, swing, and the end card carrying
  the operator's record without leaking message content
- `tests/office/atmosphere_test.gd` (43) — armature travel both ways, live transcript against the
  schedule, `WATCHER` appearing letter by letter, figure cannot be observed before it appears,
  flicker bounds, creak dwell/cooldown/re-arm/placement, and the hush

`tests/office/shift_director_test.gd` grew to 89 assertions covering the seating gate. No
pre-existing suite changed its result other than that intentional contract change.

Also: production scene headless boot — exit 0. 16-shot capture through the live Forward+/D3D12
pipeline — exit 0, mean luminance 47.8, no blown highlights. Seated interaction reachability
probed against the real ray.

---

## 10. Honest gaps

- **I have not played it.** Feel is a playtest question and nothing above changes that.
- **No hands or arms.** The PSX language does not need a viewmodel and the art cost is large.
- **Sound is still placeholder** apart from the new creaks. Everything sits on the `Ambience` bus
  so a sound designer can swap files without touching mix logic.
- **The chair was not moved.** It sits ~0.8 m from the desk, which is slightly far for a working
  posture. Moving it means re-asserting `m1_spatial_metrics_test.gd`; left alone until you say
  the seated pose feels wrong.
- **Seated, the "Stand Up" prompt never displays** — the interaction ray does not report a
  trigger it starts inside. Standing works via any movement key and the duty sheet says so, but
  it is a discoverability rough edge.
- **The end card is a card.** It ends the slice; it is not an ending in the GDD's sense.

---

## 11. Play it

```powershell
& "C:\Users\YUSIF\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --path "C:\Users\YUSIF\Documents\dead-wire"
```

1. Read the duty sheet by the south door. Try the door while you are there.
2. Sit at the chair. Open the line.
3. Then get up and go somewhere — the window, the board, the ledger. That is the experiment.
4. When `CR CR` starts, get back and sit down before the sender gives up.
5. Watch the pad during the third message, not the window.
6. Stand still somewhere for a few seconds and wait.

What to report:

1. Does walking feel like carrying a body?
2. Is standing up to check the window a real decision now?
3. Does the sounder look alive?
4. `WATCHER` appearing while you hear `WATER` — does it land?
5. Is the delayed creak unnerving or just noise?
6. Does the room breathe, or does the flicker become the subject?
7. Is sitting a good rule or an annoyance?
