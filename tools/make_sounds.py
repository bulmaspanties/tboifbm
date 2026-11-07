"""Synthesize Gridiron's sound effects (stdlib only): whistle, crowd cheer and boo,
helmet clack, stadium air horn and a brass fanfare.

    python3 tools/make_sounds.py      (from the repo root)
"""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RATE = 44100


def referee_whistle(path, seconds=0.75):
    """A pea whistle: ~3 kHz tone, the pea gives a fast trill, plus some breath."""
    rng = random.Random(7)
    n = int(RATE * seconds)
    phase = 0.0
    samples = []
    for i in range(n):
        t = i / RATE
        trill = math.sin(2 * math.pi * 34 * t)                 # the pea rattling
        freq = 2950 + 160 * trill + 40 * math.sin(2 * math.pi * 5 * t)
        phase += 2 * math.pi * freq / RATE
        tone = math.sin(phase) + 0.25 * math.sin(2 * phase) + 0.08 * math.sin(3 * phase)
        am = 0.72 + 0.28 * (0.5 + 0.5 * trill)
        breath = rng.uniform(-1, 1) * 0.06
        attack = min(1.0, t / 0.025)
        release = min(1.0, (seconds - t) / 0.09)
        env = attack * release
        samples.append((tone * am * 0.42 + breath) * env)
    peak = max(abs(s) for s in samples)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.8 * 32767)) for s in samples))


def write(path, samples, level=0.8):
    peak = max(abs(x) for x in samples) or 1.0
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x / peak * level * 32767)) for x in samples))


class Biquad:
    """RBJ band-pass / low-pass filter."""
    def __init__(self, kind, freq, q=0.7):
        w0 = 2 * math.pi * freq / RATE
        alpha = math.sin(w0) / (2 * q)
        cos = math.cos(w0)
        if kind == "band":
            b = (alpha, 0.0, -alpha)
        else:
            b = ((1 - cos) / 2, 1 - cos, (1 - cos) / 2)
        a0 = 1 + alpha
        self.b = [x / a0 for x in b]
        self.a = [-2 * cos / a0, (1 - alpha) / a0]
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0

    def __call__(self, x):
        y = self.b[0] * x + self.b[1] * self.x1 + self.b[2] * self.x2 - self.a[0] * self.y1 - self.a[1] * self.y2
        self.x2, self.x1, self.y2, self.y1 = self.x1, x, self.y1, y
        return y


def envelope(t, length, attack, release):
    return min(1.0, t / attack) * max(0.0, min(1.0, (length - t) / release))


def crowd(path, seconds, voices, formants, voiced, swell, seed):
    """A stadium crowd: many voices, each a noisy (or buzzy) source through vowel formants."""
    rng = random.Random(seed)
    n = int(RATE * seconds)
    out = [0.0] * n
    for _ in range(voices):
        f1, f2 = rng.uniform(*formants[0]), rng.uniform(*formants[1])
        bp1, bp2 = Biquad("band", f1, 4), Biquad("band", f2, 5)
        start = rng.uniform(0, seconds * 0.35)
        length = rng.uniform(seconds * 0.5, seconds - start)
        pitch = rng.uniform(110, 260)
        phase = 0.0
        gain = rng.uniform(0.5, 1.0)
        for i in range(int(start * RATE), min(n, int((start + length) * RATE))):
            t = i / RATE - start
            if voiced:
                phase = (phase + (pitch * (1 + 0.03 * math.sin(2 * math.pi * 5 * t))) / RATE) % 1.0
                src = (2 * phase - 1) * 0.6 + rng.uniform(-0.3, 0.3)
            else:
                src = rng.uniform(-1, 1)
            out[i] += (bp1(src) + 0.6 * bp2(src)) * gain * envelope(t, length, 0.12, 0.35)
    room = Biquad("low", 3000)
    for i in range(n):
        t = i / RATE
        out[i] = room(out[i] + rng.uniform(-1, 1) * 0.04) * envelope(t, seconds, swell, 0.5)
    write(path, out, 0.7)


def helmet_clack(path, seconds=0.18):
    """Two hard shells colliding: a sharp click, plastic ring and a low thud."""
    rng = random.Random(3)
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        click = rng.uniform(-1, 1) * math.exp(-t / 0.004)
        ring = sum(math.sin(2 * math.pi * f * t) * a for f, a in ((1650, 0.6), (2870, 0.4), (4100, 0.25)))
        thud = math.sin(2 * math.pi * 120 * t) * 0.8
        out.append(click * 0.9 + ring * math.exp(-t / 0.028) + thud * math.exp(-t / 0.05))
    write(path, out, 0.85)


def saw_voice(freqs, seconds, attack, release, cutoff, vibrato=0.0):
    n = int(RATE * seconds)
    lp = Biquad("low", cutoff)
    phases = [0.0] * len(freqs)
    out = []
    for i in range(n):
        t = i / RATE
        v = 0.0
        for k, f in enumerate(freqs):
            f *= 1 + vibrato * math.sin(2 * math.pi * 5.5 * t)
            phases[k] = (phases[k] + f / RATE) % 1.0
            v += 2 * phases[k] - 1
        out.append(lp(v) * envelope(t, seconds, attack, release))
    return out


def air_horn(path):
    """Stadium horn: a detuned brassy chord."""
    write(path, saw_voice([233.1, 234.4, 293.7, 349.2, 466.2], 1.3, 0.04, 0.25, 2200, 0.004), 0.75)


def fanfare(path):
    """Four-note brass rise (C-E-G-C) that holds the top note."""
    notes = [(523.3, 0.13), (659.3, 0.13), (784.0, 0.13), (1046.5, 0.55)]
    out = []
    for f, length in notes:
        out += saw_voice([f, f * 1.004, f / 2], length, 0.012, 0.05 if length < 0.2 else 0.2, 3000, 0.006)
    write(path, out, 0.75)


SOUNDS = {
    "gridiron_whistle.wav": referee_whistle,
    "gridiron_cheer.wav": lambda p: crowd(p, 2.2, 36, ((500, 900), (1100, 1900)), False, 0.3, 11),
    "gridiron_boo.wav": lambda p: crowd(p, 1.8, 30, ((280, 420), (650, 900)), True, 0.25, 12),
    "gridiron_clack.wav": helmet_clack,
    "gridiron_horn.wav": air_horn,
    "gridiron_fanfare.wav": fanfare,
}


def main():
    out_dir = ROOT / "resources/sfx"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        make(out_dir / name)
        print(f"wrote resources/sfx/{name}")


if __name__ == "__main__":
    main()
