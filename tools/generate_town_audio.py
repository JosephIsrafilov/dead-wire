"""Deterministic 1890 Colorado town & boarding-house audio generator for M2-A."""

from pathlib import Path
import wave
import numpy as np


OUT_DIR = Path(__file__).resolve().parent.parent / "audio" / "sfx" / "town"
SR = 44100
RNG = np.random.default_rng(1890)


def write_wav(name: str, samples: np.ndarray, gain: float = 0.85) -> None:
    peak = float(np.max(np.abs(samples)))
    if peak > 1e-6:
        samples = samples / peak * gain
    pcm = np.clip(samples * 32767.0, -32768, 32767).astype(np.int16)
    with wave.open(str(OUT_DIR / name), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())


def smooth_noise(n: int, cutoff_passes: int = 10) -> np.ndarray:
    x = RNG.standard_normal(n).astype(np.float64)
    kernel = np.ones(7, dtype=np.float64) / 7.0
    for _ in range(cutoff_passes):
        x = np.convolve(x, kernel, mode="same")
    return x


def loop_crossfade(arr: np.ndarray, fade_sec: float = 0.6) -> np.ndarray:
    k = int(fade_sec * SR)
    if k * 2 >= len(arr):
        return arr
    out = arr[:-k].copy()
    alpha = np.linspace(0.0, 1.0, k)
    out[:k] = arr[:k] * alpha + arr[-k:] * (1.0 - alpha)
    return out


def make_wind(dur: float, warmth: float) -> np.ndarray:
    n = int((dur + 0.6) * SR)
    t = np.linspace(0.0, dur + 0.6, n, endpoint=False)
    gust = 0.55 + 0.45 * np.sin(2.0 * np.pi * 0.22 * t) * np.sin(2.0 * np.pi * 0.09 * t + 0.7)
    low = smooth_noise(n, 24) * 0.75
    mid = smooth_noise(n, 6) * (0.28 + warmth * 0.18)
    bed = (low + mid) * gust
    return loop_crossfade(bed)


def add_bird_chirp(buf: np.ndarray, start_s: float, f0: float, f1: float, dur_s: float, amp: float) -> None:
    i0 = int(start_s * SR)
    m = int(dur_s * SR)
    if i0 + m >= len(buf):
        return
    t = np.linspace(0.0, dur_s, m, endpoint=False)
    freq = np.linspace(f0, f1, m) + np.sin(2.0 * np.pi * 18.0 * t) * 140.0
    phase = np.cumsum(2.0 * np.pi * freq / SR)
    env = np.sin(np.pi * t / dur_s) ** 1.6
    buf[i0 : i0 + m] += np.sin(phase) * env * amp


def make_day_ambience() -> np.ndarray:
    bed = make_wind(10.0, 0.35) * 0.55
    for st, f0, f1, d in [
        (1.1, 2100.0, 2900.0, 0.11),
        (1.26, 2500.0, 3200.0, 0.09),
        (4.4, 1850.0, 2450.0, 0.13),
        (7.8, 2300.0, 1900.0, 0.12),
        (7.96, 2400.0, 3100.0, 0.10),
    ]:
        add_bird_chirp(bed, st, f0, f1, d, 0.06)
    return bed


def make_creek_rush() -> np.ndarray:
    n = int(6.6 * SR)
    t = np.linspace(0.0, 6.6, n, endpoint=False)
    broad = smooth_noise(n, 2) * 0.55
    low_rumble = smooth_noise(n, 18) * 0.70
    bubble_mod = 0.70 + 0.30 * np.sin(2.0 * np.pi * 1.8 * t + smooth_noise(n, 30) * 3.0)
    return loop_crossfade((broad + low_rumble) * bubble_mod)


def make_boarding_room_tone() -> np.ndarray:
    n = int(8.6 * SR)
    air = smooth_noise(n, 28) * 0.18
    for sec in range(8):
        pos = int((sec + 0.25) * SR)
        tick = np.exp(-np.arange(900) / 140.0) * np.sin(2.0 * np.pi * (1200.0 if sec % 2 == 0 else 980.0) * np.arange(900) / SR)
        air[pos : pos + 900] += tick * 0.12
    return loop_crossfade(air)


def make_gravel_step(idx: int) -> np.ndarray:
    dur = 0.24
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, endpoint=False)
    env = np.exp(-t * 20.0) * (1.0 - np.exp(-t * 220.0))
    crunch = smooth_noise(n, 1) * env
    thud = np.sin(2.0 * np.pi * (95.0 + idx * 11.0) * t) * np.exp(-t * 34.0) * 0.65
    grit = RNG.standard_normal(n) * np.exp(-((t - 0.045) ** 2) / 0.0005) * 0.35
    return crunch + thud + grit


def make_splash() -> np.ndarray:
    dur = 1.1
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, endpoint=False)
    env = np.exp(-t * 4.5) * (1.0 - np.exp(-t * 45.0))
    water = smooth_noise(n, 2) * env
    drops = np.zeros(n)
    for dt in [0.18, 0.29, 0.42, 0.56, 0.72]:
        i0 = int(dt * SR)
        m = 1800
        if i0 + m < n:
            tt = np.arange(m) / SR
            drops[i0 : i0 + m] += np.sin(2.0 * np.pi * (950.0 + dt * 400.0) * tt) * np.exp(-tt * 28.0) * 0.25
    return water + drops


def make_bed_creak() -> np.ndarray:
    dur = 1.35
    n = int(dur * SR)
    t = np.linspace(0.0, dur, n, endpoint=False)
    cloth = smooth_noise(n, 3) * np.sin(np.pi * t / dur) * 0.45
    spring = (
        np.sin(2.0 * np.pi * 240.0 * t + np.sin(2.0 * np.pi * 6.0 * t) * 4.0)
        * np.exp(-((t - 0.35) ** 2) / 0.025)
        * 0.35
    )
    spring += np.sin(2.0 * np.pi * 310.0 * t) * np.exp(-((t - 0.72) ** 2) / 0.02) * 0.25
    return cloth + spring


def make_morning_birds() -> np.ndarray:
    n = int(2.2 * SR)
    buf = smooth_noise(n, 20) * 0.08
    for st, f0, f1, d in [
        (0.15, 2100.0, 2850.0, 0.14),
        (0.32, 2600.0, 3300.0, 0.12),
        (0.75, 1950.0, 2600.0, 0.15),
        (1.12, 2400.0, 3150.0, 0.13),
        (1.30, 2800.0, 2250.0, 0.12),
        (1.68, 2200.0, 3050.0, 0.16),
    ]:
        add_bird_chirp(buf, st, f0, f1, d, 0.35)
    return buf * np.sin(np.pi * np.linspace(0.0, 1.0, n))


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_wav("dawn_mountain_wind.wav", make_wind(8.0, 0.0), 0.55)
    write_wav("day_town_ambience.wav", make_day_ambience(), 0.55)
    write_wav("creek_rush_loop.wav", make_creek_rush(), 0.65)
    write_wav("boarding_room_tone.wav", make_boarding_room_tone(), 0.45)
    for i in range(1, 4):
        write_wav(f"footstep_gravel_{i}.wav", make_gravel_step(i), 0.75)
    write_wav("water_splash_basin.wav", make_splash(), 0.75)
    write_wav("bed_creak_sleep.wav", make_bed_creak(), 0.75)
    write_wav("morning_birds_wake.wav", make_morning_birds(), 0.70)
    print(f"Generated {len(list(OUT_DIR.glob('*.wav')))} town audio WAVs in {OUT_DIR}")


if __name__ == "__main__":
    main()
