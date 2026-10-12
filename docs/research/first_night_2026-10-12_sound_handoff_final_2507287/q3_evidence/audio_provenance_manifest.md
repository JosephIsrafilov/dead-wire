# Beta audio provenance — complete referenced manifest (sound_handoff_final_2507287)

One row per asset actually referenced by runtime code/scenes (grep-verified against
scripts/, scenes/, data/). Hashes re-verified this session against the live files.
No audio asset was regenerated (documentary task). External licences unchanged;
third-party notices ship in the package (licenses/fonts/*/OFL.txt,
licenses/audio/ATTRIBUTION.txt).

## Telegraph (critical channel)
| asset | trigger / bus | provenance | sha256-16 |
|---|---|---|---|
| audio/sfx/telegraph/sounder_down.wav | MARK start (SounderController) | project generator tools/generate_sounder.py | 937b0e802a3a4e05 |
| audio/sfx/telegraph/sounder_up.wav | MARK end / GAP (SounderController) | project generator tools/generate_sounder.py | 21abfe483cb0a9f4 |

## Foley (one-shots, OfficeFoley streams)
| asset | trigger | provenance | sha256-16 |
|---|---|---|---|
| audio/sfx/foley/paper_sheet.mp3 | viewer open/close (paper_stream) | external CC0: Luckius, various-paper-sound-effects (opengameart) | 6e81a68cfe8283f7 |
| audio/sfx/foley/ink_stamp_cc0.ogg | stamp (stamp_stream) | external CC0: Kenney impactSounds impactPlate_heavy | 142fd6c77f13d25f |
| audio/sfx/foley/chair_settle_cc0.ogg | sit/stand (chair_stream) | external CC0: Kenney impactSounds impactWood_medium | 15271dbe8e2872db |
| assets/audio/sfx/kenney_impact/lever_stop.ogg | lever throw+stop (RoutingBoard _throw_lever, Foley bus) | external CC0: Kenney impact-sounds | 15ff82332f342c30 |
| audio/sfx/foley/route_lever.wav | accepted route (lever_stream) | tools/generate_action_foley.py | 8ffaa5f3e75d4aba |
| audio/sfx/foley/door_latch.wav | latch (latch_stream) | tools/generate_action_foley.py | cf923379ddcf3b84 |
| audio/sfx/foley/paper_turn.wav | document pickup (pickup_stream) | tools/generate_action_foley.py | b49e2de27fc0e62c |
| audio/sfx/foley/pen_scratch.wav | writing tick (pen_stream) | tools/generate_action_foley.py | b8d89ab8a2db43c9 |
| audio/sfx/foley/key_click.wav | key press (key_stream) | tools/generate_action_foley.py | b7856a5b1f7a648b |
| audio/sfx/foley/door_hinge.wav | door (hinge_stream) | tools/generate_action_foley.py | 73a91748f4508083 |
| audio/sfx/foley/sheet_slide.wav | paper feed (feed_stream) | tools/generate_action_foley.py | e30becd7b01e33c4 |
| audio/sfx/foley/wick_turn.wav | lamp wick (wick_stream) | tools/generate_action_foley.py | 632db6662be818ec |
| audio/sfx/foley/register_wind.wav | register wind, ±6% jitter (winding_stream) | tools/generate_action_foley.py | c491c2d5d539351a |
| audio/sfx/foley/footstep_wood_beta.wav | footstep (PlayerController footstep_stream preload) | tools/generate_beta_footstep.py | 8b3f3a965218e843 |
| audio/sfx/foley/floor_creak_1.wav | unease creak variant 1 (unease_director preload) | tools/generate_beta_footstep.py | e5c7dc9caa35100d |
| audio/sfx/foley/floor_creak_2.wav | unease creak variant 2 | tools/generate_beta_footstep.py | af42fd86490c4647 |
| audio/sfx/foley/floor_creak_3.wav | unease creak variant 3 | tools/generate_beta_footstep.py | 9e2b9c35ecd56bd1 |
| audio/sfx/foley/clock_tick.wav | clock (OfficeClock) | tools/generate_action_foley.py | 53295843452afc5c |

## Ambience (loops)
| asset | trigger | provenance | sha256-16 |
|---|---|---|---|
| audio/sfx/ambience/room_tone.wav | office room bed (OfficeAmbience, bus Ambience) | project-generated provisional | 10abf53ed7a6c84a |
| audio/sfx/ambience/stove_fire.wav | stove loop | project-generated provisional | 83cf06b2969075b2 |
| audio/sfx/ambience/wind_window.wav | window wind loop | project-generated provisional | 01982b6c6ac47952 |

## Music
| asset | trigger | provenance | sha256-16 |
|---|---|---|---|
| audio/music/temp/long_note_one.mp3 | intro music (MainMenu) | CC BY 4.0 Kevin MacLeod "Long Note One"; attribution file ships in package | 665aef3a5eaba25a |

## Excluded legacy (NOT referenced, NOT in PCK p12; repo rollback only)
- audio/sfx/foley/footstep_wood.wav — unknown provenance; excluded via Windows-only
  exclude_filter; PCK p12 verified without it (5814b110ae7e8976, file stays in repo).
  Live footstep stream is footstep_wood_beta.wav (PlayerController preload).

## Listening checklist (sound designer; POST-SEND evaluation task)
Headphones + ordinary speakers, one pass each:
1. Telegraph MARK/GAP intelligibility over room bed at normal listening level.
2. Lever throw + stop reads as ONE physical event (no double hit, stop lands with peg).
3. Paper pickup (paper_turn) vs paper feed (sheet_slide) are distinct.
4. Pen/stamp contacts land with the visible hand contact, not before.
5. Wick turn and register wind: no clicks, tails, or loop seams.
6. Ambience balance: room tone vs stove vs wind; no pumping between loops.
7. Intro/pause/quit transitions: music fades, no pops.
Automated PASS above is provenance only — it is NOT a listening verdict.
