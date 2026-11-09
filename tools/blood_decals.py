#!/usr/bin/env python3
"""Les TACHES DE SANG posées au sol et sur les murs pendant les combats
(assets/fx/blood_floor_<n>.png et assets/fx/blood_wall_<n>.png, 128 x 128).

Rouge sombre presque noir au centre, plus clair et luisant sur les bords, fond
transparent. Le jeu (scripts/blood.gd) les pose au hasard, tournées, puis les
efface au bout de quelques dizaines de secondes.

Usage (depuis la racine du projet) :
    python3 tools/blood_decals.py
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx")
BIG = 512
SIZE = 128


def _blob(draw, rng, cx, cy, r, color):
    """Une goutte irrégulière (un polygone bosselé)."""
    points = []
    bumps = rng.randint(7, 12)
    phase = rng.uniform(0, math.tau)
    for k in range(48):
        a = math.tau * k / 48
        wobble = 1.0 + 0.18 * math.sin(a * bumps + phase) + rng.uniform(-0.05, 0.05)
        points.append((cx + math.cos(a) * r * wobble, cy + math.sin(a) * r * wobble))
    draw.polygon(points, fill=color)


def _finish(mask, rng):
    """Couleur : sombre au centre, rouge plus vif sur les bords, un reflet clair."""
    mask = mask.filter(ImageFilter.GaussianBlur(3))
    mask = mask.point(lambda v: 255 if v > 110 else int(v * 1.6) if v > 70 else 0)
    inner = mask.filter(ImageFilter.GaussianBlur(14))
    image = Image.new("RGBA", (BIG, BIG))
    px = image.load()
    m = mask.load()
    i = inner.load()
    for y in range(BIG):
        for x in range(BIG):
            a = m[x, y]
            if a == 0:
                continue
            depth = i[x, y] / 255.0
            r = int(185 - 75 * depth)
            g = int(10 + 14 * (1 - depth))
            b = int(14 + 12 * (1 - depth))
            px[x, y] = (r, g, b, int(a * (0.82 + 0.15 * depth)))
    return image.resize((SIZE, SIZE), Image.LANCZOS)


def floor_splat(seed):
    rng = random.Random(seed)
    mask = Image.new("L", (BIG, BIG), 0)
    draw = ImageDraw.Draw(mask)
    c = BIG / 2
    _blob(draw, rng, c, c, rng.uniform(80, 120), 255)
    # Des éclaboussures autour, et des gouttes en traînée.
    for _ in range(rng.randint(8, 14)):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(110, 220)
        _blob(draw, rng, c + math.cos(a) * d, c + math.sin(a) * d, rng.uniform(8, 26), 255)
    for _ in range(rng.randint(2, 4)):
        a = rng.uniform(0, math.tau)
        for k in range(5):
            d = 100 + k * 28
            _blob(draw, rng, c + math.cos(a) * d, c + math.sin(a) * d, 18 - k * 3, 255)
    return _finish(mask, rng)


def wall_splat(seed):
    rng = random.Random(seed)
    mask = Image.new("L", (BIG, BIG), 0)
    draw = ImageDraw.Draw(mask)
    cx, cy = BIG / 2, BIG * 0.35
    _blob(draw, rng, cx, cy, rng.uniform(70, 100), 255)
    for _ in range(rng.randint(6, 10)):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(90, 170)
        _blob(draw, rng, cx + math.cos(a) * d, cy + math.sin(a) * d * 0.7, rng.uniform(6, 18), 255)
    # Des coulures vers le bas.
    for _ in range(rng.randint(3, 6)):
        x = cx + rng.uniform(-70, 70)
        width = rng.uniform(7, 14)
        length = rng.uniform(120, 300)
        draw.rectangle((x - width / 2, cy, x + width / 2, cy + length), fill=255)
        draw.ellipse((x - width * 0.9, cy + length - width, x + width * 0.9, cy + length + width), fill=255)
    return _finish(mask, rng)


def main():
    os.makedirs(OUT, exist_ok=True)
    for n in range(4):
        floor_splat(100 + n).save(os.path.join(OUT, "blood_floor_%d.png" % n))
    for n in range(3):
        wall_splat(200 + n).save(os.path.join(OUT, "blood_wall_%d.png" % n))
    print("Taches de sang :", OUT)


if __name__ == "__main__":
    main()
