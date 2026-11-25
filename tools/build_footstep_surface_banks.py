"""Cut real CC0 footstep recordings into the surface banks the player walks on.

Phase B anti-slop rule: this tool never synthesises a footstep. It only decodes
a recorded file, trims one contact out of it, optionally applies a fixed EQ, and
normalises the peak. Every source is a registered CC0 recording under
`assets/third_party/footsteps_cc0/` (see each pack's SOURCE.md and
`docs/third_party_assets.md`); the sources themselves never ship.

    python tools/build_footstep_surface_banks.py            # write the banks
    python tools/build_footstep_surface_banks.py --dry-run  # report only

Output: `audio/sfx/foley/surfaces/<surface>_<n>.wav`, mono 44.1 kHz 16-bit
one-shots. `scripts/audio/footstep_surface_bank.gd` and
`data/audio/footstep_surfaces.tres` point at them.

The wood_office surface is not rebuilt here: it is the already-shipping
mikeask recording set (`footstep_boards_1..5.wav`), which the beta packager
requires as a complete set.
"""

from __future__ import annotations

import argparse
import math
import re
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "assets" / "third_party" / "footsteps_cc0"
OUT_DIR = ROOT / "audio" / "sfx" / "foley" / "surfaces"
CONFIG = ROOT / "data" / "audio" / "footstep_surfaces.tres"
RATE = 44100
PEAK_DBFS = -6.0
EDGE_FADE_IN = 0.0012
EDGE_FADE_OUT = 0.010

# surface -> [(source file, start seconds, duration seconds, extra ffmpeg EQ)]
# Starts come from measured onsets (tools/audio_measure.py) of each recording;
# a contact is cut from the onset back-off to the decay, never looped.
BANKS: dict[str, list[tuple[str, float, float, str]]] = {
    "wood_saloon": [
        ("rubberduck_sfx100/sfx100v2_footstep_wood_01.ogg", 0.005, 0.24, ""),
        ("rubberduck_sfx100/sfx100v2_footstep_wood_02.ogg", 0.005, 0.22, ""),
        ("rubberduck_sfx100/sfx100v2_footstep_wood_03.ogg", 0.005, 0.23, ""),
        ("rubberduck_sfx100/sfx100v2_footstep_wood_04.ogg", 0.005, 0.26, ""),
    ],
    "boardwalk": [
        ("tinyworlds_steps/wood01.ogg", 0.0, 0.22, ""),
        ("tinyworlds_steps/wood02.ogg", 0.0, 0.22, ""),
        ("tinyworlds_steps/wood03.ogg", 0.0, 0.28, ""),
    ],
    # A bridge deck is the same kind of contact with more body under it: the
    # same take sits lower and rings longer over the hollow span.
    "wood_bridge": [
        ("tinyworlds_steps/wood03.ogg", 0.0, 0.30, "bass=g=5:f=160"),
        ("tinyworlds_steps/wood02.ogg", 0.0, 0.26, "bass=g=5:f=160"),
        ("tinyworlds_steps/wood01.ogg", 0.0, 0.26, "bass=g=4:f=160"),
    ],
    # Stair treads: a shorter, tighter contact — the ball of the foot on a riser,
    # not the whole sole settling on a deck.
    "stairs": [
        ("rubberduck_sfx100/sfx100v2_footstep_wood_02.ogg", 0.005, 0.15, ""),
        ("rubberduck_sfx100/sfx100v2_footstep_wood_03.ogg", 0.005, 0.15, ""),
        ("tinyworlds_steps/wood02.ogg", 0.0, 0.17, ""),
    ],
    "carpet": [
        ("hael_db_cloth_steps/step_cloth1.ogg", 0.0, 0.22, ""),
        ("hael_db_cloth_steps/step_cloth2.ogg", 0.0, 0.22, ""),
        ("hael_db_cloth_steps/step_cloth3.ogg", 0.0, 0.22, ""),
        ("hael_db_cloth_steps/step_cloth4.ogg", 0.0, 0.19, ""),
    ],
    "wet_mud": [
        ("rubberduck_mud/mud_10.ogg", 0.0, 0.24, ""),
        ("rubberduck_mud/mud_25.ogg", 0.0, 0.21, ""),
        ("rubberduck_mud/mud_15.ogg", 0.0, 0.26, ""),
        ("rubberduck_sfx100/sfx100v2_footstep_wet_01.ogg", 0.005, 0.24, ""),
        ("rubberduck_sfx100/sfx100v2_footstep_wet_02.ogg", 0.005, 0.28, ""),
        ("rubberduck_sfx100/sfx100v2_footstep_wet_03.ogg", 0.005, 0.27, ""),
    ],
    "dirt": [
        ("fantozzi_steps/Fantozzi-SandL1.ogg", 0.0, 0.28, ""),
        ("fantozzi_steps/Fantozzi-SandL2.ogg", 0.0, 0.26, ""),
        ("fantozzi_steps/Fantozzi-SandR1.ogg", 0.0, 0.27, ""),
        ("fantozzi_steps/Fantozzi-SandR2.ogg", 0.0, 0.26, ""),
    ],
    # Ballast / slag: one recorded gravel walk, cut at its four contacts.
    "ballast": [
        ("tinyworlds_steps/gravel.ogg", 0.030, 0.22, ""),
        ("tinyworlds_steps/gravel.ogg", 0.112, 0.22, ""),
        ("tinyworlds_steps/gravel.ogg", 0.256, 0.24, ""),
        ("tinyworlds_steps/gravel.ogg", 0.366, 0.24, ""),
    ],
    # Steel rail under a boot: recorded metal-on-concrete contacts, high-passed
    # so the concrete body drops away and the plate ring stays.
    "rail": [
        ("thimras_metal_steps/metal_steps_01.wav", 0.0, 0.14, "highpass=f=180"),
        ("thimras_metal_steps/metal_steps_02.wav", 0.0, 0.13, "highpass=f=180"),
        ("thimras_metal_steps/metal_steps_05.wav", 0.0, 0.14, "highpass=f=180"),
        ("thimras_metal_steps/metal_steps_09.wav", 0.0, 0.15, "highpass=f=180"),
    ],
    "stone": [
        ("fantozzi_steps/Fantozzi-StoneL1.ogg", 0.0, 0.26, ""),
        ("fantozzi_steps/Fantozzi-StoneL2.ogg", 0.0, 0.25, ""),
        ("fantozzi_steps/Fantozzi-StoneR1.ogg", 0.0, 0.25, ""),
        ("fantozzi_steps/Fantozzi-StoneR2.ogg", 0.0, 0.25, ""),
    ],
}

# The interior boards already ship and stay referenced in place.
WOOD_OFFICE = [f"audio/sfx/foley/footstep_boards_{index}.wav" for index in range(1, 6)]


def decode(path: Path, eq: str) -> np.ndarray:
    filters = "highpass=f=45" + ("," + eq if eq else "")
    result = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-af", filters,
         "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"],
        capture_output=True, check=False,
    )
    if result.returncode != 0 or not result.stdout:
        raise RuntimeError(f"ffmpeg could not decode {path}: {result.stderr.decode('utf-8', 'replace')[:200]}")
    return np.frombuffer(result.stdout, dtype="<f4").astype(np.float64)


def cut(signal: np.ndarray, start: float, duration: float) -> np.ndarray:
    first = int(round(start * RATE))
    count = int(round(duration * RATE))
    chunk = signal[first:first + count].copy()
    if chunk.size < count:  # the recording ended early: pad with its own silence
        chunk = np.pad(chunk, (0, count - chunk.size))
    fade_in = max(1, int(EDGE_FADE_IN * RATE))
    fade_out = min(max(1, int(EDGE_FADE_OUT * RATE)), chunk.size)
    chunk[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
    chunk[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
    return chunk


def normalise(chunk: np.ndarray) -> np.ndarray:
    peak = float(np.max(np.abs(chunk))) if chunk.size else 0.0
    if peak <= 1e-9:
        raise RuntimeError("silent cut: check the source onset")
    return chunk * (10.0 ** (PEAK_DBFS / 20.0) / peak)


def rms_db(chunk: np.ndarray) -> float:
    power = float(np.mean(np.square(chunk)))
    return 20.0 * math.log10(max(math.sqrt(power), 1e-9))


def write_wav(path: Path, chunk: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    samples = np.clip(chunk, -1.0, 1.0)
    pcm = (samples * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())


def build(dry_run: bool) -> int:
    levels: dict[str, float] = {}
    written = 0
    for surface, contacts in BANKS.items():
        surface_levels = []
        for number, (source, start, duration, eq) in enumerate(contacts, start=1):
            path = SOURCES / source
            if not path.is_file():
                print(f"missing source: {path}", file=sys.stderr)
                return 1
            chunk = normalise(cut(decode(path, eq), start, duration))
            surface_levels.append(10.0 ** (rms_db(chunk) / 20.0))
            target = OUT_DIR / f"{surface}_{number}.wav"
            if not dry_run:
                write_wav(target, chunk)
            written += 1
        levels[surface] = 20.0 * math.log10(float(np.mean(surface_levels)))

    # Mixed by measurement: every surface is peak-matched at -6 dBFS, so the
    # only level the bank may add is attenuation. Boosting a quiet-but-peaky
    # transient would push its crest into the ceiling; a surface that measures
    # quieter than the boards simply is quieter, which is honest for gravel.
    office_power = []
    for relative in WOOD_OFFICE:
        path = ROOT / relative
        office_power.append(10.0 ** (rms_db(decode(path, "")[: RATE // 4]) / 20.0))
    reference = 20.0 * math.log10(float(np.mean(office_power)))

    offsets: dict[str, float] = {}
    print(f"wood_office reference {reference:.1f} dBFS RMS (existing mikeask set)")
    for surface in sorted(levels):
        # Attenuation only: a quieter-but-peakier surface is not boosted into the
        # ceiling to pretend it is as loud as a floorboard.
        offset = min(0.0, reference - levels[surface])
        offset = max(-6.0, offset)
        offsets[surface] = round(offset, 1)
        print(f"  {surface:12s} {levels[surface]:7.1f} dBFS RMS  volume_offset_db {offset:+.1f}")
    if not dry_run:
        applied = write_offsets(offsets)
        print(f"offsets written to {applied} bank(s) in {CONFIG.relative_to(ROOT)}")
    print(f"{written} one-shots {'reported' if dry_run else 'written'} in {OUT_DIR.relative_to(ROOT)}")
    return 0


def write_offsets(offsets: dict[str, float]) -> int:
    """Keep the resource's measured trims in step with the files it points at."""
    text = CONFIG.read_text(encoding="utf-8")
    blocks = text.split("[sub_resource")
    applied = 0
    for index, block in enumerate(blocks):
        match = re.search(r'surface = &"(\w+)"', block)
        if not match or match.group(1) not in offsets or match.group(1) == "wood_office":
            continue
        updated = re.sub(r"volume_offset_db = -?[\d.]+",
                         f"volume_offset_db = {offsets[match.group(1)]}", block, count=1)
        if updated != block:
            blocks[index] = updated
            applied += 1
    CONFIG.write_text("[sub_resource".join(blocks), encoding="utf-8")
    return applied


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="measure and report, write nothing")
    return build(parser.parse_args().dry_run)


if __name__ == "__main__":
    raise SystemExit(main())
