"""The dawn train's three sounds (plan 4.6), deterministic, stdlib only.

Writes ONLY audio/sfx/train/{train_whistle,train_rumble,train_steam}.wav;
nothing else is touched.

    .venv-tools/Scripts/python.exe tools/generate_train_audio.py
"""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'audio/sfx/train'
RATE = 44100


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(b''.join(struct.pack('<h', int(max(-.95, min(.95, x)) * 32767)) for x in samples))


def band_noise(duration, low_hz, high_hz, seed):
    """Band-limited noise from two one-pole filters."""
    r = random.Random(seed)
    lo = math.exp(-2 * math.pi * high_hz / RATE)
    hi = math.exp(-2 * math.pi * low_hz / RATE)
    a = b = 0.0
    out = []
    for _ in range(int(RATE * duration)):
        x = r.uniform(-1, 1)
        a = (1 - lo) * x + lo * a
        b = (1 - hi) * a + hi * b
        out.append(a - b)
    return out


# A three-chime steam whistle: a soft attack, a held chord, a falling tail.
def whistle():
    duration = 2.6
    breath = band_noise(duration, 900, 4000, 1885)
    out = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        env = min(1.0, t / 0.18) * (1.0 if t < 1.9 else math.exp(-(t - 1.9) * 5.0))
        sag = 1.0 - 0.012 * max(0.0, t - 1.9)
        chord = sum(math.sin(2 * math.pi * f * sag * t) for f in (392.0, 493.9, 587.3)) / 3.0
        out.append(0.42 * env * (0.82 * chord + 0.5 * breath[i]))
    return out


# Wheels on jointed rail: a low roll with a clack-clack every rail length.
# Four seconds that loop: the clacks fall on a 0.5 s grid.
def rumble():
    duration = 4.0
    roll = band_noise(duration, 35, 220, 1890)
    out = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        phase = t % 0.5
        clack = 0.0
        for at in (0.0, 0.09):
            d = phase - at
            if d >= 0.0:
                clack += math.sin(2 * math.pi * 140 * d) * math.exp(-d * 38.0)
        out.append(0.55 * roll[i] * 3.0 + 0.32 * clack)
    return out


# A long release of steam at a stand: hiss swelling and dying.
def steam():
    duration = 2.8
    hiss = band_noise(duration, 1400, 7000, 1871)
    return [0.5 * hiss[i] * math.sin(math.pi * (i / RATE) / duration) ** 0.8 for i in range(len(hiss))]


write('train_whistle', whistle())
write('train_rumble', rumble())
write('train_steam', steam())
print('wrote', OUT)
