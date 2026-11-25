"""Build the Stage 1.1 window-figure horror reveal sting from real CC0 recordings.

Zero procedural oscillators or synthetic noise: mixes and pitch-shifts existing
recorded CC0 / Public Domain WAV assets already tracked in docs/third_party_assets.md:
  - audio/sfx/town/chapel_bell_toll.wav  (0.42x sub-octave dread tail)
  - audio/sfx/foley/board_door.wav        (0.52x sudden chest-drop thud)
  - audio/sfx/foley/surfaces/rail_1.wav   (0.76x cold iron spike transient)
  - audio/sfx/foley/door_hinge.wav        (0.58x organic strained iron resonance)

Run:
    python tools/build_figure_sting_audio.py
"""

from pathlib import Path
import struct
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "audio/sfx/foley/figure_window_sting.wav"
SR = 44100
DURATION = 2.40


def load_mono_wav(rel_path: str) -> tuple[np.ndarray, int]:
    path = ROOT / rel_path
    with wave.open(str(path), "rb") as wf:
        ch = wf.getnchannels()
        sw = wf.getsampwidth()
        sr = wf.getframerate()
        frames = wf.readframes(wf.getnframes())
    if sw == 2:
        data = np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32768.0
    elif sw == 4:
        data = np.frombuffer(frames, dtype="<i4").astype(np.float64) / 2147483648.0
    elif sw == 1:
        data = (np.frombuffer(frames, dtype=np.uint8).astype(np.float64) - 128.0) / 128.0
    else:
        raise ValueError(f"Unsupported sample width {sw} in {rel_path}")
    if ch > 1:
        data = data.reshape(-1, ch).mean(axis=1)
    peak = float(np.max(np.abs(data))) if len(data) else 1.0
    if peak > 1e-6:
        data /= peak
    return data, sr


def resample_rate(samples: np.ndarray, src_sr: int, speed: float, target_len: int) -> np.ndarray:
    t_out = np.arange(target_len, dtype=np.float64) / SR
    idx = t_out * (src_sr * speed)
    valid = np.clip(idx, 0.0, max(0, len(samples) - 1))
    out = np.interp(valid, np.arange(len(samples), dtype=np.float64), samples)
    out[idx >= len(samples) - 1] = 0.0
    return out


def simple_lowpass(signal: np.ndarray, cutoff_hz: float) -> np.ndarray:
    rc = 1.0 / (2.0 * np.pi * cutoff_hz)
    dt = 1.0 / SR
    alpha = dt / (rc + dt)
    out = np.empty_like(signal)
    prev = 0.0
    for i, x in enumerate(signal):
        prev = prev + alpha * (x - prev)
        out[i] = prev
    return out


def main() -> None:
    n = int(DURATION * SR)
    t = np.arange(n, dtype=np.float64) / SR

    bell, bell_sr = load_mono_wav("audio/sfx/town/chapel_bell_toll.wav")
    thud, thud_sr = load_mono_wav("audio/sfx/foley/board_door.wav")
    rail, rail_sr = load_mono_wav("audio/sfx/foley/surfaces/rail_1.wav")
    hinge, hinge_sr = load_mono_wav("audio/sfx/foley/door_hinge.wav")

    # 1) Sudden chest-drop wooden/air thump on reveal frame (0..0.45 s)
    thud_layer = resample_rate(thud, thud_sr, 0.50, n)
    thud_env = np.minimum(1.0, t / 0.008) * np.exp(-t / 0.16)
    thud_layer = simple_lowpass(thud_layer, 520.0) * thud_env * 0.72

    # 2) Sharp icy metallic spike (0..0.38 s)
    rail_layer = resample_rate(rail, rail_sr, 0.78, n)
    rail_env = np.minimum(1.0, t / 0.006) * np.exp(-t / 0.11)
    rail_layer = simple_lowpass(rail_layer, 3400.0) * rail_env * 0.42

    # 3) Deep subterranean dropped bell shroud (0..2.40 s)
    bell_trim = bell[int(0.08 * bell_sr):] if len(bell) > int(0.15 * bell_sr) else bell
    bell_layer = resample_rate(bell_trim, bell_sr, 0.42, n)
    bell_env = np.minimum(1.0, t / 0.025) * np.exp(-t / 1.05)
    bell_layer = simple_lowpass(bell_layer, 1150.0) * bell_env * 0.65

    # 4) Cold strained hinge resonance swelling slightly behind the spike (0.04..1.90 s)
    hinge_layer = np.zeros(n, dtype=np.float64)
    hinge_shift = int(0.03 * SR)
    hinge_raw = resample_rate(hinge, hinge_sr, 0.58, n - hinge_shift)
    hinge_t = np.arange(len(hinge_raw), dtype=np.float64) / SR
    hinge_env = np.minimum(1.0, hinge_t / 0.09) * np.exp(-hinge_t / 0.65)
    hinge_layer[hinge_shift:] = simple_lowpass(hinge_raw, 1800.0) * hinge_env * 0.36

    mix = thud_layer + rail_layer + bell_layer + hinge_layer

    # Remove any DC drift and shape final tail to exact silence
    mix -= np.mean(mix)
    fade_out_len = int(0.45 * SR)
    fade = np.linspace(1.0, 0.0, fade_out_len) ** 1.6
    mix[-fade_out_len:] *= fade

    # Soft saturation glue then normalize peak to -6.0 dBFS (0.501)
    mix = np.tanh(mix * 1.35)
    peak = float(np.max(np.abs(mix)))
    if peak > 1e-6:
        mix *= 0.501 / peak

    pcm = np.clip(np.round(mix * 32767.0), -32767, 32767).astype("<i2")
    with wave.open(str(OUT), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())

    rms_db = 20.0 * np.log10(float(np.sqrt(np.mean(mix * mix))) + 1e-12)
    peak_db = 20.0 * np.log10(float(np.max(np.abs(mix))) + 1e-12)
    print(f"WROTE {OUT.relative_to(ROOT)} len={DURATION:.2f}s peak={peak_db:.2f}dBFS rms={rms_db:.2f}dBFS")


if __name__ == "__main__":
    main()
