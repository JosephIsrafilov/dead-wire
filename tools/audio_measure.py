"""Measure the office mix without hearing it.

    python tools/audio_measure.py measure audio/sfx/ambience
    python tools/audio_measure.py mask --bed audio/sfx/ambience/room_tone.wav \
        --target audio/sfx/telegraph/sounder_down.wav --bed-gain-db -16 --target-gain-db -3

Read-only. Needs ffmpeg/ffprobe on PATH and numpy (.venv-tools).

This is measurement, not listening. It reports loudness, band balance and the
loop seam: the three numbers that decide whether the room buries the telegraph.
It cannot say a sample sounds right, and it cannot hear a click that only
happens at a volume a scene node drifts to. Judge with headphones after it.

The band that matters is the telegraph band. The sounder brass partials sit at
2350-5100 Hz (tools/generate_sounder.py), so a bed with energy there fights the
one channel the game is not allowed to lie about (AGENTS.md, audio fairness).
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

SAMPLE_RATE = 44100
AUDIO_SUFFIXES = {".wav", ".ogg", ".mp3", ".flac"}

BANDS = {
    "low": (20.0, 300.0),
    "speech": (300.0, 3400.0),
    "telegraph": (1800.0, 5500.0),
    "air": (5500.0, 16000.0),
}

# Steady-state band separation, target band level minus bed band level. This is
# not a readability test: readability also depends on mark/gap timing and on
# the levels the scene actually sets.
SAFE_SEPARATION_DB = 12.0
TIGHT_SEPARATION_DB = 6.0


def _run(args):
    return subprocess.run(args, capture_output=True, check=False)


def decode(path):
    """Mono float32 PCM at SAMPLE_RATE, through ffmpeg so every format works."""
    result = _run([
        "ffmpeg", "-v", "error", "-i", str(path),
        "-f", "f32le", "-ac", "1", "-ar", str(SAMPLE_RATE), "-",
    ])
    if result.returncode != 0 or not result.stdout:
        message = result.stderr.decode("utf-8", "replace").strip()[:200]
        raise RuntimeError(f"ffmpeg could not decode {path}: {message}")
    return np.frombuffer(result.stdout, dtype="<f4")


def _float(value):
    try:
        return float(value)
    except ValueError:
        return None


def loudness(path):
    """Integrated LUFS, loudness range and true peak, from ffmpeg EBU R128."""
    result = _run([
        "ffmpeg", "-nostats", "-hide_banner", "-i", str(path),
        "-filter_complex", "ebur128=peak=true", "-f", "null", "-",
    ])
    text = result.stderr.decode("utf-8", "replace")
    # The summary block is printed last, so the final match of each field wins.
    integrated = re.findall(r"I:\s+(-?[\d.]+)\s+LUFS", text)
    loudness_range = re.findall(r"LRA:\s+(-?[\d.]+)\s+LU", text)
    peak = re.findall(r"Peak:\s+(-?[\d.]+)\s+dBFS", text)
    return {
        "lufs": _float(integrated[-1]) if integrated else None,
        "lra": _float(loudness_range[-1]) if loudness_range else None,
        "true_peak": _float(peak[-1]) if peak else None,
    }


def _frame_size(signal):
    """Largest power-of-two FFT frame the file can carry; short hits get a small one."""
    size = 4096
    while size > 64 and signal.size < size * 2:
        size //= 2
    return size


def band_levels(signal):
    """Mean power per band in dB, relative to the signal own mean power."""
    frame = _frame_size(signal)
    if signal.size < frame:
        return {name: None for name in BANDS}
    window = np.hanning(frame)
    frequencies = np.fft.rfftfreq(frame, 1.0 / SAMPLE_RATE)
    masks = {name: (frequencies >= low) & (frequencies < high)
             for name, (low, high) in BANDS.items()}
    total = 0.0
    accumulated = dict.fromkeys(BANDS, 0.0)
    for start in range(0, signal.size - frame + 1, frame // 2):
        spectrum = np.abs(np.fft.rfft(signal[start:start + frame] * window)) ** 2
        total += float(spectrum.sum())
        for name, mask in masks.items():
            accumulated[name] += float(spectrum[mask].sum())
    if total <= 0.0:
        return {name: None for name in BANDS}
    return {name: round(10.0 * float(np.log10(max(power, 1e-20) / total)), 1)
            for name, power in accumulated.items()}


def loops_in_engine(path):
    """True when the Godot sidecar loops this file, so the seam is audible."""
    sidecar = Path(str(path) + ".import")
    if not sidecar.exists():
        return None
    try:
        text = sidecar.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    match = re.search(r"^edit/loop_mode=(\d+)$", text, re.MULTILINE)
    if match is None:
        return None
    return match.group(1) == "1"


def loop_seam(signal):
    """How hard the last sample jumps back to the first, against the local floor."""
    if signal.size < SAMPLE_RATE // 10:
        return {"seam_db": None, "clean": None}
    edge = 256
    jump = abs(float(signal[-1]) - float(signal[0]))
    head = float(np.sqrt(np.mean(np.square(signal[:edge]))))
    tail = float(np.sqrt(np.mean(np.square(signal[-edge:]))))
    reference = max((head + tail) * 0.5, 1e-9)
    seam_db = 20.0 * float(np.log10(max(jump, 1e-9) / reference))
    # A click is a discontinuity above the material own noise floor.
    return {"seam_db": round(seam_db, 1), "clean": bool(jump <= reference)}


def rms_dbfs(signal):
    """Root-mean-square level: the honest figure where integrated LUFS cannot gate."""
    if signal.size == 0:
        return None
    power = float(np.mean(np.square(signal)))
    return round(10.0 * float(np.log10(max(power, 1e-20))), 1)


def measure(path):
    signal = decode(path)
    seconds = signal.size / SAMPLE_RATE
    record = {
        "file": path.name,
        "seconds": round(seconds, 2),
    }
    record.update(loudness(path))
    # EBU R128 gates anything shorter than its 400 ms window out of the
    # integration, which reports -70 LUFS for a single Morse stroke.
    # RMS is the honest number for a one-shot.
    if seconds < 1.0:
        record["lufs"] = None
        record["lra"] = None
        record["rms_dbfs"] = rms_dbfs(signal)
    record["bands"] = band_levels(signal)
    record["loops"] = loops_in_engine(path)
    # A one-shot has no seam to judge; only a looped bed is heard across it.
    record.update(loop_seam(signal) if record["loops"] else
                  {"seam_db": None, "clean": None})
    return record


def _cell(value, width):
    padded = " " * (width - 2) + "--"
    if value is None:
        return padded
    return format(value, ">{0}.1f".format(width))


def format_row(record):
    bands = record["bands"]
    if record["lufs"] is None:
        level = "rms " + _cell(record["rms_dbfs"], 6) + " dBFS"
    else:
        level = _cell(record["lufs"], 7) + " LUFS"
    if record["loops"] is None:
        loop = "loop?"
    elif record["loops"] is False:
        loop = "one-shot"
    elif record["clean"] is True:
        loop = "loop ok " + _cell(record["seam_db"], 6) + " dB"
    else:
        loop = "loop CLICK " + _cell(record["seam_db"], 6) + " dB"
    return "  ".join([
        record["file"][:30].ljust(30),
        _cell(record["seconds"], 6) + "s",
        level,
        _cell(record["true_peak"], 7) + " dBTP",
        "LRA " + _cell(record["lra"], 5),
        "low " + _cell(bands["low"], 6),
        "speech " + _cell(bands["speech"], 6),
        "tel " + _cell(bands["telegraph"], 6),
        "air " + _cell(bands["air"], 6),
        loop,
    ])


def collect(targets):
    paths = []
    for target in targets:
        candidate = Path(target)
        if candidate.is_dir():
            paths.extend(sorted(p for p in candidate.rglob("*")
                                if p.suffix.lower() in AUDIO_SUFFIXES))
        elif candidate.is_file():
            paths.append(candidate)
        else:
            print(f"skip, no such file or directory: {target}", file=sys.stderr)
    return paths


def band_power(signal, low, high):
    """Mean power inside one band; the caller applies the gain."""
    frame = _frame_size(signal)
    if signal.size < frame:
        return 0.0
    window = np.hanning(frame)
    frequencies = np.fft.rfftfreq(frame, 1.0 / SAMPLE_RATE)
    selected = (frequencies >= low) & (frequencies < high)
    powers = []
    for start in range(0, signal.size - frame + 1, frame // 2):
        spectrum = np.abs(np.fft.rfft(signal[start:start + frame] * window)) ** 2
        powers.append(float(spectrum[selected].sum()))
    return float(np.mean(powers)) if powers else 0.0


def mask(bed, target, bed_gain, target_gain):
    """Band separation between bed and target in the sounder own band."""
    low, high = BANDS["telegraph"]
    bed_db = 10.0 * float(np.log10(max(band_power(decode(bed), low, high), 1e-20)))
    target_db = 10.0 * float(np.log10(max(band_power(decode(target), low, high), 1e-20)))
    separation = (target_db + target_gain) - (bed_db + bed_gain)
    if separation >= SAFE_SEPARATION_DB:
        verdict = "safe"
    elif separation >= TIGHT_SEPARATION_DB:
        verdict = "tight"
    else:
        verdict = "masked"
    return {
        "bed": bed.name,
        "target": target.name,
        "band_hz": [low, high],
        "bed_band_db": round(bed_db + bed_gain, 1),
        "target_band_db": round(target_db + target_gain, 1),
        "separation_db": round(separation, 1),
        "verdict": verdict,
    }


def main(argv):
    parser = argparse.ArgumentParser(description="Measure the office mix. Read-only.")
    sub = parser.add_subparsers(dest="command", required=True)

    measure_parser = sub.add_parser("measure", help="one line per audio file")
    measure_parser.add_argument("paths", nargs="+")
    measure_parser.add_argument("--json", action="store_true", help="machine-readable")

    mask_parser = sub.add_parser("mask", help="bed versus target, in the sounder band")
    mask_parser.add_argument("--bed", required=True)
    mask_parser.add_argument("--target", required=True)
    mask_parser.add_argument("--bed-gain-db", type=float, default=0.0)
    mask_parser.add_argument("--target-gain-db", type=float, default=0.0)
    mask_parser.add_argument("--json", action="store_true")

    arguments = parser.parse_args(argv)

    if arguments.command == "measure":
        paths = collect(arguments.paths)
        if not paths:
            print("nothing to measure", file=sys.stderr)
            return 1
        records = [measure(path) for path in paths]
        if arguments.json:
            print(json.dumps(records, indent=1))
            return 0
        print("bands: dB below the file own mean power; seam: loop point"
              " against that file own floor.")
        for record in records:
            print(format_row(record))
        return 0

    result = mask(Path(arguments.bed), Path(arguments.target),
                  arguments.bed_gain_db, arguments.target_gain_db)
    if arguments.json:
        print(json.dumps(result, indent=1))
        return 0
    low, high = result["band_hz"]
    print(result["bed"] + " under " + result["target"] + " at "
          + format(low, ".0f") + "-" + format(high, ".0f") + " Hz: "
          + format(result["separation_db"], ".1f") + " dB separation ("
          + result["verdict"] + ")")
    print("  steady-state band balance only; mark/gap timing is pinned by the tape suite")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
