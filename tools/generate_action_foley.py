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
# The register winding handle is lower and slower than the wick wheel. Plan
# 8.3: four clicks of the ratchet, one per quarter turn of the side key, at the
# times TapeRegisterController.WIND_CLICK_SECONDS turns it (same length, so the
# shared RNG leaves every other sound byte-identical).
write('register_wind', .78, lambda t, n: sum(impact(t, n, .04 + k * .2, 520 - k * 45, 32, .14) for k in range(4)))

# --- third pass: multi-variant foley for natural physical variation (WS3.12) ---
write_samples('pen_scratch_2', filtered(.052, lambda t: math.sin(math.pi * t / .052) ** 1.4 * (.55 + .45 * math.sin(2 * math.pi * 165 * t) ** 2),
                                        2300, 6600, .85, 2101))
write_samples('pen_scratch_3', filtered(.058, lambda t: math.sin(math.pi * t / .058) ** 1.6 * (.65 + .35 * math.sin(2 * math.pi * 125 * t) ** 2),
                                        2700, 7200, .88, 2102))
write('paper_turn_2', .44, lambda t, n: n * .17 * math.sin(math.pi * t / .44) ** 2 * (.35 + .65 * math.sin(2 * math.pi * 22 * t) ** 2))
write('paper_turn_3', .48, lambda t, n: n * .16 * math.sin(math.pi * t / .48) ** 2 * (.28 + .72 * math.sin(2 * math.pi * 16 * t) ** 2))

# --- fourth pass: the room's rigid bodies and the coat ---------------------
# An enamel cup tipping onto bare boards. Enamel is thin steel with a glass
# fired onto it, so it rings high and dies fast over a wooden knock. Two hits:
# the rim as it lands, and the body settling a moment later.
write('cup_clink', .30, lambda t, n:
      impact(t, n, .006, 1650, 95, .13)
      + impact(t, n, .006, 2480, 130, .05)
      + impact(t, n, .050, 210, 30, .16)
      + impact(t, n, .104, 190, 34, .05))
# A squat glass ink bottle: duller and heavier than the cup, no ring, and it
# rocks twice because a bottle that lands upright keeps going.
write('bottle_knock', .34, lambda t, n:
      impact(t, n, .004, 420, 70, .12)
      + impact(t, n, .004, 880, 110, .04)
      + impact(t, n, .070, 165, 26, .18)
      + impact(t, n, .158, 150, 30, .06))
# Wool moving. Not a swish and not a whoosh: heavy hung cloth has no sustained
# tone at all, only a low band of noise that rises and falls with the fold, so
# this is band-passed noise whose envelope is modulated by a slow beat.
write_samples('cloth_rustle', filtered(
      .55,
      lambda t: (math.sin(math.pi * t / .55) ** 1.7) * (.35 + .65 * math.sin(2 * math.pi * 3.1 * t) ** 2),
      180, 1900, .55, 3101))

# --- fifth pass (plan 7.4): no knock twice the same ------------------------
# Appended last so the shared RNG leaves every sound above byte-identical.
# The cup lands on its base instead of its rim, then on its side and rolls.
write('cup_clink_2', .32, lambda t, n:
      impact(t, n, .005, 1520, 105, .10)
      + impact(t, n, .005, 2310, 140, .04)
      + impact(t, n, .036, 230, 34, .18)
      + impact(t, n, .121, 200, 36, .04))
write('cup_clink_3', .40, lambda t, n:
      impact(t, n, .007, 1760, 90, .12)
      + impact(t, n, .060, 1700, 120, .05)
      + impact(t, n, .062, 205, 30, .13)
      + impact(t, n, .190, 1640, 140, .03))
# The bottle lands on its shoulder; then flat with a single dull rock.
write('bottle_knock_2', .32, lambda t, n:
      impact(t, n, .004, 470, 80, .10)
      + impact(t, n, .004, 960, 120, .03)
      + impact(t, n, .052, 175, 28, .20)
      + impact(t, n, .135, 160, 32, .05))
write('bottle_knock_3', .30, lambda t, n:
      impact(t, n, .004, 390, 75, .13)
      + impact(t, n, .004, 820, 115, .04)
      + impact(t, n, .088, 150, 24, .16))

