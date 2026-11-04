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





# ===========================================================================
# PERSONNAGES EN 32 x 32
# ===========================================================================
# Chaque personnage est assemblé avec des « pièces » (jambes, torse, bras, tête,
# casque, cape, armes...). Chaque pièce est ombrée toute seule : bord clair en
# haut et à gauche, bord sombre en bas et à droite. Un contour sombre est ajouté
# à la fin. Chaque dessin reçoit une POSE (voir la classe Pose) : quelle jambe est
# levée, où sont les bras, le rebond du corps... Une pose vaut aussi 0 ou 1
# (comme un « pas »), ce qu'utilisent les ailes, pattes et queues des créatures.

OUTLINE = "#120a08"


def shade(color, factor):
    r, g, b, a = rgb(color)
    if factor > 1:
        r, g, b = (int(c + (255 - c) * (factor - 1)) for c in (r, g, b))
    else:
        r, g, b = (int(c * factor) for c in (r, g, b))
    return "#%02x%02x%02x" % (r, g, b)


class Sprite:
    def __init__(self):
        self.image = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    def part(self, shape, xy, base, light=None, dark=None):
        """Dessine une pièce (rect, ellipse ou polygon) avec son ombrage."""
        mask = Image.new("L", (S, S), 0)
        draw = ImageDraw.Draw(mask)
        getattr(draw, shape)(xy, fill=255)
        light = light or shade(base, 1.35)
        dark = dark or shade(base, 0.7)
        pixels = mask.load()
        for y in range(S):
            for x in range(S):
                if not pixels[x, y]:
                    continue
                edge = lambda nx, ny: not (0 <= nx < S and 0 <= ny < S and pixels[nx, ny])
                if edge(x, y - 1) or edge(x - 1, y):
                    color = light
                elif edge(x, y + 1) or edge(x + 1, y):
                    color = dark
                else:
                    color = base
                self.image.putpixel((x, y), rgb(color))

    def flat(self, shape, xy, color):
        """Une pièce d'une seule couleur (yeux, bouche, détails)."""
        getattr(ImageDraw.Draw(self.image), shape)(xy, fill=rgb(color))

    def dots(self, points, color):
        for point in points:
            self.image.putpixel(point, rgb(color))

    def finish(self):
        return outline(self.image, OUTLINE)


def eyes(sp, y, color="#ffffff", pupil="#1a1a1a", left=12, right=18, glow=False):
    if glow:
        sp.flat("rectangle", [left, y, left + 1, y], color)
        sp.flat("rectangle", [right, y, right + 1, y], color)
        return
    sp.flat("rectangle", [left, y, left + 1, y + 1], color)
    sp.flat("rectangle", [right, y, right + 1, y + 1], color)
    sp.dots([(left + 1, y + 1), (right, y + 1)], pupil)


class Pose(int):
    """Une pose d'animation. C'est aussi un nombre (0 ou 1) pour les dessins de
    créatures qui l'utilisent comme un « pas » (ailes, pattes, queue)."""

    def __new__(cls, step, lift_left=0, lift_right=0, bob=0, arm_left=0, arm_right=0, kind="walk", frame=0):
        pose = super().__new__(cls, step)
        pose.lift_left, pose.lift_right, pose.bob = lift_left, lift_right, bob
        pose.arm_left, pose.arm_right = arm_left, arm_right
        pose.kind, pose.frame = kind, frame
        return pose


## Toutes les animations : nom -> liste de poses (une par image).
ANIMATIONS = {
    # Marche : pied gauche levé, passage (corps plus haut), pied droit levé, passage.
    "walk": [Pose(1, lift_left=1, arm_left=1, arm_right=-1, frame=0),
             Pose(0, bob=-1, frame=1),
             Pose(1, lift_right=1, arm_left=-1, arm_right=1, frame=2),
             Pose(0, bob=-1, frame=3)],
    # Respiration : le corps monte et descend d'un pixel.
    "idle": [Pose(0, kind="idle", frame=0), Pose(1, bob=-1, arm_left=-1, arm_right=-1, kind="idle", frame=1)],
    # Attaque : l'élan (bras droit levé), puis la frappe (bras en avant, corps qui plonge).
    "attack": [Pose(0, bob=-1, arm_right=-5, kind="attack", frame=0),
               Pose(1, bob=1, arm_right=2, lift_left=1, kind="attack", frame=1)],
}


def humanoid(pose, skin, top, legs, boots, *, robe=None, head_drop=0, short=False):
    """Le corps de base : jambes (ou robe), torse, bras, mains et tête, dans la pose donnée.
    Renvoie le Sprite et un dictionnaire de repères pour placer les accessoires."""
    if not isinstance(pose, Pose):
        pose = Pose(pose, lift_left=int(pose), bob=-int(pose))
    sp = Sprite()
    bob, lift_l, lift_r = pose.bob, pose.lift_left, pose.lift_right
    leg_top = 26 if short else 24
    if robe:
        sp.part("polygon", [(10, 15 + bob), (21, 15 + bob), (24, 30), (7, 30)], robe)
        sp.part("rectangle", [9, 29 - lift_l, 13, 30 - lift_l], boots)
        sp.part("rectangle", [18, 29 - lift_r, 22, 30 - lift_r], boots)
    else:
        sp.part("rectangle", [11, leg_top - lift_l, 14, 29 - lift_l], legs)
        sp.part("rectangle", [17, leg_top - lift_r, 20, 29 - lift_r], legs)
        sp.part("rectangle", [10, 29 - lift_l, 14, 30 - lift_l], boots)
        sp.part("rectangle", [17, 29 - lift_r, 21, 30 - lift_r], boots)
        sp.part("rectangle", [10, 15 + bob + (3 if short else 0), 21, leg_top + 1 + bob], top)
    arm_y = 16 + bob + (3 if short else 0)
    left_y, right_y = arm_y + pose.arm_left, arm_y + pose.arm_right
    sp.part("rectangle", [7, left_y, 9, left_y + 6], top if not robe else robe)
    sp.part("rectangle", [22, right_y, 24, right_y + 6], top if not robe else robe)
    sp.part("ellipse", [7, left_y + 6, 9, left_y + 8], skin)
    sp.part("ellipse", [22, right_y + 6, 24, right_y + 8], skin)
    head_y = 3 + bob + head_drop
    sp.part("ellipse", [9, head_y, 22, head_y + 12], skin)
    return sp, {"bob": bob, "lift": lift_l, "head_y": head_y, "arm_y": arm_y,
                "left_hand": (8, left_y + 7), "right_hand": (23, right_y + 7)}


def sword(sp, hand, blade="#cfd8dc"):
    x, y = hand
    sp.part("rectangle", [x - 1, y - 11, x, y - 1], blade, "#ffffff", "#78909c")
    sp.flat("rectangle", [x - 2, y - 1, x + 1, y - 1], "#8d6e63")


def staff(sp, hand, orb, wood="#6d4c41"):
    x, y = hand
    sp.part("rectangle", [x, y - 16, x + 1, y + 4], wood)
    sp.part("ellipse", [x - 2, y - 20, x + 3, y - 15], orb)
    sp.dots([(x - 1, y - 19)], "#ffffff")


# --- Les créatures du donjon --------------------------------------------------

def draw_worker(step):
    # Petit diablotin vert aux grandes oreilles, tablier de cuir.
    sp, m = humanoid(step, "#7cb342", "#8d6e63", "#5d4037", "#3e2723")
    hy = m["head_y"]
    sp.part("polygon", [(9, hy + 5), (3, hy + 1), (9, hy + 9)], "#7cb342")
    sp.part("polygon", [(22, hy + 5), (28, hy + 1), (22, hy + 9)], "#7cb342")
    eyes(sp, hy + 5, "#ffeb3b")
    sp.flat("line", [(14, hy + 9), (17, hy + 9)], "#33691e")
    sp.dots([(13, hy + 9), (18, hy + 8)], "#ffffff")
    return sp.finish()


def draw_kobold(step):
    sp = Sprite()
    # La queue derrière le corps.
    sp.part("polygon", [(18, 22), (27, 27 - step), (29, 30), (21, 26)], "#ff9800")
    body, m = humanoid(step, "#ff9800", "#ff9800", "#ff9800", "#c66900")
    sp.image.alpha_composite(body.image)
    hy = m["head_y"]
    sp.part("ellipse", [12, 17 + m["bob"], 19, 24 + m["bob"]], "#ffe0b2")  # ventre clair
    sp.part("ellipse", [11, hy + 6, 20, hy + 13], "#ffb74d")              # museau
    sp.dots([(14, hy + 9), (17, hy + 9)], "#5d2e00")
    sp.part("polygon", [(11, hy + 2), (9, hy - 2), (13, hy + 1)], "#c66900")  # petites cornes
    sp.part("polygon", [(20, hy + 2), (22, hy - 2), (18, hy + 1)], "#c66900")
    eyes(sp, hy + 4, "#ffffff")
    return sp.finish()


def draw_orc(step):
    sp, m = humanoid(step, "#4e7d2a", "#6d4c41", "#4e342e", "#2e1d16")
    hy, bob = m["head_y"], m["bob"]
    sp.part("rectangle", [6, 15 + bob, 10, 18 + bob], "#9e9e9e")   # épaulières
    sp.part("rectangle", [21, 15 + bob, 25, 18 + bob], "#9e9e9e")
    sp.flat("rectangle", [10, 22 + bob, 21, 22 + bob], "#3e2723")  # ceinture
    sp.flat("line", [(11, hy + 4), (14, hy + 5)], "#1b2e0f")       # sourcils froncés
    sp.flat("line", [(20, hy + 4), (17, hy + 5)], "#1b2e0f")
    eyes(sp, hy + 6, "#ff5252", glow=True)
    sp.flat("line", [(13, hy + 10), (18, hy + 10)], "#1b2e0f")
    sp.dots([(13, hy + 9), (18, hy + 9), (13, hy + 8), (18, hy + 8)], "#fffde7")  # défenses
    return sp.finish()


def draw_warlock(step):
    sp, m = humanoid(step, "#2a1b3d", "#5e35b1", "#5e35b1", "#2a1b3d", robe="#5e35b1")
    hy = m["head_y"]
    sp.part("polygon", [(15, hy - 3), (24, hy + 8), (22, hy + 14), (9, hy + 14), (7, hy + 8)], "#4527a0")  # capuche
    sp.part("ellipse", [11, hy + 5, 20, hy + 13], "#1a1026")  # visage dans l'ombre
    eyes(sp, hy + 8, "#ffee58", glow=True)
    sp.part("rectangle", [14, 18 + m["bob"], 17, 29], "#8e6bd6")  # bande de la robe
    staff(sp, m["right_hand"], "#ffee58")
    return sp.finish()


def draw_spider(step):
    sp = Sprite()
    for side in (-1, 1):  # Huit pattes, qui alternent à chaque pas.
        for i, (dx, dy) in enumerate([(10, -6), (12, -1), (12, 4), (10, 9)]):
            up = (i + step) % 2
            x0, y0 = 16 + side * 4, 17 + (i - 1) * 2
            knee = (16 + side * (dx - 2), y0 + dy - 4 - up)
            foot = (16 + side * dx, y0 + dy + 2 - up)
            sp.flat("line", [(x0, y0), knee], "#2a1838")
            sp.flat("line", [knee, foot], "#2a1838")
    sp.part("ellipse", [9, 15, 22, 28], "#3b2350")   # abdomen
    sp.part("ellipse", [11, 8, 20, 17], "#4a2d63")   # tête
    sp.flat("rectangle", [12, 19, 19, 20], "#6a3d8f")  # motif
    sp.flat("rectangle", [15, 18, 16, 24], "#6a3d8f")
    sp.dots([(13, 11), (14, 11), (17, 11), (18, 11), (14, 13), (17, 13)], "#ff1744")
    sp.dots([(14, 16), (17, 16)], "#e0e0e0")  # crochets
    return sp.finish()


def draw_demon(step):
    sp = Sprite()
    flap = 2 if step else 0
    sp.part("polygon", [(10, 15), (1, 6 + flap), (3, 18), (8, 22)], "#4a0e0e")   # ailes
    sp.part("polygon", [(21, 15), (30, 6 + flap), (28, 18), (23, 22)], "#4a0e0e")
    body, m = humanoid(step, "#c62828", "#b71c1c", "#8e1b1b", "#3b0a0a")
    sp.image.alpha_composite(body.image)
    hy = m["head_y"]
    sp.part("polygon", [(11, hy + 3), (8, hy - 3), (13, hy + 1)], "#ffd54f")  # cornes
    sp.part("polygon", [(20, hy + 3), (23, hy - 3), (18, hy + 1)], "#ffd54f")
    eyes(sp, hy + 5, "#ffeb3b", glow=True)
    sp.flat("rectangle", [12, hy + 9, 19, hy + 10], "#3b0a0a")  # grand sourire
    sp.dots([(13, hy + 9), (15, hy + 9), (17, hy + 9)], "#ffffff")
    sp.flat("rectangle", [10, 22 + m["bob"], 21, 23 + m["bob"]], "#3b0a0a")
    return sp.finish()


def draw_bat(step):
    sp = Sprite()
    up = -4 if step else 0
    sp.part("polygon", [(13, 14), (1, 8 + up), (3, 18), (6, 15), (9, 20), (13, 19)], "#4a3b5c")
    sp.part("polygon", [(18, 14), (30, 8 + up), (28, 18), (25, 15), (22, 20), (18, 19)], "#4a3b5c")
    sp.part("ellipse", [11, 11, 20, 22], "#5d4a72")
    sp.part("polygon", [(12, 12), (11, 6), (14, 11)], "#5d4a72")  # oreilles
    sp.part("polygon", [(19, 12), (20, 6), (17, 11)], "#5d4a72")
    sp.dots([(13, 14), (18, 14)], "#ff5252")
    sp.dots([(14, 18), (17, 18)], "#ffffff")
    return sp.finish()


def draw_golem(step):
    sp = Sprite()
    bob, lift = step.bob, step.lift_left - step.lift_right
    stone, light, dark = "#8d8d8d", "#bdbdbd", "#5a5a5a"
    sp.part("rectangle", [9, 24 - lift, 14, 30 - lift], stone, light, dark)
    sp.part("rectangle", [17, 24, 22, 30], stone, light, dark)
    sp.part("rectangle", [7, 13 + bob, 24, 25 + bob], stone, light, dark)
    sp.part("rectangle", [3, 14 + bob + step.arm_left, 7, 25 + bob + step.arm_left], stone, light, dark)
    sp.part("rectangle", [24, 14 + bob + step.arm_right, 28, 25 + bob + step.arm_right], stone, light, dark)
    sp.part("rectangle", [10, 3 + bob, 21, 13 + bob], stone, light, dark)
    sp.flat("rectangle", [12, 7 + bob, 13, 8 + bob], "#4dd0e1")
    sp.flat("rectangle", [18, 7 + bob, 19, 8 + bob], "#4dd0e1")
    sp.flat("line", [(12, 17 + bob), (15, 20 + bob), (14, 23 + bob)], dark)  # fissures
    sp.flat("line", [(20, 15 + bob), (18, 18 + bob)], dark)
    sp.dots([(9, 14 + bob), (10, 14 + bob), (22, 24 + bob), (11, 3 + bob)], "#558b2f")  # mousse
    return sp.finish()


def draw_vampire(step):
    sp = Sprite()
    sp.part("polygon", [(9, 14), (22, 14), (26, 30), (5, 30)], "#1a1a2e")   # cape
    sp.part("polygon", [(10, 16), (21, 16), (23, 29), (8, 29)], "#b71c1c")
    body, m = humanoid(step, "#e0e0e0", "#311b92", "#212121", "#121212")
    sp.image.alpha_composite(body.image)
    hy = m["head_y"]
    sp.part("polygon", [(9, hy + 5), (15, hy + 4), (16, hy + 1), (17, hy + 4), (22, hy + 5),
                        (22, hy + 1), (16, hy - 1), (9, hy + 1)], "#212121")  # cheveux en pointe
    sp.part("polygon", [(8, 14 + m["bob"]), (10, 10 + m["bob"]), (12, 15 + m["bob"])], "#1a1a2e")  # col
    sp.part("polygon", [(23, 14 + m["bob"]), (21, 10 + m["bob"]), (19, 15 + m["bob"])], "#1a1a2e")
    eyes(sp, hy + 6, "#ff1744", glow=True)
    sp.flat("line", [(14, hy + 10), (17, hy + 10)], "#5d0000")
    sp.dots([(14, hy + 11), (17, hy + 11)], "#ffffff")  # crocs
    return sp.finish()


def draw_salamander(step):
    sp = Sprite()
    tail = 1 if step else 0
    sp.part("polygon", [(18, 22), (26, 25 - tail), (28, 30), (20, 27)], "#e64a19")
    sp.part("polygon", [(25, 23 - tail), (30, 18 - tail), (29, 25), (27, 27)], "#ff9800")  # flamme
    sp.dots([(29, 20 - tail)], "#ffeb3b")
    body, m = humanoid(step, "#e64a19", "#e64a19", "#bf360c", "#7f2207")
    sp.image.alpha_composite(body.image)
    hy = m["head_y"]
    sp.part("ellipse", [12, 17 + m["bob"], 19, 24 + m["bob"]], "#ffcc80")  # ventre
    sp.part("ellipse", [11, hy + 6, 20, hy + 13], "#ff7043")              # museau
    sp.dots([(14, hy + 9), (17, hy + 9)], "#3e0e00")
    sp.dots([(12, hy - 1 + 1), (15, hy - 1), (19, hy)], "#ff9800")  # crête de feu
    eyes(sp, hy + 4, "#ffeb3b", glow=True)
    return sp.finish()


def draw_catcher(step):
    sp, m = humanoid(step, "#0a0f14", "#1f3a44", "#1f3a44", "#0a0f14", robe="#1f3a44")
    hy = m["head_y"]
    sp.part("polygon", [(15, hy - 2), (23, hy + 7), (22, hy + 14), (9, hy + 14), (8, hy + 7)], "#2f5d6b")
    sp.part("ellipse", [11, hy + 5, 20, hy + 13], "#05080a")
    eyes(sp, hy + 8, "#ffeb3b", glow=True)
    # Un filet de chaînes porté en bandoulière.
    for i in range(0, 12, 3):
        sp.flat("line", [(7 + i, 16 + m["bob"]), (11 + i, 27)], "#90a4ae")
    sp.flat("line", [(8, 25), (22, 17 + m["bob"])], "#90a4ae")
    return sp.finish()


# --- Les héros -------------------------------------------------------------------

def draw_adventurer(step):
    sp, m = humanoid(step, "#ffccbc", "#1e88e5", "#5d4037", "#3e2723")
    hy, bob = m["head_y"], m["bob"]
    sp.part("polygon", [(9, hy + 6), (10, hy + 1), (16, hy - 1), (22, hy + 2), (22, hy + 5), (16, hy + 3)], "#6d4c41")
    sp.flat("rectangle", [10, 21 + bob, 21, 22 + bob], "#5d4037")
    sp.flat("rectangle", [15, 21 + bob, 16, 22 + bob], "#ffca28")
    eyes(sp, hy + 6)
    sp.flat("line", [(14, hy + 10), (17, hy + 10)], "#a1665e")
    sword(sp, m["right_hand"])
    return sp.finish()


def draw_thief(step):
    sp, m = humanoid(step, "#ffccbc", "#37474f", "#263238", "#1c1c1c")
    hy = m["head_y"]
    sp.part("polygon", [(16, hy - 2), (24, hy + 6), (23, hy + 12), (9, hy + 12), (8, hy + 6)], "#26a69a")  # capuche
    sp.part("ellipse", [11, hy + 4, 20, hy + 12], "#ffccbc")
    sp.flat("rectangle", [11, hy + 9, 20, hy + 12], "#00695c")  # foulard
    eyes(sp, hy + 6)
    sp.part("rectangle", [23, m["right_hand"][1] - 6, 23, m["right_hand"][1] - 1], "#cfd8dc")  # dague
    return sp.finish()


def draw_knight(step):
    sp, m = humanoid(step, "#90a4ae", "#90a4ae", "#78909c", "#455a64")
    hy, bob = m["head_y"], m["bob"]
    sp.part("ellipse", [9, hy, 22, hy + 12], "#b0bec5")              # casque
    sp.flat("rectangle", [11, hy + 6, 20, hy + 7], "#1c2833")        # visière
    sp.part("polygon", [(16, hy), (18, hy - 5), (21, hy - 4), (18, hy + 1)], "#e53935")  # plumet
    sp.flat("rectangle", [14, 16 + bob, 17, 24 + bob], "#cfd8dc")
    sword(sp, m["right_hand"])
    lx, ly = m["left_hand"]
    sp.part("polygon", [(lx - 4, ly - 8), (lx + 4, ly - 8), (lx + 4, ly - 1), (lx, ly + 3), (lx - 4, ly - 1)], "#1565c0")
    sp.flat("rectangle", [lx - 1, ly - 6, lx, ly - 1], "#ffca28")
    sp.flat("rectangle", [lx - 2, ly - 4, lx + 1, ly - 3], "#ffca28")
    return sp.finish()


def draw_cleric(step):
    sp, m = humanoid(step, "#ffccbc", "#eceff1", "#eceff1", "#795548", robe="#eceff1")
    hy = m["head_y"]
    sp.part("polygon", [(9, hy + 5), (12, hy), (19, hy), (22, hy + 5), (16, hy + 2)], "#8d6e63")
    eyes(sp, hy + 6)
    sp.flat("line", [(14, hy + 10), (17, hy + 10)], "#a1665e")
    sp.flat("rectangle", [15, 17 + m["bob"], 16, 26], "#ffca28")   # croix dorée
    sp.flat("rectangle", [13, 19 + m["bob"], 18, 20 + m["bob"]], "#ffca28")
    staff(sp, m["right_hand"], "#ffca28")
    return sp.finish()


def draw_archer(step):
    sp = Sprite()
    sp.part("rectangle", [19, 12, 22, 22], "#6d4c41")  # carquois dans le dos
    sp.dots([(19, 10), (20, 11), (21, 10)], "#eceff1")
    body, m = humanoid(step, "#ffccbc", "#2e7d32", "#5d4037", "#3e2723")
    sp.image.alpha_composite(body.image)
    hy = m["head_y"]
    sp.part("polygon", [(16, hy - 2), (24, hy + 6), (22, hy + 9), (16, hy + 3), (10, hy + 9), (8, hy + 6)], "#1b5e20")
    eyes(sp, hy + 6)
    sp.flat("line", [(14, hy + 10), (17, hy + 10)], "#a1665e")
    x, y = m["right_hand"]
    ImageDraw.Draw(sp.image).arc([x - 2, y - 12, x + 6, y + 4], 270, 90, fill=rgb("#8d6e63"), width=2)  # arc
    sp.flat("line", [(x + 2, y - 12), (x + 2, y + 4)], "#eceff1")      # corde
    return sp.finish()


def draw_dwarf(step):
    sp, m = humanoid(step, "#ffccbc", "#6d4c41", "#4e342e", "#3e2723", head_drop=3, short=True)
    hy = m["head_y"]
    sp.part("ellipse", [9, hy - 1, 22, hy + 6], "#9e9e9e")              # casque
    sp.part("polygon", [(10, hy + 8), (21, hy + 8), (20, hy + 18), (16, hy + 21), (11, hy + 18)], "#ff8f00")  # barbe
    eyes(sp, hy + 6)
    x, y = m["right_hand"]
    sp.part("rectangle", [x, y - 12, x + 1, y + 2], "#8d6e63")          # hache
    sp.part("polygon", [(x + 1, y - 12), (x + 6, y - 14), (x + 6, y - 7), (x + 1, y - 8)], "#cfd8dc")
    return sp.finish()


def draw_mage(step):
    sp, m = humanoid(step, "#ffccbc", "#3949ab", "#3949ab", "#1a237e", robe="#3949ab")
    hy = m["head_y"]
    sp.part("polygon", [(16, hy - 10), (21, hy + 1), (11, hy + 1)], "#283593")  # chapeau pointu
    sp.part("ellipse", [6, hy, 25, hy + 4], "#283593")                          # bord du chapeau
    sp.dots([(15, hy - 4), (17, hy - 2)], "#ffd54f")
    eyes(sp, hy + 6)
    sp.flat("line", [(14, hy + 10), (17, hy + 10)], "#a1665e")
    staff(sp, m["right_hand"], "#ff7043")
    return sp.finish()


def draw_paladin(step):
    sp, m = humanoid(step, "#fbc02d", "#fbc02d", "#f9a825", "#795548")
    hy, bob = m["head_y"], m["bob"]
    sp.part("ellipse", [9, hy, 22, hy + 12], "#fdd835")               # heaume doré
    sp.flat("rectangle", [12, hy + 6, 19, hy + 7], "#3e2a00")
    sp.flat("rectangle", [15, hy + 2, 16, hy + 10], "#3e2a00")
    sp.part("rectangle", [12, 16 + bob, 19, 25 + bob], "#eceff1")     # tabard blanc
    sp.flat("rectangle", [15, 17 + bob, 16, 24 + bob], "#e53935")
    sp.flat("rectangle", [13, 19 + bob, 18, 20 + bob], "#e53935")
    lx, ly = m["left_hand"]
    sp.part("ellipse", [lx - 5, ly - 9, lx + 4, ly + 2], "#1565c0")   # bouclier rond
    sp.dots([(lx, ly - 4), (lx - 1, ly - 4), (lx, ly - 3)], "#ffffff")
    return sp.finish()


def draw_giant(step):
    sp, m = humanoid(step, "#c8a27a", "#558b2f", "#c8a27a", "#3e2723")
    hy, bob = m["head_y"], m["bob"]
    sp.part("polygon", [(9, hy + 4), (12, hy - 1), (20, hy - 1), (22, hy + 4), (16, hy + 1)], "#4e342e")
    sp.flat("line", [(11, hy + 4), (14, hy + 5)], "#4e342e")
    sp.flat("line", [(20, hy + 4), (17, hy + 5)], "#4e342e")
    eyes(sp, hy + 6)
    sp.flat("rectangle", [13, hy + 9, 18, hy + 10], "#5d2e1a")
    sp.flat("rectangle", [10, 22 + bob, 21, 23 + bob], "#3e2723")
    x, y = m["right_hand"]
    sp.part("polygon", [(x - 1, y), (x + 1, y), (x + 4, y - 14), (x + 2, y - 17), (x - 1, y - 14)], "#795548")  # massue
    sp.dots([(x + 2, y - 13), (x + 1, y - 10)], "#4e342e")
    return sp.finish()


CHARACTERS_32 = {
    "worker": draw_worker, "kobold": draw_kobold, "orc": draw_orc, "warlock": draw_warlock,
    "spider": draw_spider, "demon": draw_demon, "bat": draw_bat, "golem": draw_golem,
    "vampire": draw_vampire, "salamander": draw_salamander, "catcher": draw_catcher,
    "adventurer": draw_adventurer, "thief": draw_thief, "knight": draw_knight, "cleric": draw_cleric,
    "archer": draw_archer, "dwarf": draw_dwarf, "mage": draw_mage, "paladin": draw_paladin,
    "giant": draw_giant,
}


def add_swoosh(image):
    """Le trait de mouvement de la frappe : un arc clair devant le personnage."""
    d = ImageDraw.Draw(image)
    d.arc([14, 4, 31, 26], 300, 60, fill=(255, 255, 255, 210), width=2)
    d.arc([12, 2, 31, 28], 310, 40, fill=(207, 216, 220, 140), width=1)
    return image


def shifted(image, dx, dy):
    """Décale toute l'image (pour les élans des créatures sans bras)."""
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    result.paste(image, (dx, dy), image)
    return result


## Les créatures sans bras attaquent en se ramassant puis en bondissant.
LUNGERS = {"spider", "bat", "salamander", "kobold"}


def make_characters():
    """Pour chaque personnage : 4 images de marche, 2 de respiration, 2 d'attaque.
    Fichiers : units/<nom>_<animation>_<numéro>.png (par exemple knight_walk_2.png)."""
    for name, draw in CHARACTERS_32.items():
        for animation, poses in ANIMATIONS.items():
            for pose in poses:
                image = draw(pose)
                if animation == "attack":
                    if name in LUNGERS:
                        image = shifted(image, -1, -1) if pose.frame == 0 else shifted(image, 2, 1)
                    if pose.frame == 1:
                        image = add_swoosh(image)
                save(image, "units", "%s_%s_%d.png" % (name, animation, pose.frame))


def make_all():
    make_tiles()
    make_chests()
    make_characters()
    make_props_and_icons()


# ===========================================================================
# OBJETS ET ICÔNES EN 32 x 32
# ===========================================================================

def _draw(sp):
    return ImageDraw.Draw(sp.image)


def prop_heart():
    sp = Sprite()
    outer = [(16, 2), (27, 10), (24, 23), (16, 30), (8, 23), (5, 10)]
    sp.part("polygon", outer, "#c62828", "#ef5350", "#7f1515")
    d = _draw(sp)
    d.polygon([(16, 5), (24, 11), (16, 15), (8, 11)], fill=rgb("#e53935"))      # facette du haut
    d.polygon([(8, 11), (16, 15), (16, 27), (10, 22)], fill=rgb("#b71c1c"))     # facette gauche
    d.polygon([(24, 11), (16, 15), (16, 27), (22, 22)], fill=rgb("#8e1b1b"))    # facette droite
    d.line([(10, 10), (14, 7)], fill=rgb("#ffcdd2"))
    sp.dots([(12, 8), (11, 9)], "#ffffff")
    return sp.finish()


def prop_portal():
    sp = Sprite()
    sp.part("ellipse", [2, 1, 29, 30], "#5d5d6a", "#8a8a9a", "#33333c")     # anneau de pierre
    sp.part("ellipse", [6, 5, 25, 26], "#4a148c", "#6a1b9a", "#2a0a52")     # tourbillon
    d = _draw(sp)
    for box, color in (([8, 7, 23, 24], "#7b1fa2"), ([10, 9, 21, 22], "#ab47bc"), ([12, 11, 19, 20], "#ce93d8")):
        d.arc(box, 200, 520, fill=rgb(color), width=2)
    d.ellipse([14, 13, 17, 18], fill=rgb("#f3e5f5"))
    for x, y in ((5, 8), (25, 9), (4, 20), (26, 21), (15, 2)):  # pierres runiques
        d.point((x, y), fill=rgb("#b388ff"))
    return sp.finish()


def prop_entrance():
    sp = Sprite()
    sp.part("rectangle", [3, 6, 28, 31], "#78909c", "#b0bec5", "#455a64")     # piliers et arche
    sp.part("ellipse", [3, 0, 28, 14], "#78909c", "#b0bec5", "#455a64")
    sp.part("rectangle", [8, 10, 23, 31], "#5d4037", "#795548", "#3e2723")    # porte en bois
    sp.part("ellipse", [8, 4, 23, 17], "#5d4037", "#795548", "#3e2723")
    d = _draw(sp)
    d.line([(15, 6), (15, 31)], fill=rgb("#2e1d16"))                          # deux battants
    for y in (13, 22):
        d.line([(8, y), (23, y)], fill=rgb("#37474f"))                        # ferrures
        d.point([(10, y), (13, y), (18, y), (21, y)], fill=rgb("#cfd8dc"))
    d.point([(13, 18), (18, 18)], fill=rgb("#ffca28"))                        # poignées
    for x in (4, 27):                                                         # torches
        d.rectangle([x - 1, 9, x, 13], fill=rgb("#4e342e"))
        d.point([(x - 1, 7), (x, 8), (x - 1, 8)], fill=rgb("#ffb300"))
    return sp.finish()


def prop_bed():
    sp = Sprite()
    sp.part("rectangle", [3, 14, 28, 26], "#8d6e63", "#a1887f", "#4e342e")    # cadre
    sp.part("rectangle", [4, 13, 27, 21], "#c8a165", "#e0c08a", "#8d6e3a")    # paille
    sp.part("rectangle", [5, 9, 13, 15], "#d7ccc8", "#ffffff", "#a1887f")     # oreiller
    sp.part("rectangle", [12, 12, 27, 21], "#7e57c2", "#9575cd", "#4527a0")   # couverture
    d = _draw(sp)
    for x in range(14, 27, 4):
        d.line([(x, 13), (x, 20)], fill=rgb("#5e35b1"))
    sp.part("rectangle", [3, 26, 5, 29], "#5d4037")
    sp.part("rectangle", [26, 26, 28, 29], "#5d4037")
    return sp.finish()


def prop_mushroom():
    sp = Sprite()
    sp.part("rectangle", [12, 16, 19, 29], "#efebe9", "#ffffff", "#bcaaa4")   # pied
    sp.part("ellipse", [3, 4, 28, 20], "#e53935", "#ef9a9a", "#8e1b1b")       # chapeau
    d = _draw(sp)
    for box in ([8, 7, 11, 10], [17, 6, 21, 9], [13, 12, 15, 14], [22, 12, 24, 14], [6, 13, 8, 15]):
        d.ellipse(box, fill=rgb("#ffffff"))
    d.line([(6, 18), (25, 18)], fill=rgb("#8e1b1b"))
    return sp.finish()


def prop_gold_pile(count):
    sp = Sprite()
    rng = random.Random(count)
    spots = [(13, 22), (8, 24), (18, 24), (11, 18), (16, 19), (14, 14), (6, 20), (21, 20), (10, 13), (18, 14)]
    for x, y in spots[:count * 2]:
        sp.part("ellipse", [x, y, x + 6, y + 4], "#f2b632", "#ffe27a", "#a8741a")
        if rng.random() < 0.5:
            sp.dots([(x + 2, y + 1)], "#ffffff")
    return sp.finish()


def prop_spikes(raised):
    image = Image.new("RGBA", (S, S), rgb("#263238"))
    d = ImageDraw.Draw(image)
    d.rectangle([2, 2, 29, 29], fill=rgb("#546e7a"))
    d.line([(2, 2), (29, 2)], fill=rgb("#78909c"))
    d.line([(2, 29), (29, 29)], fill=rgb("#37474f"))
    holes = [(7, 7), (16, 7), (25, 7), (11, 15), (21, 15), (7, 24), (16, 24), (25, 24)]
    for x, y in holes:
        d.ellipse([x - 2, y - 1, x + 2, y + 2], fill=rgb("#111111"))
        if raised:
            d.polygon([(x - 2, y + 1), (x + 2, y + 1), (x, y - 6)], fill=rgb("#b0bec5"))
            d.line([(x, y - 6), (x - 2, y + 1)], fill=rgb("#ffffff"))
            d.line([(x, y - 6), (x + 2, y + 1)], fill=rgb("#607d8b"))
    for x, y in ((4, 4), (27, 4), (4, 27), (27, 27)):
        d.point((x, y), fill=rgb("#cfd8dc"))
    return image


def prop_rune():
    image = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    d.ellipse([2, 2, 29, 29], outline=rgb("#ff6f00"), width=2)
    d.ellipse([7, 7, 24, 24], outline=rgb("#ffa000"), width=1)
    d.polygon([(16, 6), (25, 21), (7, 21)], outline=rgb("#ffd54f"))           # triangle
    d.polygon([(16, 26), (7, 11), (25, 11)], outline=rgb("#ffd54f"))          # étoile à 6 branches
    d.ellipse([14, 14, 18, 18], fill=rgb("#fff59d"))
    for angle in range(0, 360, 45):                                           # petites runes autour
        import math
        x = 16 + 12.5 * math.cos(math.radians(angle))
        y = 16 + 12.5 * math.sin(math.radians(angle))
        d.point((round(x), round(y)), fill=rgb("#fff3e0"))
    return image


def prop_door():
    sp = Sprite()
    sp.part("rectangle", [2, 4, 29, 31], "#78909c", "#b0bec5", "#455a64")     # cadre de pierre
    sp.part("rectangle", [6, 7, 25, 31], "#8d6e63", "#a1887f", "#5d4037")     # porte
    d = _draw(sp)
    for x in (10, 15, 20):
        d.line([(x, 7), (x, 31)], fill=rgb("#5d4037"))                        # planches
    for y in (11, 25):
        d.rectangle([6, y, 25, y + 1], fill=rgb("#37474f"))                   # bandes de fer
        d.point([(8, y), (13, y), (18, y), (23, y)], fill=rgb("#cfd8dc"))
    d.ellipse([20, 17, 22, 19], fill=rgb("#ffca28"))                          # anneau
    return sp.finish()


def prop_torch():
    sp = Sprite()
    sp.part("rectangle", [14, 14, 17, 28], "#5d4037", "#795548", "#3e2723")   # pied
    sp.part("rectangle", [11, 28, 20, 30], "#4e342e")
    sp.part("polygon", [(8, 10), (23, 10), (20, 16), (11, 16)], "#6d4c41", "#8d6e63", "#3e2723")  # coupe
    sp.part("polygon", [(10, 10), (13, 3), (15, 6), (16, 0), (18, 5), (20, 2), (22, 10)], "#ff9800", "#ffcc80", "#e65100")
    sp.part("polygon", [(13, 10), (15, 5), (17, 8), (19, 5), (19, 10)], "#ffeb3b", "#ffffff", "#ffc107")
    return sp.finish()


def prop_bookshelf():
    sp = Sprite()
    sp.part("rectangle", [3, 1, 28, 31], "#6d4c41", "#8d6e63", "#3e2723")
    d = _draw(sp)
    colors = ["#c62828", "#1565c0", "#2e7d32", "#f9a825", "#6a1b9a", "#ef6c00"]
    rng = random.Random(3)
    for top in (3, 12, 21):
        d.rectangle([5, top, 26, top + 7], fill=rgb("#2a1c12"))
        x = 5
        while x < 26:
            width = rng.choice([2, 2, 3])
            height = rng.randint(5, 7)
            color = rng.choice(colors)
            d.rectangle([x, top + 7 - height, min(x + width - 1, 26), top + 7], fill=rgb(color))
            d.line([(x, top + 7 - height), (x, top + 7)], fill=rgb(shade(color, 1.4)))
            x += width
        d.line([(4, top + 8), (27, top + 8)], fill=rgb("#8d6e63"))
    return sp.finish()


def prop_anvil():
    sp = Sprite()
    sp.part("rectangle", [9, 22, 22, 30], "#795548", "#8d6e63", "#4e342e")    # billot
    sp.part("polygon", [(3, 11), (24, 11), (29, 13), (24, 16), (20, 16), (19, 22), (12, 22), (11, 16), (5, 16)],
            "#78909c", "#cfd8dc", "#455a64")
    sp.part("rectangle", [21, 5, 23, 11], "#8d6e63")                          # marteau posé
    sp.part("rectangle", [18, 3, 27, 6], "#90a4ae")
    _draw(sp).point((7, 12), fill=rgb("#ffffff"))
    return sp.finish()


def prop_dummy():
    sp = Sprite()
    sp.part("rectangle", [15, 18, 16, 29], "#6d4c41")                         # poteau
    sp.part("rectangle", [10, 28, 21, 30], "#5d4037")
    sp.part("rectangle", [5, 11, 26, 14], "#6d4c41", "#8d6e63", "#3e2723")    # bras
    sp.part("ellipse", [9, 9, 22, 22], "#d4a85a", "#e8c886", "#a0782f")       # corps en paille
    sp.part("ellipse", [11, 1, 20, 10], "#d4a85a", "#e8c886", "#a0782f")      # tête
    d = _draw(sp)
    d.ellipse([12, 12, 19, 19], outline=rgb("#c62828"), width=1)              # cible
    d.ellipse([14, 14, 17, 17], fill=rgb("#c62828"))
    d.line([(13, 5), (14, 6)], fill=rgb("#5d4037"))
    d.line([(18, 5), (17, 6)], fill=rgb("#5d4037"))
    d.line([(10, 21), (12, 20)], fill=rgb("#a0782f"))                         # brins de paille
    return sp.finish()


def prop_temple_altar():
    sp = Sprite()
    sp.part("rectangle", [4, 13, 27, 29], "#78909c", "#b0bec5", "#455a64")
    sp.part("rectangle", [2, 11, 29, 15], "#90a4ae", "#cfd8dc", "#546e7a")
    sp.part("rectangle", [11, 14, 20, 27], "#6a1b9a", "#9c27b0", "#4a148c")   # étoffe violette
    d = _draw(sp)
    d.line([(15, 17), (15, 23)], fill=rgb("#ffd54f"))
    d.line([(13, 19), (17, 19)], fill=rgb("#ffd54f"))
    for x in (5, 25):                                                         # bougies
        d.rectangle([x, 5, x + 2, 11], fill=rgb("#eceff1"))
        d.polygon([(x, 5), (x + 1, 1), (x + 2, 5)], fill=rgb("#ffb300"))
        d.point((x + 1, 3), fill=rgb("#fff59d"))
    return sp.finish()


def prop_prison_bars():
    image = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    d.rectangle([0, 0, 31, 3], fill=rgb("#37474f"))
    d.rectangle([0, 28, 31, 31], fill=rgb("#37474f"))
    d.line([(0, 1), (31, 1)], fill=rgb("#78909c"))
    for x in range(2, 31, 6):
        d.rectangle([x, 3, x + 1, 28], fill=rgb("#78909c"))
        d.line([(x, 3), (x, 28)], fill=rgb("#b0bec5"))
        d.point([(x + 1, 12), (x, 20)], fill=rgb("#8d4e2a"))                   # rouille
    d.line([(0, 15), (31, 15)], fill=rgb("#546e7a"))
    return outline(image, OUTLINE)


def prop_sacrifice_altar():
    sp = Sprite()
    sp.part("rectangle", [5, 18, 26, 30], "#2a2a30", "#3d3d44", "#141418")
    sp.part("rectangle", [2, 12, 29, 19], "#4a4a52", "#6a6a74", "#25252b")
    d = _draw(sp)
    d.line([(6, 15), (25, 15)], fill=rgb("#c62828"))                          # sang
    d.point([(9, 16), (9, 17), (20, 16)], fill=rgb("#8e1b1b"))
    d.ellipse([12, 21, 19, 27], outline=rgb("#c62828"))                       # rune rouge
    d.point((15, 24), fill=rgb("#ff5252"))
    sp.part("ellipse", [12, 5, 19, 12], "#e0e0e0", "#ffffff", "#9e9e9e")      # crâne
    d.point([(14, 8), (17, 8)], fill=rgb("#1a1a1a"))
    d.line([(14, 11), (17, 11)], fill=rgb("#757575"))
    for x in (3, 27):                                                         # bougies rouges
        d.rectangle([x, 6, x + 1, 12], fill=rgb("#b71c1c"))
        d.point([(x, 4), (x + 1, 5)], fill=rgb("#ff5252"))
    return sp.finish()


# --- Icônes de l'interface ---------------------------------------------------------

def icon_pickaxe():
    sp = Sprite()
    sp.part("polygon", [(4, 27), (6, 29), (24, 11), (22, 9)], "#8d6e63", "#a1887f", "#5d4037")
    sp.part("polygon", [(8, 4), (20, 3), (29, 10), (27, 12), (19, 7), (10, 7)], "#90a4ae", "#eceff1", "#546e7a")
    return sp.finish()


def icon_hammer():
    sp = Sprite()
    sp.part("rectangle", [14, 12, 17, 30], "#8d6e63", "#a1887f", "#5d4037")
    sp.part("rectangle", [5, 3, 26, 12], "#78909c", "#cfd8dc", "#455a64")
    _draw(sp).line([(7, 5), (24, 5)], fill=rgb("#eceff1"))
    return sp.finish()


def icon_heal():
    sp = Sprite()
    sp.part("ellipse", [3, 5, 16, 18], "#43a047", "#a5d6a7", "#1b5e20")
    sp.part("ellipse", [15, 5, 28, 18], "#43a047", "#a5d6a7", "#1b5e20")
    sp.part("polygon", [(4, 14), (27, 14), (16, 28)], "#43a047", "#66bb6a", "#1b5e20")
    d = _draw(sp)
    d.rectangle([14, 9, 17, 20], fill=rgb("#ffffff"))
    d.rectangle([10, 13, 21, 16], fill=rgb("#ffffff"))
    return sp.finish()


def icon_bolt():
    sp = Sprite()
    sp.part("polygon", [(19, 1), (7, 17), (15, 17), (11, 31), (25, 12), (17, 12), (23, 1)],
            "#ffeb3b", "#fffde7", "#f9a825")
    return sp.finish()


def icon_haste():
    sp = Sprite()
    sp.part("polygon", [(8, 13), (20, 13), (20, 7), (30, 16), (20, 25), (20, 19), (8, 19)],
            "#4dd0e1", "#e0f7fa", "#00838f")
    d = _draw(sp)
    for y, x0 in ((10, 1), (16, 0), (22, 2)):
        d.line([(x0, y), (x0 + 5, y)], fill=rgb("#4dd0e1"))
    return sp.finish()


def icon_mana():
    sp = Sprite()
    sp.part("polygon", [(16, 1), (26, 12), (16, 30), (6, 12)], "#2979ff", "#82b1ff", "#0d47a1")
    d = _draw(sp)
    d.polygon([(16, 4), (22, 12), (16, 14), (10, 12)], fill=rgb("#448aff"))
    d.line([(10, 12), (15, 5)], fill=rgb("#e3f2fd"))
    d.point((12, 10), fill=rgb("#ffffff"))
    return sp.finish()


def icon_hand():
    sp = Sprite()
    skin, light, dark = "#ffcc80", "#ffe0b2", "#e0a050"
    sp.part("rectangle", [7, 15, 25, 28], skin, light, dark)                  # paume
    for x, top in ((7, 7), (12, 4), (17, 4), (22, 7)):                        # doigts
        sp.part("rectangle", [x, top, x + 3, 17], skin, light, dark)
    sp.part("rectangle", [2, 16, 7, 21], skin, light, dark)                   # pouce
    return sp.finish()


def icon_dagger():
    sp = Sprite()
    sp.part("polygon", [(27, 2), (29, 4), (14, 19), (12, 17)], "#eceff1", "#ffffff", "#90a4ae")
    sp.part("rectangle", [9, 17, 15, 19], "#ffca28")
    sp.part("polygon", [(10, 20), (12, 22), (5, 29), (3, 27)], "#6d4c41", "#8d6e63", "#3e2723")
    _draw(sp).point([(21, 9), (19, 11)], fill=rgb("#c62828"))
    return sp.finish()


def make_props_and_icons():
    props = {
        "heart": prop_heart, "portal": prop_portal, "entrance": prop_entrance, "bed": prop_bed,
        "mushroom": prop_mushroom, "door": prop_door, "torch": prop_torch, "bookshelf": prop_bookshelf,
        "anvil": prop_anvil, "dummy": prop_dummy, "altar": prop_temple_altar, "prison_bars": prop_prison_bars,
        "sacrifice_altar": prop_sacrifice_altar, "rune": prop_rune,
    }
    for name, draw in props.items():
        save(draw(), "props", name + ".png")
    save(prop_spikes(False), "props", "spikes_down.png")
    save(prop_spikes(True), "props", "spikes_up.png")
    for count in range(1, 6):
        save(prop_gold_pile(count), "props", "gold_pile_%d.png" % count)
    icons = {"pickaxe": icon_pickaxe, "hammer": icon_hammer, "heal": icon_heal, "bolt": icon_bolt,
             "haste": icon_haste, "mana": icon_mana, "hand": icon_hand, "dagger": icon_dagger}
    for name, draw in icons.items():
        save(draw(), "icons", name + ".png")
