# M1 — Playable Night Shift

**Date:** 2026-09-01
**Goal:** finish a *part* of DEAD WIRE that is actually playable and shaped like the GDD — brisk, and psychologically pressuring. Final audio is a later job for a sound designer.
**Status:** AUTOMATED GATES PASS — NOT PLAYTESTED BY A HUMAN
**Nothing committed.**

---

## 1. The defect this pass exists to fix

M1 had every system the GDD asks for and could not ask the GDD's own central question.

The flow was:

> the operator walks to the desk → presses the key → **his own telegram starts**

Nothing arrives unless the player summons it, and the player summons it while standing at the desk with a hand on the key. There is no moment where attention is somewhere else when the wire speaks. So this:

> *"Is it uncomfortable to turn away from the window when the sounder begins a transmission?"*
> — GDD §3.2, named as the single most important M1 question

was **unanswerable by construction**. Not badly tuned. Structurally impossible.

Everything below follows from inverting that.

---

## 2. The wire calls first — `ShiftDirector`

New: [`scripts/office/shift_director.gd`](../../scripts/office/shift_director.gd), wired into `m1_office.tscn`.

A night now runs on the wire's clock:

```
PRE_SHIFT → WAITING → CALLING → RECEIVING → AWAITING_ROUTE → … → CLOSING → SHIFT_OVER
```

- **PRE_SHIFT** — the one deliberate act the player makes. `Open the Line (Begin Shift)`. Nothing happens before it and time alone never triggers it.
- **WAITING** — the line is quiet for 14 s, then 9 s, then 7 s. The first gap is long on purpose: the player needs unpressured time to learn the room before the room starts pressing back. The key is dead here — **the operator can no longer start his own traffic.**
- **CALLING** — Black Creek's office call rattles out of the sounder on its own. The player may be at the routing board, at the ledger, at the duty sheet by the door, or looking out of the window. Answering means getting back to the key.
- **RECEIVING / AWAITING_ROUTE** — the existing session, unchanged, now under a deadline.
- **CLOSING / SHIFT_OVER** — the sender signs off `GN` and the line goes dead. The night does not loop.

### The call is real Morse

The call sign `CR CR` is encoded through **the same** `AmericanMorseEncoder` and `MorseScheduleCompiler` the real traffic uses, and played through the same scheduler and sounder. It is not a sound effect. It is physically the same American Morse as a message, restricted to the 18 characters M1 supports.

The same is true of the sender's prods during the routing deadline, and of the `GN` sign-off.

### Fairness is a test, not a promise

GDD §7 forbids making a required message unhearable. The answering window is:

```
3 calls × call duration + 2 gaps + grace = 21.8 s
two crossings of the room diagonal at 3.0 m/s = 4.9 s
```

`shift_director_test.gd` asserts the window exceeds two full room crossings and fails the build if a timing change ever breaks that. The game competes for attention; it never hides the message behind reflexes.

---

## 3. Ignoring the wire costs something

Three unanswered calls and the sender gives up.

| Store | What it records |
|---|---|
| WorldState | `telegram_missed_baseline_train_17` — objectively, the message was never delivered |
| KnowledgeState | `missed_call_baseline_train_17` — Elias knows he missed a call |
| KnowledgeState | *nothing about the content* — he has no idea what it said |

The shift then **moves on**. No game over, no reload, no retry. That is GDD §3.3 working: the mistake became state, and the state will be there later.

Same shape on the routing deadline. Let 45 s run out and the director files `NO ORDER`, which lands as an incorrect decision and writes the scenario's consequence fact. Elias learns `lapsed_<id>`, not `filed_<id>` — he knows he let it go, which is not the same as knowing he handled it.

---

## 4. The player now knows what the job is — the duty sheet

New: [`scripts/telegraph/ui/duty_sheet.gd`](../../scripts/telegraph/ui/duty_sheet.gd), attached to the duty roster already hanging by the south door.

There is **no HUD, no quest log, no marker, no objective text on screen.** To learn what the shift expects, you walk to the south wall and read a piece of paper — which is itself an attention commitment, away from the desk, away from the window.

It carries the standing orders (answer the call, copy what you hear, set the route before the sender releases the line, rules are in the ledger) and the night's traffic with live status:

```
  1. TRAIN 17 — PASSENGER ......... COPIED / FILED
  2. NIGHT FREIGHT — UNVERIFIED ... NO ORDER SENT
```

Two things make this the right object rather than a menu:

**It is written from KnowledgeState alone.** WorldState is never consulted. A message Elias never copied leaves `NO COPY` on the sheet even though the world recorded a consequence for it. The sheet ends:

> *This sheet records what you know.*
> *It does not record what happened.*

**The third message is not on it.** The station booked two items tonight. `WATER` / `WATCHER` is unscheduled traffic — it appears on the paper only after Elias has copied it, as `UNSCHEDULED TRAFFIC`, and never with its content. A message that was not supposed to exist arrives anyway.

A test asserts the sheet never prints `WATER` or `WATCHER`.

---

## 5. The night visibly passes — station clock

New: [`scripts/office/station_clock.gd`](../../scripts/office/station_clock.gd).

The regulator clock on the west wall was decorative and, on inspection, **broken**: its hands were boxes offset from the dial with their own centres as pivots, and the minute hand's long axis ran through the wall rather than across the face. It could never have been rotated into a reading.

Rebuilt on real pivots at the dial centre, plus hour marks at 12/3/6/9 and a plain dial material — the face had been using the writing-paper texture and read as a framed sheet of handwriting.

The hands hold at 11:00 P.M. until the line opens, sweep the compressed watch, and land on 6:00 A.M. as the line closes — however long the operator actually took. Reading the time means turning away from the desk, same as everything else in this room.

---

## 6. Debug telemetry

`F3` now reports the shift layer, read-only as required:

```
SHIFT AWAITING_ROUTE (31.2s left)  |  slot 1  |  station 2:14 A.M.
  calls 5  missed 1  lapsed 0
```

---

## 7. What was deliberately *not* broken

The old manual flow is still a supported API. `TelegraphSessionController` gained one export, `allow_key_start`; the director clears it to take ownership of the key, and nothing else about the session, the encoder, the compiler, the scheduler, or the sounder changed.

That means:

- **Morse determinism** — untouched. TRUE SIGNAL is compiled the same way from the same data. No jitter was introduced anywhere.
- **WorldState / KnowledgeState separation** — strengthened, not weakened. The new facts land on opposite sides of the line on purpose.
- **The Listener rule** — no object in the office is moved by anything unexplained. The wire is a sender in another town.
- **The 58-assertion integration suite** — kept, with one added line standing the director down so it still covers the manual API end to end.

---

## 8. Verification

```
bash tools/run_all_tests.sh
  30 suites, 0 failures, 1171 assertions
```

The current regression baseline is 30 suites / 1171 assertions. The historical
counts from earlier passes are superseded and are not used for status. This pass
added `tests/office/shift_director_test.gd`, which drives a complete shift twice with a hand-cranked clock:

The Windows runner is now available as `tools/run_all_tests.ps1`; both runners
accept `GODOT_BIN`. In this restricted desktop session, Godot can boot and run
an individual suite, but the full editor-backed loop does not complete reliably
because the engine cannot create its `user://` editor data directory. The
resulting ObjectDB/RID warnings are recorded technical debt, not attributed to
the M1 scene without a clean-machine reproduction.

- both the ignored path and the answered path
- the miss lands in WorldState, the ignorance lands in KnowledgeState
- the routing deadline expires and the world acts on it
- the sender prods on the wire, not through an on-screen timer
- the night reaches `SHIFT_OVER` and does not loop
- the duty sheet reads from knowledge only and leaks no message content
- the clock winds, and stops

Also run: production scene headless boot — exit 0. 16-shot capture through the live Forward+/D3D12 pipeline — exit 0, all frames unique. Duty sheet reachability probed against the real interaction ray: it answers from 1.0 m to 2.1 m, inside the 2.2 m ray.

---

## 9. Honest gaps

- **I have not played this.** Every timing below is a considered guess, not a tuned value. They are all exported and meant to be moved by feel:

  | Knob | Current |
  |---|---|
  | quiet before each call | 14 s / 9 s / 7 s |
  | calls before the sender gives up | 3 |
  | grace after the last call | 4 s |
  | routing deadline | 45 s |
  | sender prods every | 15 s |
  | compressed watch | 300 s |

- **Audio is placeholder by design.** Synthesised beds and the existing sounder clicks. Levels sit on the `Ambience` bus under the sounder so a sound designer can replace the files without touching the mix logic.
- **One shift, three messages.** This is a slice, not the game. No day phase, no second night, no evidence chain, no endings.
- **The miss path has no follow-up yet.** A missed telegram writes a WorldState fact that nothing later reads, because there is no "later" yet. The consequence is recorded, not paid. That is M2 work.
- **The clock reads the compressed watch, not the scenario fiction.** If the shift is meant to be a specific number of in-world hours per message, that mapping is not modelled.

---

## 10. How to play it

```
Godot_v4.7.1-stable_win64_console.exe --path C:\Users\YUSIF\Documents\dead-wire
```

1. Look around. Find the duty sheet by the south door and read it.
2. Go to the key. Open the line.
3. Then **stop standing at the desk.** Go look out of the window, or read the ledger, or study the routing board. That is the whole experiment.
4. When the sounder starts rattling `CR CR`, get back and answer.
5. Copy, check the ledger, set the route before the sender loses patience.
6. Try deliberately ignoring one call. Then read the duty sheet again.

What to report back:

1. Is it uncomfortable to turn away when the wire calls?
2. Is 14 / 9 / 7 seconds of quiet dead time, or dread?
3. Is 45 seconds for a route generous, tight, or wrong?
4. Does answering the call feel like work, or like a QTE?
5. When you ignore a call on purpose, does the cost land?
6. Does the shift end, or just stop?
