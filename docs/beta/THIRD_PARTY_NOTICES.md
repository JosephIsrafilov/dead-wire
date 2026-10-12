# Third-Party Notices — DEAD WIRE Beta

The package must retain the game's required notices and license texts. This short index does not replace individual license files or the full provenance record.

- **Kenney impact sounds:** CC0. Used for stamp and chair-related impact Foley; voluntary credit is recorded in `docs/third_party_assets.md`.
- **Luckius paper sound effects:** CC0. Selected paper sample; source and usage are recorded in `docs/third_party_assets.md`.
- **IM FELL English Roman, Cedarville Cursive, Courier Prime:** SIL Open Font License 1.1. The corresponding `OFL.txt` files are bundled beside the fonts and must remain with redistributed font files.
- **Long Note One — Kevin MacLeod:** CC BY 4.0; attribution is in `audio/music/temp/ATTRIBUTION.txt` and must be included if the track is shipped.
- **Noto Sans (static Regular), SIL OFL 1.1:** `assets/fonts/noto/NotoSans-Regular.ttf` (variable source kept out of the package under `variable_source/`); UI/control readability. Source: https://github.com/google/fonts/tree/main/ofl/notosans . OFL text in `licenses/fonts/noto/OFL.txt`.
- **Old Standard TT, SIL OFL 1.1:** `assets/fonts/oldstandard/`; period-inspired styling. Source: https://github.com/google/fonts/tree/main/ofl/oldstandardtt . OFL text in `licenses/fonts/oldstandard/OFL.txt`.
- **Elias Working hand (project-authored bitmap font):** generated from project SVG sources by `tools/build_elias_font.py`; not a third-party font. Artistic status is unaccepted (see the beta report).
- **Temporary beta sounds (project-generated, provisional):** sounder, footstep_wood_beta, register_wind, wick_turn, sheet_slide, paper_turn, route_lever, door_latch and room/ambience beds; all regenerate byte-identically through the project generators listed below. Not final recorded Foley; human listening acceptance is a separate open gate.
- **Project-authored/generated assets:** listed in the project register.

Provenance status: the sounder down/up samples were closed by byte-identical regeneration through `tools/generate_sounder.py`; action Foley (paper_turn, route_lever, door_latch, ink_stamp, wick_turn, sheet_slide, pen_scratch, key_click, door_hinge) regenerates byte-identically through `tools/generate_action_foley.py`; footsteps use project-authored `footstep_wood_beta.wav` from `tools/generate_beta_footstep.py` (the unknown legacy `footstep_wood.wav` is excluded from this package and kept only in the source repository for rollback). Music, Luckius paper, Kenney impacts, and Long Note One keep their external licenses as listed above. These are project-owned temporary sounds, not final recorded Foley; the owner provenance review and human listening pass remain open gates. No blanket legal clearance is claimed.

Preserve all asset-local license files and `audio/music/temp/ATTRIBUTION.txt` in the runtime package when those assets are included. See `docs/third_party_assets.md` in the source repository for the full register and URLs.
