# M1 — Framing, Options, and Consequence

**Date:** 2026-09-01
**Status:** AUTOMATED GATES PASS — NOT YET RE-PLAYTESTED
**Nothing committed.**

Follows the feel-and-dread pass. That one made the room feel like a place; this one
makes it feel like a product: a beginning, a pause menu, controls the player owns,
and a night that answers for itself.

---

## 1. The game now has a beginning

It used to open on an unexplained man standing in a dark room. Nothing about the
premise the whole design rests on — 1894, a railroad telegraph office, an operator
whose competence is the thing that will betray him — was anywhere on screen.

`scripts/ui/intro_card.gd` opens on black with the order that put him there:

```
BLACK CREEK, COLORADO
APRIL 1894

WESTERN UNION — ORDER 41

E. CRANE TO RELIEVE NIGHT OPERATOR AT BLACK CREEK.
LINE HAS RUN QUIET SINCE THE MINE CLOSED IN 89.
KEEP THE WIRE. COPY WHAT COMES.
```

Written as the order rather than as narration, held for six seconds, skippable on
any key after the first beat, then fading into the office over 2.2 s. Movement and
look are locked until it clears — he is not in the room yet.

**This immediately broke the evidence harness** and would have shipped every
canonical capture as a black rectangle. `capture_12_evidence_shots.gd` now skips the
intro before posing the camera.

---

## 2. Escape holds the line

Escape previously did one thing: drop the mouse cursor. The shift kept running
behind an uncaptured pointer with no way back except clicking somewhere.

`scripts/ui/pause_menu.gd` owns the key now. It stops the tree, shows **LINE HELD**,
and offers the options that have to be the player's rather than the designer's:

| | |
|---|---|
| Mouse sensitivity | slider |
| Head movement while walking | toggle |
| Master volume | slider |
| Room ambience | slider |

Head bob is the important one. The research is consistent that some players need it
for a room to read as a space at all, and others get motion sick from the same
amount — shipping it as an exported constant was not good enough.

Settings persist to `user://settings.cfg` via `scripts/ui/game_settings.gd` and are
applied on load, so a player's choices survive a rebuild.

**A document in hand takes Escape first.** Put the paper down before you stop the
shift. A test asserts that ordering.

---

## 3. The chair, finished

Three rough edges from the previous pass, all closed:

- **Pulled up to the desk.** It sat 0.45 m back; it now sits 0.18 m off the desk
  edge, a working distance. The player capsule still clears the desk collision by
  4 cm.
- **A seated man looks at his desk.** Sitting now pitches the head down 17° over the
  same transition. The seated view was previously a wall with the work somewhere
  below the bottom of the screen. It is posture, not a camera lock — look back up
  whenever you want.
- **Standing up is discoverable.** The interaction ray does not report a trigger it
  starts inside, so a seated operator was never told how to get up. The interaction
  controller gained a persistent fallback prompt, and the seat sets it to
  `[W A S D] Rise from the chair`.

Moving the chair had a consequence the spatial suite caught: the chair's own trigger
began swallowing the interaction ray aimed across it at the transcript pad. The
trigger now sits low enough to clear that sight line while still being an easy
target aimed at the seat.

FOV also went 75 → 80. Narrow enough to stay claustrophobic, wide enough that the
key is not at the edge of the frame while seated.

---

## 4. The night answers for itself

The previous pass recorded consequences that nothing ever read. Now the wire pays
them.

`ShiftDirector` tracks missed messages, lapsed routes and **misdirected** routes
(new — it listens to `routing_resolved`). At the end of the watch:

- a clean night is signed off `GN` — good night
- a night with a hole in it gets `OS 17` — *report train 17*

Both are real American Morse from the 18 characters M1 supports, sent through the
same encoder and sounder as everything else. The last thing you hear is the division
asking where the train is, which is pointed if you never copied it.

This is the state split working. **The wire speaks for WorldState** — the outside
world knows what actually happened. **The duty sheet speaks for KnowledgeState** — it
now closes with *"Not every item on this sheet is closed"* when Elias's own paperwork
has a gap, and still never reports what that gap cost. A test asserts the sheet never
prints `WATER`, `WATCHER`, or the word "missed".

---

## 5. Verification

```
bash tools/run_all_tests.sh
  30 suites, 0 failures, 1171 assertions
```

Up from 29 / 1129. New `tests/ui/framing_test.gd` (42 assertions): settings round-trip
through disk and reach the controller and the audio buses; the intro locks and
releases; the pause menu stops and restarts the tree, and yields Escape to an open
document; both closing signals encode; the duty sheet reports its own open items
without leaking the truth.

Production scene headless boot — exit 0. 16-shot canonical capture through the live
Forward+/D3D12 pipeline — exit 0, mean luminance 49.0, no blown highlights.

Four UI frames captured to `docs/art/m1_visual_acceptance/ui_probe/` and inspected:
the intro card, the seated working view, the pause menu, and the duty sheet. All four
read correctly.

---

## 6. Still open

- **Not playtested.** Everything above is verified, not felt.
- **One shift.** No day phase, no second night, no evidence chain. The missed-telegram
  consequence is now paid by the closing signal, but it still has no *tomorrow* to
  land in.
- **Sound is placeholder** apart from the synthesised creaks and beds.
- **No main menu.** The game boots straight into the intro card. Fine for a slice;
  a title screen is its own job.
- **The end card is a card**, not an ending in the GDD's sense.

---

## 7. Play it

```powershell
& "C:\Users\YUSIF\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --path "C:\Users\YUSIF\Documents\dead-wire"
```

Press Escape early and set the head movement and sensitivity to taste before you
judge the feel — that is what the menu is for.

Then: read the duty sheet, try the door, sit, open the line, and get up and walk away
from the desk. Deliberately ignore one call. Listen to what the wire says at 6 a.m.
