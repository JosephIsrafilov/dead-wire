"""Cut the town, train and creak foley files out of real CC0 recordings.

Phase B anti-slop rule: this tool never synthesises these files. It decodes a
recorded source, cuts one measured window out of it, applies a fixed filter
chain, closes the loop seam with an equal-power crossfade and level-matches the
result. Where the cut is and what it is cut from live in
`tools/town_audio_sources.py`; the recordings themselves are staged as lossless
FLAC excerpts under `assets/third_party/town_audio_cc0/` by
`tools/stage_cc0_town_audio.py` (each pack's SOURCE.md and `docs/
third_party_assets.md` carry the original URL, author, licence and SHA-256).

    python tools/build_town_audio_recordings.py            # write
    python tools/build_town_audio_recordings.py --dry-run  # measure only

Output: `audio/sfx/town/*.wav`, `audio/sfx/train/*.wav` and the replaced creak
foley under `audio/sfx/foley/`, all 44.1 kHz 16-bit PCM.

Level is matched to each file this replaces, because the mix was tuned against
those numbers. A bed is matched by integrated loudness. A one-shot is matched by
sample peak, which is the hard constraint: peak sets the bus headroom the scenes
were mixed against, so every foley replacement is attenuation-only and never
touches the -1 dBTP ceiling. A real contact carries much more crest than the
near-continuous synth tone it replaces, so the "hit" column shows its loudest
50 ms landing below the old file's — a physical difference in the recording, not
a mixing mistake to be flattened with a limiter.

For beds, a matched gain that would break the ceiling is limited down rather
than the whole file turned down, because dropping a bed 3 dB to save one gust
would make the room quieter than the mix expects — the same slop in the other
direction. `MAX_LIMIT_DB` caps how much of that is honest, and anything beyond
it is printed as an explicit shortfall.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from town_audio_sources import CUTS, LOOPED, SOURCES, check  # noqa: E402

SOURCE_DIR = ROOT / "assets" / "third_party" / "town_audio_cc0"
MANIFEST = SOURCE_DIR / "excerpts.json"
OUT_DIR = ROOT / "audio" / "sfx"
RATE = 44100
PEAK_CEILING_DB = -1.0
MAX_LIMIT_DB = 3.0
SEAM_FADE = 0.75
STAGE_PROBE = ROOT / ".dream-loop" / "phaseb_stage_probe.wav"


def load_manifest() -> dict[str, dict]:
    if not MANIFEST.is_file():
        raise SystemExit(
            f"missing {MANIFEST.relative_to(ROOT)}: run "
            "tools/stage_cc0_town_audio.py --input <downloads> first")
    return {record["key"]: record for record in
            json.loads(MANIFEST.read_text(encoding="utf-8"))}


def decode(path: Path, filters: str) -> np.ndarray:
    """Float64 at RATE, always stereo, so a mono target is a true mono sum of
    one decode rather than a second decode that drops one channel."""
    result = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-af", filters or "anull",
         "-f", "f64le", "-ac", "2", "-ar", str(RATE), "-"],
        capture_output=True, check=False,
    )
    if result.returncode != 0 or not result.stdout:
        raise RuntimeError(
            f"ffmpeg could not decode {path}: "
            f"{result.stderr.decode('utf-8', 'replace').strip()[:200]}")
    return np.frombuffer(result.stdout, dtype="<f8").reshape(-1, 2)


def cut(signal: np.ndarray, start: float, length: float) -> np.ndarray:
    first = int(round(start * RATE))
    count = int(round(length * RATE))
    if first < 0:
        raise RuntimeError("cut starts before the tracked excerpt begins")
    chunk = signal[first:first + count].copy()
    if chunk.shape[0] < count:
        raise RuntimeError(
            f"cut runs {count - chunk.shape[0]} samples past the tracked "
            "excerpt: rerun tools/stage_cc0_town_audio.py with a wider window")
    return chunk


def close_seam(chunk: np.ndarray) -> np.ndarray:
    """Equal-power crossfade of the tail into the head, so the loop point is a
    blend of the same material rather than a cut."""
    fade = int(round(SEAM_FADE * RATE))
    if fade * 2 >= chunk.shape[0]:
        return chunk
    alpha = np.linspace(0.0, 1.0, fade)[:, None]
    out = chunk[:-fade].copy()
    out[:fade] = (chunk[:fade] * np.sin(alpha * math.pi / 2)
                  + chunk[-fade:] * np.cos(alpha * math.pi / 2))
    return out


def edge_fade(chunk: np.ndarray, head: float = 0.004,
              tail: float = 0.012) -> np.ndarray:
    out = chunk.copy()
    h = min(int(head * RATE), out.shape[0])
    t = min(int(tail * RATE), out.shape[0])
    out[:h] *= np.linspace(0.0, 1.0, h)[:, None]
    out[-t:] *= np.linspace(1.0, 0.0, t)[:, None]
    return out


def integrated_lufs(path: Path) -> float | None:
    result = subprocess.run(
        ["ffmpeg", "-nostats", "-hide_banner", "-i", str(path),
         "-filter_complex", "ebur128=peak=true", "-f", "null", "-"],
        capture_output=True, check=False,
    )
    found = re.findall(r"I:\s+(-?[\d.]+)\s+LUFS",
                       result.stderr.decode("utf-8", "replace"))
    return float(found[-1]) if found else None


def peak_db(signal: np.ndarray) -> float:
    return 20.0 * math.log10(max(float(np.max(np.abs(signal))), 1e-12))


def rms_db(signal: np.ndarray) -> float:
    return 10.0 * math.log10(max(float(np.mean(np.square(signal))), 1e-20))


def write_wav(path: Path, signal: np.ndarray, stereo: bool) -> None:
    data = signal if stereo else signal.mean(axis=1, keepdims=True)
    pcm = np.round(np.clip(data, -1.0, 1.0) * 32767.0).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(pcm.shape[1])
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())


def limit(signal: np.ndarray, ceiling_db: float) -> tuple[np.ndarray, float]:
    """Turn the signal down only where it would break the ceiling.

    A look-ahead limiter, so the bed keeps the loudness it was matched to and
    only the peaks that would have clipped are bent.
    """
    over = peak_db(signal) - ceiling_db
    if over <= 0.0:
        return signal, 0.0
    result = subprocess.run(
        ["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(RATE), "-ac", "2",
         "-i", "-", "-af",
         f"alimiter=limit={10.0 ** (ceiling_db / 20.0):.6f}"
         ":attack=1:release=90:level=0:latency=1",
         "-f", "f64le", "-ac", "2", "-ar", str(RATE), "-"],
        input=signal.astype("<f4").tobytes(), capture_output=True, check=False,
    )
    if result.returncode != 0 or not result.stdout:
        raise RuntimeError("alimiter failed: "
                           + result.stderr.decode("utf-8", "replace")[:200])
    limited = np.frombuffer(result.stdout, dtype="<f8").reshape(-1, 2)
    if limited.shape[0] != signal.shape[0]:
        raise RuntimeError("alimiter changed the sample count")
    return limited, round(over, 1)


def hit_db(signal: np.ndarray, window: float = 0.05) -> float:
    """Loudness of the loudest `window` second: the hit, not the programme."""
    mono = signal.mean(axis=1)
    span = min(int(window * RATE), mono.size)
    if span < 2:
        return rms_db(signal)
    power = np.convolve(mono ** 2, np.ones(span) / span, mode="valid")
    return 10.0 * math.log10(max(float(power.max()), 1e-20))


def stage(signal: np.ndarray, stereo: bool, target_lufs: float | None,
          target_peak: float | None) -> tuple[np.ndarray, dict[str, object]]:
    """Level-match to the file being replaced, then hold the peak ceiling."""
    notes: dict[str, object] = {}
    if target_peak is not None:
        gain = target_peak - peak_db(signal)
        notes["mode"] = "peak"
    else:
        write_wav(STAGE_PROBE, signal, stereo)
        measured = integrated_lufs(STAGE_PROBE)
        STAGE_PROBE.unlink(missing_ok=True)
        if measured is None or target_lufs is None:
            raise RuntimeError("could not measure integrated loudness")
        gain = target_lufs - measured
        notes["mode"] = "lufs"
    out = signal * (10.0 ** (gain / 20.0))
    over = peak_db(out) - PEAK_CEILING_DB
    if over > 0.0:
        if over > MAX_LIMIT_DB:
            # The crest does not fit: take the rest off the gain, not the peaks.
            out *= 10.0 ** (-(over - MAX_LIMIT_DB) / 20.0)
            gain -= over - MAX_LIMIT_DB
            notes["short"] = round(over - MAX_LIMIT_DB, 1)
        out, _ = limit(out, PEAK_CEILING_DB)
        notes["limited"] = round(min(over, MAX_LIMIT_DB), 1)
    notes["gain"] = round(gain, 1)
    notes["peak"] = round(peak_db(out), 1)
    notes["rms"] = round(rms_db(out), 1)
    notes["hit"] = round(hit_db(out), 1)
    return out, notes


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--only", default=None)
    args = parser.parse_args(argv)

    problems = check()
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1

    manifest = load_manifest()
    print(f"{'target':32} {'len':>5} {'gain':>6} {'peak':>6} {'hit':>6}  note")
    for cut_spec in CUTS:
        if args.only is not None and args.only not in cut_spec.target:
            continue
        record = manifest.get(cut_spec.key)
        if record is None:
            print(f"{cut_spec.target}: no excerpt staged for {cut_spec.key}",
                  file=sys.stderr)
            return 1
        source = SOURCES[cut_spec.key]
        if (source.excerpt_origin != record["excerpt_origin"]
                or source.excerpt_end != record["excerpt_end"]):
            print(f"{cut_spec.target}: staged excerpt does not match the "
                  "declared window; rerun tools/stage_cc0_town_audio.py",
                  file=sys.stderr)
            return 1
        path = SOURCE_DIR / record["excerpt"]
        offset = cut_spec.start - record["excerpt_origin"]
        chunk = cut(decode(path, cut_spec.filters), offset, cut_spec.length)
        chunk = (close_seam(chunk) if cut_spec.target in LOOPED
                 else edge_fade(chunk))
        out, notes = stage(chunk, cut_spec.stereo, cut_spec.target_lufs,
                           cut_spec.oneshot_peak)
        note = f"{notes['mode']}{' stereo' if cut_spec.stereo else ' mono'}"
        if "limited" in notes:
            note += f" limited {notes['limited']} dB"
        if "short" in notes:
            note += f" UNDER TARGET {notes['short']} dB"
        print(f"{cut_spec.target:32} {out.shape[0] / RATE:5.2f} "
              f"{notes['gain']:>6.1f} {notes['peak']:>6.1f} "
              f"{notes['hit']:>6.1f}  {note}")
        if not args.dry_run:
            write_wav(OUT_DIR / cut_spec.target, out, cut_spec.stereo)
    if args.dry_run:
        print("\ndry run: nothing written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
