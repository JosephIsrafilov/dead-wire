"""Render a quiet, band-limited upright and indistinct room murmur for the street."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
BEAT = 0.62
BARS = [(48, 60, 64, 67), (48, 62, 65, 69), (45, 60, 64, 69), (43, 59, 62, 67),
        (41, 57, 60, 65), (48, 60, 64, 67), (43, 59, 62, 65), (48, 60, 64, 67)]
MELODY = [(76, 79), (81, 77), (76, 72), (74, 71), (69, 72), (76, 79), (77, 74), (72, 0)]


def render(path):
    rng = random.Random(1890)
    n = round(RATE * BEAT * 3 * len(BARS))
    samples = [0.0] * n
    for bar, notes in enumerate(BARS):
        events = [(0.0, notes[:1], .14), (1.0, notes[1:], .095), (2.0, notes[1:], .065),
                  (.05, MELODY[bar][:1], .20), (1.51, MELODY[bar][1:], .16)]
        for when, chord, gain in events:
            for note in chord:
                if not note:
                    continue
                freq = 440 * 2 ** ((note - 69) / 12)
                start = round((bar * 3 + when + rng.uniform(-.013, .013)) * BEAT * RATE)
                phase = rng.uniform(0, 6)
                for i in range(round(1.6 * RATE)):
                    t = i / RATE
                    env = min(t * 130, 1) * math.exp(-t * 5.9)
                    w = math.tau * freq * t
                    tone = (math.sin(w) + .37 * math.sin(w * 1.003 + phase)
                            + .16 * math.exp(-t * 6) * math.sin(w * 2.002))
                    samples[(start + i) % n] += gain * env * tone
    # Impersonal, low room-tone babble with moving voiced formants, not intelligible speech.
    for _ in range(47):
        start = rng.randrange(n)
        length = rng.randrange(RATE // 3, RATE * 2)
        freq = rng.uniform(87, 174)
        for i in range(length):
            t = i / RATE
            env = math.sin(math.pi * i / length) ** 1.5
            syllable = .42 + .58 * abs(math.sin(t * rng.uniform(8, 13)))
            w = math.tau * freq * t + 2.1 * math.sin(t * 3.9)
            samples[(start + i) % n] += .047 * env * syllable * (
                math.sin(w * 2) + .6 * math.sin(w * 3) + .25 * math.sin(w * 5))
    low = 0.0
    for s in samples[-120:]:
        low += .14 * (s - low)
    pcm = bytearray()
    for s in samples:
        low += .14 * (s - low)
        pcm.extend(struct.pack('<h', int(max(-1, min(1, low)) * 32767)))
    with wave.open(str(path), 'wb') as dst:
        dst.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        dst.writeframes(pcm)


if __name__ == '__main__':
    render(Path(__file__).resolve().parents[1] / 'audio/sfx/town/saloon_through_wall.wav')
