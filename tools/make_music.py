"""Synthesize Gridiron's boss themes and encode them to .ogg (needs numpy and ffmpeg).

    python3 tools/make_music.py      (from the repo root)

Two seamless loops in the spirit of Isaac's dark synth score, built from a marching drumline:
  * The Linebacker  - 140 bpm, D minor: snare cadence, toms, low brass stabs, an organ drone
  * The Franchise   - 120 bpm, C minor: heavier drums, a choir pad, a twisted stadium-organ
                      "charge!" riff, and a distant crowd roar
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
RATE = 44100
rng = np.random.default_rng(7)


def note(n):
    """MIDI note number -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n, attack, release, total):
    t = np.arange(n) / RATE
    return np.clip(t / max(attack, 1e-4), 0, 1) * np.clip((total - t) / max(release, 1e-4), 0, 1)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def band(x, lo, hi):
    return lowpass(x, hi) - lowpass(x, lo)


# --- instruments --------------------------------------------------------------------------
def kick(length=0.35):
    n = int(RATE * length)
    t = np.arange(n) / RATE
    freq = 50 + 90 * np.exp(-t / 0.04)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / 0.18)


def snare(length=0.22, tight=1.0):
    n = int(RATE * length)
    t = np.arange(n) / RATE
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05)
    rattle = band(rng.uniform(-1, 1, n), 1500, 7000) * np.exp(-t / (0.08 * tight))
    return 0.6 * body + 1.4 * rattle


def tom(pitch, length=0.4):
    n = int(RATE * length)
    t = np.arange(n) / RATE
    freq = pitch * (1 + 0.6 * np.exp(-t / 0.03))
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / 0.2)


def cymbal(length=1.2):
    n = int(RATE * length)
    t = np.arange(n) / RATE
    noise = rng.uniform(-1, 1, n)
    return (noise - lowpass(noise, 6000)) * np.exp(-t / 0.35) * 0.35


def saw(freqs, length, attack=0.02, release=0.1, cutoff=1800, detune=0.004):
    n = int(RATE * length)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for f in freqs:
        for d in (1 - detune, 1 + detune):
            out += 2 * ((t * f * d) % 1.0) - 1
    return lowpass(out / (2 * len(freqs)), cutoff) * env(n, attack, release, length)


def organ(freqs, length):
    n = int(RATE * length)
    t = np.arange(n) / RATE
    leslie = 1 + 0.004 * np.sin(2 * np.pi * 6.2 * t)
    out = np.zeros(n)
    for f in freqs:
        for h, a in ((1, 1.0), (2, 0.5), (3, 0.25), (4, 0.18), (6, 0.08)):
            out += a * np.sin(2 * np.pi * f * h * leslie * t)
    return out / len(freqs) * env(n, 0.03, 0.08, length)


def choir(freqs, length):
    """Saw voices through 'ah' formants: a dark, wordless choir."""
    raw = saw(freqs, length, attack=0.4, release=0.6, cutoff=5000, detune=0.007)
    return band(raw, 500, 900) * 1.4 + band(raw, 1000, 1400) * 0.6


def crowd(length):
    n = int(RATE * length)
    t = np.arange(n) / RATE
    roar = band(rng.uniform(-1, 1, n), 300, 1800)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * t / length * 2) ** 2
    return roar * swell * 0.12


# --- arrangement -------------------------------------------------------------------------------
class Track:
    def __init__(self, bpm, bars):
        self.beat = 60 / bpm
        self.length = bars * 4 * self.beat
        self.buf = np.zeros(int(RATE * self.length) + RATE)

    def at(self, beat, sound, gain=1.0):
        i = int(beat * self.beat * RATE)
        n = min(len(sound), len(self.buf) - i)
        self.buf[i:i + n] += sound[:n] * gain

    def render(self, path):
        n = int(RATE * self.length)
        out = self.buf[:n].copy()
        tail = self.buf[n:n + RATE]                      # fold the tail back to the start: seamless loop
        out[:len(tail)] += tail
        out = lowpass(lowpass(out, 7500), 9000)          # tame the hiss (cymbals, rattle, saw aliasing)
        out /= np.max(np.abs(out)) / 0.85
        with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
            with wave.open(tmp.name, "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes((out * 32767).astype("<i2").tobytes())
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "4",
                            str(path)], check=True)


def drumline(track, bars, heavy=False):
    sn, k, cr = snare(), kick(), cymbal()
    for bar in range(bars):
        b = bar * 4
        for beat in (0, 2):
            track.at(b + beat, k, 0.9)
        if heavy:
            track.at(b + 1.5, k, 0.6)
            track.at(b + 3.5, k, 0.6)
        # marching cadence: accents on 2 and 4, a ruff of sixteenths at the end of each bar
        for beat in (1, 3):
            track.at(b + beat, sn, 0.8)
        for s in range(4):
            track.at(b + 3 + s * 0.25, snare(tight=0.6), 0.25 + 0.1 * s)
        if bar % 4 == 3:                                 # tom fill into the next phrase
            for i, p in enumerate((180, 150, 120, 95)):
                track.at(b + 2 + i * 0.5, tom(p), 0.7)
        if bar % 8 == 0:
            track.at(b, cr, 0.5)


def linebacker(path):
    bars = 16
    tr = Track(140, bars)
    drumline(tr, bars)
    progression = [(50, 53, 57), (50, 53, 57), (46, 50, 53), (48, 52, 55)]   # Dm Dm Bb C
    for bar in range(bars):
        chord = progression[bar % 4]
        tr.at(bar * 4, organ([note(chord[0] - 12)], tr.beat * 4), 0.35)    # low drone
        for hit in (0, 1.5, 3):                                             # brass stabs
            tr.at(bar * 4 + hit, saw([note(n) for n in chord], 0.22, cutoff=1400), 0.45)
    riff = [62, 65, 64, 62, 60, 62, 57, 0]                                  # lead brass, second half
    for bar in range(8, bars):
        for i, n in enumerate(riff):
            if n:
                tr.at(bar * 4 + i * 0.5, saw([note(n)], tr.beat * 0.45, cutoff=2400), 0.3)
    tr.render(path)


def franchise(path):
    bars = 16
    tr = Track(120, bars)
    drumline(tr, bars, heavy=True)
    progression = [(48, 51, 55), (44, 48, 51), (46, 50, 53), (43, 47, 50)]  # Cm Ab Bb G
    for bar in range(bars):
        chord = progression[bar % 4]
        tr.at(bar * 4, choir([note(n) for n in chord], tr.beat * 4), 0.5)
        tr.at(bar * 4, saw([note(chord[0] - 24)], tr.beat * 4, attack=0.01, release=0.2, cutoff=300), 0.5)
    # the stadium "charge!" riff, twisted into minor (organ), every other phrase
    charge = [(0, 55), (0.5, 60), (1, 63), (1.5, 67), (2.5, 63), (3, 67)]
    for bar in (2, 3, 6, 7, 10, 11, 14, 15):
        for beat, n in charge:
            tr.at(bar * 4 + beat, organ([note(n + 12)], tr.beat * 0.45), 0.35)
    tr.at(0, crowd(tr.length + 1), 1.0)
    tr.render(path)


def main():
    out = ROOT / "resources/music"
    out.mkdir(parents=True, exist_ok=True)
    linebacker(out / "gridiron_linebacker.ogg")
    franchise(out / "gridiron_franchise.ogg")
    for f in sorted(out.glob("gridiron_*.ogg")):
        print(f"{f.relative_to(ROOT)}  {f.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
