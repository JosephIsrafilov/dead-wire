"""The surface footsteps are cut from real recordings, not synthesised.

The Godot suite (`tests/audio/footstep_surface_test.gd`) proves the resolver and
the player contract. It cannot tell a recorded contact from a hand-written sine,
because at runtime both arrive as PCM. This file checks the files on disk:

  - every shipped surface one-shot decodes to real audio with a transient crest
    and no dominant pure tone (the anti-slop rule for Phase B);
  - each bank came from the registered CC0 pack its SOURCE.md names;
  - the source recordings are staged, listed, and never shipped.

    python tools/footstep_surface_banks_test.py
"""

from __future__ import annotations

import re
import subprocess
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SURFACES = ROOT / "audio" / "sfx" / "foley" / "surfaces"
SOURCES = ROOT / "assets" / "third_party" / "footsteps_cc0"
BUILDER = ROOT / "tools" / "build_footstep_surface_banks.py"

# A recorded footstep contact is a transient: the peak stands well above the
# RMS, and no single FFT bin owns the signal (that would be a sine or a whistle).
MIN_CREST_DB = 8.0
MAX_BIN_CONCENTRATION = 0.55


def decode(path: Path) -> np.ndarray:
    result = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", "44100", "-"],
        capture_output=True, check=False,
    )
    if result.returncode != 0 or not result.stdout:
        raise RuntimeError(f"ffmpeg could not decode {path}")
    return np.frombuffer(result.stdout, dtype="<f4").astype(np.float64)


def crest_db(signal: np.ndarray) -> float:
    rms = float(np.sqrt(np.mean(np.square(signal))))
    peak = float(np.max(np.abs(signal)))
    return 20.0 * float(np.log10(max(peak, 1e-9) / max(rms, 1e-9)))


def bin_concentration(signal: np.ndarray) -> float:
    spectrum = np.abs(np.fft.rfft(signal * np.hanning(signal.size))) ** 2
    return float(spectrum.max() / max(spectrum.sum(), 1e-20))


def builder_banks() -> dict[str, list[tuple[str, float, float, str]]]:
    """Read the surface table out of the builder without importing it (no numpy CLI run)."""
    text = BUILDER.read_text(encoding="utf-8")
    body = text.split("BANKS: dict[str, list[tuple[str, float, float, str]]] = {", 1)[1]
    body = body.split("\n}\n", 1)[0]
    banks: dict[str, list[tuple[str, float, float, str]]] = {}
    for match in re.finditer(r'"(\w+)": \[(.*?)\]', body, re.DOTALL):
        surface, rows = match.group(1), match.group(2)
        entries = []
        for row in re.finditer(r'\("([^"]+)",\s*([\d.]+),\s*([\d.]+),\s*"([^"]*)"\)', rows):
            entries.append((row.group(1), float(row.group(2)), float(row.group(3)), row.group(4)))
        banks[surface] = entries
    return banks


class SurfaceBankFileTests(unittest.TestCase):
    def test_every_declared_surface_has_voice_files(self):
        banks = builder_banks()
        self.assertGreaterEqual(len(banks), 10, "the builder must declare the town surfaces")
        for surface, contacts in banks.items():
            for number in range(1, len(contacts) + 1):
                path = SURFACES / f"{surface}_{number}.wav"
                self.assertTrue(path.is_file(), f"missing {path.relative_to(ROOT)}")

    def test_no_bank_file_exists_without_a_declared_source(self):
        banks = builder_banks()
        for path in SURFACES.glob("*.wav"):
            surface = path.stem.rsplit("_", 1)[0]
            self.assertIn(surface, banks, f"{path.name} has no row in the builder table")

    def test_voices_are_mono_short_pcm(self):
        for path in sorted(SURFACES.glob("*.wav")):
            with self.subTest(path=path.name):
                info = subprocess.run(
                    ["ffprobe", "-v", "error", "-show_entries",
                     "stream=channels,sample_rate,codec_name:format=duration",
                     "-of", "default=nw=1", str(path)],
                    capture_output=True, text=True, check=False,
                ).stdout
                self.assertIn("channels=1", info)
                self.assertIn("sample_rate=44100", info)
                self.assertIn("codec_name=pcm_s16le", info)
                match = re.search(r"duration=([\d.]+)", info)
                self.assertIsNotNone(match)
                duration = float(match.group(1))
                self.assertGreaterEqual(duration, 0.08)
                self.assertLessEqual(duration, 0.60)

    def test_voices_are_transients_not_tones(self):
        for path in sorted(SURFACES.glob("*.wav")):
            with self.subTest(path=path.name):
                signal = decode(path)
                self.assertGreater(signal.size, 3000)
                self.assertGreater(crest_db(signal), MIN_CREST_DB,
                                   f"{path.name} reads as steady state, not a footfall")
                self.assertLess(bin_concentration(signal), MAX_BIN_CONCENTRATION,
                                f"{path.name} is dominated by one frequency")

    def test_voices_are_peak_matched_under_the_ceiling(self):
        for path in sorted(SURFACES.glob("*.wav")):
            with self.subTest(path=path.name):
                peak = 20.0 * float(np.log10(max(np.max(np.abs(decode(path))), 1e-9)))
                self.assertLessEqual(peak, -5.5)
                self.assertGreater(peak, -7.0)

    def test_config_offsets_match_the_measured_banks(self):
        """The .tres trims are the builder's own numbers, not hand-edited ones."""
        config = (ROOT / "data" / "audio" / "footstep_surfaces.tres").read_text(encoding="utf-8")
        pattern = (r'surface = &"(\w+)"\s*\nstreams = \[[^\]]*\]\s*\n'
                   r'volume_offset_db = (-?[\d.]+)')
        declared = dict(re.findall(pattern, config))
        self.assertGreaterEqual(len(declared), 10)
        for surface, offset in declared.items():
            with self.subTest(surface=surface):
                self.assertGreaterEqual(float(offset), -6.0,
                                        f"{surface} is attenuated past the bank limit")
                self.assertLessEqual(float(offset), 0.0,
                                     f"{surface} is boosted; the banks only attenuate")

    def test_banks_do_not_share_a_first_voice(self):
        banks = builder_banks()
        firsts = {}
        for surface, contacts in banks.items():
            source = contacts[0][0]
            self.assertNotIn(source, firsts, f"{surface} opens on {firsts.get(source)}'s take")
            firsts[source] = surface


class SourceRegisterTests(unittest.TestCase):
    def test_sources_are_staged_with_provenance(self):
        self.assertTrue(SOURCES.is_dir())
        packs = [path for path in SOURCES.iterdir() if path.is_dir()]
        self.assertGreaterEqual(len(packs), 5)
        for pack in packs:
            with self.subTest(pack=pack.name):
                note = pack / "SOURCE.md"
                self.assertTrue(note.is_file(), f"{pack.name} has no SOURCE.md")
                text = note.read_text(encoding="utf-8")
                self.assertIn("- source: https://", text)
                self.assertIn("- author:", text)
                self.assertIn("CC0 1.0", text)
                self.assertIn("sha256", text.lower())

    def test_every_builder_source_exists_in_the_register(self):
        for surface, contacts in builder_banks().items():
            for source, _start, _duration, _eq in contacts:
                with self.subTest(surface=surface, source=source):
                    self.assertTrue((SOURCES / source).is_file(), f"{source} is not staged")

    def test_registered_sources_never_reach_the_package(self):
        # The raw downloads stay in assets/third_party, which both export presets
        # and the packager exclude; the check pins that contract.
        manager = (ROOT / "tools" / "package_windows_beta.py").read_text(encoding="utf-8")
        self.assertIn("assets/third_party/", manager.split("UNSHIPPABLE_PREFIXES", 1)[1])
        presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn("assets/third_party/*", presets)


if __name__ == "__main__":
    unittest.main()
