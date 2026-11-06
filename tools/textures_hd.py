#!/usr/bin/env python3
"""Les TEXTURES HD de la vue 3D (128 x 128) : murs en pierre taillée et dalles.

Usage : python3 tools/textures_hd.py   (images dans assets/tiles_hd/)

- brick_wall : des moellons de pierre sombre, joints creusés, arêtes éclairées ;
- wall_cap   : le dessus des murs (grosses dalles usées) ;
- cobble_0/1 : le sol revendiqué (pavés irréguliers).
"""

import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "tiles_hd")
S = 128


def noise(rng, scale=1.0):
    base = Image.fromarray((rng.random((S // 8, S // 8)) * 255).astype("uint8")).resize((S, S), Image.BICUBIC)
    fine = Image.fromarray((rng.random((S, S)) * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(1))
    return (np.asarray(base, dtype=float) * 0.7 + np.asarray(fine, dtype=float) * 0.3) / 255.0 * scale


def stone_blocks(rng, rows, base, mortar, jitter=0.12):
    img = Image.new("RGB", (S, S), mortar)
    d = ImageDraw.Draw(img)
    h = S // rows
    tone = noise(rng)
    for r in range(rows):
        offset = rng.randint(0, S // 2) if r % 2 else 0
        x = -offset
        while x < S:
            w = rng.randint(S // 4, S // 2)
            shade = 1.0 + rng.uniform(-jitter, jitter)
            color = tuple(int(min(255, c * shade)) for c in base)
            d.rectangle([x + 2, r * h + 2, x + w - 2, r * h + h - 2], fill=color)
            d.line([(x + 2, r * h + 2), (x + w - 2, r * h + 2)], fill=tuple(min(255, int(c * 1.35)) for c in color), width=2)
            d.line([(x + 2, r * h + h - 2), (x + w - 2, r * h + h - 2)], fill=tuple(int(c * 0.6) for c in color), width=2)
            x += w
    arr = np.asarray(img, dtype=float)
    arr *= (0.8 + 0.4 * tone)[..., None]
    for _ in range(10):  # Des fissures et des taches.
        cx, cy = rng.randint(0, S - 1), rng.randint(0, S - 1)
        arr[max(0, cy - 1):cy + 1, max(0, cx - 6):cx + 6] *= 0.7
    return Image.fromarray(np.clip(arr, 0, 255).astype("uint8"))


def cobble(rng):
    img = Image.new("RGB", (S, S), (34, 26, 24))
    d = ImageDraw.Draw(img)
    tone = noise(rng)
    for gy in range(0, S, 32):
        for gx in range(0, S, 32):
            x, y = gx + rng.randint(-3, 3), gy + rng.randint(-3, 3)
            shade = rng.uniform(0.8, 1.15)
            color = tuple(int(c * shade) for c in (92, 72, 64))
            d.rounded_rectangle([x + 3, y + 3, x + 29, y + 29], radius=6, fill=color)
            d.arc([x + 4, y + 4, x + 28, y + 28], 180, 270, fill=tuple(min(255, int(c * 1.4)) for c in color), width=2)
    arr = np.asarray(img, dtype=float) * (0.8 + 0.4 * tone)[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype("uint8"))


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = random.Random(4)
    np_rng = np.random.default_rng(4)

    class R:  # Un petit mélange des deux générateurs (randint de random, random de numpy).
        randint = staticmethod(rng.randint)
        uniform = staticmethod(rng.uniform)
        random = staticmethod(np_rng.random)

    stone_blocks(R, 4, (88, 72, 66), (26, 20, 18)).save(os.path.join(OUT, "brick_wall.png"))
    stone_blocks(R, 2, (70, 60, 58), (22, 18, 16), 0.08).save(os.path.join(OUT, "wall_cap.png"))
    cobble(R).save(os.path.join(OUT, "cobble_0.png"))
    cobble(R).save(os.path.join(OUT, "cobble_1.png"))
    print("Textures HD générées dans", OUT)


if __name__ == "__main__":
    main()
