"""Synthesise the telegraph sounder's two strokes: down (click) and up (clack).

    python3 tools/generate_sounder.py

A real sounder is a brass armature striking an anvil on a hollow wooden base:
a hard transient, a short metallic ring and a woody body knock. Both tails
decay well inside one Morse unit (100 ms), so consecutive marks never smear —
timing stays the information (GDD §6-7). Deterministic: same seed, same files.
"""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'audio/sfx/telegraph'
RATE = 44100
PEAK = 10 ** (-3 / 20)  # -3 dBFS


def bandpass(signal, freq, q):
    """RBJ biquad band-pass (constant peak gain)."""
    w = 2 * math.pi * freq / RATE
    alpha = math.sin(w) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w), 1 - alpha
    out, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for x in signal:
        y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        out.append(y)
        x2, x1, y2, y1 = x1, x, y1, y
    return out


def stroke(seed, duration, rings, body, transient_gain):
    rng = random.Random(seed)
    n = int(RATE * duration)
    noise = [rng.uniform(-1, 1) for _ in range(n)]
    # Transient: a 1.5 ms burst of broadband contact noise.
    samples = [noise[i] * math.exp(-i / (RATE * 0.0015)) * transient_gain for i in range(n)]
    # Metallic ring: resonant partials excited by the hit, fast decay.
    for freq, decay, gain in rings:
        for i in range(n):
            t = i / RATE
            samples[i] += gain * math.sin(2 * math.pi * freq * t + 0.3) * math.exp(-t / decay)
    # Wooden base: band-limited knock.
    for freq, q, decay, gain in body:
        knock = bandpass([noise[i] * math.exp(-i / (RATE * 0.004)) for i in range(n)], freq, q)
        for i in range(n):
            samples[i] += gain * knock[i] * 8.0 * math.exp(-(i / RATE) / decay)
    # 0.5 ms fade-in keeps the onset click-free at sample level; 5 ms fade-out.
    for i in range(n):
        t = i / RATE
        samples[i] *= min(1.0, t / 0.0005) * min(1.0, (duration - t) / 0.005)
    top = max(abs(s) for s in samples) or 1.0
    return [s / top * PEAK for s in samples]


def write(name, samples):
    with wave.open(str(OUT / (name + '.wav')), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(b''.join(struct.pack('<h', int(s * 32767)) for s in samples))


# Down stroke: the heavier strike onto the anvil — lower, fuller body.
write('sounder_down', stroke(1894, 0.075,
                             rings=[(2350, 0.009, 0.35), (3620, 0.006, 0.22), (5100, 0.004, 0.10)],
                             body=[(210, 3.0, 0.030, 0.9), (460, 4.0, 0.022, 0.6)],
                             transient_gain=0.9))
# Up stroke: the lighter return against the back stop — brighter, thinner, 4 dB down.
up = stroke(1895, 0.055,
            rings=[(2950, 0.007, 0.30), (4400, 0.004, 0.16)],
            body=[(330, 3.5, 0.018, 0.5), (720, 4.0, 0.014, 0.35)],
            transient_gain=1.0)
write('sounder_up', [s * 10 ** (-4 / 20) for s in up])
print('wrote sounder_down.wav, sounder_up.wav')
