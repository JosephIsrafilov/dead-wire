# DEAD WIRE — GAME DESIGN DOCUMENT
## Version 1.1 — Project Compass / Frozen Prototype Direction

> v1.1 (2026-09-26): added pillar §3.7 Weight, presentation direction §35, open scope
> decisions §36; §25–26 refreshed to the real M1 state; §32 FNAF wording reconciled with
> `DEAD_WIRE_HORROR_LAYER_DESIGN.md`. Core direction unchanged.

**Project:** DEAD WIRE  
**Genre:** 3D First-Person Psychological Horror  
**Engine:** Godot 4.x stable (development currently oriented around Godot 4.7)  
**Language:** GDScript  
**Platform:** PC  
**Target Duration:** 3–4 hours  
**Structure:** 6 nights + daytime investigation  
**Setting:** American West, April 1894  
**Disaster Night:** October 14, 1889  

---

# 1. HIGH CONCEPT

DEAD WIRE is a first-person psychological horror game about a professional telegraph operator, Elias Crane, who returns to the isolated railroad town of Black Creek years after a catastrophe connected to the mine, the water supply, and the railroad company controlling the region.

The player spends the day investigating the abandoned or damaged town, reading physical evidence, tracing inconsistencies, and speaking to the remaining people connected to the disaster.

At night, Elias works inside a small telegraph office.

The central horror mechanic is not combat.

It is information.

The player hears telegraph messages, watches the office, handles documents, checks routing information, and slowly realizes that Elias's own perception cannot always be trusted.

The core hook is:

> YOU HEAR ONE THING. YOUR HAND WRITES ANOTHER.

Or:

> ТЫ СЛЫШИШЬ ОДНО. ТВОЯ РУКА ПИШЕТ ДРУГОЕ.

The game is built around the moment when the player realizes that the objective Morse signal and Elias's written transcript are no longer necessarily the same thing.

---

# 2. PLAYER FANTASY

The player is not a soldier, detective superhero, monster hunter, or action protagonist.

The player is a trained worker inside a system.

Elias knows his job well.

He understands railroad procedure.

He understands telegraphy.

He understands Morse better than the player initially does.

The player fantasy is:

- being a competent telegraph operator under pressure;
- checking whether information is reliable;
- noticing procedural inconsistencies;
- learning to distrust Elias without being told to distrust him;
- deciding what evidence is real;
- understanding how one "small" job can make someone complicit in a larger disaster;
- surviving psychological pressure without a conventional combat system.

---

# 3. DESIGN PILLARS

## 3.1 Morse Integrity

The objective telegraph signal exists independently from Elias.

The architecture and game design must preserve a source-of-truth pipeline:

TRUE SIGNAL  
↓  
ELIAS PERCEPTION  
↓  
WRITTEN TRANSCRIPT  
↓  
PLAYER INTERPRETATION

These layers must never be collapsed into a single text value.

The game may distort Elias's perception or transcript.

It must not secretly rewrite objective reality.

---

## 3.2 Divided Attention

The player cannot monitor everything at once.

Inside the office, important attention zones include:

- telegraph sounder;
- transcript;
- ledger;
- routing board;
- door;
- window;
- surrounding sound.

The player should regularly need to turn away from one source of information to inspect another.

The central M1 question is:

> Is it uncomfortable to turn away from the window when the sounder begins a transmission?

If the answer is no, the core tension is not yet working.

---

## 3.3 Consequence Without Reload

Most mistakes should not produce:

GAME OVER  
RELOAD CHECKPOINT

Instead, mistakes become part of the game state.

A mistake may:

- change WorldState;
- alter KnowledgeState;
- increase suspicion;
- close a clue;
- delay information;
- create a later consequence;
- weaken an evidence chain;
- influence an ending.

The player should frequently be forced to live with imperfect decisions.

---

## 3.4 Investigative Anchors

Not everything in DEAD WIRE is unreliable.

The game must provide physical, objective anchors.

Examples:

- signed documents;
- medical ledger entries;
- routing records;
- timestamps;
- physical telegram copies;
- witness testimony with cross-checkable details;
- company records.

The player must have enough stable evidence to reason through uncertainty.

---

## 3.5 Sparse Horror

Horror events are not constant.

The game needs a believable normal baseline first.

Strange events become effective because they break a procedure the player has already learned.

The game should avoid turning every minute into:

- jumpscares;
- hallucinations;
- paranormal events;
- loud stingers;
- scripted interruptions.

The unusual must remain unusual.

---

## 3.6 Procedural Realism

Telegraph work, railroad procedure, documents, equipment, Morse timing, routing, office behavior, and communication should feel believable for 1894.

Historical realism exists to support immersion and tension.

It is not an excuse to make the game tedious.

---

## 3.7 Weight

Every action costs time, makes a sound, and leaves a trace.

The office must feel physical: paper has thickness and casts a shadow, the lamp is the only
safe light, the chair creaks when Elias sits, the pen scratches in sync with ink contact.

Weight comes from:

- darkness (one dominant light source; what is outside the lamp's circle is unknown);
- material (aged paper, ink, brass, worn wood — never clean surfaces);
- time (taking a sheet, committing a copy, standing up are short animated rituals, not instant toggles);
- sound (room tone, foley for every mechanism, real silence);
- the absence of interface (the room tells state; text overlays do not).

The test:

> Would a stranger watching a 30-second clip guess this game cost more than it did?

If the answer is no, add darkness, material, or silence — not content.

---

# 4. CORE GAMEPLAY LOOP

## Day

The player investigates Black Creek.

Possible activities:

- explore limited locations;
- inspect documents;
- compare records;
- speak with survivors or company-linked characters;
- recover evidence;
- trace contradictions;
- build knowledge about the 1889 disaster.

The daytime sections broaden context and provide investigative anchors.

---

## Night

The player works inside the telegraph office.

The night loop revolves around:

- receiving Morse transmissions;
- monitoring the sounder;
- reading Elias's automatic transcript;
- checking routing information;
- handling ledger entries;
- watching the door and window;
- responding to distractions;
- deciding which information to trust.

Night is where information becomes pressure.

---

## Overall Cycle

INVESTIGATE  
↓  
LEARN  
↓  
WORK TELEGRAPH  
↓  
RECEIVE INFORMATION  
↓  
NOTICE INCONSISTENCY  
↓  
MAKE A DECISION  
↓  
LIVE WITH CONSEQUENCES  
↓  
INVESTIGATE THE RESULT

---

# 5. CORE TELEGRAPH SYSTEM

Telegraphy is the mechanical center of the game.

The player begins with little or limited Morse knowledge.

Elias, however, is a professional.

At first, Elias's transcription is reliable.

This trains the player to trust him.

Later, the player starts encountering mismatches.

Example:

TRUE SIGNAL:
WATER

ELIAS PERCEPTION:
WATER

WRITTEN TRANSCRIPT:
WATCHER

The game does not display:

"ELIAS MADE AN ERROR."

The player must notice the mismatch.

The long-term progression is psychological:

1. Elias is trusted.
2. Small inconsistencies appear.
3. The player notices that sound and text may disagree.
4. The player starts checking Elias.
5. The player gradually learns enough American Morse to independently verify critical messages.
6. Telegraphy changes from atmosphere into investigative proof.

---

# 6. AMERICAN MORSE / RAILROAD MORSE

DEAD WIRE uses:

**American Morse / Railroad Morse**

Not International Morse.

This matters because timing itself can carry information.

The data model must not reduce every character to a simple string such as:

.-..

The intended conceptual representation is closer to:

MARK(duration)  
GAP(duration)  
MARK(duration)  
GAP(duration)  
...

using relative timing units.

Key principle:

> TIMING = DATA

Sounder timbre may change.

Room acoustics may change.

The player may be distracted.

But the actual timing of a critical fair signal must remain intact.

---

# 7. AUDIO FAIRNESS

Critical Morse must remain physically readable.

The game may distract the player.

The game may not cheat.

Do not:

- hide critical Morse under loud music;
- alter timing randomly;
- cover essential characters with a jumpscare;
- create arbitrary timing jitter;
- make a required message impossible to hear.

Horror can compete for attention.

It cannot invalidate the information source.

---

# 8. ATTENTION SYSTEM

Attention is the primary pressure mechanic.

The office layout is intentionally built so that the player cannot perfectly monitor:

- desk;
- window;
- door;
- routing board;

from a single ideal viewing angle.

The player should repeatedly make small commitments:

- turn toward the routing board;
- look down at the ledger;
- inspect the transcript;
- check the window;
- listen to the sounder;
- react to a noise near the door.

These commitments create vulnerability without requiring combat.

---

# 9. OFFICE AS A GAMEPLAY MACHINE

The office is not just scenery.

Every major object should eventually have a mechanical purpose.

## Desk

Primary work zone.

Houses telegraph-related interaction and paperwork.

## Window

Visual attention zone.

Creates discomfort when ignored.

## Door

Separate spatial threat/attention zone from the window.

## Routing Board

Requires looking or moving away from the main work position.

## Ledger

Provides procedural verification and investigative information.

## Telegraph Key / Sounder

Core communication system.

## Lamp

Environmental readability and later possible tension tool, but not supernatural interaction by the Listener.

The room must create tension through geometry before any elaborate horror event is added.

---

# 10. THE LISTENER

The Listener is an ambiguous presence.

Possible interpretations include:

- trauma;
- guilt;
- insomnia;
- neurological exposure;
- supernatural presence.

The game should not immediately confirm one explanation.

Absolute rule:

> The Listener never physically interacts with objects.

The Listener does not:

- open doors;
- move papers;
- press the telegraph key;
- touch the lamp;
- move chairs;
- create physical evidence through direct manipulation.

This protects the ambiguity.

If an object physically changes, there must be another explanation.

---

# 11. WORLDSTATE AND KNOWLEDGESTATE

The game requires two distinct state systems.

## WorldState

Stores objective reality.

Example:

eleanor_alive = true

## KnowledgeState

Stores what Elias/player currently knows.

Example:

knows_eleanor_alive = false

These must not be combined.

The story depends on the difference between:

what is true

and

what Elias believes is true.

---

# 12. FAILURE PHILOSOPHY

DEAD WIRE is not primarily about succeeding perfectly.

It is about making decisions with incomplete or corrupted information.

Failure should often generate narrative material.

Examples:

- wrong routing choice produces a consequence the next day;
- missed detail prevents a clue from becoming available;
- trusting a transcript over a signal weakens an evidence chain;
- ignoring an event changes suspicion;
- failing to verify a message changes what Elias believes.

The game should avoid teaching the player that the optimal strategy is simply to reload every imperfect decision.

---

# 13. STORY PREMISE

Black Creek is a railroad and mining town controlled by a large company.

Years before the main story, mining operations exposed a dangerous underground water source.

The company's infrastructure helped distribute contaminated water.

A neurological illness or related phenomenon spread through the town.

The exact nature of the phenomenon remains deliberately ambiguous enough to support psychological and supernatural interpretations.

The company suppressed or manipulated information connected to the disaster.

Elias Crane has a personal connection to the event.

His family became part of the evidence chain.

---

# 14. ELIAS CRANE

Elias Crane is the protagonist.

Profession:

**Telegraph Operator**

His competence is important.

The core hook only works if the player initially believes Elias is better at Morse than they are.

Elias is not presented as incompetent.

His errors therefore become disturbing.

The central psychological conflict is not:

"Can Elias do his job?"

It is:

"Can Elias trust what his own mind is doing?"

---

# 15. ELIAS'S FAMILY

## Mother — Eleanor Crane

Eleanor survived the original catastrophe.

She was removed by the company and kept in a private institution in Denver.

Internal identifier:

P01/W  
Patient 01

Her condition includes:

- lucid intervals;
- partial amnesia;
- fragmented memory.

Elias initially does not know the full truth of her status.

---

## Father

Elias's father was a physician.

He was removed to a remote company-controlled location.

He later died from natural causes while effectively under company control.

A letter written shortly before his death becomes important evidence.

An altered telegram provides evidence of information manipulation.

---

# 16. INVESTIGATION

The modern investigation is connected to:

- a state railroad commission;
- a federal land-grant auditor;
- pressure from a competing railroad.

This creates moral ambiguity.

The investigation is not driven purely by justice.

Multiple institutions have material interests.

The railroad company is responsible for serious wrongdoing, but its opponents are not necessarily altruistic.

---

# 17. EVIDENCE CHAIN

The late-game dispatch can be built from several major evidence elements.

Current key evidence set:

1. Medical Ledger
2. Altered Telegram
3. Patient 01
4. Elias's Self-Confession
5. Guard Testimony

The exact combination affects the strength, meaning, and consequences of the final action.

The game should not reduce the ending to a simple morality meter.

The quality and completeness of evidence matter.

---

# 18. ENDING PHILOSOPHY

Current broad ending directions include:

## Minimal Honest Dispatch

Enough truthful evidence to expose part of the case.

## Full Dispatch

The strongest evidence chain.

## Cowardly / Limited Dispatch

Elias sends only limited material.

## Send Nothing

Elias refuses or fails to expose the evidence.

The endings should reflect:

- truth discovered;
- truth proven;
- truth sent;
- consequences of earlier decisions.

Not just a final dialogue choice.

---

# 19. STRUCTURE

Target structure:

**6 nights + daytime investigation**

Each cycle should add a new layer of complexity.

A possible progression principle:

Night 1 — procedural trust  
Night 2 — attention pressure  
Night 3 — contradiction  
Night 4 — self-doubt  
Night 5 — active verification  
Night 6 — final evidence / decision pressure

This is a structural direction, not a mandate to over-script before M1 proves the core loop.

---

# 20. HORROR PHILOSOPHY

DEAD WIRE should generate fear through:

- uncertainty;
- divided attention;
- procedure;
- information mismatch;
- spatial vulnerability;
- sound;
- anticipation;
- guilt;
- incomplete knowledge.

It should not depend primarily on:

- monsters chasing the player;
- weapons;
- combat;
- frequent jumpscares;
- complicated enemy AI.

The central horror question is:

> What if the information you depend on is correct, but the person interpreting it is you?

---

# 21. M1 — OFFICE PROTOTYPE

The current production phase is:

**M1 — OFFICE PROTOTYPE**

The blueprint is frozen for prototype purposes.

Large lore redesign is intentionally paused.

The purpose of M1 is to prove the core loop before building the rest of the game.

---

# 22. M1 GOAL

M1 must answer five questions:

1. Is telegraph interaction fun?
2. Does divided attention create tension?
3. Is Morse fair and readable?
4. Does spatial audio support attention pressure?
5. Does the central mismatch hook work?

The most important test question:

> Is it uncomfortable to turn away from the window when the sounder begins a transmission?

If not, M1 has failed regardless of story quality.

---

# 23. M1 TARGET CONTENT

M1 eventually contains:

- 1 greybox office
- 1 FPS controller
- 1 interaction system
- 1 telegraph key
- 1 sounder
- American Morse playback
- 2–3 transmissions
- automatic Elias transcription
- 1 deliberate mismatch
- 1 Morse reference
- 1 routing board
- 1 ledger
- 1 door
- 1 window
- directional footsteps
- 1 false attention event
- 1 genuine attention event
- WorldState
- KnowledgeState
- Debug Inspector

Nothing beyond this is necessary to prove M1.

---

# 24. M1 IMPLEMENTATION ORDER

Current intended order:

01. Project + folders  
02. Greybox office  
03. Player controller  
04. Interaction system  
05. WorldState / KnowledgeState  
06. Debug Inspector  
07. TransmissionData  
08. Morse data model  
09. Morse scheduler  
10. SounderController  
11. Transcript paper  
12. Telegraph state machine  
13. Routing board  
14. Baseline transmission  
15. Attention transmission  
16. False event  
17. WATER → WATCHER  
18. Genuine event  
19. Debug telemetry  
20. External playtest  

Do not skip forward just because later systems sound more interesting.

---

# 25. CURRENT DEVELOPMENT STATUS

Status as of 2026-09-26 (history in `docs/reports/`, latest in `docs/plans/2026-09-21_SESSION_HANDOVER.md`):

- M1 implementation order §24 steps 01–19 are built: office, controller, interaction, WorldState /
  KnowledgeState, debug inspector, American Morse model + scheduler, sounder, transcript paper with
  writer rig, session state machine, routing board, ledger, WATER → WATCHER, door and window events;
- tape register (objective MARK/GAP record) is built as the third renderer of the scheduler;
- horror layer (6 nights + Sunday trial) is designed and approved, not yet implemented;
- regression: 38 suites, 0 failures;
- visual acceptance is **not** passed: see `docs/plans/2026-09-26-production-value-pass.md`;
- step 20 (external playtest) is still open.

Current office layout intent:

Desk — west wall, northern half, facing east  
Window — north wall, eastern half  
Routing Board — east wall, northern half  
Door — south wall, western half  
Cabinet — southwest  
Lamp — southeast

Current room dimensions:

Width X = 5.8 m  
Depth Z = 4.6 m  
Height Y = 2.85 m

---

# 26. CURRENT NEXT STEP

The immediate development step is:

**M1 PRODUCTION VALUE SLICE**

One moment — seated at the desk, first transmission of Night 1 — brought to release quality
(§3.7, §35) before Nights 2–6 are built. Plan: `docs/plans/2026-09-26-production-value-pass.md`.

Then: external playtest (§24 step 20) on that slice, then horror layer step 2 (night_index + directives).

Controller feel (supersedes the original greybox controller brief): ~2.35 m/s, weighted
acceleration/deceleration, restrained body bob only while walking, none while seated.
Still not added: sprint, crouch, stamina, jump, lean, inventory, camera shake.

---

# 27. PLAYER TEST ACCEPTANCE

After the FPS controller exists, manually walk inside the office for several minutes.

Check:

## Scale

The room should not feel absurdly large or cramped.

## Attention Layout

From the desk, the player should not have a perfect view of:

- window;
- door;
- routing board;

simultaneously.

## Routing Commitment

Using the routing board should require a meaningful turn or slight movement.

## Spatial Separation

Door and window must feel like separate attention zones.

If the geometry fails this test, fix the greybox before building interaction.

---

# 28. PRODUCTION GUARDRAILS

Until M1 succeeds, do not build:

- the full Black Creek town;
- final art;
- full narrative content;
- full character systems;
- final soundtrack;
- final endings;
- complex Listener logic;
- complicated AI;
- large open-world systems.

Do not attempt to save a weak core loop with narrative complexity.

If M1 is weak, change:

- room geometry;
- timing;
- interaction;
- sound;
- transmission pacing.

---

# 29. TECHNICAL ARCHITECTURE PRINCIPLES

Use small, testable systems.

Prefer:

- typed GDScript;
- data-driven transmissions;
- explicit state separation;
- reusable interaction contracts;
- deterministic Morse timing;
- debug visibility.

Avoid:

- giant managers;
- hard-coded object-specific interaction chains;
- hidden coupling;
- rewriting working systems without a reason;
- mixing objective state and player knowledge;
- storing Morse only as visual dot-dash strings.

Future interaction contract:

get_prompt()  
can_interact()  
interact()

All interactable objects should follow a shared contract.

---

# 30. DEBUG INSPECTOR

M1 should eventually include a development-only inspector.

Suggested key:

F3

It should expose:

CURRENT PHASE  
CURRENT TRANSMISSION  

TRUE SIGNAL  
ELIAS PERCEPTION  
WRITTEN TRANSCRIPT  

WORLDSTATE  
KNOWLEDGESTATE  

MORSE STATE  
ACTIVE EVENTS  
SCHEDULED CONSEQUENCES

The Debug Inspector is important because the game intentionally contains multiple layers of truth and perception.

Without debug visibility, narrative bugs will be difficult to diagnose.

---

# 31. M1 TEST TRANSMISSIONS

Possible baseline:

TRAIN 17 CLEAR EAST

Attention test:

HOLD FREIGHT UNTIL TEN

Core hook:

TRUE SIGNAL:
WATER

WRITTEN TRANSCRIPT:
WATCHER

These are prototype test messages, not final narrative content.

---

# 32. WHAT DEAD WIRE IS NOT

DEAD WIRE is not:

- a combat horror game;
- a monster-chase game;
- a FNAF clone;
- a Morse-learning simulator;
- a walking simulator with occasional jumpscares;
- a fully realistic telegraph simulator;
- a detective game where every clue is objectively presented;
- a story in which every strange event is definitively supernatural.

It borrows tension from observation games and procedural horror, but its identity comes from information integrity.

The horror layer borrows FNAF's **shift structure** (night as a shift, attention as a resource,
escalation 1→6) — not its jumpscare economy, animatronic threat, or fail-state loop.

---

# 33. PROJECT COURSE IN ONE PARAGRAPH

DEAD WIRE is a 3–4 hour first-person psychological horror game set in 1894 about telegraph operator Elias Crane investigating a railroad-town catastrophe while working night shifts in an isolated telegraph office. The player receives objective American Morse signals, but Elias's perception and written transcription gradually diverge from reality. The player must divide attention between telegraph work, documents, routing information, the door, the window, and environmental sounds, while learning enough Morse to verify Elias independently. Mistakes usually become persistent story consequences rather than game-over states. Daytime investigation provides physical evidence and objective anchors, while nighttime telegraph work creates procedural psychological horror. The entire production currently focuses on proving this loop in the M1 Office Prototype before expanding the world or story.

---

# 34. CURRENT PROJECT MANTRA

The project does not currently need to become bigger.

It needs to become testable.

The order is:

PROVE THE ROOM  
↓  
PROVE MOVEMENT  
↓  
PROVE INTERACTION  
↓  
PROVE TELEGRAPH  
↓  
PROVE ATTENTION  
↓  
PROVE THE MISMATCH  
↓  
PLAYTEST  
↓  
ONLY THEN EXPAND

The project succeeds if the player starts doubting the transcript because they trust what they heard.

That is DEAD WIRE.

---

# 35. PRESENTATION DIRECTION

The target is disciplined PSX, not nostalgic PSX filter. References for *feel*, not copying:
Mouthwashing (one location, material honesty), Iron Lung (reality only through an instrument),
Signalis / Crow Country (strict palette, typography as identity), Papers, Please (documents carry drama).

## 35.1 Image

- Fixed low internal resolution with integer upscale; one pixel size on every screen, UI included.
- One dominant warm light (the desk lamp), one cold light (the moon). Ambient near zero.
  The door, the corners, and the routing board live in darkness until approached.
- Consistent texel density across all assets; all third-party textures remapped to one palette.
  Mixed-style asset packs are the fastest way to look like an asset flip.
- Grain and vignette: subtle and constant. No CRT frame, VHS noise, or chromatic aberration.
- Vertex snap / affine warp only if playtested; never on paper or text.

## 35.2 Paper and Type

Reading is the core verb; paper is the most important material in the game.

- Three typefaces maximum: period letterpress (printed forms, card, board, citations),
  Elias's hand (transcript, ledger — ideally an authored glyph atlas with per-letter variants),
  and the printed face again for menus. No modern sans anywhere.
- Paper has thickness, stains, folds, contact shadow; it is never brighter than the lamp that lights it.
- Documents are lifted toward the camera, not opened as full-screen panels.

## 35.3 The Hand

The hand is the protagonist of the hook. It is modelled and skinned, textured with ink stains
that accumulate across nights, holds the pen at rest, and moves by rotating joints — never by
detached parts sliding. Tremor is authored per night (horror layer §8), zero on Night 1.

## 35.4 Interface

The room shows state; overlays do not.

- No status strings ("Line Busy", "Still Copying"). The sounder, tape, and pen carry that information.
- Interaction hint: a small dot and, on focus, one printed word. Key hints only during the first
  minutes of Night 1.
- Choices are physical (lever, stamp, spike), each with a sound and a short animation.

## 35.5 Sound

Sound is the cheapest source of production value and a gameplay channel (§7).

- Room tone: wire hum, wind, clock, stove. Foley for every mechanism, including pen scratch
  synchronized to ink contact.
- Real silence is allowed and used. Night 1 establishes the full normal soundscape so later nights
  can take pieces away.
- Audio never hints at Elias's errors: the pen sounds the same whether it is right or wrong.

## 35.6 Rituals and Transitions

Starting a shift (light the lamp, wind the clock, sign the ledger), sitting down, committing a copy,
and dawn are short physical rituals. Title, shift start, and shift end are framed as moments in the
world, not UI cards over a paused scene.

---

# 36. OPEN SCOPE DECISIONS

Recorded for the owner; not yet decided.

1. **Daytime investigation — DECIDED 2026-09-26: small, intimate town.** Not an open world:
   one street, depot, 4–6 enterable interiors max (general store, boarding house, company office,
   doctor's house, water tower / mine gate as exteriors). Every location is built to the §35 bar;
   fewer places at release quality over many at prototype quality. Still after M1 (§28).
2. **Sending mechanic.** The Sunday trial (horror layer §7) and Night 3+ repeat requests need the
   player to transmit with the key. This is a new core verb and must be prototyped and playtested
   before trial content is written.
3. **Elias's voice.** The GDD gives Elias no inner voice. Options: none (pure documents), margin notes
   in his own hand, or rare spoken lines. Margin notes fit §35.2 and the unreliable-hand hook.
