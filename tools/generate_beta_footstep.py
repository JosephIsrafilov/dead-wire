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

if __name__ == "__main__":
    generate()
