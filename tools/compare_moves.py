"""Measures how alike two fighters move, so a new fighter is not an old one with
different art.

    python tools/compare_moves.py <hero>            # against every other rigged fighter
    python tools/compare_moves.py <hero> <other>    # against one

(Run from the game folder with the art kit's Python, which has numpy:
D:/pytools/venv/Scripts/python.exe. Reads data/heroes/<hero>/rig/rig.json.)

For each animation of <hero> it finds the other fighter whose animation of the
same name is most like it and prints three numbers:

    shape   how alike the BODY's choreography is, 0-100 %: do the hips, the
            spine and the legs rise, sink, lean, step and turn at the same
            moments? Bigger or smaller movements of the same kind still match,
            and so does a small difference in timing.
    body    how many degrees apart the spine, hips and legs are on average.
    arms    the same for the arms. (The weapon itself is not compared.)

and a verdict on the body:

    same    shape 85 % or more and under 10 degrees apart: the same move on
            another body, whatever the arms and the weapon are doing
    close   shape 70 % or more and under 15 degrees: the same idea, restyled
    own     anything else

An animation in which the body barely moves (an idle) is judged on the pose
alone. This is a smoke alarm, not a judge: "own" does not mean good, and two
attacks can share a body and still be told apart by what the weapon does. But a
column of "same" means the fighter was keyed from another fighter's keys.
The exit code is the number of animations marked "same" (hurt and death, which
may share a recorded fall, are not counted).
"""
import json
import os
import sys

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BODY = ["torso", "head", "pelvis", "n_thigh", "n_shin", "f_thigh", "f_shin"]
ARMS = ["n_upper_arm", "n_forearm", "f_upper_arm", "f_forearm"]
SAMPLES = 32
MOVING = 4.0          # a joint that turns less than this (degrees) is standing still
SHARED_OK = ("hurt", "death")


def load(hero):
    path = os.path.join(ROOT, "data", "heroes", hero, "rig", "rig.json")
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def sampled(values):
    values = np.asarray(values, dtype=np.float64)
    if len(values) == 1:
        return np.full(SAMPLES, values[0])
    return np.interp(np.linspace(0, len(values) - 1, SAMPLES), np.arange(len(values)), values)


def degrees_of(anim, bone):
    return np.degrees(sampled(np.unwrap(anim["theta"][bone])))


def apart(a, b, bones):
    """Mean degrees between two animations over the given joints."""
    diffs = [np.mean(np.abs((degrees_of(a, bone) - degrees_of(b, bone) + 180.0) % 360.0 - 180.0))
             for bone in bones if bone in a["theta"] and bone in b["theta"]]
    return float(np.mean(diffs)) if diffs else 999.0


def channels(anim):
    """Everything the body does over the animation: joint turns, the hips' path, a spin."""
    out = {bone: degrees_of(anim, bone) for bone in BODY if bone in anim["theta"]}
    root = np.asarray(anim["root"], dtype=np.float64)
    out["hips_x"] = sampled(root[:, 0]) * 2.0          # world px, weighted like degrees
    out["hips_y"] = sampled(root[:, 1]) * 2.0
    if anim.get("spin"):
        out["spin"] = np.degrees(sampled(anim["spin"]))
    return out


def shape(a, b):
    """How alike two bodies' choreography is, 0..1 (None when neither body moves)."""
    ca, cb = channels(a), channels(b)
    looping = a.get("loop") and b.get("loop")
    shifts = range(SAMPLES) if looping else range(-3, 4)
    total = weight = 0.0
    for key in set(ca) | set(cb):
        x, y = ca.get(key, np.zeros(SAMPLES)), cb.get(key, np.zeros(SAMPLES))
        reach_x, reach_y = np.ptp(x), np.ptp(y)
        if reach_x < MOVING and reach_y < MOVING:
            continue
        alike = 0.0
        if reach_x >= MOVING and reach_y >= MOVING:
            for shift in shifts:
                if looping:
                    xs, ys = np.roll(x, shift), y
                else:
                    xs, ys = x[max(0, shift):SAMPLES + min(0, shift)], y[max(0, -shift):SAMPLES + min(0, -shift)]
                corr = np.corrcoef(xs, ys)[0, 1]
                if not np.isnan(corr):
                    alike = max(alike, corr)
        total += alike * max(reach_x, reach_y)
        weight += max(reach_x, reach_y)
    return None if weight == 0.0 else total / weight


def verdict(alike, body):
    if alike is None:
        return "same" if body < 5.0 else "close" if body < 10.0 else "own"
    if alike >= 0.85 and body < 10.0:
        return "same"
    if alike >= 0.70 and body < 15.0:
        return "close"
    return "own"


def main(argv):
    if not argv:
        raise SystemExit(__doc__)
    mine = load(argv[0])
    if mine is None:
        raise SystemExit("no rig for %s" % argv[0])
    heroes = sorted(os.listdir(os.path.join(ROOT, "data", "heroes")))
    others = argv[1:] or [h for h in heroes if h != argv[0]]
    rigs = {h: load(h) for h in others}
    rigs = {h: r for h, r in rigs.items() if r is not None}
    print("%-13s %-6s %-17s %6s %6s %6s" % ("animation", "body", "most like", "shape", "body", "arms"))
    counts = {"same": 0, "close": 0, "own": 0}
    copied = 0
    for name, anim in mine["anims"].items():
        best = None
        for hero, rig in rigs.items():
            other = rig["anims"].get(name)
            if other is None:
                continue
            alike, body = shape(anim, other), apart(anim, other, BODY)
            score = (1.0 if alike is None else alike) * 100.0 - body * 2.0
            if best is None or score > best[0]:
                best = (score, hero, alike, body, apart(anim, other, ARMS))
        if best is None:
            print("%-13s %-6s %s" % (name, "own", "(no other fighter has it)"))
            counts["own"] += 1
            continue
        _, hero, alike, body, arms = best
        word = verdict(alike, body)
        counts[word] += 1
        if word == "same" and name not in SHARED_OK:
            copied += 1
        print("%-13s %-6s %-17s %6s %5.0f° %5.0f°" % (
            name, word, hero, "  -- " if alike is None else "%4.0f%%" % (alike * 100.0), body, arms))
    print("\n%d same, %d close, %d own" % (counts["same"], counts["close"], counts["own"]))
    return copied


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
