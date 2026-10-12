# DEAD WIRE — mechanics pass: evidence and choice

## Confirmed understanding

Owner explicitly approved the evidence/choice patch after internet research. Preserve the current
1894/PSX one-office M1, its three telegrams, uncommitted instrument art, hand, layouts, audio assets
and core canon. No new nights/town/combat/chores, no arbitrary pacing changes. Goal: dependable
procedure and genuine amendment choice, not a claim of improved fun before novice playtesting.
PC single-player, target60fps, local-only data; editable GDScript/resources; no paid API, project
uploads, remote telemetry, automatic commit/push. These assumptions were stated in approval.

## Research-grounded direction

Procedure understood → ordinary work produces competence → rare discrepancy → independent evidence
→ chosen action → persistent, truthful acknowledgement. Sources support this principle, NOT exact
pause durations or a statistically proven Dead Wire design.
- Lucas Pope Papers,Please postmortem:protect the discrepancy-checking authority; do not change
  the decision into exploiting a safe time window. https://dukope.com/devlogs/papers-please/tig-10/
- Pope2013interview:simultaneous conversation caused players to miss rule introductions.
  https://gamedeveloper.com/design/designing-the-bleak-genius-of-i-papers-please-i-
- PopeObraDinn devlog:feedback must avoid trivial brute-force; exact wording traps need care.
  https://dukope.com/devlogs/obra-dinn/tig-30
- KelseyBeachum GDC2021:record known discoveries, no journal-generated deductions.
  https://media.gdcvault.com/GDC+2021/beachum_gdc_2021(1).pdf
- ThomasGrip2019:fewer scares and room for interpretation. https://frictionalgames.com/2019-10-9-years-9-lessons-on-horror
- Szymanski2024:physical human reorientation, actual-world photographs, not arbitrary fake data.
  https://softwareengineeringdaily.com/wp-content/uploads/2024/07/SED1712-Dusk.txt

Durable evidence:docs/research/mechanics_2026-10-10/.38short excerpts from12developer URLs independently
matched to source text; other sources/learning notes present. Multiple interviews of the same
creator are not independent studies. We have not personally played the referenced games.

## Alternatives and decisions

A. Evidence/choice repairs first — APPROVED owner. Makes the existing hook testable, low content risk.
B. First replace ordinary routing with ledger puzzle — defer until acknowledgement/evidence work.
C. More horror/maintenance/nights — reject for M1 until novice playtest, cognitive load and scope.
Typed correction chosen over multiple-choice candidates:choices can supply WATER without reasoning.
Existing calls/audio timestamps, t0 deadlines and paper animation remain authoritative and unchanged.

## Slice1 — lossless tape presentation and recording boundary

1. Fix office prose-style wrap so no original character/space is removed; rejoining only layout
   newlines reconstructs exact input. Clamp columns positive and retain runs/empty input.
2. Display tape in the same mono reference font; preserve all timing gaps, long MARK(6) visibly
   distinct from MARK(3), no text decoding or automatic correctness. Ensure no automatic RichText
   word-wrap removes whitespace; use explicit layout, scrolling; inspection opens newest ink.
3. Remove phantom12-unit post-completion gap. Scheduler playback start creates separate *presentation*
   segments (take numbers only, no telegram identities); boundary metadata is NOT a MARK/GAP event.
   A completed/cancelled schedule never invents elapsed silence. Current segmentation means wire
   takes, including calls and nags, not automatically 'message3'. Explain boundary versus blank timing.
4. Preserve started-event recording for compatibility but clone source scheduler events (never mutate
   the source). Maintain separate exact actual units/seconds for in-flight event; update from
   scheduler elapsed, finalize full event on timing_event_finished, truncate cancellation from its
   elapsed_seconds. get_record returns snapshots/clones; physical completed ink immutable. Store
   in-flight actual durations separately from compiled event's integer units; no schedule change.
   No real inter-schedule idle-gap clock in this patch:honest non-ink boundaries instead of fabricated
   timing. Mark interrupted takes clearly; fractional/in-progress marks are not presented as complete
   valid Morse characters. Exact values retained in a plain timing detail view/segment snapshot.
5. One-way evidence flow:scheduler events+elapsed→register record→presentation. No input from
   true_message, Elias's perception, transcript, player correction, or route outcomes.

Tests:40-column original whitespace reconstruction; C/O/R internal2-unit pauses; dots no-space
fallback; MARK1/3/6; boundary adds noGAP; cancelled0.05s of0.1sMARK keeps0.05s and unchanged source;
completed event exact duration; stable copies/snapshots; cancelled call→answer beat→telegram has
clear metadata boundary, not fictitious12units. Pause does not advance record; current ink newest.

## Slice2 — accepted route acknowledgement

RoutingBoard.select_action expresses intent only. Rejected late requests change no recorded memory,
lever, stamp, journal or foley. play_route_accept(action,accepted) sets terminal board state and
last accepted action then moves lever; a new route_accepted signal drives throw sound. Maintain
pending intent guard for repeated inputs; emit synchronously and clear rejected pending request.
Office rejects deadline requests explicitly; no need to fabricate lapse before its actual owner.
Reject invalid actions at the session boundary (only CLEAR EAST/HOLD). Preserve prior accepted
board state across new slots; reset only on a new watch. LapsedNOORDER emits no accepted foley.

OfficeFoley binds once only while inside tree and parent/components valid. Deferred binding after
removal exits without creating players or touching transforms. This guards proven detached errors,
NOT a claimed fix for unexplained native shift crash. Readability/audio mix otherwise untouched.

Tests:direct rejection, real office deadline-epsilon/exact/plus, repeated request and synchronous
slot reset, last route preserved, no accepted sound signal on reject; normal correct/wrong route
both count as accepted orders; lifecycle detach/rebind no duplicate players/connections.

## Slice3 — genuine amendment

Scenario retains two physical actions but labels neutral:AMEND COPY / FILE AS COPIED. AMEND does
not instantly resolve or expose a candidate. A small paper-styled AmendmentEditor has one LineEdit,
submit/cancel buttons. Empty/unsupported input shows only syntax feedback. Explicitly display
uppercase canonical word before submit, limit24ASCIIletters; no dictionary/autocomplete/candidates,
no answer prefill, no WATER in prompt, hidden default, footers or predecision labels.

Add requires_correction flag to amendment option and authored wrong-amendment world fact/result
fields to scenario. Action remains a neutral amendment identifier, not an answer. Session rejects
bare amendment submit_commit; only submit_amendment(text) can resolve it in AWAITING_COMMIT and
before original t0 deadline. Correct correction preserves existing core_hook_filed_water outcome;
wrong valid word creates distinct core_hook_amended_wrong world fact but is still accepted.
Knowledge learns only 'amendment entered', not 'correct/wrong'. Minimal independent knowledge value
store records exactly its chosen filed word; WorldState independently stores actual filed word.
No sharing dictionary/reference and no WorldState reads to build operator journal.

Confirmation is FILED/CORRECTION FILED, not a green correct/wrong verdict; wrong amendment is not
silently changed to WATER and does not produce gameover. Dawn/ledger/duty records show exactly the
chosen word with neutral 'amended copy sealed' wording, originalWATCHER retained separately.
FILEAS COPIED retains writtenWATCHER outcome, timeoutUNFILED remains distinct. Window consequence
unchanged for all filed/lapsed choices; no clue/grading revealed by animation or audio.

Input/lifecycle:editor_open closes on Esc/cancel and retains draft for reopening. World movement,
look, interact/number filing shortcuts are blocked while editor owns input. E is a letter here;
only Enter/button submits. Escape closes editor, not pause, and is consumed. Deadlines continue
unchanged (no pause/reset on edit/read). On timeout/scenario change/restart, close editor safely
and release locks once, clearing draft for next scenario. Do not swallow movement letters once
editor closes or create duplicate submit/stamp on E/Enter spam. All UI gates centrally include editor.

Tests:neutral captions; preinspection refusal; no bare amendment bypass; validWATER/WATCHER/WAITER
and another arbitraryword preserve exact choice; wrongWorldfact but no knowledge-correctness leak;
syntax errors/cancel leave session undecided; timer unchanged; exactdeadline rejection;lapse closes
editor; duplicate submit no second stamp; draftcancel/reopen; edit-E/1/2 never interacts behindUI;
Esc does not pause; restart resets independent stores andeditor. Update all active branch/capture
tools previously calling file_water directly so they exercise explicit amendment input instead.
Historical evidence scripts in docs are historical and need not be rewritten; document incompatibility.

## Out of scope and validation

Do not yet change second telegram/Rule44, ledger narration, window timing, repeats, maintenance,
intro content, movement, sounder timing or deadline numbers. Plain instructions may be made honest
about current route-as-filing flow, but universal filing is separate content/mechanics scope.

One vertical slice at a time:RED→GREEN→focused tests; complete regression counts never drop,
whitespace-tolerant failure parser with bounded process execution/full logs; distinguish asserted
pass from runtimeERROR/leaks. Lintproduction scripts. Windowed production realinput/physics route
and whole-night amended/as-written/wrong/lapsed branches; real editor typed-input test and capture.
Do not claim human engagement/horror effect from automation. Image service unavailable:source/UI
integration evidence not finalvisual approval. Five consented unassisted novice tests later ask when
mismatch discovered and what independently proves it; record time/readability, not just answer.

## Review status

Owner:APPROVED understanding and approach. Sequential skeptic/constraint/user/arbiter review pending.
## Skeptic review resolution — four objections ACCEPTED

S1(record semantics):public tape evidence contains only observed kind, delivered duration_seconds/
duration_units(float), is_complete and interrupted status in a dedicated tape-ink value type.
Planned scheduler event references stay private; event index, future end, plannedunits and schedule
message metadata never enter public snapshots or detailview. A new event begins at0actualunits;
advance/completion/cancel fill only elapsed. In-flight/interruptedmark uses an incomplete symbol,
not dot/dash classification even if it crossed an intermediate threshold. Wire-take separators
are explicit non-ink metadata. Tests mutate returned clones and prove underlying ink unaffected.

S2(reentrancy):session validates and snapshots oldscenario,chosen canonicalword,outcome before
any signal/state change; writes both independent stores exactly once, then emits immutable oldslot
resolutionpayload. Presentation apply methods use payload only, never current nextscenario/draft.
Set pending guard before intent emit; acceptance copies fields and clears/resolves before publishing
acceptedfeedback. Reset during signal dispatch may clear per-slot guard, but cannot erase captured
oldslot acceptedpayload or reapply it to a newslot. Tests include same-frame reset/reentrant duplicate
submit and ensure one accepted sound/stamp/fact and preserved prior-route memory.

S3(authorityvalidation):session and editor share one pure validator. Valid canonical is1..24ASCII
uppercaseA-Z; editor converts lowercasevisibly, but authority does NOT secretly trim/case-normalize.
Public nonUI submit rejects lowercase, surrounding whitespace, nonASCII and over24length. Validation
and deadlinefailures leave both stores unchanged. Editor shows exact stored uppercaseword before
confirmation; explicit submission preserves that exact value.

S4(eventownership):capture opening frame/event; deferLineEditfocus/edit until nextframe so activating
E never becomes draft text. ClosingEsc,Enter,buttonclick consume their triggering event BEFORE modal
locks release; no world action receives the sameevent. Input guards cover transitionframe too, not
only editor_open; mouse capture restored after triggeringpointerevent. RealInput.parse_input_event
checks demonstrate E openernottyped, Ewhileediting istext, Enter/closingclick notdoublefile and Esc
closes withoutpausing. Keyrelease restores movementstate, no stuckWASD.

Arbiter:APPROVED for implementation; accepts S1–S4 as resolved, rejects reopening unchanged deadlines/scope solely on untested novice workload. No unresolved design blockers. Approval is not runtime/art/human acceptance.

## Final code-review remediation

Independent spec review found two S2 violations:reentrant routing authority and office reset-before
loadrejection. Both reproducedRED; now routeguard spansfacts/result/state callbacks with captured
scenario, legitimate COMPLETEprogression remainsallowed, and officepreflight prevents anyUI/index
mutation forrefusedreentrant/invalidload. RouteActionsharedvocabularyretainsvalidationatseparate
boundaries. Standardslifecycle concern reproducedget_tree-null/offtreefocusERROR; editorpostawait
lifetimeguardsimplemented. Newregressions/logs:review_fixes/,route_reentrancy/office_load_atomicity/
amendment_lifetime. Fullregressionafterthesefixes supersedespreviouscounts.

## Implementation adjustments (verified, not changes to locked gameplay)

- BundledCourierPrimeRegular(SILOFL1.1) replaces host-dependentSystemFont for tape/card.
  Godotfont.has_char probe showed ◌ missing, so unfinished evidence marker changed toASCII`?`,
  with explicit footer explanation. No dot/dashfutureclassification or automaticdecoder.
- Non-inktake headers remain whole while inkcolumns wraplosslessly; scroll openslatestink and
  uses boundedpaper surface. Staledocumentcallbacks cannot movea differentdocument.
- Headlesspointerfixture sets1280×720viewport(defaultheadless64×64wouldclipGUI). Realwindowed
  rawkeyboard/mouse checksexercised separately. Windowedcaptures serialized after concurrent
  windowinterference causedmousecapturemode0 andinvalidnightcapture; failedlogretained.
- Intro existingfixedtimer test observedbefore sameframetweenrelease in deterministicprobe;
  replacedwithboundedsemanticintro_finishedcheck. No productionintroor musicasset/mixchange.

All accepted amendments, including a valid wrong word, enter the same neutral consequence;
no choice grading via sounds/window. Typed/session+editor+office79checks now green. Realwindowed
rawkeys and pointerclick exercised separately; universal test UI snapshots use1280×720 headless
viewport instead of default64×64. Full regression awaits independent tape/routing slices.
