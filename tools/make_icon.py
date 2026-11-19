"""Draws the game icon (icon.png): a gold S punched out of the logo's impact burst.

    python tools/make_icon.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SIZE = 256
SS = 4                      # draw large, then shrink for clean edges
INK = (13, 11, 20, 255)
HOT = (255, 61, 110, 255)
CORAL = (255, 115, 82, 255)
GOLD = (255, 207, 58, 255)


def burst(radius, inner, spikes, seed, spin=0.0):
    rng = random.Random(seed)
    centre = SIZE * SS / 2
    points = []
    for i in range(spikes * 2):
        angle = spin + math.tau * i / (spikes * 2)
        reach = radius * rng.uniform(0.9, 1.0) if i % 2 == 0 else inner * rng.uniform(0.95, 1.05)
        points.append((centre + math.cos(angle) * reach * SS, centre + math.sin(angle) * reach * SS))
    return points


image = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)
draw.polygon(burst(126, 92, 14, 5), fill=INK)
draw.polygon(burst(116, 86, 14, 5), fill=HOT)
draw.polygon(burst(92, 66, 14, 5, 0.12), fill=CORAL)

font = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "Bangers-Regular.ttf"), 190 * SS)
letter = Image.new("RGBA", image.size, (0, 0, 0, 0))
pen = ImageDraw.Draw(letter)
box = pen.textbbox((0, 0), "S", font=font)
at = ((image.width - (box[2] - box[0])) / 2 - box[0], (image.height - (box[3] - box[1])) / 2 - box[1])
pen.text((at[0] + 5 * SS, at[1] + 7 * SS), "S", font=font, fill=(0, 0, 0, 150),
         stroke_width=11 * SS, stroke_fill=(0, 0, 0, 150))
pen.text(at, "S", font=font, fill=GOLD, stroke_width=11 * SS, stroke_fill=INK)
letter = letter.rotate(7, resample=Image.BICUBIC)
image.alpha_composite(letter)
image.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(ROOT, "icon.png"))
print("icon.png written")
