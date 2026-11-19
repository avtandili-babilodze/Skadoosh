"""Builds every sound effect in assets/audio/sfx/ from recorded CC0 sources.

    python tools/build_sfx.py

Sources live in D:/SkadooshArt/sfx_src (see LICENSES.md there; all CC0). Each
game sound is a recipe: recorded layers (a real whoosh, blade, impact, splash,
fire crackle) trimmed, pitched and mixed, often with a synthesized low thump
from make_sfx.py underneath for weight. Most sounds get several variants
(name_1.ogg, name_2.ogg, ...); the game picks one at random each time so
repeated hits never sound stamped. Needs numpy and ffmpeg on PATH.
"""
import glob
import importlib.util
import os
import subprocess
import tempfile
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = "D:/SkadooshArt/sfx_src"
OUT = os.path.join(HERE, "..", "assets", "audio", "sfx")
RATE = 44100

_spec = importlib.util.spec_from_file_location("make_sfx", os.path.join(HERE, "make_sfx.py"))
synth = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(synth)


# --- building blocks -----------------------------------------------------------

def load(rel):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", os.path.join(SRC, rel), "-ac", "1", "-ar", str(RATE),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def trim(x, threshold_db=-40.0, keep_tail=True):
    """Cuts silence before the sound starts (and after it ends)."""
    if len(x) == 0:
        return x
    level = np.abs(x) > np.abs(x).max() * 10 ** (threshold_db / 20.0)
    idx = np.nonzero(level)[0]
    start = max(0, idx[0] - int(RATE * 0.002))
    end = idx[-1] + int(RATE * 0.02) if keep_tail else len(x)
    return x[start:end]


def window(x, start, length):
    a = int(start * RATE)
    return x[a:a + int(length * RATE)].copy()


def pitch(x, factor):
    """Resampled playback: factor > 1 is higher and shorter."""
    if abs(factor - 1.0) < 1e-6:
        return x
    n = int(len(x) / factor)
    return np.interp(np.arange(n) * factor, np.arange(len(x)), x)


def gain(x, db):
    return x * 10 ** (db / 20.0)


def norm(x, peak=1.0):
    return x / max(1e-9, np.abs(x).max()) * peak


def fade(x, out=0.04, inn=0.002):
    x = x.copy()
    a, b = int(RATE * inn), int(RATE * out)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b and b < len(x):
        x[-b:] *= np.linspace(1, 0, b) ** 2
    return x


def decay(x, tau):
    t = np.arange(len(x)) / RATE
    return x * np.exp(-t / tau)


def layer(*parts):
    """parts: (signal, offset seconds, gain dB)."""
    n = max(int(off * RATE) + len(sig) for sig, off, _ in parts)
    out = np.zeros(n)
    for sig, off, db in parts:
        a = int(off * RATE)
        out[a:a + len(sig)] += gain(sig, db)
    return out


def soft_clip(x, drive=1.3):
    return np.tanh(x * drive) / np.tanh(drive)


S = {}


def src(rel):
    if rel not in S:
        S[rel] = trim(load(rel))
    return S[rel]


# --- recipes -----------------------------------------------------------------------

def swing_light(i):
    sw = src("swishes/swish-%d.wav" % [1, 2, 3, 4][i])
    return layer((pitch(sw, 1.06), 0.0, 0), (synth.swing(0.14, 900, 3400, 1300, 2.2), 0.0, -16))


def swing_heavy(i):
    sw = src("swishes/swish-%d.wav" % [5, 7, 9, 12][i])
    return layer((pitch(sw, 0.78), 0.0, 0), (norm(src("kenney_rpg/cloth3.ogg")), 0.0, -12))


def blade_light(i):
    s = src("swords/sword.%d.ogg" % [2, 3, 4, 6][i])
    return fade(layer((s, 0.0, 0), (pitch(src("swishes/swish-%d.wav" % [1, 3, 2, 4][i]), 1.1), 0.0, -8)), 0.06)


def blade_heavy(i):
    s = src("swords/sword.%d.ogg" % [1, 5, 7, 8][i])
    return fade(layer((pitch(s, 0.86), 0.0, 0), (pitch(src("swishes/swish-%d.wav" % [6, 8, 10, 13][i]), 0.72), 0.04, -5)), 0.08)


def claw_light(i):
    return layer((pitch(src("swishes/swish-%d.wav" % [2, 4, 3][i]), 0.95), 0.0, 0),
                 (window(src("kenney_rpg/knifeSlice2.ogg"), 0.0, 0.18), 0.03, -6))


def claw_heavy(i):
    return layer((pitch(src("swishes/swish-%d.wav" % [7, 9, 11][i]), 0.7), 0.0, 0),
                 (pitch(src("kenney_rpg/knifeSlice.ogg"), 0.8), 0.05, -5),
                 (synth.band(synth.sweep(90, 45, 0.3, 0.7, "saw") * synth.bell(0.3, 0.3, 1.2), 40, 700), 0.0, -10))


def _whip(swish, crack_at, pitch_swish):
    crack = layer((src("oga100/shot_02.ogg"), 0.0, 0),
                  (synth.band(synth.noise(0.05), 2500, 9000) * synth.decay(0.05, 0.008), 0.0, -3))
    return layer((pitch(src("swishes/swish-%d.wav" % swish), pitch_swish), 0.0, -2), (crack, crack_at, 0))


def whip_light(i):
    return _whip([1, 3, 4][i], 0.07, 1.15)


def whip_heavy(i):
    return _whip([6, 9, 12][i], 0.17, 0.85)


def _thump(start_hz, end_hz, seconds, tau):
    return synth.sweep(start_hz, end_hz, seconds, 0.5) * synth.decay(seconds, tau)


def hit_light(i):
    h = src("oga100/hit_%02d.ogg" % [1, 2, 3, 4][i])
    return soft_clip(layer((norm(h), 0.0, 0), (_thump(200, 90, 0.12, 0.035), 0.0, -3)))


def hit_heavy(i):
    s = src("oga100/slam_%02d.ogg" % [2, 3, 6, 4][i])
    return soft_clip(layer((norm(s), 0.0, 0), (norm(src("oga100/hit_03.ogg")), 0.0, -4),
                           (_thump(140, 40, 0.34, 0.1), 0.0, 0)), 1.6)


def hit_blade_light(i):
    sl = window(src("kenney_rpg/knifeSlice2.ogg"), 0.0, 0.2)
    return soft_clip(layer((norm(fade(sl, 0.05)), 0.0, 0), (norm(src("oga100/hit_%02d.ogg" % [3, 1, 4][i])), 0.0, -5),
                           (_thump(190, 80, 0.12, 0.04), 0.0, -4)))


def hit_blade_heavy(i):
    return soft_clip(layer((norm(src("kenney_rpg/knifeSlice.ogg")), 0.0, -1),
                           (norm(src("oga100/slam_%02d.ogg" % [3, 6, 2][i])), 0.0, -2),
                           (norm(src("clash/sword_clash.%d.ogg" % [2, 4, 7][i])), 0.0, -10),
                           (_thump(140, 40, 0.34, 0.1), 0.0, 0)), 1.5)


def _fire_chunk(start, length):
    return decay(window(src("fire/fire_sound_effect.mp3"), start, length), length * 0.45)


def hit_fire(i):
    return soft_clip(layer((norm(_fire_chunk([0.3, 1.2, 2.1][i], 0.32)), 0.0, 0),
                           (norm(src("oga100/hit_04.ogg")), 0.0, -4), (_thump(160, 50, 0.25, 0.08), 0.0, -2)))


def hit_water(i):
    sp = window(src("oga100/splash_%02d.ogg" % [1, 2][i]), 0.0, 0.4)
    return layer((norm(fade(sp, 0.12)), 0.0, 0), (norm(src("oga100/plop_02.ogg")), 0.0, -6), (_thump(150, 60, 0.2, 0.06), 0.0, -6))


def hit_magic(i):
    m = src("magic/magical_%d.ogg" % [3, 2, 5][i])
    peak = np.argmax(np.abs(m)) / RATE
    shimmer = decay(window(m, max(0.0, peak - 0.03), 0.4), 0.16)
    return soft_clip(layer((norm(shimmer), 0.0, -2), (norm(src("oga100/hit_04.ogg")), 0.0, -3), (_thump(170, 60, 0.2, 0.06), 0.0, -3)))


def step(i):
    return src("kenney_rpg/footstep%02d.ogg" % [0, 1, 2, 3, 4][i])


def jump(i):
    return layer((norm(src("kenney_rpg/cloth%d.ogg" % [2, 1][i])), 0.0, -4), (pitch(src("swishes/swish-%d.wav" % [2, 3][i]), 1.2), 0.0, -2))


def double_jump(i):
    return layer((pitch(src("swishes/swish-%d.wav" % [11, 13][i]), 1.25), 0.0, 0),
                 (norm(src("kenney_rpg/cloth%d.ogg" % [1, 3][i])), 0.0, -8), (synth.jump() * 0.5, 0.0, -10))


def land(i):
    return soft_clip(layer((norm(src("kenney_rpg/footstep04.ogg")), 0.0, 0), (norm(src("kenney_rpg/dropLeather.ogg")), 0.0, -6),
                           (_thump([130, 115, 145][i], 50, 0.15, 0.04), 0.0, -2)))


def dash(i):
    return layer((pitch(src("swishes/swish-%d.wav" % [8, 10][i]), 0.66), 0.0, 0), (norm(src("oga100/noise_01.ogg")), 0.0, -16))


def dodge(i):
    m = src("magic/magical_5.ogg")
    return layer((norm(decay(window(m, 0.18, 0.4), 0.15)), 0.0, -2), (pitch(src("swishes/swish-3.wav"), 1.35), 0.0, -4))


def cast_fire(i):
    return layer((norm(_fire_chunk([0.5, 1.6][i], 0.5)), 0.0, 0), (synth.cast_fire(), 0.0, -5))


def cast_water(i):
    return layer((norm(fade(window(src("oga100/splash_02.ogg"), 0.0, 0.42), 0.12)), 0.0, 0),
                 (pitch(src("swishes/swish-%d.wav" % [5, 6][i]), 0.9), 0.0, -4))


def cast_dark(i):
    return soft_clip(layer((norm(src("oga100/weird_05.ogg")), 0.0, -1), (norm(src("oga100/weird_04.ogg")), 0.05, -5), (synth.cast_dark(), 0.0, -6)))


def spike(i):
    return soft_clip(layer((norm(src("oga100/slam_03.ogg")), 0.0, 0), (synth.spike(), 0.0, -2)), 1.5)


def ko(i):
    return soft_clip(layer((norm(src("oga100/explosion.ogg")), 0.0, 0), (norm(src("oga100/slam_06.ogg")), 0.0, -4), (synth.ko(), 0.0, -2)), 1.8)


def respawn(i):
    m = src("magic/magical_3.ogg")
    return fade(window(m, 0.0, 1.1), 0.35)


def ui(name):
    return lambda i: src("kenney_ui/%s.ogg" % name)


def count_go(i):
    return layer((synth.count_go(), 0.0, -2), (norm(src("oga100/gong_01.ogg")), 0.0, -6))


RECIPES = {
    "swing_light": (swing_light, 4), "swing_heavy": (swing_heavy, 4),
    "blade_light": (blade_light, 4), "blade_heavy": (blade_heavy, 4),
    "claw_light": (claw_light, 3), "claw_heavy": (claw_heavy, 3),
    "whip_light": (whip_light, 3), "whip_heavy": (whip_heavy, 3),
    "hit_light": (hit_light, 4), "hit_heavy": (hit_heavy, 4),
    "hit_blade_light": (hit_blade_light, 3), "hit_blade_heavy": (hit_blade_heavy, 3),
    "hit_fire": (hit_fire, 3), "hit_water": (hit_water, 2), "hit_magic": (hit_magic, 3),
    "step": (step, 5), "jump": (jump, 2), "double_jump": (double_jump, 2), "land": (land, 3),
    "dash": (dash, 2), "dodge": (dodge, 1),
    "cast_fire": (cast_fire, 2), "cast_water": (cast_water, 2), "cast_dark": (cast_dark, 1),
    "spike": (spike, 1), "ko": (ko, 1), "respawn": (respawn, 1),
    "ui_move": (ui("tick_002"), 1), "ui_select": (ui("confirmation_001"), 1),
    "ui_back": (ui("back_002"), 1), "ui_lock": (ui("confirmation_002"), 1),
    "count_beep": (lambda i: synth.count_beep(), 1), "count_go": (count_go, 1),
    "win": (lambda i: synth.win(), 1),
}

# Loudness each sound is mastered to (peak), so hits sit above swings and steps
# sit under everything without per-call volume juggling.
PEAKS = {"step": 0.45, "jump": 0.6, "double_jump": 0.6, "land": 0.7, "dash": 0.6, "dodge": 0.6,
         "swing_light": 0.7, "swing_heavy": 0.8, "blade_light": 0.75, "blade_heavy": 0.85,
         "claw_light": 0.75, "claw_heavy": 0.85, "whip_light": 0.8, "whip_heavy": 0.9,
         "ui_move": 0.5, "ui_select": 0.6, "ui_back": 0.6, "ui_lock": 0.7}


def save(name, x, peak):
    x = fade(np.asarray(x, dtype=np.float64), 0.01)
    x = norm(x, peak)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "s.wav")
        with wave.open(wav_path, "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(RATE)
            f.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "6",
                        os.path.join(OUT, name + ".ogg")], check=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for old in glob.glob(os.path.join(OUT, "*")):
        if old.endswith((".wav", ".ogg", ".wav.import", ".ogg.import")):
            os.remove(old)
    total = 0
    for name, (recipe, count) in RECIPES.items():
        peak = PEAKS.get(name, 0.92)
        for i in range(count):
            label = name if count == 1 else "%s_%d" % (name, i + 1)
            save(label, recipe(i), peak)
            total += 1
    print("built %d sound files for %d sounds" % (total, len(RECIPES)))


if __name__ == "__main__":
    main()
