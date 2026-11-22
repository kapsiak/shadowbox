"""Synthesizes the game's placeholder sounds and music into sounds/. Usage: python3 tools/make_sounds.py"""
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


def marimba(freq, length=0.9, brightness=1.0):
    x = t(length)
    tone = np.sin(2 * np.pi * freq * x) + 0.25 * brightness * np.sin(2 * np.pi * freq * 4 * x) * decay(0.05, length)
    attack = np.minimum(1, x / 0.003)
    return tone * attack * decay(length / 4, length)


def bell(freq, length=2.0):
    x = t(length)
    partials = [(1, 1.0, 0.6), (2.76, 0.4, 0.25), (5.4, 0.2, 0.12)]
    tone = sum(a * np.sin(2 * np.pi * freq * m * x) * decay(d * length, length) for m, a, d in partials)
    return tone * np.minimum(1, x / 0.004)


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
    x = t(0.05)
    tone = np.sin(2 * np.pi * 1500 * x) * decay(0.008, 0.05)
    noise = lowpass(RNG.standard_normal(len(x)), 4000) * decay(0.004, 0.05) * 0.3
    save("ui_tap", tone + noise, 0.5)


def pick():
    x = t(0.18)
    freq = 480 + 260 * x / 0.18
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    save("pick", np.sin(phase) * decay(0.05, 0.18) * np.minimum(1, x / 0.004), 0.45)


def thock():
    x = t(0.3)
    body = np.sin(2 * np.pi * 190 * x) + 0.5 * np.sin(2 * np.pi * 410 * x) * decay(0.03, 0.3)
    knock = lowpass(RNG.standard_normal(len(x)), 1800) * decay(0.008, 0.3) * 0.8
    save("place", reverb((body * decay(0.06, 0.3) + knock) * np.minimum(1, x / 0.002), 0.4, 0.15), 0.75)


def turn():
    tick = marimba(1320, 0.12, 0.5)
    save("turn", place(tick, 0, 0.2) + 0.6 * place(marimba(1760, 0.1, 0.5), 0.05, 0.2), 0.4)


def refuse():
    x = t(0.25)
    freq = 150 - 50 * x / 0.25
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    save("refuse", np.sin(phase) * decay(0.07, 0.25) * np.minimum(1, x / 0.003), 0.55)


def wall_chime():
    notes = [659.25, 987.77]
    out = sum(place(marimba(f, 1.0), i * 0.09, 1.3) for i, f in enumerate(notes))
    save("wall", reverb(out, 1.0, 0.3), 0.5)


def solve_chime():
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    out = sum(place(bell(f, 2.2) * (0.9 if i < 4 else 0.6), i * 0.11, 3.0) for i, f in enumerate(notes))
    save("solve", reverb(out, 1.6, 0.35), 0.7)


def sparkle():
    notes = [1568.0, 2093.0, 2637.0]
    out = sum(place(bell(f, 0.8) * 0.6, i * 0.06, 1.2) for i, f in enumerate(notes))
    save("unlock", reverb(out, 1.0, 0.3), 0.45)


def music():
    length, bar = 32.0, 8.0
    chords = [[261.63, 329.63, 392.0, 493.88], [220.0, 261.63, 329.63, 392.0],
              [174.61, 220.0, 261.63, 329.63], [196.0, 246.94, 293.66, 329.63]]
    x = t(bar)
    envelope = np.minimum(1, x / 2.5) * np.minimum(1, (bar - x) / 2.5)
    pad = np.zeros(int(length * RATE))
    for i, chord in enumerate(chords):
        voice = sum(np.sin(2 * np.pi * f * x + 0.3 * np.sin(2 * np.pi * 0.2 * x)) +
                    0.3 * np.sin(2 * np.pi * f * 2.003 * x) for f in chord)
        pad += place(voice * envelope, i * bar, length)
    pad = lowpass(pad, 1400) * 0.5
    melody = [(1, 783.99), (5, 659.25), (9.5, 880.0), (13, 783.99), (17, 698.46), (21, 659.25), (25.5, 587.33), (29, 659.25)]
    bells = sum(place(bell(f, 3.0) * 0.18, at, length) for at, f in melody)
    loop = pad + bells
    tail = reverb(loop, 2.5, 0.3)
    wrapped = tail[: len(loop)].copy()
    overflow = tail[len(loop):]
    wrapped[: len(overflow)] += overflow
    save("music", wrapped, 0.5)


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
