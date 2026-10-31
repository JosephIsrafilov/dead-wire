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


def render_window_wind(loop_seconds: float = 53.0) -> np.ndarray:
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


def render_stove_fire(loop_seconds: float = 41.0) -> np.ndarray:
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


def render_clock_tock() -> np.ndarray:
	"""The other end of the swing (plan 7.9): a darker, softer strike than the tick."""
	rng = np.random.default_rng(8)
	length = int(0.15 * SAMPLE_RATE)
	time = np.arange(length) / SAMPLE_RATE

	transient = rng.standard_normal(length) * np.exp(-time * 360.0)
	brass = np.sin(2.0 * np.pi * 1840.0 * time) * np.exp(-time * 130.0) * 0.45
	case = np.sin(2.0 * np.pi * 355.0 * time) * np.exp(-time * 55.0) * 0.42
	return normalise(transient + brass + case, -15.0)


def render_clock_strike() -> np.ndarray:
	"""One stroke of the regulator's coiled gong (plan 9.2): a leather-faced
	hammer on a steel coil. A low tone with the coil's inharmonic partials, the
	upper ones dying first, and a long tail. The game plays one per hour."""
	rng = np.random.default_rng(1902)
	seconds = 6.0
	total = int(seconds * SAMPLE_RATE)
	time = np.arange(total) / SAMPLE_RATE
	fundamental = 196.0
	partials = ((1.0, 1.0, 0.55), (2.41, 0.55, 1.2), (4.07, 0.32, 2.6), (6.18, 0.16, 4.8))
	coil = np.zeros(total)
	for ratio, level, decay in partials:
		# The coil beats slowly against itself: two strands a hair apart.
		detune = 1.0 + 0.0016 * ratio
		coil += level * np.exp(-time * decay) * (
			np.sin(2.0 * np.pi * fundamental * ratio * time)
			+ 0.6 * np.sin(2.0 * np.pi * fundamental * ratio * detune * time + 0.5))
	hammer = bandpass(rng.standard_normal(total), 400.0, 2600.0) * np.exp(-time * 220.0) * 0.6
	case = np.sin(2.0 * np.pi * 118.0 * time) * np.exp(-time * 9.0) * 0.35
	attack = np.clip(time / 0.004, 0.0, 1.0)
	return normalise(one_pole_lowpass((coil + case) * attack + hammer, 3200.0), -13.0)


def render_wire_sing(loop_seconds: float = 37.0) -> np.ndarray:
	"""Wind in the telegraph wire outside (plan 7.8): an aeolian tone, never a note.

	A low fundamental that wanders a few hertz with the gusts, two thin
	partials that come and go, and a breath of air under it. The loop is long
	and its modulators share no period with it, so it does not repeat by ear.
	"""
	rng = np.random.default_rng(1891)
	total = int((loop_seconds + 2.0) * SAMPLE_RATE)
	time = np.arange(total) / SAMPLE_RATE
	gust = (
		0.55 * np.sin(2.0 * np.pi * 0.053 * time + 1.1)
		+ 0.30 * np.sin(2.0 * np.pi * 0.091 * time + 0.3)
		+ 0.15 * np.sin(2.0 * np.pi * 0.023 * time + 4.2)
	)
	gust = np.clip(0.25 + 0.75 * (gust * 0.5 + 0.5), 0.0, 1.0)
	wander = 6.0 * np.sin(2.0 * np.pi * 0.037 * time) + 2.5 * np.sin(2.0 * np.pi * 0.11 * time + 2.0)
	frequency = 138.0 + wander + 9.0 * gust
	phase = 2.0 * np.pi * np.cumsum(frequency) / SAMPLE_RATE
	partial_2 = 0.35 * (0.5 + 0.5 * np.sin(2.0 * np.pi * 0.071 * time + 0.9))
	partial_3 = 0.18 * (0.5 + 0.5 * np.sin(2.0 * np.pi * 0.047 * time + 3.3))
	tone = np.sin(phase) + partial_2 * np.sin(2.0 * phase) + partial_3 * np.sin(3.0 * phase + 0.7)
	air = bandpass(rng.standard_normal(total), 200.0, 1400.0) * 0.25
	mixed = (tone * gust + air * (0.4 + 0.6 * gust))
	return normalise(seamless(mixed, loop_seconds, 1.5), -22.0)


def render_register_whir(loop_seconds: float = 6.0) -> np.ndarray:
	"""The register's clockwork running (plan 7.11): a gear buzz on an escapement
	flutter. The game lowers its pitch and speed as the spring runs down."""
	rng = np.random.default_rng(1893)
	total = int((loop_seconds + 0.5) * SAMPLE_RATE)
	time = np.arange(total) / SAMPLE_RATE
	flutter = 0.6 + 0.4 * (np.sin(2.0 * np.pi * 18.0 * time) > 0.6)
	gears = np.sign(np.sin(2.0 * np.pi * 212.0 * time)) * 0.25 + np.sin(2.0 * np.pi * 424.0 * time) * 0.2
	gears = bandpass(gears, 150.0, 2400.0)
	grit = bandpass(rng.standard_normal(total), 1500.0, 5000.0) * 0.12
	return normalise(seamless((gears + grit) * flutter, loop_seconds, 0.4), -24.0)


def render_board(base_hz: float, seconds: float, slips: int, seed: int) -> np.ndarray:
	"""One particular board under the operator's weight (plan 7.10).

	Unlike the settling creaks, a board always says the same thing: the same
	pitch, the same number of stick-slip catches, so the room can be read by ear.
	"""
	rng = np.random.default_rng(seed)
	length = int(seconds * SAMPLE_RATE)
	time = np.arange(length) / SAMPLE_RATE
	span = time[-1]
	# The board catches and lets go `slips` times as the weight comes on.
	catches = 0.5 + 0.5 * np.cos(2.0 * np.pi * slips * time / span) ** 6
	sweep = base_hz * (1.0 + 0.25 * (time / span)) * (1.0 + 0.05 * catches)
	phase = 2.0 * np.pi * np.cumsum(sweep) / SAMPLE_RATE
	voice = np.sin(phase) + 0.55 * np.sin(2.0 * phase + 0.3) + 0.25 * np.sin(3.0 * phase)
	grain = bandpass(rng.standard_normal(length), 500.0, 3000.0) * 0.35
	envelope = np.sin(np.pi * np.clip(time / span, 0.0, 1.0)) ** 1.3 * (0.55 + 0.45 * catches)
	return normalise((voice + grain) * envelope, -16.0)


def render_headframe_groan() -> np.ndarray:
	"""The mine headframe working in the wind, far off (plan 7.2): timber and
	iron under load, a long low groan with no note in it."""
	rng = np.random.default_rng(1901)
	seconds = 3.2
	total = int(seconds * SAMPLE_RATE)
	time = np.arange(total) / SAMPLE_RATE
	frequency = 58.0 + 14.0 * np.sin(np.pi * time / seconds) + 3.0 * np.sin(2.0 * np.pi * 7.0 * time)
	phase = 2.0 * np.pi * np.cumsum(frequency) / SAMPLE_RATE
	groan = np.sin(phase) + 0.6 * np.sin(2.0 * phase) + 0.3 * np.sin(3.3 * phase)
	iron = bandpass(rng.standard_normal(total), 300.0, 1100.0) * 0.4
	envelope = np.sin(np.pi * time / seconds) ** 2.2
	return normalise(one_pole_lowpass((groan + iron) * envelope, 900.0), -16.0)


def render_switch_points() -> np.ndarray:
	"""Switch points thrown in the yard (plan 7.2): iron dragged over the chair
	plates, then the blade seating against the stock rail."""
	rng = np.random.default_rng(1902)
	seconds = 1.5
	total = int(seconds * SAMPLE_RATE)
	time = np.arange(total) / SAMPLE_RATE
	drag_span = 0.95
	drag_env = np.where(time < drag_span, np.sin(np.pi * np.clip(time / drag_span, 0.0, 1.0)) ** 1.5, 0.0)
	squeal_hz = 1650.0 + 140.0 * np.sin(2.0 * np.pi * 5.5 * time)
	squeal = np.sin(2.0 * np.pi * np.cumsum(squeal_hz) / SAMPLE_RATE) * 0.3
	scrape = bandpass(rng.standard_normal(total), 900.0, 4200.0) * 0.8
	drag = (scrape + squeal) * drag_env
	hit_time = np.clip(time - 1.0, 0.0, None)
	clunk = np.where(time >= 1.0, np.exp(-hit_time * 18.0), 0.0) * (
		np.sin(2.0 * np.pi * 140.0 * hit_time) + 0.4 * np.sin(2.0 * np.pi * 520.0 * hit_time))
	return normalise(drag + clunk * 1.4, -17.0)


def render_couplings() -> np.ndarray:
	"""A string of freight cars taking up slack somewhere down the line
	(plan 7.2): iron knuckles closing one after another, each further off."""
	rng = np.random.default_rng(1903)
	seconds = 3.4
	total = int(seconds * SAMPLE_RATE)
	time = np.arange(total) / SAMPLE_RATE
	mixed = np.zeros(total)
	at = 0.05
	for car in range(5):
		hit = np.clip(time - at, 0.0, None)
		gate = (time >= at).astype(float)
		partials = rng.uniform(280.0, 640.0)
		knock = (np.sin(2.0 * np.pi * partials * hit) + 0.5 * np.sin(2.0 * np.pi * partials * 2.63 * hit)) \
			* np.exp(-hit * 9.0) + rng.standard_normal(total) * np.exp(-hit * 60.0) * 0.4
		mixed += knock * gate * (0.85 ** car)
		at += rng.uniform(0.38, 0.62)
	return normalise(one_pole_lowpass(mixed, 1400.0), -18.0)


def render_intro_drone(seconds: float = 9.0) -> np.ndarray:
	"""The opening card's own drone (plan 7.12, replacing the temporary
	third-party cue): a low A with its fifth beating slowly against it, and the
	same wire hum the yard has, as if heard before the room is. No melody, no
	pulse, one breath in and out under the order card."""
	rng = np.random.default_rng(1890)
	total = int(seconds * SAMPLE_RATE)
	time = np.arange(total) / SAMPLE_RATE
	low = np.sin(2.0 * np.pi * 55.0 * time) + 0.55 * np.sin(2.0 * np.pi * 82.6 * time + 0.4)
	low += 0.25 * np.sin(2.0 * np.pi * 110.3 * time + 1.3)
	beat = 0.8 + 0.2 * np.sin(2.0 * np.pi * 0.31 * time)
	wander = 3.0 * np.sin(2.0 * np.pi * 0.07 * time)
	wire = np.sin(2.0 * np.pi * np.cumsum(138.0 + wander) / SAMPLE_RATE) * 0.22
	air = bandpass(rng.standard_normal(total), 120.0, 900.0) * 0.12
	envelope = np.clip(time / 1.6, 0.0, 1.0) ** 2 * np.clip((seconds - time) / 2.8, 0.0, 1.0) ** 1.5
	mixed = one_pole_lowpass((low * beat + wire + air) * envelope, 1800.0)
	return normalise(mixed, -14.0)


ONLY = {
	"intro_drone": lambda: write_wav(PROJECT_ROOT / "audio" / "music" / "intro_drone.wav", render_intro_drone()),
	"clock_tock": lambda: write_wav(AUDIO_ROOT / "foley" / "clock_tock.wav", render_clock_tock()),
	"clock_strike": lambda: write_wav(AUDIO_ROOT / "foley" / "clock_strike.wav", render_clock_strike()),
	"wire_sing": lambda: write_wav(AUDIO_ROOT / "ambience" / "wire_sing.wav", render_wire_sing()),
	"register_whir": lambda: write_wav(AUDIO_ROOT / "foley" / "register_whir.wav", render_register_whir()),
	# Plan 7.3: beds long enough that a 10-minute watch does not hear the seam.
	"wind_window": lambda: write_wav(AUDIO_ROOT / "ambience" / "wind_window.wav", render_window_wind()),
	"stove_fire": lambda: write_wav(AUDIO_ROOT / "ambience" / "stove_fire.wav", render_stove_fire()),
	# Plan 7.10: the board inside the door is low and slow, the one under the
	# window short and dry.
	"boards": lambda: (
		write_wav(AUDIO_ROOT / "foley" / "board_door.wav", render_board(88.0, 0.62, 3, 431)),
		write_wav(AUDIO_ROOT / "foley" / "board_window.wav", render_board(205.0, 0.36, 2, 432)),
	),
	# Plan 7.2: the yard, heard through the glass.
	"outside": lambda: (
		write_wav(AUDIO_ROOT / "ambience" / "outside_headframe.wav", render_headframe_groan()),
		write_wav(AUDIO_ROOT / "ambience" / "outside_switch.wav", render_switch_points()),
		write_wav(AUDIO_ROOT / "ambience" / "outside_couplings.wav", render_couplings()),
	),
}


def main() -> None:
	# `--only name [name ...]` writes just those layers: the generator must
	# never regenerate the whole bed for one new asset (AGENT_RULES §10).
	import sys
	if "--only" in sys.argv:
		for name in sys.argv[sys.argv.index("--only") + 1:]:
			ONLY[name]()
		return
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
