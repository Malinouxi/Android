"""Pixel art 32 x 32 : tuiles du sol et des murs, et coffres du Trésor.

Utilisé par tools/generate_art.py (lancer ce script-là). Les tuiles sont
fabriquées avec du « bruit » lissé (des variations douces, comme de la matière),
puis réduit à quelques couleurs pour garder un vrai rendu pixel art. On ajoute
ensuite les détails à la main : cailloux, pépites, fissures, joints, motifs...

Toutes les tuiles se raccordent sans couture avec leurs voisines (le bruit
« boucle » sur les bords).
"""

import os
import random

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
S = 32  # Taille des nouvelles images.


def rgb(value, alpha=255):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def save(image, *parts):
    path = os.path.join(ASSETS, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)


# ---------------------------------------------------------------------------
# Briques de base
# ---------------------------------------------------------------------------

def value_noise(rng, cells):
    """Bruit lissé qui boucle : une grille de valeurs au hasard, interpolée."""
    grid = np.array([[rng.random() for _ in range(cells)] for _ in range(cells)])
    out = np.zeros((S, S))
    for y in range(S):
        for x in range(S):
            gx, gy = x * cells / S, y * cells / S
            x0, y0 = int(gx), int(gy)
            fx, fy = gx - x0, gy - y0
            fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)  # adoucissement
            a = grid[y0 % cells][x0 % cells]
            b = grid[y0 % cells][(x0 + 1) % cells]
            c = grid[(y0 + 1) % cells][x0 % cells]
            d = grid[(y0 + 1) % cells][(x0 + 1) % cells]
            out[y][x] = (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
    return out


def fractal_noise(rng, octaves=((4, 0.6), (8, 0.3), (16, 0.1))):
    total = sum(weight for _, weight in octaves)
    return sum(value_noise(rng, cells) * weight for cells, weight in octaves) / total


def quantize(noise, palette):
    """Transforme un bruit (0..1) en image, avec une couleur par tranche de valeurs."""
    image = Image.new("RGBA", (S, S))
    low, high = noise.min(), noise.max()
    for y in range(S):
        for x in range(S):
            level = (noise[y][x] - low) / max(high - low, 1e-6)
            index = min(int(level * len(palette)), len(palette) - 1)
            image.putpixel((x, y), rgb(palette[index]))
    return image


def bevel(image, light, dark, width=1):
    """Bord clair en haut à gauche, sombre en bas à droite : un bloc en relief."""
    for i in range(S):
        for w in range(width):
            image.putpixel((i, w), rgb(light))
            image.putpixel((w, i), rgb(light))
            image.putpixel((i, S - 1 - w), rgb(dark))
            image.putpixel((S - 1 - w, i), rgb(dark))
    return image


def pebble(image, x, y, w, h, base, light, dark):
    """Un petit caillou ovale, éclairé par le haut à gauche."""
    draw = ImageDraw.Draw(image)
    draw.ellipse([x, y, x + w, y + h], fill=rgb(base))
    draw.point([(x + 1, y + 1)], fill=rgb(light))
    draw.line([(x + 1, y + h), (x + w - 1, y + h)], fill=rgb(dark))


def outline(image, color):
    """Contour d'un pixel autour de tout ce qui n'est pas transparent."""
    result = image.copy()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            if image.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < width and 0 <= ny < height and image.getpixel((nx, ny))[3] > 0:
                    result.putpixel((x, y), rgb(color))
                    break
    return result


# ---------------------------------------------------------------------------
# Tuiles
# ---------------------------------------------------------------------------

EARTH = ["#4a3220", "#5a3d27", "#6b4a2f", "#7a5636", "#8a6440"]
ROCK = ["#2e2e36", "#393943", "#454550", "#52525e", "#62626f"]


def earth_tile(rng):
    image = quantize(fractal_noise(rng), EARTH)
    for _ in range(rng.randint(4, 6)):
        w, h = rng.randint(2, 4), rng.randint(1, 3)
        pebble(image, rng.randint(2, S - 7), rng.randint(2, S - 6), w, h, "#8d7a68", "#b0a08e", "#4a3a2d")
    # Une petite racine sombre.
    draw = ImageDraw.Draw(image)
    x, y = rng.randint(4, 24), rng.randint(4, 24)
    for _ in range(6):
        nx, ny = x + rng.choice([-1, 0, 1]), y + 1
        draw.line([(x, y), (nx, ny)], fill=rgb("#3a2618"))
        x, y = nx, ny
    return bevel(image, "#9a734c", "#2e1f13")


def gold_tile(rng):
    image = earth_tile(rng)
    draw = ImageDraw.Draw(image)
    for _ in range(rng.randint(3, 4)):
        x, y = rng.randint(3, S - 9), rng.randint(3, S - 9)
        # Une pépite : forme irrégulière, ombre, reflet et éclat blanc.
        draw.polygon([(x + 1, y), (x + 4, y), (x + 5, y + 2), (x + 4, y + 4), (x + 1, y + 4), (x, y + 2)],
                     fill=rgb("#f2b632"))
        draw.line([(x + 1, y + 4), (x + 4, y + 4), (x + 5, y + 2)], fill=rgb("#8a5d14"))
        draw.line([(x + 1, y + 1), (x + 3, y + 1)], fill=rgb("#ffe27a"))
        draw.point([(x + 2, y + 1)], fill=rgb("#ffffff"))
    return image


def rock_tile(rng):
    image = quantize(fractal_noise(rng, ((3, 0.6), (8, 0.3), (16, 0.1))), ROCK)
    draw = ImageDraw.Draw(image)
    for _ in range(2):  # Deux fissures qui serpentent.
        x, y = rng.randint(4, S - 5), rng.randint(2, 6)
        while y < S - 4:
            nx = max(2, min(S - 3, x + rng.choice([-1, 0, 0, 1])))
            draw.line([(x, y), (nx, y + 2)], fill=rgb("#1e1e24"))
            draw.point([(nx + 1, y + 1)], fill=rgb("#6e6e7c"))
            x, y = nx, y + 2
    for _ in range(8):  # Quelques reflets minéraux.
        draw.point([(rng.randint(2, S - 3), rng.randint(2, S - 3))], fill=rgb("#8a8a9a"))
    return bevel(image, "#77778a", "#1c1c22")


def flagstones(rng, mortar, shades, highlight, shadow):
    """Des dalles de tailles variées, chacune avec sa teinte, un reflet et une ombre."""
    image = Image.new("RGBA", (S, S), rgb(mortar))
    draw = ImageDraw.Draw(image)
    rows = [(0, 10), (10, 11), (21, 11)]
    for row, (top, height) in enumerate(rows):
        x = -rng.randint(0, 6) if row % 2 else 0
        while x < S:
            width = rng.randint(9, 13)
            left, right = max(x + 1, 0), min(x + width - 1, S - 1)
            bottom = top + height - 1
            if right > left:
                draw.rectangle([left, top + 1, right, bottom], fill=rgb(rng.choice(shades)))
                draw.line([(left, top + 1), (right, top + 1)], fill=rgb(highlight))
                draw.line([(left, bottom), (right, bottom)], fill=rgb(shadow))
                if rng.random() < 0.3:  # Une petite fêlure.
                    cx = rng.randint(left, right)
                    draw.line([(cx, top + 3), (cx + rng.choice([-2, 2]), top + 6)], fill=rgb(shadow))
            x += width
    # Grain de la pierre.
    for _ in range(40):
        px, py = rng.randint(0, S - 1), rng.randint(0, S - 1)
        if image.getpixel((px, py))[:3] != rgb(mortar)[:3]:
            draw.point([(px, py)], fill=rgb(shadow))
    return image


def floor_tile(rng):
    return flagstones(rng, "#15110f", ["#2b2622", "#2f2925", "#28231f"], "#3d352e", "#1f1a17")


def claimed_tile(rng, with_emblem):
    image = flagstones(rng, "#140c0e", ["#3a2226", "#40262b", "#352022"], "#5a333c", "#26161a")
    if with_emblem:
        # L'emblème du donjon : un losange à cornes.
        draw = ImageDraw.Draw(image)
        cx, cy = 16, 16
        draw.polygon([(cx, cy - 4), (cx + 4, cy), (cx, cy + 4), (cx - 4, cy)], outline=rgb("#8a3442"))
        draw.line([(cx - 4, cy - 4), (cx - 2, cy - 2)], fill=rgb("#8a3442"))
        draw.line([(cx + 4, cy - 4), (cx + 2, cy - 2)], fill=rgb("#8a3442"))
        draw.point([(cx, cy)], fill=rgb("#c2495c"))
    return image


def room_treasury():
    image = Image.new("RGBA", (S, S), rgb("#3e3118"))
    draw = ImageDraw.Draw(image)
    for ty in range(0, S, 8):
        for tx in range(0, S, 8):
            shade = "#5a4a22" if (tx + ty) // 8 % 2 == 0 else "#4f4020"
            draw.rectangle([tx + 1, ty + 1, tx + 7, ty + 7], fill=rgb(shade))
            draw.line([(tx + 1, ty + 1), (tx + 6, ty + 1)], fill=rgb("#7a6530"))
            draw.point([(tx + 4, ty + 4)], fill=rgb("#8a7232"))
    return image


def room_lair():
    image = Image.new("RGBA", (S, S), rgb("#3d2f4d"))
    draw = ImageDraw.Draw(image)
    for y in range(S):
        for x in range(S):
            if (x + y) % 4 == 0 or (x - y) % 8 == 0:
                draw.point([(x, y)], fill=rgb("#4a3a5e"))
    draw.rectangle([1, 1, S - 2, S - 2], outline=rgb("#5e4a78"))
    draw.rectangle([3, 3, S - 4, S - 4], outline=rgb("#2c2238"))
    return image


def room_farm(rng):
    image = quantize(fractal_noise(rng), ["#2a1e14", "#33251a", "#3b2b1e"])
    draw = ImageDraw.Draw(image)
    for row in range(4, S, 8):  # Des sillons de mousse.
        draw.line([(0, row), (S - 1, row)], fill=rgb("#2c4630"))
        for x in range(rng.randint(0, 3), S, 4):
            draw.point([(x, row - 1)], fill=rgb("#4f7a3a"))
            draw.point([(x + 1, row - 2)], fill=rgb("#6b9a4a"))
    return image


def room_library(rng):
    image = Image.new("RGBA", (S, S), rgb("#2a1c12"))
    draw = ImageDraw.Draw(image)
    for top in range(0, S, 6):  # Des lattes de parquet.
        offset = rng.randint(0, 15)
        draw.rectangle([0, top + 1, S - 1, top + 5], fill=rgb("#5a3d27"))
        draw.line([(0, top + 1), (S - 1, top + 1)], fill=rgb("#6b4a2f"))
        for x in range(offset, S, 16):
            draw.line([(x, top + 1), (x, top + 5)], fill=rgb("#2a1c12"))
        for _ in range(3):
            gx = rng.randint(0, S - 4)
            draw.line([(gx, top + 3), (gx + 3, top + 3)], fill=rgb("#4a3220"))
    return image


def room_workshop():
    image = Image.new("RGBA", (S, S), rgb("#2c2a28"))
    draw = ImageDraw.Draw(image)
    for ty in range(0, S, 16):
        for tx in range(0, S, 16):
            draw.rectangle([tx + 1, ty + 1, tx + 14, ty + 14], fill=rgb("#47423c"))
            draw.line([(tx + 1, ty + 1), (tx + 14, ty + 1)], fill=rgb("#5e5850"))
            for gy in range(ty + 4, ty + 13, 3):  # Une grille d'aération.
                draw.line([(tx + 4, gy), (tx + 11, gy)], fill=rgb("#2c2a28"))
            for rx, ry in ((tx + 2, ty + 2), (tx + 13, ty + 2), (tx + 2, ty + 13), (tx + 13, ty + 13)):
                draw.point([(rx, ry)], fill=rgb("#8a8278"))
    return image


def room_training():
    image = Image.new("RGBA", (S, S), rgb("#2e1712"))
    draw = ImageDraw.Draw(image)
    for row, top in enumerate(range(0, S, 5)):
        offset = 0 if row % 2 == 0 else 5
        for x in range(-offset, S, 10):
            draw.rectangle([x + 1, top + 1, x + 9, top + 4], fill=rgb("#5e352a" if (x // 10 + row) % 3 else "#6b3e30"))
            draw.line([(x + 1, top + 1), (x + 9, top + 1)], fill=rgb("#7a4a38"))
    return image


def room_prison(rng):
    image = quantize(fractal_noise(rng), ["#1e1e22", "#26262b", "#2e2e34"])
    draw = ImageDraw.Draw(image)
    for i in range(0, S, 8):
        draw.line([(i, 0), (i, S - 1)], fill=rgb("#16161a"))
        draw.line([(0, i), (S - 1, i)], fill=rgb("#16161a"))
    for _ in range(3):  # Des traces d'humidité.
        x = rng.randint(2, S - 4)
        draw.line([(x, rng.randint(2, 10)), (x, rng.randint(14, 28))], fill=rgb("#22302a"))
    return image


def room_temple():
    image = Image.new("RGBA", (S, S), rgb("#241c33"))
    draw = ImageDraw.Draw(image)
    for ty in range(0, S, 4):
        for tx in range(0, S, 4):  # Mosaïque.
            shade = ["#2e2440", "#352a4a", "#2b2140"][(tx * 7 + ty * 3) // 4 % 3]
            draw.rectangle([tx, ty, tx + 2, ty + 2], fill=rgb(shade))
    # Une étoile dorée au centre.
    cx = cy = 16
    for dx, dy in ((0, -5), (5, 0), (0, 5), (-5, 0), (3, -3), (3, 3), (-3, 3), (-3, -3)):
        draw.line([(cx, cy), (cx + dx, cy + dy)], fill=rgb("#c9a227"))
    draw.point([(cx, cy)], fill=rgb("#ffe27a"))
    return image


def make_tiles():
    rng = random.Random(42)  # Toujours le même résultat.
    for i in range(3):
        save(earth_tile(rng), "tiles", "earth_%d.png" % i)
        save(floor_tile(rng), "tiles", "floor_%d.png" % i)
        save(claimed_tile(rng, with_emblem=(i == 0)), "tiles", "claimed_%d.png" % i)
    for i in range(2):
        save(gold_tile(rng), "tiles", "gold_%d.png" % i)
        save(rock_tile(rng), "tiles", "rock_%d.png" % i)
    save(room_treasury(), "tiles", "room_treasury.png")
    save(room_lair(), "tiles", "room_lair.png")
    save(room_farm(rng), "tiles", "room_farm.png")
    save(room_library(rng), "tiles", "room_library.png")
    save(room_workshop(), "tiles", "room_workshop.png")
    save(room_training(), "tiles", "room_training.png")
    save(room_prison(rng), "tiles", "room_prison.png")
    save(room_temple(), "tiles", "room_temple.png")


# ---------------------------------------------------------------------------
# Coffres du Trésor : fermé, puis de plus en plus plein d'or
# ---------------------------------------------------------------------------

WOOD, WOOD_LIGHT, WOOD_DARK = "#7a4a26", "#9a6234", "#4e2c14"
IRON, IRON_LIGHT = "#5d5d66", "#9a9aa8"
GOLD, GOLD_LIGHT, GOLD_DARK = "#f2b632", "#ffe27a", "#a8741a"


def coin(draw, x, y):
    draw.ellipse([x, y, x + 3, y + 2], fill=rgb(GOLD))
    draw.point([(x + 1, y)], fill=rgb(GOLD_LIGHT))
    draw.point([(x + 3, y + 2)], fill=rgb(GOLD_DARK))


def chest(level, rng):
    """level : 0 = fermé ; 1, 2, 3 = ouvert et de plus en plus plein."""
    image = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # Le corps du coffre (planches de bois, cerclages de fer).
    draw.rectangle([5, 16, 26, 28], fill=rgb(WOOD))
    for y in (19, 23):
        draw.line([(5, y), (26, y)], fill=rgb(WOOD_DARK))
    draw.line([(5, 16), (26, 16)], fill=rgb(WOOD_LIGHT))
    for x in (8, 23):
        draw.rectangle([x, 16, x + 1, 28], fill=rgb(IRON))
        draw.point([(x, 17)], fill=rgb(IRON_LIGHT))

    if level == 0:
        # Couvercle bombé, fermé, avec une serrure dorée.
        draw.chord([5, 8, 26, 22], 180, 360, fill=rgb(WOOD))
        draw.line([(7, 11), (24, 11)], fill=rgb(WOOD_LIGHT))
        for x in (8, 23):
            draw.rectangle([x, 9, x + 1, 16], fill=rgb(IRON))
        draw.rectangle([14, 14, 17, 19], fill=rgb(GOLD))
        draw.point([(15, 17)], fill=rgb("#3e2a00"))
    else:
        # Couvercle ouvert, rejeté en arrière.
        draw.rectangle([6, 4, 25, 9], fill=rgb(WOOD_DARK))
        draw.line([(6, 4), (25, 4)], fill=rgb(WOOD))
        for x in (8, 23):
            draw.rectangle([x, 4, x + 1, 9], fill=rgb(IRON))
        # L'intérieur sombre, puis l'or qui monte avec le niveau.
        draw.rectangle([6, 13, 25, 16], fill=rgb("#2a170a"))
        top = {1: 13, 2: 10, 3: 7}[level]
        draw.chord([6, top, 25, top + 8], 180, 360, fill=rgb(GOLD))
        if top + 4 <= 16:
            draw.rectangle([6, top + 4, 25, 16], fill=rgb(GOLD))
        for _ in range(4 + level * 4):
            draw.point([(rng.randint(7, 24), rng.randint(top + 1, 15))], fill=rgb(GOLD_LIGHT))
        for _ in range(level * 2):
            draw.point([(rng.randint(7, 24), rng.randint(top + 1, 15))], fill=rgb(GOLD_DARK))
        if level == 3:
            # Ça déborde : des pièces tombent devant le coffre, une gemme brille.
            for x, y in ((2, 26), (26, 25), (24, 28), (4, 29)):
                coin(draw, x, y)
            draw.polygon([(15, top - 1), (17, top + 1), (15, top + 3), (13, top + 1)], fill=rgb("#e53935"))
            draw.point([(14, top + 1)], fill=rgb("#ffcdd2"))
    return outline(image, "#1a0f06")


def make_chests():
    rng = random.Random(5)
    for level in range(4):
        save(chest(level, rng), "props", "chest_%d.png" % level)


def make_all():
    make_tiles()
    make_chests()
