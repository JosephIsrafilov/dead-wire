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
