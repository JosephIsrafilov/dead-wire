"""Project-authored temporary wood footstep; independent RNG, no legacy asset overwrite."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
DURATION = 0.18
OUT = Path(__file__).resolve().parents[1] / "audio/sfx/foley/footstep_wood_beta.wav"

def generate():
    rng = random.Random(189471)
    samples = []
    for index in range(int(RATE * DURATION)):
        t = index / RATE
        noise = rng.uniform(-1.0, 1.0)
        body = math.sin(2 * math.pi * 95 * t) * math.exp(-t * 34)
        contact = noise * math.exp(-t * 130) * 0.22
        sole = noise * math.sin(math.pi * t / DURATION) ** 2 * math.exp(-t * 22) * 0.07
        envelope = min(1.0, t / 0.001) * min(1.0, (DURATION - t) / 0.006)
        samples.append(int((body * 0.25 + contact + sole) * envelope * 32767))
    with wave.open(str(OUT), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(struct.pack("<%dh" % len(samples), *samples))
    print(OUT)

# Plan 7.4: five boards' worth of steps so walking never machine-guns one
# sample. Each has its own body pitch, length and, for some, a second toe
# contact. `--variants` writes only these; the beta step above is untouched.
VARIANTS = [
    # (body_hz, duration, contact_gain, toe_at or None, seed)
    (92.0, 0.18, 0.22, None, 189501),
    (104.0, 0.17, 0.25, 0.045, 189502),
    (86.0, 0.20, 0.19, None, 189503),
    (98.0, 0.19, 0.23, 0.058, 189504),
    (112.0, 0.16, 0.27, None, 189505),
]

def generate_variant(number, body_hz, duration, contact_gain, toe_at, seed):
    rng = random.Random(seed)
    samples = []
    for index in range(int(RATE * duration)):
        t = index / RATE
        noise = rng.uniform(-1.0, 1.0)
        body = math.sin(2 * math.pi * body_hz * t) * math.exp(-t * 34)
        contact = noise * math.exp(-t * 130) * contact_gain
        sole = noise * math.sin(math.pi * t / duration) ** 2 * math.exp(-t * 22) * 0.07
        toe = 0.0
        if toe_at is not None and t >= toe_at:
            toe = noise * math.exp(-(t - toe_at) * 160) * contact_gain * 0.45
        envelope = min(1.0, t / 0.001) * min(1.0, (duration - t) / 0.006)
        samples.append(int(max(-1.0, min(1.0, (body * 0.25 + contact + sole + toe) * envelope)) * 32767))
    out = OUT.with_name("footstep_wood_%d.wav" % number)
    with wave.open(str(out), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(struct.pack("<%dh" % len(samples), *samples))
    print(out)

if __name__ == "__main__":
    import sys
    if "--variants" in sys.argv:
        for number, variant in enumerate(VARIANTS, start=1):
            generate_variant(number, *variant)
    else:
        generate()
