"""Synthesizes every sound effect in assets/audio/sfx/ from scratch.

    python tools/make_sfx.py

Nothing is sampled or downloaded: each sound is built from sine sweeps and
filtered noise, so the whole set can be regenerated or retuned from this file.
Needs only numpy.
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "sfx")
rng = np.random.default_rng(7)


# --- building blocks -----------------------------------------------------------

def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def sweep(f0, f1, seconds, curve=1.0, shape="sine"):
    """A tone gliding from f0 to f1. curve > 1 spends longer near f1."""
    x = t(seconds)
    k = (x / seconds) ** (1.0 / curve)
    freq = f0 + (f1 - f0) * k
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    if shape == "square":
        return np.sign(np.sin(phase)) * 0.6
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    if shape == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1.0) - 1
    return np.sin(phase)


def noise(seconds):
    return rng.uniform(-1, 1, int(RATE * seconds))


def decay(seconds, tau, attack=0.002):
    """Fast attack, exponential decay."""
    x = t(seconds)
    return np.minimum(x / attack, 1.0) * np.exp(-x / tau)


def bell(seconds, peak=0.5, sharpness=2.0):
    """Swell up to `peak` (0..1 of the length) and back down: a whoosh shape."""
    x = t(seconds) / seconds
    up = np.clip(x / peak, 0, 1) ** sharpness
    down = np.clip((1 - x) / (1 - peak), 0, 1) ** sharpness
    return np.minimum(up, down)


def band(x, lo, hi):
    """Zero-phase band-pass by shaping the spectrum with soft edges."""
    spectrum = np.fft.rfft(x)
    freq = np.fft.rfftfreq(len(x), 1 / RATE)
    gain = 1 / (1 + (lo / np.maximum(freq, 1e-6)) ** 6) / (1 + (freq / hi) ** 6)
    return np.fft.irfft(spectrum * gain, len(x))


def swept_band(x, f0, f1, q=2.5):
    """Band-pass whose centre glides from f0 to f1 (state-variable filter)."""
    n = len(x)
    centre = f0 * (f1 / f0) ** (np.arange(n) / max(1, n - 1))
    f = 2 * np.sin(np.pi * np.minimum(centre, RATE / 6.5) / RATE)
    low = band_out = 0.0
    out = np.empty(n)
    damp = 1.0 / q
    for i in range(n):
        low += f[i] * band_out
        high = x[i] - low - damp * band_out
        band_out += f[i] * high
        out[i] = band_out
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def delay(x, seconds):
    return np.concatenate([np.zeros(int(RATE * seconds)), x])


def drive(x, amount):
    return np.tanh(x * amount) / np.tanh(amount)


def save(name, x, volume=0.9):
    x = np.asarray(x, dtype=np.float64)
    # Short fade at both ends so no sound ever starts or stops with a click.
    edge = min(len(x) // 2, int(RATE * 0.004))
    x[:edge] *= np.linspace(0, 1, edge)
    x[-edge:] *= np.linspace(1, 0, edge)
    x = x / max(1e-9, np.max(np.abs(x))) * volume
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((x * 32767).astype("<i2").tobytes())
    print("%-16s %.2fs" % (name, len(x) / RATE))


def note(freq, seconds, tau, shape="tri"):
    tone = sweep(freq, freq, seconds, shape=shape)
    if shape == "square":
        tone = band(tone, 60, 3200)
    return tone * decay(seconds, tau, 0.004)


# --- combat ----------------------------------------------------------------------

def hit_light():
    crack = band(noise(0.09), 1400, 5200) * decay(0.09, 0.018)
    thump = sweep(210, 95, 0.11, 0.6) * decay(0.11, 0.035)
    return drive(mix(crack * 0.9, thump * 0.8), 1.6)


def hit_heavy():
    crack = band(noise(0.16), 500, 4200) * decay(0.16, 0.030)
    crunch = band(noise(0.26), 120, 900) * decay(0.26, 0.070)
    thump = sweep(150, 42, 0.32, 0.5) * decay(0.32, 0.090)
    return band(drive(mix(crack, crunch * 0.9, thump * 1.2), 2.4), 30, 3600)


def hit_projectile():
    pop = sweep(520, 140, 0.10, 0.5) * decay(0.10, 0.03)
    fizz = band(noise(0.14), 1800, 7000) * decay(0.14, 0.035)
    return mix(pop, fizz * 0.7)


def swing(seconds, f0, f_mid, f1, q):
    half = int(RATE * seconds * 0.45)
    x = noise(seconds)
    rising = swept_band(x[:half], f0, f_mid, q)
    falling = swept_band(x[half:], f_mid, f1, q)
    return band(np.concatenate([rising, falling]), 250, 4800) * bell(seconds, 0.42, 1.8)


def cast_fire():
    whoosh = swept_band(noise(0.36), 2600, 420, 1.6) * bell(0.36, 0.18, 1.4)
    crackle = band(noise(0.36), 3000, 9000) * (rng.random(int(RATE * 0.36)) > 0.985) * 6
    crackle = band(crackle, 2000, 9000) * decay(0.36, 0.16)
    body = sweep(190, 70, 0.30, 0.6) * decay(0.30, 0.09) * 0.5
    return band(mix(whoosh, crackle * 0.5, body), 90, 4600)


def cast_water():
    x = t(0.30)
    wobble = 1 + 0.35 * np.sin(2 * np.pi * 34 * x)
    freq = (760 * np.exp(-x * 5.5) + 180) * wobble
    blub = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * decay(0.30, 0.10, 0.006)
    splash = swept_band(noise(0.26), 5200, 1500, 1.4) * bell(0.26, 0.2, 1.3) * 0.5
    return band(mix(blub, splash), 120, 4600)


def cast_dark():
    growl = sweep(96, 48, 0.42, 0.7, "saw") * bell(0.42, 0.25, 1.2)
    growl = band(growl, 40, 900)
    hiss = swept_band(noise(0.42), 700, 2600, 2.0) * bell(0.42, 0.6, 1.6) * 0.45
    return band(drive(mix(growl, hiss), 1.8), 40, 2200)


def spike():
    rumble = band(noise(0.40), 50, 420) * decay(0.40, 0.12, 0.01)
    crack = band(noise(0.12), 900, 5200) * decay(0.12, 0.025)
    thump = sweep(120, 40, 0.30, 0.5) * decay(0.30, 0.09)
    return band(drive(mix(rumble * 1.2, delay(crack, 0.02), thump), 2.0), 30, 3000)


# --- movement --------------------------------------------------------------------

def jump():
    chirp = sweep(280, 640, 0.12, 0.7) * decay(0.12, 0.05, 0.006)
    puff = band(noise(0.08), 900, 4200) * decay(0.08, 0.02) * 0.35
    return mix(chirp, puff)


def double_jump():
    chirp = sweep(430, 980, 0.13, 0.7) * decay(0.13, 0.05, 0.006)
    air = band(swept_band(noise(0.13), 1500, 5000, 2.0), 300, 4200) * bell(0.13, 0.3, 1.5) * 0.4
    return mix(chirp, air)


def land():
    thud = sweep(130, 55, 0.12, 0.5) * decay(0.12, 0.035)
    tap = band(noise(0.07), 300, 2400) * decay(0.07, 0.016) * 0.6
    return mix(thud, tap)


def step():
    # A soft scuff: mostly low thump, a little grit, gone in a few hundredths.
    thud = sweep(150, 80, 0.05, 0.5) * decay(0.05, 0.014)
    scuff = band(noise(0.05), 500, 2600) * decay(0.05, 0.012) * 0.45
    return mix(thud, scuff)


def dash():
    return band(swept_band(noise(0.20), 900, 5200, 1.8), 300, 5200) * bell(0.20, 0.25, 1.4)


def dodge():
    shimmer = mix(sweep(1500, 620, 0.26, 0.6), sweep(1540, 640, 0.26, 0.6)) * decay(0.26, 0.09, 0.01) * 0.4
    air = band(swept_band(noise(0.26), 4200, 1200, 2.2), 300, 5200) * bell(0.26, 0.2, 1.4) * 0.6
    return mix(shimmer, air)


def ko():
    crack = band(noise(0.10), 800, 7000) * decay(0.10, 0.02)
    boom = band(noise(1.20), 30, 520) * decay(1.20, 0.34, 0.004)
    sub = sweep(105, 28, 0.9, 0.45) * decay(0.9, 0.30)
    zap = sweep(2400, 220, 0.34, 0.45, "saw") * decay(0.34, 0.10) * 0.28
    return band(drive(mix(crack, boom * 1.3, sub * 1.1, zap), 2.6), 25, 2400)


def respawn():
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = [delay(note(f, 0.34, 0.11, "sine"), i * 0.06) for i, f in enumerate(notes)]
    return mix(*parts)


# --- interface -------------------------------------------------------------------

def ui_move():
    return note(980, 0.05, 0.016)


def ui_select():
    return mix(note(660, 0.09, 0.03), delay(note(990, 0.14, 0.05), 0.055))


def ui_back():
    return mix(note(620, 0.08, 0.03), delay(note(415, 0.13, 0.05), 0.055))


def ui_lock():
    chord = mix(*[note(f, 0.34, 0.11) for f in (392.0, 587.33, 783.99)])
    snap = band(noise(0.05), 1500, 7000) * decay(0.05, 0.010) * 0.5
    return mix(chord, snap)


def count_beep():
    return mix(note(523.25, 0.20, 0.07, "square") * 0.5, note(523.25, 0.20, 0.07))


def count_go():
    chord = mix(*[note(f, 0.60, 0.20, "square") * 0.35 + note(f, 0.60, 0.20) for f in (523.25, 783.99, 1046.5)])
    burst = band(noise(0.25), 1000, 8000) * decay(0.25, 0.06) * 0.5
    return mix(chord, burst)


def win():
    melody = [(523.25, 0.0), (659.25, 0.12), (783.99, 0.24), (1046.5, 0.36), (783.99, 0.52), (1046.5, 0.64)]
    lead = [delay(note(f, 0.42, 0.14, "square") * 0.4 + note(f, 0.42, 0.14), when) for f, when in melody]
    final = delay(mix(*[note(f, 1.1, 0.42) for f in (523.25, 659.25, 783.99, 1046.5)]), 0.64)
    return mix(*lead, final * 0.7)


SOUNDS = {
    "hit_light": hit_light, "hit_heavy": hit_heavy, "hit_projectile": hit_projectile,
    "swing_light": lambda: swing(0.14, 900, 3400, 1300, 2.2),
    "swing_heavy": lambda: swing(0.26, 420, 2300, 520, 2.6),
    "cast_fire": cast_fire, "cast_water": cast_water, "cast_dark": cast_dark, "spike": spike,
    "jump": jump, "double_jump": double_jump, "land": land, "step": step, "dash": dash, "dodge": dodge,
    "ko": ko, "respawn": respawn,
    "ui_move": ui_move, "ui_select": ui_select, "ui_back": ui_back, "ui_lock": ui_lock,
    "count_beep": count_beep, "count_go": count_go, "win": win,
}

if __name__ == "__main__":
    for sound_name, build in SOUNDS.items():
        save(sound_name, build())
