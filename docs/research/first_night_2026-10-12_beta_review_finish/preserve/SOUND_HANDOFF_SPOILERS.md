# Sound Handoff — SPOILERS

**Spoiler warning:** This brief names the central transcription anomaly and later decisions. Please play the night once before reading it. This brief is not included in the beta ZIP; it is delivered separately after the first playthrough. The event descriptions below are mapped to the current source bindings, not a final sound design. Every listed sound is provisional unless explicitly noted otherwise.

## Dramatic and mix intent

The ordinary room should establish a legible mechanical routine. Telegraph information is the protected channel: MARK/GAP timing and critical copy must remain readable. Foley and ambience provide physical location and tactile response; they must not mask or grade the player's decisions. The core horror is that the received signal and the operator's written copy can diverge (WATER is perceived/written as WATCHER in the central hook). Do not sonically announce the “correct” word, punish a wrong filing, or reveal an answer through a special cue. Let the player's comparison of signal, tape, and copy carry the discovery.

Priority: **critical telegraph > action/contact Foley > optional ambience/music**. Keep the Telegraph bus independently adjustable from Foley and Ambience. Existing buses are `Telegraph`, `Foley`, `Ambience`, all sent to Master (`default_bus_layout.tres`). Protect timing and onset; variation may change timbre/pitch slightly, never event order or duration.

## Current event inventory

| Source / event | Actual trigger or contact | Bus / current asset | Current level / variation | Handoff constraints |
|---|---|---|---|---|
| Sounder down / mark | `MorseRuntimeScheduler.timing_event_started`, MARK; `SounderController.play_down` | Telegraph / `audio/sfx/telegraph/sounder_down.wav` | -3 dB; ±1.5% pitch | Protected information. Preserve exact scheduler timing; no competing transient. Project-authored deterministic synthesis; SHA256 verified against `tools/generate_sounder.py`. |
| Sounder up / gap | Scheduler event started, GAP; terminal release on final MARK completion/cancel | Telegraph / `sounder_up.wav` | -3 dB; ±1.5% pitch | Preserve mark/gap distinction and gap length. Do not replace with an arbitrary rhythmic loop. Project-authored deterministic synthesis; SHA256 verified against `tools/generate_sounder.py`. |
| Telegraph key touch | `TelegraphKey.key_touched` | Foley / `key_click.wav` | -16 dB; ±6% pitch | One tactile response to touch; no correctness signal. Project-generated temporary asset. |
| Pen on paper | `WriterRig.glyph_contact` only | Foley / `pen_scratch.wav` | -30 dB; ±6% pitch | Very subordinate to Morse. Do not trigger on cue/intent; one event per glyph contact. Project-generated. |
| Sheet feed | `TranscriptPaper.sheet_fed` | Foley / `sheet_slide.wav` via injected `feed_stream` | -24 dB; ±6% pitch | Distinct from opening a document; project-generated temporary asset. |
| Document pickup/open | `DocumentViewer.document_opened` | Foley / `paper_sheet.mp3` via injected `paper_stream` | -20 dB; ±6% pitch | Physical paper handling, not a result cue. CC0, Luckius / OpenGameArt. |
| Document return/close | `document_closed` | Foley / `paper_turn.wav` | -24 dB; ±6% pitch | One-shot on close. Provenance/license should be confirmed before public release. |
| Archived sheet slide | `TranscriptPaper.sheet_archived` | Foley / `sheet_slide.wav` | -26 dB; ±6% pitch | Paper movement only. Project-generated. |
| Stamp | `CopyCommitDesk.stamp_contact` | Foley / `ink_stamp_cc0.ogg` | -13 dB; no pitch variation | Play on physical contact, never on a rejected/late intent or correctness. Kenney impactPlate_heavy, CC0. |
| Route throw | `RoutingBoard.route_accepted` | Foley / `route_lever.wav` | -20 dB; ±6% pitch | Fires only after accepted route; must not imply whether the choice is right. Project provenance/license needs confirmation. Separate from scene `LeverSfx`, whose current node has no stream assigned in inspected scene. |
| Wick adjustment | `LampLife.wick_turned_up/down` | Foley / `wick_turn.wav` via injected `wick_stream` | -20 dB; no pitch variation | Distinct from register winding; no scare accent. Project-generated temporary asset. |
| Register wind | `TapeRegisterController.register_wound` | Foley / `register_wind.wav` via injected `winding_stream` | -18 dB; ±6% pitch | Lower/slower temporary clockwork timbre, distinct from wick adjustment. Project-generated. |
| Chair settle / rise | operator seat `seated` / `stood` | Foley / `chair_settle_cc0.ogg` | -22 dB; sit 1.0×, rise 0.8× | Physical, low-key. Kenney impactWood_medium, CC0. |
| Door latch / hinge | door `door_rattled`, `door_opened` | Foley / `door_latch.wav`, `door_hinge.wav` | -15 / -17 dB; no pitch variation | Distinguish latch from hinge; hinge accompanies open. Latch provenance should be checked; hinge project-generated. |
| Room bed | `OfficeAmbience.start()` | Ambience / `room_tone.wav` | -12 dB local, bus -4 dB | Project-generated 24 s stereo; loop. Should not mask wire. |
| Window wind | ambience start, spatial loop | Ambience / `wind_window.wav` | -9 dB local, bus -4 dB | Project-generated 20 s mono; loop; spatial source at window. |
| Stove fire | ambience start, spatial loop | Ambience / `stove_fire.wav` | -13 dB local, bus -4 dB | Project-generated 18 s mono; loop; spatial source at stove. |
| Clock tick | once per configured second | Ambience / `clock_tick.wav` | -17 dB local, bus -4 dB | Project-generated 0.13 s one-shot; intentionally quiet beneath Morse. |
| Footsteps | movement step event (see player movement binding and `DoorAttentionSource`) | Foley / `footstep_wood_beta.wav` | Project-authored temporary sample with pitch variation | Runtime no longer references the unknown legacy `footstep_wood.wav`; avoid a loud, regular competing pulse. |
| Music | intro music controller/resource | Master or configured music routing | See actual resource/controller before replacing | Existing temporary Long Note One is credited CC BY; inspect `audio/music/temp/ATTRIBUTION.txt`. Not a sounder substitute. |

## Stream replacement

The least invasive replacement points are the exported `SounderController.down_sound` and `up_sound` resources, and `OfficeAmbience` exported stream fields. Foley streams in `scripts/audio/office_foley.gd` are exported `AudioStream` fields with the existing defaults, so a sound designer can replace them in the inspector without changing session authority or signal wiring. The generated defaults remain project-owned temporary sounds until listening and provenance review are complete. Keep event authority and signal subscriptions unchanged. Validate source format, loop points, tails, click-free cutoffs, repeated triggers, spatial attenuation, and the Telegraph/Foley/Ambience balance in a real build. Do not run those checks against a headless-only result.

## Licensing and provenance

See `docs/third_party_assets.md` for the complete project register. Known runtime credits include Kenney (CC0 impact sounds), Luckius (CC0 paper), and the bundled IM FELL, Cedarville Cursive, and Courier Prime fonts (SIL OFL; license text is beside each font). Room beds and several Foley sounds are project-generated. The runtime sounder files are project-authored deterministic synthesis from `tools/generate_sounder.py`; their existing bytes were verified against regeneration. Runtime footsteps use project-authored `footstep_wood_beta.wav` from `tools/generate_beta_footstep.py`; the unknown legacy `footstep_wood.wav` is retained only for rollback and is not runtime-referenced. Other unregistered files (including paper_turn, route_lever, and door_latch) still require owner provenance review before public redistribution; this handoff is not a blanket legal clearance. The beta package must retain required license/attribution files while excluding development tools and private research.


## Remaining audio review (owner-run)

Before redistribution, the owner (or an owner-chosen reviewer) completes: (1) audit or replace any still-unregistered action Foley (paper_turn, route_lever, door_latch); (2) a listening pass through headphones and speakers on a real Windows build; (3) concrete fixes for clicks, tails, masking, and loop boundaries; (4) regeneration of project-owned assets only through `tools/generate_action_foley.py` or a separately documented project generator. Until this review is complete, this handoff must not claim legal clearance or genuine listening acceptance.

## Known audio limitations (source inspection only)

- MARK and GAP have separate samples and a dedicated Telegraph bus, but no fresh Windows export or listening QA has been performed for this handoff.
- Wick adjustment and register winding now use distinct streams (`wick_turn.wav` and `register_wind.wav`); paper feed and document pickup now use distinct streams (`sheet_slide.wav` and `paper_sheet.mp3`).
- Several short-action assets have pitch jitter; this is not a substitute for a final variation set.
- The route scene's separate `LeverSfx` has no assigned stream in the inspected scene; the accepted-route Foley binding is separate.
- Sounder provenance is closed by byte-identical deterministic regeneration; runtime footstep provenance is closed by the project-authored beta replacement. The legacy unknown footstep remains rollback-only.
- No genuine listening session has been performed for this handoff. No claim is made about final loudness, device translation, loop quality, or human playtest results.
