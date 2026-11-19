"""Points a hero's hero.tres at its live rig (data/heroes/<hero>/rig/rig.json).

    python tools/wire_rig.py <hero folder>

Adds the JSON ext_resource and `rig = ExtResource(...)` right after the
resource's `script` line (where Godot expects exported properties to start).
Running it again changes nothing.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def wire(hero):
    path = os.path.join(ROOT, "data", "heroes", hero, "hero.tres")
    rig_path = "res://data/heroes/%s/rig/rig.json" % hero
    if not os.path.exists(os.path.join(ROOT, "data", "heroes", hero, "rig", "rig.json")):
        raise SystemExit("no rig.json for %s: export it first" % hero)
    text = open(path, encoding="utf-8").read()
    if 'path="%s"' % rig_path in text and "\nrig = ExtResource(" in text:
        print(hero, "already wired")
        return
    rig_id = "90_rig"
    m = re.search(r"load_steps=(\d+)", text)
    if m:
        text = text.replace(m.group(0), "load_steps=%d" % (int(m.group(1)) + 1), 1)
    first = text.index("[ext_resource")
    text = text[:first] + '[ext_resource type="JSON" path="%s" id="%s"]\n' % (rig_path, rig_id) + text[first:]
    start = text.index("[resource]\n")
    script_end = text.index("\n", text.index("script = ", start)) + 1
    text = text[:script_end] + 'rig = ExtResource("%s")\n' % rig_id + text[script_end:]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(hero, "wired to", rig_path)


if __name__ == "__main__":
    for name in sys.argv[1:]:
        wire(name)
