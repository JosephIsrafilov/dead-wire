"""Deterministic, quiet close-miked paper, latch, lever and stamp sounds."""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'audio/sfx/foley'
RATE = 44100
rng = random.Random(1894)

def write(name, duration, sound):
    samples = [sound(i/RATE, rng.uniform(-1, 1)) for i in range(int(RATE*duration))]
    with wave.open(str(OUT / (name+'.wav')), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(b''.join(struct.pack('<h', int(max(-.95,min(.95,x))*32767)) for x in samples))

def impact(t, noise, at, pitch, decay, gain):
    t -= at
    if t < 0:
        return 0
    attack = min(1, t * 1500)
    return gain*attack*(math.sin(2*math.pi*pitch*t)*math.exp(-t*decay) + .22*noise*math.exp(-t*100))

write('paper_turn', .46, lambda t,n: n*.18*math.sin(math.pi*t/.46)**2*(.3+.7*math.sin(2*math.pi*19*t)**2))
write('ink_stamp', .32, lambda t,n: impact(t,n,.012,110,24,.34)+impact(t,n,.095,380,60,.06))
write('route_lever', .42, lambda t,n: impact(t,n,.012,620,42,.14)+impact(t,n,.19,155,25,.25)+impact(t,n,.22,910,45,.04))
write('door_latch', .48, lambda t,n: impact(t,n,.01,360,25,.2)+impact(t,n,.13,105,18,.24)+impact(t,n,.27,210,35,.08))

# --- second pass: the actions that had no sound at all --------------------
def filtered(duration, envelope, low_hz, high_hz, gain, seed):
    """Band-limited noise (two one-pole filters) shaped by an envelope."""
    r = random.Random(seed)
    lo = math.exp(-2 * math.pi * high_hz / RATE)
    hi = math.exp(-2 * math.pi * low_hz / RATE)
    a = b = 0.0
    out = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        x = r.uniform(-1, 1)
        a = (1 - lo) * x + lo * a      # low-pass at high_hz
        b = (1 - hi) * a + hi * b      # track the lows...
        out.append(gain * envelope(t) * (a - b))  # ...and remove them: band-pass
    return out

def write_samples(name, samples):
    with wave.open(str(OUT / (name + '.wav')), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(b''.join(struct.pack('<h', int(max(-.95, min(.95, x)) * 32767)) for x in samples))

# Nib on paper: a dry 55 ms scratch with a little grain. Deliberately tiny —
# it rides far under the sounder so it can never mask Morse (GDD §7).
write_samples('pen_scratch', filtered(.055, lambda t: math.sin(math.pi * t / .055) ** 1.5 * (.6 + .4 * math.sin(2 * math.pi * 140 * t) ** 2),
                                      2500, 7000, .9, 1101))
# Telegraph key: brass contact closing under the finger, then the spring.
write('key_click', .09, lambda t, n: impact(t, n, .004, 1850, 90, .30) + impact(t, n, .006, 540, 60, .22))
# Door hinges: 1.1 s of dry iron friction, pitch drifting as the leaf swings.
write_samples('door_hinge', [math.sin(2 * math.pi * (95 + 40 * math.sin(t * 2.3)) * t) * .18 * math.sin(math.pi * t / 1.1) ** 2
                             * (.55 + .45 * math.sin(2 * math.pi * 17 * t) ** 8) + x
                             for t, x in zip([i / RATE for i in range(int(RATE * 1.1))],
                                             filtered(1.1, lambda t: math.sin(math.pi * t / 1.1) ** 2, 400, 2500, .25, 1102))])
# A finished sheet sliding across the desk to the stack.
write_samples('sheet_slide', filtered(.32, lambda t: math.sin(math.pi * t / .32) ** 2, 300, 3200, .55, 1103))
# Wick wheel: a brass thumbwheel ratcheting the wick up, five small teeth.
write('wick_turn', .62, lambda t, n: sum(impact(t, n, .03 + k * .105, 2300 - k * 90, 140, .09) for k in range(5)))
