# M1 PSX Visual Direction Pass

## Pipeline

Production now renders the office through a 0.5 3D buffer with nearest scaling. MSAA, screen-space AA, TAA, debanding, and smooth canvas filtering remain disabled. A restrained screen-space grade quantizes color in shallow steps and uses a four-phase stipple, preserving readable shadow detail while giving dark corners the authored PSX dither language. Materials continue using small nearest-sampled period textures; geometry remains deliberately sparse and low-poly.

The previous native 1.0 production scale was a visual regression: it made the scene look like modern Forward+ with low-poly assets. The restored half-resolution buffer is consistent with the existing PSX reference captures and the GDD's intended visual identity.

## Room and South Door

The dedicated filing desk moved from the western south-door approach to the southeast work bay at `(0.95, 0.72, 1.35)`. This keeps filing physically close to the office's records and lamp while leaving the south door's silhouette, threshold, and floor approach isolated for the door attention event. The cabinet remains wall-bound; no furniture crosses the approach. Its paper stock now uses a muted umber base against the lamp so copy plates retain ink contrast instead of blooming white. A new spatial assertion protects this decision.

## Functional Props

- Telegraph key: sprung operator input; seating gate makes its use a believable shift procedure.
- Sounder: twin iron coils and brass armature visibly strike and release on Morse marks; spatial audio carries the cause and effect.
- Filing desk: two physical paper plates, stamps, and world-space interaction targets; filing changes WorldState and the dawn record.
- Routing board: lever and line state move together; route choice advances the corresponding traffic state.
- Ledger, duty sheet, Morse card, and transcript: separate readable paper objects; opening each requires a spatial attention commitment.
- Lamp, clock, wire runs, insulators, stove, cabinet, and roster remain period context and lighting anchors rather than arbitrary controls.

## Writer Viewmodel

The authored hand has separate palm, bent finger groups, opposing thumb, cuff, wool sleeve, and pen/nib meshes. The rig aligns the whole arm assembly to the transcript glyph contact, preserving grip and desk contact while writing. The sleeve was tightened to 82% scale to keep the working hand tactile without filling the frame; contact remains computed from the nib, so timing and placement are unchanged.

## Validation

- Full regression: **34 suites, 1,359 assertions, 0 failures**.
- Production WATER playthrough after PSX/layout changes: **0 failures, 14 screenshots**, ending and restart passed.
- Visual capture: `.dream-loop/review/door_zone.png`, `.dream-loop/review/writing_50.png`, `.dream-loop/review/filing_water.png`, and related first-night frames.
- Door-zone capture shows a clear threshold and unobstructed approach. Writer capture shows live hand contact during transcript writing. Automated evidence does not replace a subjective human playtest.

## Follow-up Interaction And Layout Audit

Player feel target is now the requested Silent Hill 1/2 PSX direction: slower 2.35 m/s movement with 7.5 m/s² acceleration and 6.5 m/s² deceleration, restrained body bob, and long quiet beats. Interior fog is subtle and blue-gray, strongest in the upper room and cold window distance, so the lamp remains a readable work source while silhouettes soften at range.

The requested feel was chosen after clarification: Silent Hill 1/2 PSX visual language, heavy deliberate movement, and slow psychological dread. The bundled `image_gen.py` CLI reached the configured `gpt-image-2` provider, but its decode step failed with `TypeError: argument should be a bytes-like object or ASCII string, not 'NoneType'` because the response contained no `image_b64`; no generated image was used or treated as a target. Existing runtime captures remain the visual validation source.

A verified provider smoke-test render is preserved at `.dream-loop/concept_psx_target.png` as a private mood target. It reinforces the chosen amber-lamp / blue-window composition and low-resolution material breakup; it is reference only, not a runtime asset.

The compact filing desk remains in the southeast work bay, east of the south-door approach. This keeps the door silhouette and threshold readable from room center, preserves a clear exit path, and places filing beside the lamp and station records in a plausible service zone.

Routing board contract: before selection, `E` opens the modal route panel; `1` or `2` submits exactly one route; submission closes the panel and advances the session. After submission, the physical board remains inspectable as non-actionable status feedback (`Route recorded: CLEAR EAST` or `Route recorded: HOLD`). Repeated `E` is idempotent: no stale modal, state change, or movement/look lock. `reset_for_new_transmission()` clears status and restores route affordance for the next slot.

The board face was simplified into two horizontal brass line rails with left aligned station plaques. This keeps the 1894 routing function legible at close range and removes diagonal/floating elements that previously read as broken geometry in the PSX buffer.

Collision audit: the filing desk now has a layer-1 StaticBody3D for its tabletop and all four legs. Player capsule queries and runtime movement therefore stop at the actual furniture silhouette instead of passing through the visual mesh.

Regression coverage now includes repeated post-route interaction at component and production integration levels. Both targeted suites pass; full regression is the release gate.
