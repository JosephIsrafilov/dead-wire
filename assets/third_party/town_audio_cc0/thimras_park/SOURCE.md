# thimras_park

- source: https://opengameart.org/content/park-ambiences
- author: Thimras
- license: CC0 1.0
- note: Three ambience recordings made in one public park in Adelaide, South Australia, in winter: birds in a copse before rain, a small river over a low step, and an open field with more wind. Uploaded at 48 kHz.
- status: source-only. `assets/third_party/` is excluded from both
  export presets and refused by `tools/package_windows_beta.py`; only
  the cut runtime files under `audio/sfx/` ship.

Each file below is a **lossless FLAC excerpt** of the original download, not
a re-encode: the excerpt starts at `origin` seconds of the original and ends
at `end`, so every sample the build cuts is bit-identical to the download.
The original's size, duration and SHA-256 are recorded so the excerpt can be
re-derived from the same upload.

| excerpt | original | origin | end | original bytes | original sha256 | excerpt sha256 |
|---|---|---|---|---|---|---|
| `park_ambience_birds.flac` | `park_ambience_birds.wav` | 185 s | 211 s | 86190432 | `dc1a5ac34b89cab7…` | `419a2321089ce612…` |
| `park_ambience_wind.flac` | `park_ambience_wind.wav` | 109 s | 139 s | 73960096 | `5c381856745b4706…` | `db17aff3b7f416ea…` |
| `park_ambience_river.flac` | `park_ambience_river.wav` | 93 s | 111 s | 99072736 | `da0c0c9b1249a83a…` | `69d142e5518ed2c8…` |

Cut times and filters live in `tools/town_audio_sources.py`; the build is
`tools/build_town_audio_recordings.py`.
