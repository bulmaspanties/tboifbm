"""Synthesize Gridiron's sound effects (stdlib only).

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


def main():
    out = ROOT / "resources/sfx/gridiron_whistle.wav"
    out.parent.mkdir(parents=True, exist_ok=True)
    referee_whistle(out)
    print(f"wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
