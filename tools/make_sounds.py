"""Synthesizes the game's sounds and music into sounds/. Usage: python3 tools/make_sounds.py"""
import pathlib
import wave

import numpy as np
from scipy.signal import fftconvolve, lfilter

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parent.parent / "sounds"
RNG = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def decay(seconds, length):
    return np.exp(-t(length) / seconds)


def lowpass(signal, cutoff):
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    return lfilter([alpha], [1, alpha - 1], signal)


def reverb(signal, length=1.2, mix=0.25):
    impulse = RNG.standard_normal(int(length * RATE)) * decay(length / 5, length)
    impulse = lowpass(impulse, 3500)
    wet = fftconvolve(signal, impulse)[: len(signal) + len(impulse)]
    dry = np.concatenate([signal, np.zeros(len(wet) - len(signal))])
    wet /= max(1e-9, np.max(np.abs(wet)))
    return dry * (1 - mix) + wet * mix * np.max(np.abs(signal))


def pluck(freq, length=0.5, damp=0.12, cutoff=2500):
    """A muted note, like felt on wood: a fundamental with a quick second harmonic, soon gone."""
    x = t(length)
    tone = np.sin(2 * np.pi * freq * x) + 0.35 * np.sin(2 * np.pi * freq * 2 * x) * decay(damp / 3, length)
    return lowpass(tone * np.minimum(1, x / 0.002) * decay(damp, length), cutoff)


def knock(cutoff, length, damp):
    """An unpitched tap: a burst of filtered noise."""
    return lowpass(RNG.standard_normal(int(length * RATE)), cutoff) * decay(damp, length)


def place(signal, at, length):
    out = np.zeros(int(length * RATE))
    start = int(at * RATE)
    end = min(len(out), start + len(signal))
    out[start:end] += signal[: end - start]
    return out


def save(name, signal, peak=0.8):
    OUT.mkdir(parents=True, exist_ok=True)
    signal = signal / max(1e-9, np.max(np.abs(signal))) * peak
    fade = min(len(signal), int(0.004 * RATE))
    signal[-fade:] *= np.linspace(1, 0, fade)
    data = (signal * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def click():
    body = np.sin(2 * np.pi * 320 * t(0.06)) * decay(0.01, 0.06)
    save("ui_tap", knock(3000, 0.06, 0.004) * 0.7 + body * 0.5, 0.45)


def pick():
    x = t(0.09)
    lift = np.sin(2 * np.pi * (520 + 900 * x) * x) * decay(0.018, 0.09)
    save("pick", knock(5000, 0.09, 0.003) * 0.5 + lift * 0.6, 0.4)


def thock():
    x = t(0.18)
    body = np.sin(2 * np.pi * 170 * x) * decay(0.035, 0.18) + 0.4 * np.sin(2 * np.pi * 380 * x) * decay(0.015, 0.18)
    snap = knock(4500, 0.18, 0.003)
    save("place", (body + snap * 0.7) * np.minimum(1, x / 0.001), 0.75)


def turn():
    detent = knock(3500, 0.03, 0.003) + 0.4 * np.sin(2 * np.pi * 900 * t(0.03)) * decay(0.006, 0.03)
    save("turn", place(detent, 0, 0.1) + 0.7 * place(detent, 0.045, 0.1), 0.38)


def refuse():
    bump = np.sin(2 * np.pi * 110 * t(0.12)) * decay(0.03, 0.12) + knock(900, 0.12, 0.01) * 0.5
    save("refuse", place(bump, 0, 0.25) + 0.7 * place(bump, 0.09, 0.25), 0.55)


def wall_chime():
    out = place(pluck(587.33, 0.4, 0.07), 0, 0.5) + place(pluck(880.0, 0.4, 0.08), 0.07, 0.5)
    save("wall", reverb(out, 0.4, 0.1), 0.5)


def solve_chime():
    run = [392.0, 523.25, 659.25]
    out = sum(place(pluck(f, 0.3, 0.06), i * 0.08, 1.4) for i, f in enumerate(run))
    chord = sum(pluck(f, 1.1, 0.28, 1800) * a for f, a in ((261.63, 1.0), (392.0, 0.8), (523.25, 0.7), (659.25, 0.5)))
    out += place(chord, 0.26, 1.4)
    save("solve", reverb(out, 0.6, 0.12), 0.7)


def sparkle():
    out = place(pluck(783.99, 0.35, 0.07), 0, 0.5) + place(pluck(1046.5, 0.35, 0.08), 0.06, 0.5)
    save("unlock", reverb(out, 0.4, 0.1), 0.45)


def music():
    length, bar = 32.0, 8.0
    chords = [[130.81, 196.0, 261.63, 329.63], [110.0, 164.81, 220.0, 261.63],
              [87.31, 174.61, 220.0, 261.63], [98.0, 146.83, 196.0, 246.94]]
    x = t(bar)
    envelope = np.minimum(1, x / 3.0) * np.minimum(1, (bar - x) / 3.0)
    pad = np.zeros(int(length * RATE))
    for i, chord in enumerate(chords):
        voice = sum(np.sin(2 * np.pi * f * x + 0.2 * np.sin(2 * np.pi * 0.15 * x)) +
                    0.15 * np.sin(2 * np.pi * f * 2.002 * x) for f in chord)
        pad += place(voice * envelope, i * bar, length)
    pad = lowpass(pad, 700) * 0.5
    melody = [(2, 392.0), (6.5, 329.63), (10, 440.0), (18, 349.23), (22.5, 329.63), (26, 293.66)]
    notes = sum(place(pluck(f, 1.6, 0.35, 1200) * 0.25, at, length) for at, f in melody)
    loop = pad + notes
    tail = reverb(loop, 2.0, 0.2)
    wrapped = tail[: len(loop)].copy()
    overflow = tail[len(loop):]
    wrapped[: len(overflow)] += overflow
    save("music", wrapped, 0.45)


def main():
    click()
    pick()
    thock()
    turn()
    refuse()
    wall_chime()
    solve_chime()
    sparkle()
    music()


if __name__ == "__main__":
    main()
