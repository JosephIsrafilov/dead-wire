"""Synthesises the M1 office ambience bed.

    python tools/generate_office_ambience.py

Every sample is generated here rather than sourced externally, so the office bed
carries no third-party licence obligations. Regenerating is deterministic: the
RNG is seeded per layer, so re-running produces byte-identical files.

The loops are built to be seamless. Each one is rendered slightly longer than its
target length and the overhang is cross-faded back over the head, so the file can
be looped end-to-start without a click.
"""

from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

SAMPLE_RATE = 44100
PROJECT_ROOT = Path(__file__).resolve().parent.parent
AUDIO_ROOT = PROJECT_ROOT / "audio" / "sfx"


def one_pole_lowpass(signal: np.ndarray, cutoff_hz: float) -> np.ndarray:
	"""Cheap single-pole lowpass. Enough shaping for a noise bed."""
	alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff_hz / SAMPLE_RATE)
	out = np.empty_like(signal)
	accumulator = 0.0
	for index, sample in enumerate(signal):
		accumulator += alpha * (sample - accumulator)
		out[index] = accumulator
	return out


def one_pole_highpass(signal: np.ndarray, cutoff_hz: float) -> np.ndarray:
	return signal - one_pole_lowpass(signal, cutoff_hz)


def bandpass(signal: np.ndarray, low_hz: float, high_hz: float) -> np.ndarray:
	return one_pole_highpass(one_pole_lowpass(signal, high_hz), low_hz)


def seamless(signal: np.ndarray, loop_seconds: float, fade_seconds: float = 0.75) -> np.ndarray:
	"""Cross-fades the overhang back over the head so the loop point is silent."""
	loop_samples = int(loop_seconds * SAMPLE_RATE)
	fade_samples = int(fade_seconds * SAMPLE_RATE)
	assert signal.shape[0] >= loop_samples + fade_samples, "render more overhang than the fade"
	head = signal[:loop_samples].copy()
	tail = signal[loop_samples:loop_samples + fade_samples]
	ramp = np.linspace(0.0, 1.0, fade_samples)
	head[:fade_samples] = head[:fade_samples] * ramp + tail * (1.0 - ramp)
	return head


def normalise(signal: np.ndarray, peak_dbfs: float) -> np.ndarray:
	peak = float(np.max(np.abs(signal)))
	if peak == 0.0:
		return signal
	return signal * (10.0 ** (peak_dbfs / 20.0)) / peak


def write_wav(path: Path, left: np.ndarray, right: np.ndarray | None = None) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	channels = [left] if right is None else [left, right]
	stacked = np.stack(channels, axis=1)
	clipped = np.clip(stacked, -1.0, 1.0)
	pcm = (clipped * 32767.0).astype("<i2")
	with wave.open(str(path), "wb") as handle:
		handle.setnchannels(len(channels))
		handle.setsampwidth(2)
		handle.setframerate(SAMPLE_RATE)
		handle.writeframes(pcm.tobytes())
	print(f"{path.relative_to(PROJECT_ROOT)}  {stacked.shape[0] / SAMPLE_RATE:.2f}s  {len(channels)}ch")


def render_room_tone(loop_seconds: float = 24.0) -> tuple[np.ndarray, np.ndarray]:
	"""Still air in a small wooden room: low rumble, faint structural creak, no melody."""
	rng = np.random.default_rng(1894)
	total = int((loop_seconds + 1.0) * SAMPLE_RATE)
	time = np.arange(total) / SAMPLE_RATE

	rumble = one_pole_lowpass(rng.standard_normal(total), 90.0) * 3.5
	# Two detuned low partials read as a building settling rather than a hum tone.
	body = 0.06 * np.sin(2.0 * np.pi * 47.0 * time) + 0.04 * np.sin(2.0 * np.pi * 63.3 * time)
	body *= 0.5 + 0.5 * np.sin(2.0 * np.pi * 0.031 * time)
	air = bandpass(rng.standard_normal(total), 900.0, 5200.0) * 0.35

	mixed = rumble + body + air
	left = seamless(mixed, loop_seconds)
	right = seamless(np.roll(mixed, 977), loop_seconds)
	return normalise(left, -26.0), normalise(right, -26.0)


def render_window_wind(loop_seconds: float = 20.0) -> np.ndarray:
	"""Cold air working at a sash window. Gusts, never a constant hiss."""
	rng = np.random.default_rng(1889)
	total = int((loop_seconds + 1.0) * SAMPLE_RATE)
	time = np.arange(total) / SAMPLE_RATE

	# Slow, irregular gust envelope from summed low-frequency oscillators.
	gust = (
		0.50 * np.sin(2.0 * np.pi * 0.067 * time + 0.4)
		+ 0.30 * np.sin(2.0 * np.pi * 0.113 * time + 2.1)
		+ 0.20 * np.sin(2.0 * np.pi * 0.041 * time + 5.0)
	)
	gust = np.clip(0.35 + 0.65 * (gust * 0.5 + 0.5), 0.0, 1.6)

	noise = rng.standard_normal(total)
	low_whistle = bandpass(noise, 260.0, 900.0) * 2.2
	high_whistle = bandpass(noise, 1100.0, 3000.0) * 1.1 * gust
	mixed = (low_whistle + high_whistle) * gust

	return normalise(seamless(mixed, loop_seconds), -20.0)


def render_stove_fire(loop_seconds: float = 18.0) -> np.ndarray:
	"""Coal settling in a closed firebox: muffled roar plus sparse pops."""
	rng = np.random.default_rng(1017)
	total = int((loop_seconds + 1.0) * SAMPLE_RATE)

	roar = bandpass(rng.standard_normal(total), 70.0, 520.0) * 2.6

	pops = np.zeros(total)
	pop_count = int(loop_seconds * 3.2)
	for _ in range(pop_count):
		start = int(rng.uniform(0.0, total - SAMPLE_RATE * 0.3))
		length = int(rng.uniform(0.01, 0.07) * SAMPLE_RATE)
		decay = np.exp(-np.linspace(0.0, 9.0, length))
		tone = np.sin(2.0 * np.pi * rng.uniform(700.0, 2600.0) * np.arange(length) / SAMPLE_RATE)
		crack = (0.65 * tone + 0.35 * rng.standard_normal(length)) * decay
		pops[start:start + length] += crack * rng.uniform(0.25, 1.0)

	mixed = roar + pops
	return normalise(seamless(mixed, loop_seconds), -18.0)


def render_floor_creak(index: int) -> np.ndarray:
	"""A dry board taking weight it was not given.

	Stick-slip: the timber grips, releases, grips again, which is why a creak
	warbles instead of sliding smoothly in pitch.
	"""
	rng = np.random.default_rng(400 + index)
	length = int(rng.uniform(0.42, 0.72) * SAMPLE_RATE)
	time = np.arange(length) / SAMPLE_RATE
	span = time[-1]

	base_hz = rng.uniform(105.0, 190.0)
	# Pitch rises as the board loads up.
	sweep = base_hz * (1.0 + 0.42 * (time / span))
	# Stick-slip warble on top of the sweep.
	warble = 1.0 + 0.09 * np.sin(2.0 * np.pi * rng.uniform(11.0, 19.0) * time)
	phase = 2.0 * np.pi * np.cumsum(sweep * warble) / SAMPLE_RATE

	voice = np.sin(phase) + 0.45 * np.sin(2.0 * phase) + 0.2 * np.sin(3.0 * phase)
	grain = bandpass(rng.standard_normal(length), 400.0, 2600.0) * 0.5

	envelope = np.sin(np.pi * np.clip(time / span, 0.0, 1.0)) ** 1.6
	return normalise((voice + grain) * envelope, -17.0)


def render_clock_tick() -> np.ndarray:
	"""One escapement tick from a regulator wall clock. Wood body, brass movement."""
	rng = np.random.default_rng(7)
	length = int(0.13 * SAMPLE_RATE)
	index = np.arange(length)
	time = index / SAMPLE_RATE

	transient = rng.standard_normal(length) * np.exp(-time * 420.0)
	brass = np.sin(2.0 * np.pi * 2350.0 * time) * np.exp(-time * 150.0) * 0.5
	case = np.sin(2.0 * np.pi * 430.0 * time) * np.exp(-time * 65.0) * 0.35
	return normalise(transient + brass + case, -14.0)


def main() -> None:
	left, right = render_room_tone()
	write_wav(AUDIO_ROOT / "ambience" / "room_tone.wav", left, right)

	write_wav(AUDIO_ROOT / "ambience" / "wind_window.wav", render_window_wind())
	write_wav(AUDIO_ROOT / "ambience" / "stove_fire.wav", render_stove_fire())

	write_wav(AUDIO_ROOT / "foley" / "clock_tick.wav", render_clock_tick())

	# Several variants so the same board never creaks twice in the same way.
	for index in range(3):
		write_wav(AUDIO_ROOT / "foley" / f"floor_creak_{index + 1}.wav", render_floor_creak(index))


if __name__ == "__main__":
	main()
