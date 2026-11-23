"""Tests for the audio measurement helper.

    cd tools && ../.venv-tools/Scripts/python.exe -m unittest audio_measure_test

Synthetic signals only: these pin what the numbers mean, not what the office
sounds like. No ffmpeg needed, so the suite stays fast and host-independent.
"""

import math
import tempfile
import unittest
import wave
from pathlib import Path

import numpy as np

import audio_measure

RATE = audio_measure.SAMPLE_RATE


def write_wav(path, samples, rate=RATE):
    """Mono 16-bit PCM, so the file behaves like every project WAV."""
    clipped = np.clip(samples, -1.0, 1.0)
    frames = (clipped * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(rate)
        stream.writeframes(frames.tobytes())


def sine(frequency, seconds, amplitude=0.5, rate=RATE):
    t = np.arange(int(seconds * rate)) / rate
    return amplitude * np.sin(2.0 * math.pi * frequency * t)


class BandLevelTests(unittest.TestCase):
    def test_a_sine_lands_in_its_own_band(self):
        levels = audio_measure.band_levels(sine(3000.0, 1.0))
        self.assertGreater(levels["telegraph"], -1.0)
        self.assertLess(levels["low"], -30.0)

    def test_a_low_sine_does_not_claim_the_telegraph_band(self):
        levels = audio_measure.band_levels(sine(80.0, 1.0))
        self.assertGreater(levels["low"], -1.0)
        self.assertLess(levels["telegraph"], -30.0)

    def test_silence_reports_nothing_instead_of_zero(self):
        levels = audio_measure.band_levels(np.zeros(RATE, dtype=np.float32))
        self.assertEqual(set(levels.values()), {None})

    def test_a_single_morse_stroke_gets_a_window_that_fits_it(self):
        # 75 ms is shorter than one 4096-sample frame; the old code reported
        # nothing at all for it, which is exactly the sample that matters most.
        levels = audio_measure.band_levels(sine(2500.0, 0.075))
        self.assertIsNotNone(levels["telegraph"])


class LoopSeamTests(unittest.TestCase):
    def test_a_discontinuous_loop_is_reported_as_a_click(self):
        signal = sine(440.0, 0.5)
        signal[-1] = 0.99
        signal[0] = -0.99
        seam = audio_measure.loop_seam(signal)
        self.assertFalse(seam["clean"])
        self.assertGreater(seam["seam_db"], 0.0)

    def test_a_quiet_loop_is_reported_clean(self):
        signal = sine(440.0, 0.5, amplitude=0.2)
        seam = audio_measure.loop_seam(signal)
        self.assertTrue(seam["clean"])

    def test_a_very_short_sample_has_no_seam_to_judge(self):
        seam = audio_measure.loop_seam(sine(440.0, 0.01))
        self.assertIsNone(seam["clean"])


class LoopFlagTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.directory = Path(self.work.name)

    def tearDown(self):
        self.work.cleanup()

    def test_the_godot_loop_flag_is_read_from_the_sidecar(self):
        audio = self.directory / "bed.wav"
        audio.write_bytes(b"x")
        Path(str(audio) + ".import").write_text("edit/loop_mode=1\n", encoding="utf-8")
        self.assertTrue(audio_measure.loops_in_engine(audio))

    def test_a_one_shot_is_not_a_loop(self):
        audio = self.directory / "hit.wav"
        audio.write_bytes(b"x")
        Path(str(audio) + ".import").write_text("edit/loop_mode=0\n", encoding="utf-8")
        self.assertFalse(audio_measure.loops_in_engine(audio))

    def test_a_file_without_a_sidecar_is_unknown(self):
        audio = self.directory / "raw.wav"
        audio.write_bytes(b"x")
        self.assertIsNone(audio_measure.loops_in_engine(audio))


class MaskTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.directory = Path(self.work.name)
        self.target = self.directory / "target.wav"
        write_wav(self.target, sine(2500.0, 0.3, amplitude=0.6))

    def tearDown(self):
        self.work.cleanup()

    def test_a_bed_far_below_the_sounder_band_is_safe(self):
        bed = self.directory / "bed.wav"
        write_wav(bed, sine(90.0, 0.6, amplitude=0.4))
        result = audio_measure.mask(bed, self.target, 0.0, 0.0)
        self.assertEqual(result["verdict"], "safe")

    def test_a_bed_in_the_sounder_band_is_masked(self):
        bed = self.directory / "bed.wav"
        write_wav(bed, sine(2500.0, 0.6, amplitude=0.6))
        result = audio_measure.mask(bed, self.target, 0.0, 0.0)
        self.assertEqual(result["verdict"], "masked")

    def test_gain_is_applied_to_the_bed_side_of_the_comparison(self):
        bed = self.directory / "bed.wav"
        write_wav(bed, sine(2500.0, 0.6, amplitude=0.6))
        quiet = audio_measure.mask(bed, self.target, -30.0, 0.0)
        loud = audio_measure.mask(bed, self.target, 0.0, 0.0)
        self.assertAlmostEqual(quiet["separation_db"] - loud["separation_db"], 30.0, places=1)


class ReportingTests(unittest.TestCase):
    def test_a_short_one_shot_reports_rms_not_a_gated_lufs(self):
        with tempfile.TemporaryDirectory() as name:
            path = Path(name) / "hit.wav"
            write_wav(path, sine(2500.0, 0.1, amplitude=0.5))
            record = audio_measure.measure(path)
        self.assertIsNone(record["lufs"])
        self.assertIsNotNone(record["rms_dbfs"])
        self.assertIn("rms", audio_measure.format_row(record))

    def test_missing_numbers_print_as_dashes_not_crashes(self):
        row = audio_measure.format_row({
            "file": "x.wav", "seconds": 0.1, "lufs": None, "rms_dbfs": None,
            "true_peak": None, "lra": None, "loops": None, "seam_db": None,
            "clean": None, "bands": dict.fromkeys(audio_measure.BANDS),
        })
        self.assertIn("--", row)

    def test_collect_walks_directories_and_skips_other_files(self):
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            (directory / "a.wav").write_bytes(b"x")
            (directory / "notes.txt").write_bytes(b"x")
            found = audio_measure.collect([str(directory)])
        self.assertEqual([p.name for p in found], ["a.wav"])


if __name__ == "__main__":
    unittest.main()
