"""Writes data/maps/<id>.tres for every stage.

    python tools/make_maps.py

Layouts are designed here; the art measurements (where the walkable line sits
in each texture) come from assets/maps/maps.json, which the art pipeline writes
when it cuts the stage sheets.
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ART = json.load(open(os.path.join(ROOT, "assets", "maps", "maps.json")))

# World units: pixels at zoom 1, origin at the middle of the main floor, y up is negative.
# A single jump clears about 125 px for the heaviest fighter, so low platforms sit
# at 118 and the high one needs a double jump.
MAPS = [
    dict(id="neon", name="Neon Foundry", accent="Color(1, 0.25, 0.78, 1)", ambient="motes",
         description="A steel deck adrift above the clouds. One platform over the middle: the classic duel.",
         stage_width=940, platforms=[(0, -122, 300)]),
    dict(id="shrine", name="Sakura Shrine", accent="Color(1, 0.6, 0.72, 1)", ambient="petals",
         description="A shrine deck at sunset. Twin platforms give each side its own high ground.",
         stage_width=980, platforms=[(-290, -118, 250), (290, -118, 250)]),
    dict(id="caldera", name="Ember Caldera", accent="Color(1, 0.5, 0.13, 1)", ambient="embers",
         description="Basalt chained over a lake of fire. Three platforms stack into a tower to fight over.",
         stage_width=1000, platforms=[(-300, -118, 240), (300, -118, 240), (0, -236, 250)]),
    dict(id="frost", name="Frostfall Peak", accent="Color(0.5, 0.92, 1, 1)", ambient="snow",
         description="A broken keep under the aurora. A small floor and one platform that never stops gliding.",
         stage_width=820, platforms=[], moving=(0, -124, 240), travel=250, period=9.0),
]

TEMPLATE = """[gd_resource type="Resource" script_class="MapData" load_steps=5 format=3]

[ext_resource type="Script" path="res://data/map_data.gd" id="1_map"]
[ext_resource type="Texture2D" path="res://assets/maps/{id}/bg.jpg" id="2_bg"]
[ext_resource type="Texture2D" path="res://assets/maps/{id}/stage.png" id="3_stage"]
[ext_resource type="Texture2D" path="res://assets/maps/{id}/platform.png" id="4_platform"]

[resource]
script = ExtResource("1_map")
id = "{id}"
map_name = "{name}"
description = "{description}"
background = ExtResource("2_bg")
stage_texture = ExtResource("3_stage")
platform_texture = ExtResource("4_platform")
stage_art_line = Vector3({s_left}, {s_right}, {s_top})
platform_art_line = Vector3({p_left}, {p_right}, {p_top})
accent = {accent}
ambient = "{ambient}"
stage_width = {stage_width}.0
platforms = Array[Vector3]([{platforms}])
moving_platform = Vector3({moving})
moving_platform_travel = {travel}.0
moving_platform_period = {period}
spawn_points = PackedVector2Array({spawn}, 0, {spawn_r}, 0)
blast_zone = Rect2({bx}, -920, {bw}, 1540)
"""

os.makedirs(os.path.join(ROOT, "data", "maps"), exist_ok=True)
for m in MAPS:
    art = ART[m["id"]]
    half = m["stage_width"] / 2
    # Blast lines sit a fixed flight distance beyond the ledges.
    side = half + 720
    text = TEMPLATE.format(
        id=m["id"], name=m["name"], description=m["description"], accent=m["accent"],
        ambient=m["ambient"], stage_width=m["stage_width"],
        s_left=art["stage"]["flat_left"], s_right=art["stage"]["flat_right"], s_top=art["stage"]["top"],
        p_left=art["platform"]["flat_left"], p_right=art["platform"]["flat_right"], p_top=art["platform"]["top"],
        platforms=", ".join("Vector3(%d, %d, %d)" % p for p in m["platforms"]),
        moving="%d, %d, %d" % m.get("moving", (0, 0, 0)),
        travel=m.get("travel", 0), period=m.get("period", 8.0),
        spawn=-int(half * 0.45), spawn_r=int(half * 0.45),
        bx=-int(side), bw=int(side * 2))
    with open(os.path.join(ROOT, "data", "maps", m["id"] + ".tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", m["id"])
