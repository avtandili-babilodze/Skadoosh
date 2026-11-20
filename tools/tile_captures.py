"""Tiles a folder of game screenshots into one sheet, so a whole capture run can
be looked at in a single image.

    python tools/tile_captures.py <folder of PNGs> [out.png] [--cols=4] [--crop=W,H,TOP] [--match=text]

Each screenshot is cropped to the middle of the screen, where the fighters are:
--crop gives the kept width and height as shares of the screen and the share
cut off above (default 0.44,0.5,0.2). --match keeps only the files whose name
contains the text ("heavy", "run", ...). The file name is printed on each cell.

The screenshots come from tests/tools/fighter_capture.tscn.
"""
import os
import sys

from PIL import Image, ImageDraw


def main(argv):
    folder = argv[0]
    out = os.path.join(folder, "sheet.png")
    cols, crop, match = 4, (0.44, 0.5, 0.2), ""
    for arg in argv[1:]:
        if arg.startswith("--cols="):
            cols = int(arg[7:])
        elif arg.startswith("--crop="):
            crop = tuple(float(v) for v in arg[7:].split(","))
        elif arg.startswith("--match="):
            match = arg[8:]
        else:
            out = arg
    names = sorted(n for n in os.listdir(folder)
                   if n.lower().endswith(".png") and n != os.path.basename(out) and match in n)
    if not names:
        raise SystemExit("no screenshots in %s" % folder)
    cells = []
    for name in names:
        image = Image.open(os.path.join(folder, name)).convert("RGB")
        w, h = image.size
        cw, ch = int(w * crop[0]), int(h * crop[1])
        x0, y0 = (w - cw) // 2, int(h * crop[2])
        cell = image.crop((x0, y0, x0 + cw, y0 + ch))
        ImageDraw.Draw(cell).text((8, 6), os.path.splitext(name)[0], fill=(255, 255, 255))
        cells.append(cell)
    cw, ch = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGB", (cw * cols, ch * rows), (20, 20, 26))
    for i, cell in enumerate(cells):
        sheet.paste(cell, ((i % cols) * cw, (i // cols) * ch))
    sheet.save(out)
    print("%d screenshots -> %s %s" % (len(cells), out, sheet.size))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    main(sys.argv[1:])
