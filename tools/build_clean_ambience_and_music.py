"""Build clean car/fan-free town ambience beds, haunting dark-ambient music, and
visceral shock sting strictly from verified CC0 / Public Domain sources on disk.

Run:
    .venv-tools/Scripts/python.exe tools/build_clean_ambience_and_music.py
"""
from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[1]
SR = 44100


def read_wav(rel_path: str) -> np.ndarray:
    """Read WAV as mono float32 array normalized to [-1, 1] at SR."""
    p = ROOT / rel_path
    with wave.open(str(p), "rb") as wf:
        ch = wf.getnchannels()
        sw = wf.getsampwidth()
        fr = wf.getframerate()
        n = wf.getnframes()
        raw = wf.readframes(n)
    if sw == 2:
        data = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    elif sw == 4:
        data = np.frombuffer(raw, dtype="<i4").astype(np.float32) / 2147483648.0
    else:
        raise ValueError(f"Unsupported sample width {sw} in {rel_path}")
    if ch > 1:
        data = data.reshape(-1, ch).mean(axis=1)
    if fr != SR:
        new_len = int(round(len(data) * SR / fr))
        data = signal.resample(data, new_len).astype(np.float32)
    return data


def write_wav(rel_path: str, audio: np.ndarray) -> None:
    """Write mono (1D) or stereo (N, 2) float32 array to 16-bit PCM WAV."""
    out = ROOT / rel_path
    out.parent.mkdir(parents=True, exist_ok=True)
    arr = np.asarray(audio, dtype=np.float32)
    arr = np.clip(arr, -0.999, 0.999)
    pcm = np.round(arr * 32767.0).astype("<i2")
    if pcm.ndim == 1:
        ch = 1
        interleaved = pcm.tobytes()
    else:
        ch = pcm.shape[1]
        interleaved = pcm.reshape(-1).tobytes()
    with wave.open(str(out), "wb") as wf:
        wf.setnchannels(ch)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(interleaved)
    print(f"WROTE {rel_path} ({len(arr) / SR:.1f}s, ch={ch})")


def sos_filter(data: np.ndarray, kind: str, cutoff, order: int = 4) -> np.ndarray:
    sos = signal.butter(order, cutoff, btype=kind, fs=SR, output="sos")
    if data.ndim == 1:
        return signal.sosfiltfilt(sos, data).astype(np.float32)
    cols = [signal.sosfiltfilt(sos, data[:, c]).astype(np.float32) for c in range(data.shape[1])]
    return np.column_stack(cols)


def notch_60hz(data: np.ndarray) -> np.ndarray:
    """Strip 60 Hz & 120 Hz mains/fan harmonics cleanly."""
    out = data.astype(np.float64, copy=True)
    for freq, q in ((60.0, 6.0), (120.0, 8.0)):
        b, a = signal.iirnotch(freq, q, fs=SR)
        if out.ndim == 1:
            out = signal.filtfilt(b, a, out)
        else:
            for c in range(out.shape[1]):
                out[:, c] = signal.filtfilt(b, a, out[:, c])
    return out.astype(np.float32)


def pitch_shift(data: np.ndarray, semitones: float) -> np.ndarray:
    ratio = 2.0 ** (-semitones / 12.0)
    new_len = max(16, int(round(len(data) * ratio)))
    xp = np.linspace(0.0, len(data) - 1, len(data), dtype=np.float64)
    xnew = np.linspace(0.0, len(data) - 1, new_len, dtype=np.float64)
    return np.interp(xnew, xp, data).astype(np.float32)


def paulstretch(src: np.ndarray, stretch: float, win_size: int = 8192, seed: int = 19) -> np.ndarray:
    """Lush granular spectral stretch preserving timbre while erasing periodicity."""
    rng = np.random.default_rng(seed)
    x = np.asarray(src, dtype=np.float32)
    if len(x) < win_size:
        x = np.pad(x, (0, win_size - len(x)))
    half = win_size // 2
    window = np.hanning(win_size).astype(np.float32)
    win_norm = window * math.sqrt(2.0 / 3.0)

    hop_out = half
    hop_in = hop_out / max(stretch, 1.0)
    num_frames = int(math.floor((len(x) - win_size) / max(hop_in, 1.0))) + 1
    out_len = (num_frames - 1) * hop_out + win_size
    out = np.zeros(out_len, dtype=np.float64)
    norm_buf = np.zeros(out_len, dtype=np.float64)

    for i in range(num_frames):
        pos = int(round(i * hop_in))
        chunk = x[pos : pos + win_size]
        if len(chunk) < win_size:
            chunk = np.pad(chunk, (0, win_size - len(chunk)))
        spec = np.fft.rfft(chunk * window)
        mag = np.abs(spec)
        phases = rng.uniform(0.0, 2.0 * math.pi, size=len(mag))
        phases[0] = 0.0
        phases[-1] = 0.0
        synth = np.fft.irfft(mag * np.exp(1j * phases), n=win_size)
        o_pos = i * hop_out
        out[o_pos : o_pos + win_size] += synth * win_norm
        norm_buf[o_pos : o_pos + win_size] += win_norm * win_norm
    mask = norm_buf > 1e-8
    out[mask] /= norm_buf[mask]
    return out.astype(np.float32)


def make_loop(buf: np.ndarray, target_sec: float, fade_sec: float = 2.8) -> np.ndarray:
    """Seamless equal-power cosine crossfade loop of exact duration."""
    n_target = int(round(target_sec * SR))
    n_fade = int(round(fade_sec * SR))
    if len(buf) < n_target + n_fade:
        reps = int(math.ceil((n_target + n_fade) / len(buf))) + 1
        tiled = [buf]
        for k in range(1, reps):
            tiled.append(np.flip(buf, axis=0) if k % 2 == 1 else buf)
        buf = np.concatenate(tiled, axis=0)
    body = buf[:n_target].copy()
    tail = buf[n_target : n_target + n_fade]
    t = np.linspace(0.0, math.pi * 0.5, n_fade, dtype=np.float32)
    fade_in = np.sin(t)
    fade_out = np.cos(t)
    if body.ndim == 2:
        fade_in = fade_in[:, None]
        fade_out = fade_out[:, None]
    body[:n_fade] = body[:n_fade] * fade_in + tail * fade_out
    return body.astype(np.float32)


def norm_rms(buf: np.ndarray, target_rms_db: float, max_peak_db: float = -2.0) -> np.ndarray:
    rms = float(np.sqrt(np.mean(np.square(buf.astype(np.float64)))))
    if rms < 1e-8:
        return buf
    cur_db = 20.0 * math.log10(rms)
    gain = 10.0 ** ((target_rms_db - cur_db) / 20.0)
    out = buf * gain
    peak = float(np.max(np.abs(out)))
    max_amp = 10.0 ** (max_peak_db / 20.0)
    if peak > max_amp:
        out = out * (max_amp / peak)
    return out.astype(np.float32)


def dark_reverb(mono_or_stereo: np.ndarray, rt60_sec: float = 2.8, seed: int = 7) -> np.ndarray:
    """Convolve with a dark wooden/stone impulse for spacious 1890s dread."""
    rng = np.random.default_rng(seed)
    n_ir = int(round(rt60_sec * SR))
    t = np.arange(n_ir, dtype=np.float32) / SR
    ir_l = rng.normal(0.0, 1.0, n_ir).astype(np.float32) * np.exp(-6.9 * t / rt60_sec)
    ir_r = rng.normal(0.0, 1.0, n_ir).astype(np.float32) * np.exp(-6.9 * t / rt60_sec)
    # Remove immediate click impulse & roll off brittle highs
    ir_l[: int(0.015 * SR)] *= 0.25
    ir_r[: int(0.015 * SR)] *= 0.25
    ir_l = sos_filter(ir_l, "lowpass", 2600.0, order=2)
    ir_r = sos_filter(ir_r, "lowpass", 2400.0, order=2)
    ir_l /= max(float(np.sqrt(np.sum(ir_l * ir_l))), 1e-6)
    ir_r /= max(float(np.sqrt(np.sum(ir_r * ir_r))), 1e-6)
    if mono_or_stereo.ndim == 1:
        wet_l = signal.fftconvolve(mono_or_stereo, ir_l, mode="full")[: len(mono_or_stereo)]
        wet_r = signal.fftconvolve(mono_or_stereo, ir_r, mode="full")[: len(mono_or_stereo)]
        dry = mono_or_stereo * 0.45
        return np.column_stack([dry + wet_l * 0.55, dry + wet_r * 0.55]).astype(np.float32)
    wet_l = signal.fftconvolve(mono_or_stereo[:, 0], ir_l, mode="full")[: len(mono_or_stereo)]
    wet_r = signal.fftconvolve(mono_or_stereo[:, 1], ir_r, mode="full")[: len(mono_or_stereo)]
    return (mono_or_stereo * 0.45 + np.column_stack([wet_l, wet_r]) * 0.55).astype(np.float32)


def build_clean_town_beds() -> None:
    wind = read_wav("audio/sfx/ambience/wind_window.wav")
    room = read_wav("audio/sfx/ambience/room_tone.wav")
    wire = read_wav("audio/sfx/ambience/wire_sing.wav")
    creek = read_wav("audio/sfx/town/creek_rush_loop.wav")
    birds = read_wav("audio/sfx/town/morning_birds_wake.wav")
    creak2 = read_wav("audio/sfx/foley/floor_creak_2.wav")

    # 1) boarding_room_tone.wav: ZERO 60Hz fan, ZERO traffic! Quiet wooden house air.
    r_clean = notch_60hz(sos_filter(room, "bandpass", [95.0, 2600.0], order=3))
    w_muffled = notch_60hz(sos_filter(wind, "bandpass", [130.0, 620.0], order=3))
    w_r = np.roll(w_muffled, len(w_muffled) // 3)
    # Subtle distant beam settle from slowed recorded timber creak
    creak_slow = sos_filter(pitch_shift(creak2, -10.0), "lowpass", 420.0, order=2)
    house_bed_l = make_loop(r_clean, 36.0, 2.5) * 0.65 + make_loop(w_muffled, 36.0, 2.5) * 0.35
    house_bed_r = make_loop(np.roll(r_clean, 17000), 36.0, 2.5) * 0.65 + make_loop(w_r, 36.0, 2.5) * 0.35
    house_st = np.column_stack([house_bed_l, house_bed_r])
    for t_sec, pan_l, pan_r, amp in ((8.5, 0.7, 0.3, 0.08), (23.0, 0.3, 0.7, 0.06)):
        idx = int(t_sec * SR)
        end = min(idx + len(creak_slow), len(house_st))
        seg = creak_slow[: end - idx]
        house_st[idx:end, 0] += seg * pan_l * amp
        house_st[idx:end, 1] += seg * pan_r * amp
    house_st = norm_rms(notch_60hz(sos_filter(house_st, "highpass", 88.0, order=3)), -25.0, -9.0)
    write_wav("audio/sfx/town/boarding_room_tone.wav", house_st)

    # 2) dawn_mountain_wind.wav: Clean alpine ridge wind (no 40-170Hz urban car rumble).
    wl1 = sos_filter(wind, "bandpass", [185.0, 3200.0], order=3)
    wl2 = sos_filter(pitch_shift(wind, -2.5), "bandpass", [170.0, 1800.0], order=3)
    wr1 = np.roll(wl1, SR * 11)
    wr2 = sos_filter(pitch_shift(wind, +1.8), "bandpass", [210.0, 2400.0], order=3)
    wire_faint = sos_filter(wire, "bandpass", [220.0, 950.0], order=2)
    dawn_l = make_loop(wl1, 40.0, 3.0) * 0.60 + make_loop(wl2, 40.0, 3.0) * 0.36 + make_loop(wire_faint, 40.0, 3.0) * 0.06
    dawn_r = make_loop(wr1, 40.0, 3.0) * 0.60 + make_loop(wr2, 40.0, 3.0) * 0.36 + make_loop(np.roll(wire_faint, 22000), 40.0, 3.0) * 0.06
    dawn_st = norm_rms(sos_filter(np.column_stack([dawn_l, dawn_r]), "highpass", 175.0, order=3), -23.0, -7.0)
    write_wav("audio/sfx/town/dawn_mountain_wind.wav", dawn_st)

    # 3) saloon_window_wind.wav: Mono clean mountain gust at saloon glass.
    sal_w = sos_filter(
        make_loop(wl1, 24.0, 2.2) * 0.65 + make_loop(wl2, 24.0, 2.2) * 0.35,
        "bandpass", [180.0, 1050.0], order=3,
    )
    sal_w = norm_rms(sal_w, -28.0, -10.0)
    write_wav("audio/sfx/town/saloon_window_wind.wav", sal_w)

    # 4) day_town_ambience.wav: Mountain valley morning — crisp breeze + distant stream + clean birdsong.
    breeze_l = make_loop(sos_filter(wind, "bandpass", [210.0, 2800.0], order=3), 32.0, 2.5) * 0.48
    breeze_r = make_loop(np.roll(sos_filter(wind, "bandpass", [210.0, 2800.0], order=3), SR * 7), 32.0, 2.5) * 0.48
    creek_d = make_loop(sos_filter(creek, "bandpass", [340.0, 3400.0], order=3), 32.0, 2.5) * 0.22
    day_st = np.column_stack([breeze_l + creek_d * 0.85, breeze_r + creek_d * 1.0])
    bird_clean = sos_filter(birds, "highpass", 1300.0, order=3)
    rng = np.random.default_rng(1890)
    for t_sec in (2.4, 7.8, 13.5, 19.2, 24.8, 29.0):
        semi = float(rng.uniform(-2.0, 2.5))
        chirp = pitch_shift(bird_clean, semi) * float(rng.uniform(0.28, 0.52))
        fade = min(int(0.18 * SR), len(chirp) // 3)
        chirp[:fade] *= np.linspace(0.0, 1.0, fade, dtype=np.float32)
        chirp[-fade:] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)
        idx = int(t_sec * SR)
        end = min(idx + len(chirp), len(day_st))
        pan = float(rng.uniform(0.2, 0.85))
        day_st[idx:end, 0] += chirp[: end - idx] * pan
        day_st[idx:end, 1] += chirp[: end - idx] * (1.0 - pan)
    day_st = norm_rms(sos_filter(day_st, "highpass", 190.0, order=3), -24.0, -7.0)
    write_wav("audio/sfx/town/day_town_ambience.wav", day_st)


def build_music_and_sting() -> None:
    bell = read_wav("audio/sfx/town/chapel_bell_toll.wav")
    strike = read_wav("audio/sfx/foley/clock_strike.wav")
    headframe = read_wav("audio/sfx/ambience/outside_headframe.wav")
    couplings = read_wav("audio/sfx/ambience/outside_couplings.wav")
    wire = read_wav("audio/sfx/ambience/wire_sing.wav")
    wind = read_wav("audio/sfx/ambience/wind_window.wav")

    # Paulstretched spectral building blocks (100% derived from real recordings on disk)
    bell_low = paulstretch(pitch_shift(bell, -12.0), 14.0, win_size=8192, seed=101)
    bell_tritone = paulstretch(pitch_shift(bell, -6.0), 14.0, win_size=8192, seed=102)
    bell_fifth = paulstretch(pitch_shift(bell, -5.0), 14.0, win_size=8192, seed=103)
    strike_dark = paulstretch(pitch_shift(strike, -9.0), 6.0, win_size=8192, seed=104)
    iron_groan = paulstretch(pitch_shift(headframe, -7.0), 8.0, win_size=8192, seed=105)
    wire_ghost = paulstretch(pitch_shift(wire, 0.0), 2.0, win_size=8192, seed=106)

    # 5) menu_dread_ambient.wav (48 s, haunting oppressive 1890s frontier gothic drone)
    dur = 48.0
    t = np.linspace(0.0, dur, int(dur * SR), endpoint=False, dtype=np.float32)
    lfo_a = 0.55 + 0.45 * np.sin(2.0 * math.pi * t / 24.0)
    lfo_b = 0.50 + 0.50 * np.sin(2.0 * math.pi * t / 16.0 + 1.4)
    lfo_c = np.clip(np.sin(2.0 * math.pi * t / 48.0 - 0.5), 0.0, 1.0) ** 1.6

    bed_l = (
        make_loop(sos_filter(bell_low, "lowpass", 650.0, 2), dur, 3.5) * 0.52
        + make_loop(sos_filter(strike_dark, "bandpass", [65.0, 900.0], 2), dur, 3.5) * (0.28 * lfo_a)
        + make_loop(sos_filter(bell_tritone, "bandpass", [140.0, 1200.0], 2), dur, 3.5) * (0.22 * lfo_c)
        + make_loop(sos_filter(iron_groan, "bandpass", [180.0, 1600.0], 2), dur, 3.5) * (0.18 * lfo_b)
        + make_loop(sos_filter(wire_ghost, "bandpass", [480.0, 2600.0], 2), dur, 3.5) * (0.14 * lfo_a)
    )
    bed_r = (
        make_loop(np.roll(sos_filter(bell_low, "lowpass", 650.0, 2), 31000), dur, 3.5) * 0.52
        + make_loop(np.roll(sos_filter(strike_dark, "bandpass", [65.0, 900.0], 2), 27000), dur, 3.5) * (0.28 * lfo_a)
        + make_loop(make_loop(sos_filter(bell_fifth, "bandpass", [140.0, 1200.0], 2), dur, 3.5), dur, 3.5) * (0.20 * (1.0 - lfo_c))
        + make_loop(np.roll(sos_filter(iron_groan, "bandpass", [180.0, 1600.0], 2), 45000), dur, 3.5) * (0.18 * (1.0 - lfo_b))
        + make_loop(np.roll(sos_filter(wire_ghost, "bandpass", [480.0, 2600.0], 2), 19000), dur, 3.5) * (0.14 * lfo_b)
    )
    menu_st = np.column_stack([bed_l, bed_r])

    # Add 3 mournful distant wet chapel-bell motifs across the 48s loop (strictly dark & eerie)
    motif_times_semitones = [
        (4.0, -7.0, 0.20),
        (10.5, -6.0, 0.17),   # eerie tritone step
        (26.0, -12.0, 0.22),
        (33.5, -11.0, 0.16),  # haunting half-step rub
    ]
    for ts, semi, amp in motif_times_semitones:
        note = sos_filter(pitch_shift(bell, semi), "lowpass", 1500.0, 2)
        n_f = min(int(0.35 * SR), len(note) // 3)
        note[:n_f] *= np.linspace(0.0, 1.0, n_f, dtype=np.float32)
        note[-n_f:] *= np.linspace(1.0, 0.0, n_f, dtype=np.float32)
        idx = int(ts * SR)
        end = min(idx + len(note), len(menu_st))
        menu_st[idx:end, 0] += note[: end - idx] * amp * 0.85
        menu_st[idx:end, 1] += note[: end - idx] * amp

    menu_st = dark_reverb(menu_st, rt60_sec=3.2, seed=41)
    menu_st = make_loop(menu_st, dur, 3.5)
    menu_st = sos_filter(notch_60hz(menu_st), "highpass", 46.0, 2)
    menu_st = norm_rms(menu_st, -19.5, -3.5)
    write_wav("audio/music/menu_dread_ambient.wav", menu_st)

    # 6) watch_dread_ambient.wav (56 s, ultra-restrained night watch tension; deeply notched 1.1..4.8 kHz!)
    wdur = 56.0
    wt = np.linspace(0.0, wdur, int(wdur * SR), endpoint=False, dtype=np.float32)
    wlfo = 0.55 + 0.45 * np.sin(2.0 * math.pi * wt / 28.0)
    wb_l = (
        make_loop(sos_filter(bell_low, "lowpass", 420.0, 3), wdur, 4.0) * 0.56
        + make_loop(sos_filter(strike_dark, "bandpass", [55.0, 480.0], 3), wdur, 4.0) * (0.34 * wlfo)
        + make_loop(sos_filter(iron_groan, "bandpass", [90.0, 620.0], 3), wdur, 4.0) * (0.20 * (1.0 - wlfo))
        + make_loop(sos_filter(wind, "bandpass", [180.0, 520.0], 3), wdur, 4.0) * 0.14
    )
    wb_r = (
        make_loop(np.roll(sos_filter(bell_low, "lowpass", 420.0, 3), 41000), wdur, 4.0) * 0.56
        + make_loop(np.roll(sos_filter(strike_dark, "bandpass", [55.0, 480.0], 3), 23000), wdur, 4.0) * (0.34 * wlfo)
        + make_loop(np.roll(sos_filter(iron_groan, "bandpass", [90.0, 620.0], 3), 55000), wdur, 4.0) * (0.20 * wlfo)
        + make_loop(np.roll(sos_filter(wind, "bandpass", [180.0, 520.0], 3), 31000), wdur, 4.0) * 0.14
    )
    watch_st = dark_reverb(np.column_stack([wb_l, wb_r]), rt60_sec=2.6, seed=42)
    # GDD §7: Strip telegraph band (1100-4800 Hz) so sounder stays razor-clear!
    watch_st = sos_filter(watch_st, "bandstop", [1100.0, 4800.0], order=4)
    watch_st = sos_filter(notch_60hz(watch_st), "highpass", 48.0, 2)
    watch_st = make_loop(watch_st, wdur, 4.0)
    watch_st = norm_rms(watch_st, -25.0, -8.0)
    write_wav("audio/music/watch_dread_ambient.wav", watch_st)

    # 7) intro_drone.wav (10.0 s mono one-shot for IntroCard, LOOP_DISABLED!)
    idur = 10.0
    ni = int(idur * SR)
    it = np.linspace(0.0, idur, ni, endpoint=False, dtype=np.float32)
    env = np.minimum(1.0, it / 1.2) * np.minimum(1.0, (idur - it) / 2.4)
    env = env * env
    idrone = (
        bell_low[:ni] * 0.55
        + strike_dark[:ni] * 0.32
        + sos_filter(wire_ghost[:ni], "bandpass", [200.0, 1400.0], 2) * 0.18
    )
    bell_open = sos_filter(pitch_shift(bell, -7.0), "lowpass", 1400.0, 2)
    idrone[: len(bell_open)] += bell_open * 0.25
    idrone = dark_reverb(idrone, rt60_sec=2.4, seed=43).mean(axis=1) * env
    idrone = norm_rms(sos_filter(idrone, "highpass", 46.0, 2), -20.0, -4.0)
    write_wav("audio/music/intro_drone.wav", idrone)

    # 8) figure_window_sting.wav (2.6 s visceral shock reveal, -1.2 dBFS peak!)
    sdur = 2.6
    ns = int(sdur * SR)
    st = np.linspace(0.0, sdur, ns, endpoint=False, dtype=np.float32)
    attack = np.minimum(1.0, st / 0.008)
    decay_fast = np.exp(-st / 0.55)
    decay_tail = np.exp(-st / 1.15) * np.minimum(1.0, (sdur - st) / 0.45)

    # Punchy strike + dissonant bowed-iron shriek + chest thump
    hit_bell = pitch_shift(bell, -12.0)
    hit_metal = pitch_shift(couplings, +7.0)
    shriek_a = sos_filter(pitch_shift(headframe, +14.0), "bandpass", [700.0, 4200.0], 2)
    shriek_b = sos_filter(pitch_shift(headframe, +15.0), "bandpass", [850.0, 4600.0], 2)  # minor-2nd clash!
    sub_thump = sos_filter(strike, "lowpass", 220.0, 3)

    sting = np.zeros(ns, dtype=np.float32)
    for src, wt, env_arr in (
        (sub_thump, 0.85, decay_fast),
        (hit_bell, 0.65, decay_tail),
        (hit_metal, 0.55, decay_fast),
        (shriek_a, 0.50, decay_tail),
        (shriek_b, 0.48, decay_tail),
    ):
        n = min(len(src), ns)
        sting[:n] += src[:n] * wt * env_arr[:n]
    sting = dark_reverb(sting, rt60_sec=1.6, seed=99).mean(axis=1) * attack * np.minimum(1.0, (sdur - st) / 0.35)
    # Guarantee crisp punchy transient at start & normalize to -1.2 dBFS peak
    sting[: min(len(hit_metal), ns)] += hit_metal[: min(len(hit_metal), ns)] * 0.22 * attack[: min(len(hit_metal), ns)]
    peak = float(np.max(np.abs(sting)))
    if peak > 1e-6:
        sting = sting * (10.0 ** (-1.2 / 20.0) / peak)
    write_wav("audio/sfx/foley/figure_window_sting.wav", sting)


def main() -> None:
    build_clean_town_beds()
    build_music_and_sting()
    print("ALL_CLEAN_AUDIO_AND_MUSIC_BUILT")


if __name__ == "__main__":
    main()
