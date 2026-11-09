"""Le mobilier des salles et le décor du donjon en low-poly texturé
(assets/models/rooms/<nom>.glb), dans l'esprit de l'image de référence : pierre
taillée, bois, or, fer, lueurs colorées.

Objets d'une case (centrés sur la case, 1 m de côté) :
  bed (Repaire), mushrooms_1..3 (Champignonnière), prison (une cellule),
  tomb_empty, tomb_full (Cimetière), wall_torch, torch, banner (bannière murale).
  Les objets muraux (wall_torch, banner) ont le mur du côté +Y.
Objets de plusieurs cases, centrés sur leur milieu, le côté LONG le long de Y
(le jeu les tourne d'un quart de tour s'ils sont posés dans l'autre sens) :
  treasury_0..3 (Trésor 1 x 2, rempli de 0 à 3), library (2 x 3, le laboratoire
  d'alchimie), workshop (2 x 2), training (2 x 4), temple (2 x 3).
  Les antres (règles 2.7) : tavern, infirmary, mint, torture, mana_well, crypt_0..2
  (2 x 2, la Crypte avec 0 à 2 sarcophages occupés) et guardpost (1 x 2).
Le trône du cœur : throne (salle de départ 5 x 5, centré sur le cœur, tourné vers -Y).

Les parties animées sont des pivots nommés, que view_3d.gd fait bouger :
  flame_* (flammes, braises, bulles : l'origine est à leur base),
  sway_* (mannequins qui se balancent), wisp (feu follet qui flotte).

Repère : Blender Y = -Z de Godot (voir lowpoly.py).

Construire : rooms.build("library", r"<projet>/assets/models/rooms/library.glb").
"""

import math
import random

import lowpoly as lp
from lowpoly import Part, pivot


def build(name, export_path=None):
    scene = lp.new_scene("room_" + name)
    ctx = _Ctx(scene)
    BUILDERS[name](ctx)
    ctx.finish()
    if export_path:
        lp.export_glb(scene, export_path)
    return scene


class _Ctx:
    """La scène d'un objet : une pièce principale (« base »), des pivots animés,
    et des matériaux partagés par nom."""

    def __init__(self, scene):
        self.scene = scene
        self.parts = []
        self.base = self.part("base")
        self.counters = {}

    def part(self, name, parent=None):
        part = Part(self.scene, name + "_mesh", parent)
        self.parts.append(part)
        return part

    def mat(self, key, color, emission=0.0, double_sided=False, texture=None):
        name = "room_%s_%s" % (key, color)
        return lp.material(name, color, emission, double_sided, texture)

    def animated(self, prefix, at, unique=False):
        """Un pivot animé (flame_0, flame_1..., sway_0..., wisp) et sa pièce."""
        if unique:
            name = prefix
        else:
            index = self.counters.get(prefix, 0)
            self.counters[prefix] = index + 1
            name = "%s_%d" % (prefix, index)
        node = pivot(self.scene, name, None, at)
        return self.part(name, node)

    def finish(self):
        for part in self.parts:
            if len(part.bm.verts):
                part.finish()
            else:
                part.bm.free()

    # Les matériaux texturés les plus courants.
    def stone(self, color="6f6763"):
        return self.mat("stone", color, texture="stone")

    def flag(self, color="5f5a5f"):
        return self.mat("flag", color, texture="flagstone")

    def wood(self, color="6d4c41"):
        return self.mat("wood", color, texture="grain")

    def planks(self, color="7a5235"):
        return self.mat("planks", color, texture="planks")

    def iron(self, color="5c646b"):
        return self.mat("iron", color, texture="metal")

    def gold(self, color="e8a317", emission=0.0):
        return self.mat("gold", color, emission, texture="gold")

    def cloth(self, color):
        return self.mat("cloth", color, texture="cloth")


# ---------------------------------------------------------------------------
# Petites formes réutilisées
# ---------------------------------------------------------------------------

def _flame(ctx, at, size, outer="ff9800", inner="ffeb3b"):
    """Une flamme en goutte (pivot flame_N à sa base)."""
    part = ctx.animated("flame", at)
    part.loft([((0, 0, 0), size * 0.55, size * 0.55), ((0, 0, size * 0.7), size, size),
               ((0, 0, size * 1.6), size * 0.45, size * 0.45), ((0, 0, size * 2.4), 0.0, 0.0)],
              ctx.mat("fire", outer, emission=3.0), sides=6, cap_end=False)
    part.loft([((0, 0, size * 0.3), size * 0.5, size * 0.5), ((0, 0, size * 0.9), size * 0.6, size * 0.6),
               ((0, 0, size * 1.9), 0.0, 0.0)], ctx.mat("fire", inner, emission=3.5), sides=5,
              cap_end=False, twist=0.3)
    return part


def _candle(ctx, part, at, wax="eceff1", fire="ffb300", height=0.14):
    x, y, z = at
    part.loft([((x, y, z), 0.025, 0.025), ((x, y, z + height), 0.022, 0.022)], ctx.mat("wax", wax), sides=6)
    _flame(ctx, (x, y, z + height), 0.022, outer=fire)


def _ring(part, center, radius, height, mat, sides=10):
    cx, cy, cz = center
    part.loft([((cx, cy, cz), radius, radius), ((cx, cy, cz + height), radius, radius)], mat, sides=sides,
              cap_start=False, cap_end=False)


def _coin_pile(ctx, part, center, radius, height, rng, coins):
    """Un monticule d'or texturé de pièces, quelques pièces posées et des gemmes."""
    shine = ctx.mat("gold_shine", "ffcc33", emission=0.15)
    cx, cy, cz = center
    rx, ry = radius
    part.loft([((cx, cy, cz), rx, ry), ((cx, cy, cz + height * 0.45), rx * 0.8, ry * 0.8),
               ((cx, cy, cz + height * 0.8), rx * 0.45, ry * 0.45), ((cx, cy, cz + height), 0.0, 0.0)],
              ctx.gold(), sides=10, cap_end=False)
    for _ in range(coins):
        a = rng.uniform(0, 2 * math.pi)
        t = rng.uniform(0.0, 0.95)
        x, y = cx + math.cos(a) * rx * t, cy + math.sin(a) * ry * t
        z = cz + height * max(0.0, 1.0 - t ** 1.6) + 0.004
        r = rng.uniform(0.025, 0.04)
        part.loft([((x, y, z - 0.005), r, r), ((x, y, z + 0.006), r, r)], shine, sides=6)
    gems = ("e53935", "1e88e5", "43a047", "ab47bc")
    for k in range(max(1, coins // 10)):
        a = rng.uniform(0, 2 * math.pi)
        t = rng.uniform(0.2, 0.7)
        x, y = cx + math.cos(a) * rx * t, cy + math.sin(a) * ry * t
        z = cz + height * (1.0 - t ** 1.6)
        color = gems[k % len(gems)]
        part.loft([((x, y, z - 0.01), 0.0, 0.0), ((x, y, z + 0.025), 0.032, 0.032), ((x, y, z + 0.055), 0.0, 0.0)],
                  ctx.mat("gem", color, emission=1.5), sides=4, cap_start=False, cap_end=False)


def _chest(ctx, part, at, open_lid, angle=0.0):
    """Un coffre cerclé de fer (ouvert ou fermé), tourné de « angle » autour de Z."""
    x0, y0 = at
    ca, sa = math.cos(angle), math.sin(angle)

    def p(x, y, z):
        return (x0 + x * ca - y * sa, y0 + x * sa + y * ca, z)

    wood = ctx.planks("8d5a2b")
    iron = ctx.iron("4a5258")
    part.box(p(0, 0, 0.17), (0.56, 0.36, 0.32), wood, rotation_z=angle)
    for z in (0.06, 0.28):
        part.box(p(0, 0, z), (0.58, 0.38, 0.04), iron, rotation_z=angle)
    for x in (-0.18, 0.18):
        part.box(p(x, 0, 0.17), (0.04, 0.38, 0.33), iron, rotation_z=angle)
    part.box(p(0, -0.19, 0.24), (0.07, 0.012, 0.08), ctx.mat("lock", "ffca28"), rotation_z=angle)
    if open_lid:
        # Couvercle ouvert vers l'arrière.
        part.slab([p(-0.28, 0.18, 0.33), p(-0.28, 0.24, 0.38), p(-0.28, 0.27, 0.5), p(-0.28, 0.24, 0.62),
                   p(-0.28, 0.18, 0.66)], (0.56 * ca, 0.56 * sa, 0), ctx.planks("7a4a22"))
    else:
        # Couvercle bombé fermé : un demi-cylindre couché.
        part.loft([(p(-0.28, 0, 0.33), 0.18, 0.08), (p(0.28, 0, 0.33), 0.18, 0.08)], ctx.planks("7a4a22"), sides=6)


def _skull(ctx, part, at, size=1.0, color="e0dccb"):
    x, y, z = at
    bone = ctx.mat("bone", color, texture="rough")
    s = size
    part.loft([((x, y, z), 0.035 * s, 0.03 * s), ((x, y, z + 0.04 * s), 0.05 * s, 0.05 * s),
               ((x, y, z + 0.09 * s), 0.045 * s, 0.045 * s), ((x, y, z + 0.11 * s), 0.0, 0.0)], bone, sides=6,
              cap_end=False)
    dark = ctx.mat("socket", "1a1a1a")
    for side in (-1, 1):
        part.box((x + 0.02 * s * side, y - 0.045 * s, z + 0.055 * s), (0.022 * s, 0.01 * s, 0.022 * s), dark)


def _bottle(ctx, part, at, color, height=0.12, glow=2.0):
    x, y, z = at
    glass = ctx.mat("glass", color, emission=glow)
    part.loft([((x, y, z), 0.035, 0.035), ((x, y, z + height * 0.55), 0.04, 0.04),
               ((x, y, z + height * 0.75), 0.015, 0.015), ((x, y, z + height), 0.015, 0.015)], glass, sides=6)
    part.loft([((x, y, z + height), 0.018, 0.018), ((x, y, z + height + 0.02), 0.016, 0.016)],
              ctx.mat("cork", "8d6e63"), sides=5)


def _banner_cloth(ctx, part, x, y, z_top, width, height, facing=-1):
    """Une bannière rouge à bord doré et trident, accrochée à « z_top », face vers ±Y."""
    red = ctx.cloth("8e1b1b")
    gold = ctx.mat("trim", "e0a526")
    w = width / 2
    outline = [(x - w, z_top), (x + w, z_top), (x + w, z_top - height), (x, z_top - height + 0.14),
               (x - w, z_top - height)]
    part.slab([(px, y, pz) for px, pz in outline], (0, -0.012 * facing, 0), red)
    yf = y + 0.004 * facing

    def deco(points):
        part.flat([(px, yf, pz) for px, pz in points], gold, facing=(0, facing, 0))

    deco([(x - w, z_top - 0.02), (x + w, z_top - 0.02), (x + w, z_top - 0.06), (x - w, z_top - 0.06)])
    for side in (-1, 1):
        sx = x + side * (w - 0.02)
        deco([(sx - 0.015, z_top - 0.06), (sx + 0.015, z_top - 0.06), (sx + 0.015, z_top - height + 0.03),
              (sx - 0.015, z_top - height + 0.03)])
    # Le trident : un manche, une traverse et trois dents.
    c = z_top - height * 0.45
    s = width / 0.45
    deco([(x - 0.012 * s, c + 0.04 * s), (x + 0.012 * s, c + 0.04 * s), (x + 0.012 * s, c - 0.2 * s),
          (x - 0.012 * s, c - 0.2 * s)])
    deco([(x - 0.08 * s, c + 0.06 * s), (x + 0.08 * s, c + 0.06 * s), (x + 0.08 * s, c + 0.03 * s),
          (x - 0.08 * s, c + 0.03 * s)])
    for dx in (-0.07, 0.0, 0.07):
        tip = 0.17 if dx == 0 else 0.14
        deco([(x + (dx - 0.014) * s, c + 0.06 * s), (x + (dx + 0.014) * s, c + 0.06 * s), (x + dx * s, c + tip * s)])


# ---------------------------------------------------------------------------
# Décor mural et torches
# ---------------------------------------------------------------------------

def _banner(ctx):
    """Une bannière au trident accrochée au mur (côté +Y), comme sur l'image."""
    part = ctx.base
    wood = ctx.wood("4e342e")
    part.loft([((-0.26, 0.06, 1.12), 0.018, 0.018), ((0.26, 0.06, 1.12), 0.018, 0.018)], wood, sides=5)
    for side in (-1, 1):
        part.loft([((0.26 * side, 0.06, 1.12), 0.028, 0.028), ((0.27 * side, 0.06, 1.12), 0.0, 0.0)],
                  ctx.mat("knob", "e0a526"), sides=5, cap_end=False)
        part.loft([((0.2 * side, 0.08, 1.12), 0.01, 0.01), ((0.2 * side, 0.08, 1.2), 0.01, 0.01)],
                  ctx.iron(), sides=4)
    _banner_cloth(ctx, part, 0.0, 0.045, 1.1, 0.42, 0.78)


def _wall_torch(ctx):
    """Une torche murale : support en fer scellé dans le mur (côté +Y), flamme."""
    part = ctx.base
    iron = ctx.iron("37474f")
    part.box((0, 0.07, 0.9), (0.12, 0.03, 0.16), iron)
    part.loft([((0, 0.06, 0.9), 0.02, 0.02), ((0, 0.0, 0.95), 0.018, 0.018)], iron, sides=4)
    part.loft([((0, 0.0, 0.88), 0.03, 0.03), ((0, -0.005, 1.0), 0.045, 0.045)], ctx.wood("5d4037"), sides=6)
    _ring(part, (0, -0.005, 0.97), 0.05, 0.035, iron, sides=7)
    _flame(ctx, (0, -0.005, 1.0), 0.06)


def _torch(ctx):
    part = ctx.base
    iron = ctx.iron("37474f")
    for k in range(3):
        a = 2 * math.pi * k / 3
        part.loft([((0.14 * math.cos(a), 0.14 * math.sin(a), 0.0), 0.016, 0.016),
                   ((0.03 * math.cos(a), 0.03 * math.sin(a), 0.55), 0.014, 0.014)], iron, sides=4)
    part.loft([((0, 0, 0.5), 0.05, 0.05), ((0, 0, 0.62), 0.11, 0.11), ((0, 0, 0.68), 0.12, 0.12)], iron, sides=8,
              cap_end=False)
    part.loft([((0, 0, 0.63), 0.1, 0.1), ((0, 0, 0.66), 0.06, 0.06)], ctx.mat("embers", "bf360c", emission=1.5),
              sides=8)
    _flame(ctx, (0, 0, 0.65), 0.09)


# ---------------------------------------------------------------------------
# Objets d'une case
# ---------------------------------------------------------------------------

def _bed(ctx):
    part = ctx.base
    wood = ctx.planks("6d4c41")
    dark = ctx.wood("4e342e")
    for x in (-0.33, 0.33):
        for y in (-0.19, 0.19):
            part.box((x, y, 0.08), (0.06, 0.06, 0.16), dark)
    part.box((0, 0, 0.13), (0.7, 0.42, 0.06), wood)
    part.loft([((0, 0, 0.16), 0.33, 0.19), ((0, 0, 0.22), 0.32, 0.18), ((0, 0, 0.24), 0.3, 0.16)],
              ctx.mat("straw", "c8a165", texture="straw"), sides=8, twist=0.0)
    part.loft([((-0.24, 0, 0.23), 0.08, 0.14), ((-0.24, 0, 0.29), 0.07, 0.12)], ctx.cloth("d7ccc8"),
              sides=6, twist=0.0)
    # Une fourrure sombre jetée en travers, qui retombe sur les côtés.
    fur = ctx.mat("fur", "5d4037", texture="leather")
    part.slab([(-0.08, -0.205, 0.255), (0.33, -0.205, 0.255), (0.33, 0.205, 0.255), (-0.08, 0.205, 0.255)],
              (0, 0, 0.025), fur)
    for side in (-1, 1):
        part.slab([(-0.08, 0.205 * side, 0.27), (0.33, 0.205 * side, 0.27), (0.3, 0.215 * side, 0.13),
                   (0.05, 0.215 * side, 0.15), (-0.08, 0.215 * side, 0.13)], (0, 0.01 * side, 0), fur)
    # Tête de lit sombre ornée d'un crâne cornu.
    part.slab([(-0.36, -0.21, 0.13), (-0.36, 0.21, 0.13), (-0.36, 0.21, 0.42), (-0.36, 0.08, 0.5),
               (-0.36, -0.08, 0.5), (-0.36, -0.21, 0.42)], (0.035, 0, 0), dark)
    bone = ctx.mat("bone", "e0dccb", texture="rough")
    part.loft([((-0.32, 0, 0.36), 0.045, 0.05), ((-0.31, 0, 0.42), 0.05, 0.05), ((-0.315, 0, 0.45), 0.03, 0.03)],
              bone, sides=6)
    for side in (-1, 1):
        part.cone((-0.32, 0.035 * side, 0.43), (-0.31, 0.09 * side, 0.5), 0.012, bone, sides=4)
        part.box((-0.272, 0.018 * side, 0.405), (0.012, 0.018, 0.016), ctx.mat("socket", "1a1a1a"))
    # Une écuelle au pied du lit.
    part.loft([((0.3, -0.3, 0.0), 0.05, 0.05), ((0.3, -0.3, 0.05), 0.07, 0.07)], dark, sides=7, cap_end=False)


MUSHROOM_SPOTS = [(-0.2, -0.15), (0.18, 0.15), (0.1, -0.22)]


def _mushrooms(ctx, count):
    part = ctx.base
    soil = ctx.mat("soil", "4a3426", texture="rough")
    moss = ctx.mat("moss", "33691e", texture="rough")
    stem = ctx.mat("stem", "efebe9", texture="cloth")
    cap = ctx.mat("cap", "d32f2f", texture="rough")
    dot = ctx.mat("cap_dot", "ffffff")
    glow = ctx.mat("glowshroom", "64ffda", emission=2.0)
    rng = random.Random(3)
    part.loft([((0, 0, 0.0), 0.44, 0.44), ((0, 0, 0.035), 0.41, 0.41), ((0, 0, 0.05), 0.36, 0.36)], soil, sides=9)
    for x, y in ((0.25, -0.05), (-0.05, 0.25), (-0.28, 0.22), (0.3, 0.3)):
        part.loft([((x, y, 0.04), 0.07, 0.06), ((x, y, 0.07), 0.035, 0.03)], moss, sides=5)
    # De petits champignons lumineux (une lueur bleu-vert dans le noir).
    for x, y in ((-0.3, -0.3), (0.32, -0.12), (-0.05, 0.33)):
        part.loft([((x, y, 0.04), 0.008, 0.008), ((x, y, 0.08), 0.008, 0.008)], stem, sides=4)
        part.loft([((x, y, 0.075), 0.025, 0.025), ((x, y, 0.1), 0.0, 0.0)], glow, sides=5, cap_end=False)
    for i in range(count):
        x, y = MUSHROOM_SPOTS[i]
        scale = (1.0, 0.85, 0.7)[i]
        h = 0.19 * scale
        part.loft([((x, y, 0.04), 0.05 * scale, 0.05 * scale), ((x, y, h * 0.5), 0.037 * scale, 0.037 * scale),
                   ((x, y, h), 0.042 * scale, 0.042 * scale)], stem, sides=6)
        part.loft([((x, y, h - 0.01), 0.06 * scale, 0.06 * scale), ((x, y, h + 0.01), 0.14 * scale, 0.14 * scale),
                   ((x, y, h + 0.065 * scale), 0.11 * scale, 0.11 * scale), ((x, y, h + 0.11 * scale), 0.0, 0.0)],
                  cap, sides=8, cap_end=False)
        for k in range(5):
            a = rng.uniform(0, 2 * math.pi)
            r = 0.075 * scale
            px, py = x + math.cos(a) * r, y + math.sin(a) * r
            pz = h + 0.07 * scale
            part.loft([((px, py, pz), 0.017 * scale, 0.017 * scale), ((px, py, pz + 0.012), 0.012 * scale,
                                                                       0.012 * scale)], dot, sides=5)
        sx, sy = x + 0.09, y - 0.06
        part.loft([((sx, sy, 0.04), 0.018, 0.018), ((sx, sy, 0.09), 0.015, 0.015)], stem, sides=5)
        part.loft([((sx, sy, 0.085), 0.045, 0.045), ((sx, sy, 0.12), 0.0, 0.0)], cap, sides=6, cap_end=False)


def _prison(ctx):
    part = ctx.base
    iron = ctx.iron("5c646b")
    dark = ctx.iron("3a4045")
    rng = random.Random(9)
    # Sol de dalles, paille, barreaux sur les quatre côtés, cadres, porte et serrure.
    part.box((0, 0, 0.012), (0.94, 0.94, 0.024), ctx.flag("4a4648"))
    part.loft([((-0.1, 0.12, 0.024), 0.3, 0.26), ((-0.1, 0.12, 0.05), 0.24, 0.2)],
              ctx.mat("straw", "c8a165", texture="straw"), sides=7)
    e = 0.45
    for z in (0.04, 0.92):
        for s in (-1, 1):
            part.box((0, s * e, z), (2 * e + 0.05, 0.06, 0.05), dark)
            part.box((s * e, 0, z), (0.06, 2 * e + 0.05, 0.05), dark)
    for k in range(8):
        t = -e + k * (2 * e / 7)
        for s in (-1, 1):
            part.loft([((t, s * e, 0.02), 0.016, 0.016), ((t, s * e, 0.93), 0.016, 0.016)], iron, sides=5)
            if abs(t) < e - 0.01:
                part.loft([((s * e, t, 0.02), 0.016, 0.016), ((s * e, t, 0.93), 0.016, 0.016)], iron, sides=5)
            part.cone((t, s * e, 0.93), (t, s * e, 1.0), 0.018, iron, sides=4)
    part.box((0, -e, 0.48), (2 * e, 0.045, 0.04), dark)
    part.box((0.15, -e - 0.03, 0.48), (0.08, 0.03, 0.09), ctx.mat("lock", "ffca28"))
    # Chaîne et anneau au mur du fond, seau, os et crâne dans la paille.
    for k in range(6):
        part.box((0.3, e - 0.03, 0.82 - k * 0.05), (0.028, 0.012, 0.045) if k % 2 else (0.012, 0.028, 0.045), dark)
    _ring(part, (0.3, e - 0.03, 0.5), 0.04, 0.015, dark, sides=6)
    part.loft([((-0.3, -0.3, 0.02), 0.06, 0.06), ((-0.3, -0.3, 0.14), 0.07, 0.07)], ctx.wood("6d4c41"),
              sides=7, cap_end=False)
    _skull(ctx, part, (0.12, -0.12, 0.03), 0.9)
    bone = ctx.mat("bone", "e0dccb", texture="rough")
    for _ in range(3):
        x, y, a = rng.uniform(-0.3, 0.2), rng.uniform(-0.1, 0.3), rng.uniform(0, 3)
        part.box((x, y, 0.035), (0.14, 0.018, 0.018), bone, rotation_z=a)


def _tomb(ctx, full):
    part = ctx.base
    stone = ctx.stone("7d8580")
    carve = ctx.mat("tomb_carve", "3f4640")
    part.box((0, 0.25, 0.04), (0.4, 0.16, 0.08), stone)
    outline = [(-0.16, 0.08), (0.16, 0.08), (0.16, 0.38), (0.11, 0.47), (0, 0.5), (-0.11, 0.47), (-0.16, 0.38)]
    part.slab([(x, 0.2, z) for x, z in outline], (0, 0.09, 0), stone)
    part.box((0, 0.195, 0.35), (0.13, 0.01, 0.028), carve)
    part.box((0, 0.195, 0.32), (0.028, 0.01, 0.15), carve)
    moss = ctx.mat("moss", "33691e", texture="rough")
    part.box((-0.13, 0.2, 0.12), (0.06, 0.1, 0.06), moss)
    _skull(ctx, part, (0.22, 0.2, 0.08), 0.7)
    if full:
        part.loft([((0, -0.08, 0.0), 0.18, 0.28), ((0, -0.08, 0.06), 0.15, 0.25), ((0, -0.08, 0.1), 0.09, 0.17)],
                  ctx.mat("earth", "5d4430", texture="rough"), sides=8, twist=0.0)
        for x, y, color in ((0.05, -0.15, "ffeb3b"), (-0.06, 0.0, "e1bee7")):
            part.loft([((x, y, 0.09), 0.004, 0.004), ((x, y, 0.15), 0.004, 0.004)], moss, sides=3)
            part.loft([((x, y, 0.145), 0.02, 0.02), ((x, y, 0.16), 0.0, 0.0)], ctx.mat("flower", color),
                      sides=5, cap_end=False)
        wisp = ctx.animated("wisp", (0.1, -0.1, 0.3), unique=True)
        wisp.loft([((0, 0, -0.06), 0.0, 0.0), ((0, 0, -0.02), 0.05, 0.05), ((0, 0, 0.03), 0.045, 0.045),
                   ((0, 0, 0.09), 0.0, 0.0)], ctx.mat("wisp", "76ff03", emission=4.0), sides=6,
                  cap_start=False, cap_end=False)
    else:
        part.flat([(-0.17, -0.33, 0.004), (0.17, -0.33, 0.004), (0.17, 0.16, 0.004), (-0.17, 0.16, 0.004)],
                  ctx.mat("pit", "1e140c"), facing=(0, 0, 1))
        part.loft([((0.3, -0.25, 0.0), 0.12, 0.14), ((0.3, -0.25, 0.08), 0.08, 0.09), ((0.3, -0.25, 0.12), 0.0, 0.0)],
                  ctx.mat("earth", "6d5641", texture="rough"), sides=7, cap_end=False)
        part.loft([((0.3, -0.3, 0.06), 0.012, 0.012), ((0.33, -0.33, 0.42), 0.012, 0.012)], ctx.wood(), sides=4)
        part.slab([(0.285, -0.32, 0.0), (0.345, -0.28, 0.0), (0.35, -0.28, 0.1), (0.29, -0.32, 0.1)],
                  (0.006, 0.006, 0), ctx.iron())


# ---------------------------------------------------------------------------
# Objets de plusieurs cases (largeur w le long de X, profondeur d le long de Y)
# ---------------------------------------------------------------------------

def _treasury(ctx, level):
    """Le Trésor : de l'or qui couvre le sol, des coffres, et (plein) une idole d'or."""
    d = 2.0
    part = ctx.base
    rng = random.Random(7)
    _chest(ctx, part, (0.05, d * 0.5 - 0.32), open_lid=True)
    _chest(ctx, part, (-0.22, -d * 0.5 + 0.3), open_lid=level < 2, angle=0.35)
    if level <= 0:
        # Quelques pièces oubliées par terre.
        shine = ctx.mat("gold_shine", "ffcc33", emission=0.15)
        for _ in range(6):
            x, y = rng.uniform(-0.3, 0.3), rng.uniform(-0.5, 0.4)
            part.loft([((x, y, 0.0), 0.035, 0.035), ((x, y, 0.012), 0.035, 0.035)], shine, sides=6)
        return
    # Un tapis de pièces sur tout le sol, puis des monticules plus hauts avec le remplissage.
    part.loft([((0, 0, 0.0), 0.47, 0.97), ((0, 0, 0.03), 0.45, 0.94), ((0, 0, 0.05), 0.38, 0.85)],
              ctx.gold(), sides=12, twist=0.0)
    _coin_pile(ctx, part, (0.05, d * 0.5 - 0.32, 0.3), (0.24, 0.15), 0.04 + 0.03 * level, rng, 4 * level)
    height = 0.12 + 0.13 * level
    _coin_pile(ctx, part, (0.02, -0.08, 0.04), (0.3 + 0.05 * level, 0.42 + 0.1 * level), height, rng, 12 + 9 * level)
    if level >= 2:
        _coin_pile(ctx, part, (0.25, 0.42, 0.04), (0.18, 0.2), 0.12 + 0.04 * level, rng, 8)
        _coin_pile(ctx, part, (-0.25, -0.62, 0.04), (0.16, 0.18), 0.1 + 0.03 * level, rng, 6)
        # Un calice d'or.
        cup = ctx.mat("goldware", "ffc107", emission=0.2, texture="metal")
        cx, cy = -0.3, 0.35
        part.loft([((cx, cy, 0.05), 0.045, 0.045), ((cx, cy, 0.06), 0.012, 0.012), ((cx, cy, 0.14), 0.012, 0.012),
                   ((cx, cy, 0.16), 0.05, 0.05), ((cx, cy, 0.23), 0.055, 0.055)], cup, sides=8, cap_end=False)
    if level >= 3:
        # L'idole d'or cornue au sommet du tas, qui brille (comme l'obélisque de l'image).
        idol = ctx.mat("idol", "ffc107", emission=0.3, texture="metal")
        top = height + 0.02
        x, y = 0.02, -0.08
        part.loft([((x, y, top - 0.05), 0.09, 0.09), ((x, y, top + 0.02), 0.08, 0.08)], idol, sides=6)
        part.loft([((x, y, top + 0.02), 0.06, 0.05), ((x, y, top + 0.16), 0.08, 0.06), ((x, y, top + 0.24), 0.05, 0.05)],
                  idol, sides=6)
        part.loft([((x, y, top + 0.24), 0.045, 0.045), ((x, y - 0.01, top + 0.3), 0.05, 0.05),
                   ((x, y, top + 0.35), 0.03, 0.03)], idol, sides=6)
        for side in (-1, 1):
            part.loft([((x + 0.03 * side, y, top + 0.33), 0.012, 0.012), ((x + 0.08 * side, y, top + 0.4), 0.0, 0.0)],
                      idol, sides=4, cap_end=False)
            part.box((x + 0.018 * side, y - 0.048, top + 0.3), (0.016, 0.006, 0.01), ctx.mat("gem", "e53935", 2.0))


def _rug(ctx, part, center, size, color="7f1d2d", border="e0a526"):
    cx, cy = center
    sx, sy = size
    part.box((cx, cy, 0.008), (sx + 0.06, sy + 0.06, 0.012), ctx.mat("rug_border", border))
    part.box((cx, cy, 0.012), (sx, sy, 0.014), ctx.cloth(color))


def _bookshelf(ctx, part, x, y0, y1, side, rng, potions=True):
    """Un rayonnage contre un mur (côté « side » en X), plein de livres et de fioles."""
    wood = ctx.planks("5d3a24")
    shelf_mat = ctx.wood("3e2716")
    colors = ["8e1b1b", "1a3a6b", "2e5b2a", "8d6e00", "4a148c", "6d4c41", "b71c1c", "00695c"]
    length = y1 - y0
    cy = (y0 + y1) / 2
    part.box((x + side * 0.13, cy, 0.7), (0.04, length, 1.4), wood)
    for y in (y0, cy, y1):
        part.box((x, y, 0.7), (0.3, 0.05, 1.4), wood)
    part.box((x, cy, 1.42), (0.34, length + 0.08, 0.06), wood)
    for shelf in range(4):
        z = 0.12 + shelf * 0.32
        part.box((x, cy, z - 0.02), (0.3, length, 0.03), shelf_mat)
        y = y0 + 0.04
        while y < y1 - 0.08:
            if potions and rng.random() < 0.12:
                _bottle(ctx, part, (x - side * 0.02, y + 0.04, z), rng.choice(("76ff03", "b388ff", "40c4ff")),
                        height=0.13, glow=1.5)
                y += 0.1
                continue
            thick = rng.uniform(0.045, 0.075)
            height = rng.uniform(0.18, 0.26)
            color = rng.choice(colors)
            part.box((x - side * 0.01, y + thick / 2, z + height / 2), (0.22, thick, height),
                     ctx.mat("book", color, texture="leather"))
            y += thick + 0.005


def _library(ctx):
    """La Bibliothèque devient un LABORATOIRE D'ALCHIMIE : chaudron bouillonnant vert,
    alambic à cuve lumineuse, établi couvert de fioles, rayonnage, flaque de bave."""
    w, d = 2.0, 3.0
    part = ctx.base
    rng = random.Random(11)
    slime = ctx.mat("slime", "76ff03", emission=1.3, texture="slime")
    brass = ctx.mat("brass", "b8892e", texture="metal")
    iron = ctx.iron("3a4045")
    stone = ctx.stone("5a5350")
    # Le rayonnage le long du mur gauche.
    _bookshelf(ctx, part, -w * 0.5 + 0.2, -0.3, d * 0.5 - 0.1, -1, rng)
    # Le chaudron sur son foyer de pierres, au milieu, avec ses flammes vertes.
    cx, cy = 0.1, 0.05
    for k in range(9):
        a = 2 * math.pi * k / 9
        part.loft([((cx + 0.32 * math.cos(a), cy + 0.32 * math.sin(a), 0.0), 0.075, 0.065),
                   ((cx + 0.32 * math.cos(a), cy + 0.32 * math.sin(a), 0.1), 0.06, 0.05)], stone, sides=5)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        _flame(ctx, (cx + 0.12 * math.cos(a), cy + 0.12 * math.sin(a), 0.02), 0.07, outer="64dd17", inner="ccff90")
    part.loft([((cx, cy, 0.14), 0.16, 0.16), ((cx, cy, 0.2), 0.27, 0.27), ((cx, cy, 0.38), 0.31, 0.31),
               ((cx, cy, 0.52), 0.26, 0.26), ((cx, cy, 0.56), 0.28, 0.28)], iron, sides=12, cap_end=False)
    for side in (-1, 1):
        part.loft([((cx + side * 0.29, cy, 0.5), 0.02, 0.02), ((cx + side * 0.36, cy, 0.48), 0.02, 0.02)], iron, sides=5)
        part.loft([((cx + side * 0.2, cy, 0.14), 0.025, 0.025), ((cx + side * 0.26, cy, 0.0), 0.02, 0.02)], iron, sides=4)
    part.loft([((cx, cy, 0.5), 0.26, 0.26), ((cx, cy, 0.53), 0.25, 0.25)], slime, sides=12)
    # Les bulles et la vapeur verte qui s'élève (animées comme des flammes).
    bubbles = ctx.animated("flame", (cx, cy, 0.53))
    bubble = ctx.mat("bubble", "b2ff59", emission=3.0)
    for bx, by, r in ((0.08, 0.04, 0.05), (-0.1, -0.06, 0.04), (0.02, -0.12, 0.035), (-0.05, 0.12, 0.03)):
        bubbles.loft([((bx, by, 0.0), r, r), ((bx, by, r), r * 1.1, r * 1.1), ((bx, by, r * 1.8), 0.0, 0.0)],
                     bubble, sides=6, cap_end=False)
    vapor = ctx.animated("flame", (cx, cy, 0.55))
    for vx, vy, h in ((0.06, 0.02, 0.32), (-0.08, -0.04, 0.24)):
        vapor.loft([((vx, vy, 0.0), 0.05, 0.05), ((vx + 0.02, vy, h * 0.5), 0.04, 0.04),
                    ((vx - 0.01, vy + 0.01, h), 0.0, 0.0)], ctx.mat("vapor", "69f0ae", emission=1.2), sides=6,
                   cap_end=False)
    # L'alambic au fond à droite : une grande cuve de verre verte cerclée de laiton, des tuyaux.
    ax, ay = 0.5, d * 0.5 - 0.45
    part.loft([((ax, ay, 0.0), 0.26, 0.26), ((ax, ay, 0.12), 0.24, 0.24)], stone, sides=8)
    tank = ctx.mat("tank", "64dd17", emission=1.3, texture="slime")
    part.loft([((ax, ay, 0.12), 0.18, 0.18), ((ax, ay, 0.3), 0.2, 0.2), ((ax, ay, 0.75), 0.2, 0.2),
               ((ax, ay, 0.9), 0.12, 0.12), ((ax, ay, 1.0), 0.05, 0.05)], tank, sides=10)
    for z in (0.14, 0.45, 0.78):
        _ring(part, (ax, ay, z), 0.215, 0.04, brass, sides=10)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        part.loft([((ax + 0.21 * math.cos(a), ay + 0.21 * math.sin(a), 0.12), 0.015, 0.015),
                   ((ax + 0.21 * math.cos(a), ay + 0.21 * math.sin(a), 0.85), 0.015, 0.015)], brass, sides=4)
    part.loft([((ax, ay, 1.0), 0.03, 0.03), ((ax, ay, 1.15), 0.03, 0.03), ((ax - 0.2, ay - 0.1, 1.2), 0.025, 0.025),
               ((ax - 0.45, ay - 0.35, 0.9), 0.025, 0.025), ((ax - 0.48, ay - 0.4, 0.7), 0.025, 0.025)], brass, sides=5)
    # Un ballon violet sur son trépied au bout du tuyau.
    fx, fy = ax - 0.48, ay - 0.42
    part.loft([((fx, fy, 0.0), 0.06, 0.06), ((fx, fy, 0.45), 0.04, 0.04)], iron, sides=5)
    part.loft([((fx, fy, 0.45), 0.03, 0.03), ((fx, fy, 0.5), 0.09, 0.09), ((fx, fy, 0.62), 0.08, 0.08),
               ((fx, fy, 0.68), 0.025, 0.025), ((fx, fy, 0.72), 0.025, 0.025)],
              ctx.mat("flask_purple", "b388ff", emission=2.0), sides=8)
    # L'établi couvert de fioles, d'un grimoire ouvert et d'une bougie (devant à droite).
    tx, ty = 0.5, -d * 0.5 + 0.45
    part.box((tx, ty, 0.55), (0.75, 0.42, 0.05), ctx.planks("6d4c41"))
    for x in (-0.33, 0.33):
        for y in (-0.17, 0.17):
            part.box((tx + x, ty + y, 0.27), (0.05, 0.05, 0.54), ctx.wood("4e342e"))
    for k, color in enumerate(("76ff03", "40c4ff", "ff4081", "b388ff", "76ff03")):
        _bottle(ctx, part, (tx - 0.3 + k * 0.08, ty + 0.12 - 0.03 * (k % 2), 0.575), color, height=0.1 + 0.03 * (k % 3))
    page = ctx.mat("page", "efe6d8", texture="cloth")
    for side in (-1, 1):
        part.slab([(tx + 0.12, ty - 0.12, 0.58), (tx + 0.12 + 0.13 * side, ty - 0.12, 0.585),
                   (tx + 0.12 + 0.13 * side, ty + 0.06, 0.59), (tx + 0.12, ty + 0.06, 0.585)], (0, 0, 0.01), page)
    _candle(ctx, part, (tx + 0.3, ty - 0.12, 0.575))
    _skull(ctx, part, (tx - 0.05, ty - 0.1, 0.575), 0.8)
    # La flaque de bave verte au sol, et quelques fioles cassées.
    puddle = [(-0.55, -0.6), (-0.3, -0.75), (-0.05, -0.68), (0.0, -0.95), (-0.25, -1.2), (-0.55, -1.15), (-0.7, -0.9)]
    part.flat([(x, y, 0.006) for x, y in puddle], slime, facing=(0, 0, 1))
    for x, y in ((-0.5, -0.5), (-0.1, -1.1)):
        part.loft([((x, y, 0.0), 0.02, 0.02), ((x, y, 0.03), 0.03, 0.03)], ctx.mat("flask", "b2ff59", emission=1.5),
                  sides=5, cap_end=False)


def _workshop(ctx):
    w, d = 2.0, 2.0
    part = ctx.base
    stone = ctx.stone("5a4c45")
    stone_dark = ctx.stone("3a302c")
    iron = ctx.iron("4a5258")
    # La forge en pierre (coin arrière gauche), ses braises, sa hotte et son conduit.
    fx, fy = -w * 0.5 + 0.45, d * 0.5 - 0.4
    part.loft([((fx, fy, 0.0), 0.42, 0.36), ((fx, fy, 0.5), 0.38, 0.32), ((fx, fy, 0.58), 0.42, 0.36)],
              stone, sides=4, twist=math.pi / 4)
    coals = ctx.animated("flame", (fx, fy, 0.56))
    coals.loft([((0, 0, 0.0), 0.3, 0.24), ((0, 0, 0.05), 0.24, 0.19), ((0, 0, 0.09), 0.0, 0.0)],
               ctx.mat("coals", "e64a19", emission=2.0, texture="rough"), sides=7, cap_end=False)
    for x, y, s in ((0.05, 0.0, 0.07), (-0.1, 0.06, 0.05), (0.12, -0.05, 0.045)):
        coals.cone((x, y, 0.04), (x, y, 0.04 + s * 3), s, ctx.mat("fire", "ffab00", emission=3.0), sides=5)
    part.loft([((fx, fy + 0.05, 0.95), 0.32, 0.27), ((fx, fy + 0.07, 1.22), 0.14, 0.12),
               ((fx, fy + 0.08, 1.7), 0.13, 0.11)], stone_dark, sides=4, twist=math.pi / 4, cap_start=False)
    for x in (-0.3, 0.3):
        part.box((fx + x, fy + 0.05, 0.76), (0.07, 0.07, 0.4), stone_dark)
    # Le soufflet, contre la forge.
    part.slab([(fx + 0.45, fy - 0.1, 0.25), (fx + 0.45, fy + 0.1, 0.25), (fx + 0.7, fy, 0.3)], (0, 0, 0.08),
              ctx.mat("bellows", "6d4c41", texture="leather"))
    # L'enclume sur sa souche, une pièce rougeoyante dessus, le marteau posé.
    ax, ay = 0.15, -0.1
    part.loft([((ax, ay, 0.0), 0.16, 0.16), ((ax, ay, 0.22), 0.14, 0.14)], ctx.wood("795548"), sides=7)
    steel = ctx.iron("607d8b")
    part.box((ax, ay, 0.28), (0.14, 0.12, 0.12), steel)
    part.slab([(ax - 0.2, ay - 0.08, 0.34), (ax + 0.15, ay - 0.08, 0.34), (ax + 0.3, ay - 0.08, 0.39),
               (ax + 0.15, ay - 0.08, 0.43), (ax - 0.2, ay - 0.08, 0.43)], (0, 0.16, 0), steel)
    glow = ctx.animated("flame", (ax, ay, 0.43))
    glow.box((0, 0, 0.01), (0.18, 0.04, 0.02), ctx.mat("hot_iron", "ff5722", emission=2.5))
    part.loft([((ax + 0.05, ay + 0.2, 0.01), 0.012, 0.012), ((ax + 0.3, ay + 0.25, 0.02), 0.012, 0.012)],
              ctx.wood(), sides=4)
    part.box((ax + 0.32, ay + 0.255, 0.035), (0.05, 0.09, 0.05), steel)
    # L'établi avec ses outils, un tonneau, des lingots, un râtelier d'épées neuves.
    bx, by = w * 0.5 - 0.55, -d * 0.5 + 0.3
    part.box((bx, by, 0.55), (0.9, 0.36, 0.06), ctx.planks())
    for x in (-0.38, 0.38):
        for y in (-0.13, 0.13):
            part.box((bx + x, by + y, 0.26), (0.06, 0.06, 0.52), ctx.wood("4e342e"))
    part.box((bx, by, 0.15), (0.8, 0.3, 0.03), ctx.wood("4e342e"))
    part.box((bx - 0.15, by, 0.6), (0.3, 0.05, 0.03), ctx.iron("b0bec5"))
    part.box((bx + 0.2, by - 0.02, 0.6), (0.05, 0.2, 0.04), ctx.wood("8d6e63"))
    part.box((bx + 0.2, by + 0.09, 0.61), (0.11, 0.05, 0.05), steel)
    rx, ry = -w * 0.5 + 0.3, -d * 0.5 + 0.3
    part.loft([((rx, ry, 0.0), 0.15, 0.15), ((rx, ry, 0.25), 0.18, 0.18), ((rx, ry, 0.5), 0.15, 0.15)],
              ctx.planks("795548"), sides=8)
    for z in (0.08, 0.42):
        _ring(part, (rx, ry, z - 0.015), 0.165, 0.03, iron, sides=8)
    for x, y, z in ((0.55, 0.45, 0.025), (0.7, 0.45, 0.025), (0.62, 0.45, 0.075)):
        part.box((x, y, z), (0.12, 0.06, 0.05), ctx.iron("b0bec5"))
    for k in range(3):
        x = 0.35 + k * 0.15
        part.loft([((x, d * 0.5 - 0.12, 0.05), 0.012, 0.012), ((x, d * 0.5 - 0.12, 0.65), 0.012, 0.012)],
                  ctx.iron("cfd8dc"), sides=4)
    part.box((0.5, d * 0.5 - 0.12, 0.5), (0.5, 0.05, 0.04), ctx.wood())


def _dummy(ctx, at):
    """Un mannequin d'entraînement (pivot sway_N au pied)."""
    part = ctx.animated("sway", at)
    wood = ctx.wood()
    straw = ctx.mat("straw", "d4a85a", texture="straw")
    rope = ctx.mat("rope", "8d6e63", texture="straw")
    part.loft([((0, 0, 0.0), 0.05, 0.05), ((0, 0, 0.9), 0.035, 0.035)], wood, sides=5)
    part.box((0, 0, 0.6), (0.52, 0.05, 0.05), wood)
    part.loft([((0, 0, 0.42), 0.12, 0.09), ((0, 0, 0.6), 0.15, 0.11), ((0, 0, 0.76), 0.12, 0.09)], straw, sides=7)
    for z in (0.47, 0.71):
        part.loft([((0, 0, z - 0.01), 0.13, 0.1), ((0, 0, z + 0.01), 0.13, 0.1)], rope, sides=7,
                  cap_start=False, cap_end=False)
    part.loft([((0, 0, 0.78), 0.06, 0.06), ((0, 0, 0.86), 0.09, 0.09), ((0, 0, 0.95), 0.0, 0.0)], straw, sides=6,
              cap_end=False)
    part.loft([((0, -0.1, 0.6), 0.075, 0.075), ((0, -0.115, 0.6), 0.075, 0.075)], ctx.cloth("c62828"),
              sides=8, twist=0.0)
    part.loft([((0, -0.115, 0.6), 0.045, 0.045), ((0, -0.12, 0.6), 0.045, 0.045)], ctx.cloth("eeeeee"),
              sides=8, twist=0.0)


def _training(ctx):
    w, d = 2.0, 4.0
    part = ctx.base
    wood = ctx.wood()
    part.box((0, 0, 0.008), (w - 0.2, d - 0.2, 0.016), ctx.mat("sand", "b8955a", texture="rough"))
    for side in (-1, 1):
        x = side * (w * 0.5 - 0.12)
        n = int(d / 0.4)
        for i in range(n + 1):
            y = -d * 0.5 + 0.12 + i * (d - 0.24) / n
            part.loft([((x, y, 0.0), 0.04, 0.04), ((x, y, 0.44), 0.035, 0.035), ((x, y, 0.5), 0.0, 0.0)],
                      wood, sides=5, cap_end=False)
        for z in (0.2, 0.36):
            part.box((x, 0, z), (0.045, d - 0.2, 0.05), wood)
    for y in (-d * 0.25, d * 0.15):
        _dummy(ctx, (0, y, 0.0))
    ry = d * 0.5 - 0.2
    for x in (-0.38, 0.38):
        part.box((x, ry, 0.4), (0.05, 0.05, 0.8), wood)
    for z in (0.2, 0.7):
        part.box((0, ry, z), (0.8, 0.06, 0.05), wood)
    steel = ctx.iron("cfd8dc")
    for k in range(5):
        x = -0.28 + k * 0.14
        if k % 2 == 0:
            part.loft([((x, ry - 0.04, 0.12), 0.01, 0.01), ((x, ry - 0.04, 0.95), 0.01, 0.01)], wood, sides=4)
            part.cone((x, ry - 0.04, 0.95), (x, ry - 0.04, 1.08), 0.025, steel, sides=4)
        else:
            part.loft([((x, ry - 0.04, 0.1), 0.012, 0.012), ((x, ry - 0.04, 0.22), 0.012, 0.012)],
                      ctx.wood("8d6e63"), sides=4)
            part.box((x, ry - 0.04, 0.23), (0.09, 0.02, 0.02), ctx.mat("guard", "e0a526"))
            part.loft([((x, ry - 0.04, 0.24), 0.022, 0.006), ((x, ry - 0.04, 0.68), 0.016, 0.005),
                       ((x, ry - 0.04, 0.74), 0.0, 0.0)], steel, sides=4, twist=0.0, cap_end=False)
    # Un bouclier rond posé contre la palissade.
    part.loft([((0.75, -1.3, 0.25), 0.18, 0.18), ((0.72, -1.3, 0.25), 0.18, 0.18)], ctx.planks("6d4c41"),
              sides=10)


def _temple(ctx):
    w, d = 2.0, 3.0
    part = ctx.base
    stone = ctx.flag("5f5a5f")
    stone_light = ctx.stone("726c72")
    back = d * 0.5
    _rug(ctx, part, (0, -0.3), (w * 0.34, d - 0.8))
    part.box((0, back - 0.6, 0.06), (w - 0.3, 1.0, 0.12), stone)
    part.box((0, back - 0.5, 0.18), (w - 0.6, 0.7, 0.12), stone_light)
    part.box((0, back - 0.45, 0.45), (0.7, 0.4, 0.42), ctx.stone("78909c"))
    part.box((0, back - 0.45, 0.67), (0.76, 0.46, 0.04), ctx.flag("90a4ae"))
    part.slab([(-0.16, back - 0.672, 0.66), (0.16, back - 0.672, 0.66), (0.16, back - 0.672, 0.3),
               (0.0, back - 0.672, 0.24), (-0.16, back - 0.672, 0.3)], (0, 0.012, 0), ctx.cloth("6a1b9a"))
    for x in (-0.28, 0.28):
        _candle(ctx, part, (x, back - 0.45, 0.69))
    statue = ctx.mat("statue", "4a4248", texture="rough")
    sy = back - 0.15
    part.box((0, sy, 0.36), (0.36, 0.3, 0.12), statue)
    part.loft([((0, sy, 0.42), 0.13, 0.1), ((0, sy, 0.62), 0.17, 0.11), ((0, sy, 0.86), 0.2, 0.12),
               ((0, sy, 0.92), 0.08, 0.07)], statue, sides=6)
    part.loft([((0, sy, 0.9), 0.09, 0.09), ((0, sy - 0.02, 1.0), 0.11, 0.1), ((0, sy, 1.12), 0.07, 0.07)],
              statue, sides=6)
    bone = ctx.mat("horn", "cfc6b8", texture="rough")
    eye = ctx.mat("statue_eye", "76ff03", emission=4.0)
    for side in (-1, 1):
        part.loft([((0.07 * side, sy, 1.08), 0.03, 0.03), ((0.15 * side, sy + 0.02, 1.18), 0.022, 0.022),
                   ((0.16 * side, sy + 0.05, 1.3), 0.0, 0.0)], bone, sides=5, cap_end=False)
        part.flat([(0.02 * side, sy - 0.112, 1.03), (0.065 * side, sy - 0.1, 1.04), (0.06 * side, sy - 0.104, 1.015),
                   (0.025 * side, sy - 0.11, 1.012)], eye, facing=(0, -1, 0))
        part.loft([((0.19 * side, sy, 0.84), 0.05, 0.05), ((0.24 * side, sy - 0.08, 0.62), 0.04, 0.04)], statue, sides=5)
    for side in (-1, 1):
        cx = side * (w * 0.5 - 0.2)
        part.box((cx, back - 0.15, 0.04), (0.24, 0.24, 0.08), stone_light)
        part.loft([((cx, back - 0.15, 0.08), 0.08, 0.08), ((cx, back - 0.15, 1.3), 0.07, 0.07)], stone_light, sides=6)
        part.box((cx, back - 0.15, 1.33), (0.22, 0.22, 0.06), stone_light)
        bx, by = side * (w * 0.5 - 0.3), -d * 0.15
        iron = ctx.iron("37474f")
        for k in range(3):
            a = 2 * math.pi * k / 3 + 0.5
            part.loft([((bx + 0.12 * math.cos(a), by + 0.12 * math.sin(a), 0.0), 0.015, 0.015),
                       ((bx + 0.05 * math.cos(a), by + 0.05 * math.sin(a), 0.48), 0.015, 0.015)], iron, sides=4)
        part.loft([((bx, by, 0.46), 0.08, 0.08), ((bx, by, 0.52), 0.17, 0.17), ((bx, by, 0.6), 0.2, 0.2)],
                  ctx.iron("455a64"), sides=8, cap_end=False)
        part.loft([((bx, by, 0.56), 0.17, 0.17), ((bx, by, 0.58), 0.12, 0.12)],
                  ctx.mat("coals_green", "1b5e20", emission=1.0), sides=8)
        _flame(ctx, (bx, by, 0.57), 0.1, outer="76ff03", inner="ccff90")


# ---------------------------------------------------------------------------
# Le trône du cœur
# ---------------------------------------------------------------------------

def _throne(ctx):
    """La salle du trône (salle de départ 5 x 5, le cœur au centre) : estrade à
    marches, tapis rouge, trône à dossier en tête de démon cornu, lave, braseros,
    bannières au trident. Tourné vers -Y."""
    part = ctx.base
    rng = random.Random(13)
    stone = ctx.stone("5b4a46")
    dark = ctx.stone("3e2f2c")
    red_stone = ctx.mat("throne_stone", "7a2a24", texture="rough")
    gold = ctx.mat("trim", "e0a526")
    back = 0.35  # Le trône est un peu en arrière du centre de la case.
    # L'estrade : trois marches, bordées d'or.
    for k, (sx, sy, z) in enumerate(((2.3, 2.0, 0.0), (1.8, 1.6, 0.1), (1.35, 1.2, 0.2))):
        y = back - 0.1 * k + 0.1
        part.box((0, y, z + 0.05), (sx, sy, 0.1), stone if k < 2 else dark)
        part.box((0, y - sy / 2, z + 0.095), (sx + 0.01, 0.03, 0.012), gold)
    # Le tapis rouge, qui descend les marches puis file vers l'avant.
    carpet = ctx.cloth("8e1b1b")
    for y0, y1, z in ((-2.4, back - 0.9, 0.0), (back - 0.9, back - 0.6, 0.1),
                      (back - 0.6, back - 0.4, 0.2), (back - 0.4, back, 0.3)):
        cy, length = (y0 + y1) / 2, y1 - y0
        part.box((0, cy, z + 0.008), (0.66, length, 0.014), gold)
        part.box((0, cy, z + 0.012), (0.58, length, 0.016), carpet)
    # Le siège et les accoudoirs, terminés par des crânes.
    seat_y = back + 0.15
    part.box((0, seat_y, 0.48), (0.8, 0.6, 0.36), red_stone)
    part.box((0, seat_y - 0.02, 0.68), (0.66, 0.5, 0.06), ctx.cloth("4a0e0e"))
    for side in (-1, 1):
        part.box((0.43 * side, seat_y, 0.7), (0.14, 0.62, 0.14), red_stone)
        _skull(ctx, part, (0.43 * side, seat_y - 0.33, 0.73), 1.1)
    # Le dossier : une immense tête de démon sculptée, cornes, yeux et gueule de lave.
    by = back + 0.5
    part.slab([(-0.55, by, 0.3), (0.55, by, 0.3), (0.62, by, 1.3), (0.4, by, 1.75), (0.0, by, 1.9),
               (-0.4, by, 1.75), (-0.62, by, 1.3)], (0, 0.22, 0), red_stone, dark)
    face_y = by - 0.02
    part.loft([((0, face_y + 0.02, 0.85), 0.28, 0.1), ((0, face_y - 0.1, 1.05), 0.36, 0.14),
               ((0, face_y - 0.12, 1.35), 0.34, 0.14), ((0, face_y - 0.06, 1.62), 0.24, 0.1),
               ((0, face_y, 1.75), 0.1, 0.06)], red_stone, sides=8, twist=0.0)
    eye = ctx.mat("throne_eye", "ff6d00", emission=4.0)
    for side in (-1, 1):
        part.box((0.13 * side, face_y - 0.24, 1.42), (0.2, 0.08, 0.06), dark)
        part.flat([(0.06 * side, face_y - 0.255, 1.38), (0.2 * side, face_y - 0.235, 1.4),
                   (0.18 * side, face_y - 0.24, 1.33), (0.08 * side, face_y - 0.255, 1.33)], eye, facing=(0, -1, 0))
        # Les cornes, énormes, qui montent en spirale.
        part.loft([((0.25 * side, face_y - 0.04, 1.6), 0.08, 0.08), ((0.45 * side, face_y, 1.85), 0.06, 0.06),
                   ((0.55 * side, face_y + 0.05, 2.15), 0.04, 0.04), ((0.5 * side, face_y + 0.08, 2.4), 0.0, 0.0)],
                  ctx.mat("horn", "cfc6b8", texture="rough"), sides=6, cap_end=False)
    # La gueule ouverte, crocs, et la lave qui luit au fond (une flamme animée).
    maw_y = face_y - 0.255
    part.flat([(-0.2, maw_y, 1.2), (0.2, maw_y, 1.2), (0.15, maw_y, 0.98), (-0.15, maw_y, 0.98)],
              ctx.mat("maw", "3b0a0a"), facing=(0, -1, 0))
    teeth = ctx.mat("teeth", "fff3d6")
    for k in range(6):
        x = -0.15 + k * 0.06
        part.cone((x, maw_y - 0.01, 1.21), (x, maw_y - 0.015, 1.13), 0.018, teeth, sides=3)
        part.cone((x + 0.03, maw_y - 0.01, 0.98), (x + 0.03, maw_y - 0.015, 1.05), 0.016, teeth, sides=3)
    glow = ctx.animated("flame", (0, maw_y - 0.005, 1.0))
    glow.flat([(-0.14, 0, 0.0), (0.14, 0, 0.0), (0.12, 0, 0.16), (-0.12, 0, 0.16)],
              ctx.mat("lava", "ff5722", emission=2.0, texture="slime"), facing=(0, -1, 0))
    # Deux bassins de lave de part et d'autre de l'estrade, bordés de roches.
    lava = ctx.mat("lava", "ff5722", emission=1.5, texture="slime")
    rock = ctx.stone("2e2422")
    for side in (-1, 1):
        cx, cy = 1.55 * side, back + 0.3
        pool = [(cx + 0.35 * math.cos(a), cy + 0.6 * math.sin(a)) for a in [k * 2 * math.pi / 9 for k in range(9)]]
        part.flat([(x, y, 0.02) for x, y in pool], lava, facing=(0, 0, 1))
        for x, y in pool:
            part.loft([((x, y, 0.0), 0.09, 0.08), ((x, y, 0.07), 0.07, 0.06), ((x, y, 0.1), 0.0, 0.0)], rock,
                      sides=5, cap_end=False)
        _flame(ctx, (cx, cy, 0.02), 0.07, outer="ff3d00", inner="ffab00")
    # Braseros devant l'estrade, bannières sur des hampes derrière le trône.
    iron = ctx.iron("37474f")
    for side in (-1, 1):
        bx, by2 = 1.05 * side, back - 1.1
        part.loft([((bx, by2, 0.0), 0.12, 0.12), ((bx, by2, 0.08), 0.06, 0.06), ((bx, by2, 0.6), 0.04, 0.04)],
                  iron, sides=6)
        part.loft([((bx, by2, 0.58), 0.06, 0.06), ((bx, by2, 0.66), 0.17, 0.17), ((bx, by2, 0.74), 0.2, 0.2)],
                  iron, sides=8, cap_end=False)
        part.loft([((bx, by2, 0.69), 0.16, 0.16), ((bx, by2, 0.71), 0.1, 0.1)],
                  ctx.mat("embers", "bf360c", emission=1.5), sides=8)
        _flame(ctx, (bx, by2, 0.7), 0.12)
        px, py = 1.0 * side, back + 0.95
        part.loft([((px, py, 0.0), 0.03, 0.03), ((px, py, 2.1), 0.025, 0.025)], ctx.wood("3e2723"), sides=5)
        part.cone((px, py, 2.1), (px, py, 2.25), 0.04, gold, sides=4)
        part.loft([((px - 0.27, py - 0.03, 2.0), 0.015, 0.015), ((px + 0.27, py - 0.03, 2.0), 0.015, 0.015)],
                  ctx.wood("3e2723"), sides=4)
        _banner_cloth(ctx, part, px, py - 0.04, 1.98, 0.5, 1.1)
    # Des crânes entassés au pied de l'estrade.
    for _ in range(7):
        x = rng.choice((-1, 1)) * rng.uniform(0.75, 1.1)
        y = rng.uniform(back - 0.7, back - 0.3)
        _skull(ctx, part, (x, y, 0.1 if abs(x) < 0.9 else 0.0), rng.uniform(0.8, 1.2))


# ---------------------------------------------------------------------------
# Les antres (règles 2.7) : objets de 2 x 2 cases (le Poste de garde : 1 x 2).
# Les créatures se tiennent au milieu des cases, en (±0,5, ±0,5) : on y laisse
# de la place, le mobilier est au centre, sur les bords et dans les coins.
# ---------------------------------------------------------------------------

def _barrel(ctx, part, at, height=0.42, radius=0.15, lying=False):
    """Un tonneau cerclé de fer, debout (ou couché le long de X)."""
    x, y, z = at
    wood = ctx.planks("7a4a22")
    iron = ctx.iron("3a4045")
    if lying:
        part.loft([((x - height / 2, y, z + radius), radius * 0.85, radius * 0.85),
                   ((x, y, z + radius), radius, radius),
                   ((x + height / 2, y, z + radius), radius * 0.85, radius * 0.85)], wood, sides=10)
        for dx in (-height * 0.35, height * 0.35):
            part.loft([((x + dx - 0.012, y, z + radius), radius * 0.97, radius * 0.97),
                       ((x + dx + 0.012, y, z + radius), radius * 0.97, radius * 0.97)], iron, sides=10,
                      cap_start=False, cap_end=False)
        # Le robinet de laiton, sur le fond.
        part.loft([((x + height / 2, y, z + radius * 0.7), 0.015, 0.015),
                   ((x + height / 2 + 0.06, y, z + radius * 0.65), 0.012, 0.012)], ctx.mat("brass", "b8892e"), sides=5)
        return
    part.loft([((x, y, z), radius * 0.85, radius * 0.85), ((x, y, z + height / 2), radius, radius),
               ((x, y, z + height), radius * 0.85, radius * 0.85)], wood, sides=10)
    for dz in (0.08, height - 0.08):
        part.loft([((x, y, z + dz - 0.012), radius * 0.97, radius * 0.97),
                   ((x, y, z + dz + 0.012), radius * 0.97, radius * 0.97)], iron, sides=10,
                  cap_start=False, cap_end=False)


def _mug(ctx, part, at, foam=True):
    x, y, z = at
    part.loft([((x, y, z), 0.032, 0.032), ((x, y, z + 0.08), 0.035, 0.035)], ctx.planks("8d5a2b"), sides=7)
    if foam:
        part.loft([((x, y, z + 0.078), 0.036, 0.036), ((x, y, z + 0.1), 0.03, 0.03), ((x, y, z + 0.11), 0.0, 0.0)],
                  ctx.mat("foam", "fff8e1"), sides=7, cap_end=False)
    part.box((x + 0.045, y, z + 0.045), (0.02, 0.012, 0.05), ctx.wood("5d4037"))


def _stool(ctx, part, at):
    x, y = at
    wood = ctx.wood("5d4037")
    for k in range(3):
        a = 2 * math.pi * k / 3
        part.loft([((x + 0.06 * math.cos(a), y + 0.06 * math.sin(a), 0.0), 0.012, 0.012),
                   ((x + 0.04 * math.cos(a), y + 0.04 * math.sin(a), 0.22), 0.012, 0.012)], wood, sides=4)
    part.loft([((x, y, 0.22), 0.085, 0.085), ((x, y, 0.25), 0.085, 0.085)], ctx.planks("6d4c41"), sides=8)


def _tavern(ctx):
    """La Taverne : comptoir et tonneaux au fond, cheminée à gauche, table ronde au milieu,
    tabourets, chopes qui débordent de mousse, et une enseigne qui se balance."""
    part = ctx.base
    rng = random.Random(21)
    wood = ctx.planks("6d4c41")
    dark = ctx.wood("3e2723")
    stone = ctx.stone("5a4c45")
    # Le comptoir, contre le mur du fond.
    cy = 0.82
    part.box((-0.1, cy, 0.27), (1.3, 0.24, 0.54), wood)
    part.box((-0.1, cy - 0.02, 0.56), (1.38, 0.32, 0.05), dark)
    for x in (-0.65, -0.1, 0.45):
        part.box((x, cy - 0.125, 0.27), (0.05, 0.01, 0.5), dark)
    for k, x in enumerate((-0.55, -0.3, 0.05, 0.3)):
        _mug(ctx, part, (x, cy - 0.04 + 0.03 * (k % 2), 0.585), foam=k % 2 == 0)
    _candle(ctx, part, (0.42, cy, 0.585))
    # Les tonneaux : deux debout dans le coin, un couché sur son chevalet, robinet ouvert.
    _barrel(ctx, part, (0.8, 0.82, 0.0))
    _barrel(ctx, part, (0.82, 0.45, 0.0), height=0.36, radius=0.13)
    for x in (-0.75, -0.45):
        part.box((x, 0.97 - 0.05, 0.5), (0.04, 0.06, 1.0), dark)
    part.box((-0.6, 0.92, 0.72), (0.4, 0.08, 0.03), dark)
    _barrel(ctx, part, (-0.6, 0.92, 0.75), height=0.36, radius=0.12, lying=True)
    # Des caisses de champignons (la bière en est faite).
    part.box((0.78, -0.12, 0.12), (0.3, 0.26, 0.24), ctx.planks("8d6e63"))
    cap = ctx.mat("cap", "d32f2f", texture="rough")
    for k in range(5):
        x, y = 0.68 + 0.05 * (k % 3), -0.18 + 0.06 * (k // 3)
        part.loft([((x, y, 0.24), 0.04, 0.04), ((x, y, 0.27), 0.05, 0.05), ((x, y, 0.3), 0.0, 0.0)], cap, sides=6,
                  cap_end=False)
    # La cheminée de pierre, sur le mur de gauche, et son feu.
    fx = -0.88
    part.box((fx, 0.0, 0.3), (0.22, 0.7, 0.6), stone)
    part.box((fx + 0.02, 0.0, 0.62), (0.3, 0.8, 0.08), ctx.stone("3a302c"))
    part.loft([((fx, 0.0, 0.66), 0.13, 0.3), ((fx - 0.02, 0.0, 1.4), 0.09, 0.18)], stone, sides=4, twist=math.pi / 4)
    part.flat([(fx + 0.115, -0.2, 0.05), (fx + 0.115, 0.2, 0.05), (fx + 0.115, 0.2, 0.42), (fx + 0.115, -0.2, 0.42)],
              ctx.mat("hearth", "1a0e08"), facing=(1, 0, 0))
    part.loft([((fx + 0.05, 0.0, 0.0), 0.1, 0.16), ((fx + 0.05, 0.0, 0.05), 0.08, 0.14)],
              ctx.mat("embers", "bf360c", emission=1.5), sides=7)
    for y in (-0.08, 0.06):
        _flame(ctx, (fx + 0.05, y, 0.05), 0.07)
    # Un chaudron de soupe pendu au-dessus du feu.
    iron = ctx.iron("37474f")
    part.loft([((fx + 0.05, 0.0, 0.42), 0.012, 0.012), ((fx + 0.05, 0.0, 0.3), 0.012, 0.012)], iron, sides=4)
    part.loft([((fx + 0.05, 0.0, 0.14), 0.06, 0.06), ((fx + 0.05, 0.0, 0.2), 0.09, 0.09),
               ((fx + 0.05, 0.0, 0.28), 0.08, 0.08)], iron, sides=8, cap_end=False)
    # La table ronde au milieu, chopes et cruche, un os rongé.
    part.loft([((0, 0, 0.0), 0.12, 0.12), ((0, 0, 0.04), 0.05, 0.05), ((0, 0, 0.34), 0.05, 0.05)], dark, sides=6)
    part.loft([((0, 0, 0.34), 0.25, 0.25), ((0, 0, 0.38), 0.25, 0.25)], wood, sides=10)
    _mug(ctx, part, (0.08, 0.05, 0.38))
    _mug(ctx, part, (-0.1, -0.06, 0.38), foam=False)
    part.loft([((-0.02, 0.1, 0.38), 0.04, 0.04), ((-0.02, 0.1, 0.46), 0.05, 0.05), ((-0.02, 0.1, 0.52), 0.025, 0.025)],
              ctx.mat("jug", "a1887f", texture="rough"), sides=7)
    part.box((0.1, -0.1, 0.39), (0.12, 0.02, 0.02), ctx.mat("bone", "e0dccb", texture="rough"), rotation_z=0.6)
    _candle(ctx, part, (-0.12, 0.12, 0.38), height=0.08)
    for x, y in ((0.0, -0.36), (0.0, 0.36), (-0.36, 0.0), (0.36, 0.0)):
        _stool(ctx, part, (x, y))
    # Une flaque de bière renversée.
    puddle = [(0.3, -0.45), (0.45, -0.4), (0.5, -0.55), (0.35, -0.62), (0.22, -0.55)]
    part.flat([(x, y, 0.004) for x, y in puddle], ctx.mat("beer", "c88a12", emission=0.2), facing=(0, 0, 1))
    # L'enseigne qui grince, pendue à une potence dans le coin avant.
    sx, sy = -0.88, -0.88
    part.loft([((sx, sy, 0.0), 0.03, 0.03), ((sx, sy, 1.2), 0.025, 0.025)], dark, sides=5)
    part.loft([((sx, sy, 1.18), 0.018, 0.018), ((sx + 0.35, sy, 1.18), 0.018, 0.018)], dark, sides=4)
    sign = ctx.animated("sway", (sx + 0.25, sy, 1.17))
    for dx in (-0.08, 0.08):
        sign.loft([((dx, 0, 0.0), 0.004, 0.004), ((dx, 0, -0.1), 0.004, 0.004)], iron, sides=3)
    sign.box((0, 0, -0.2), (0.26, 0.03, 0.2), ctx.planks("8d6e63"))
    for side in (-1, 1):
        _mug(ctx, sign, (0, 0.022 * side, -0.25))
    for _ in range(4):
        x, y = rng.uniform(-0.3, 0.3), rng.uniform(-0.75, -0.55)
        part.loft([((x, y, 0.0), 0.02, 0.02), ((x, y, 0.01), 0.02, 0.02)], ctx.mat("cork", "8d6e63"), sides=5)


def _infirmary(ctx):
    """L'Infirmerie : quatre paillasses (une par case), chaudron d'onguent vert au milieu,
    étagère de bocaux, scie et bandages, seau de linges sanglants."""
    part = ctx.base
    straw = ctx.mat("straw", "c8a165", texture="straw")
    linen = ctx.cloth("d7ccc8")
    blood = ctx.mat("blood_stain", "7f0000")
    for x in (-0.5, 0.5):
        for y in (-0.5, 0.5):
            part.loft([((x, y, 0.0), 0.36, 0.17), ((x, y, 0.05), 0.34, 0.16), ((x, y, 0.07), 0.32, 0.15)],
                      straw, sides=8, twist=0.0)
            part.box((x + 0.05, y, 0.075), (0.5, 0.28, 0.012), linen)
            part.loft([((x - 0.26, y, 0.07), 0.06, 0.1), ((x - 0.26, y, 0.12), 0.05, 0.09)], ctx.cloth("efebe9"),
                      sides=6, twist=0.0)
            part.flat([(x + 0.1, y - 0.06, 0.083), (x + 0.2, y - 0.02, 0.083), (x + 0.16, y + 0.07, 0.083),
                       (x + 0.05, y + 0.04, 0.083)], blood, facing=(0, 0, 1))
    # Le chaudron d'onguent vert, sur son trépied et son petit feu.
    iron = ctx.iron("3a4045")
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.3
        part.loft([((0.13 * math.cos(a), 0.13 * math.sin(a), 0.0), 0.012, 0.012),
                   ((0.06 * math.cos(a), 0.06 * math.sin(a), 0.3), 0.012, 0.012)], iron, sides=4)
    _flame(ctx, (0, 0, 0.02), 0.045, outer="ff6f00")
    part.loft([((0, 0, 0.14), 0.06, 0.06), ((0, 0, 0.18), 0.11, 0.11), ((0, 0, 0.27), 0.1, 0.1)], iron, sides=8,
              cap_end=False)
    salve = ctx.mat("salve", "76ff03", emission=1.2, texture="slime")
    part.loft([((0, 0, 0.25), 0.095, 0.095), ((0, 0, 0.26), 0.09, 0.09)], salve, sides=8)
    bubbles = ctx.animated("flame", (0, 0, 0.26))
    for bx, by, r in ((0.03, 0.02, 0.025), (-0.04, -0.01, 0.02)):
        bubbles.loft([((bx, by, 0.0), r, r), ((bx, by, r * 1.6), 0.0, 0.0)], ctx.mat("bubble", "b2ff59", emission=3.0),
                     sides=6, cap_end=False)
    # L'étagère du fond : bocaux luisants, bandages roulés, un crâne.
    wood = ctx.planks("5d3a24")
    for z in (0.55, 0.85):
        part.box((0, 0.93, z), (1.3, 0.12, 0.03), wood)
    for x in (-0.65, 0.65):
        part.box((x, 0.93, 0.5), (0.04, 0.12, 1.0), wood)
    for k, color in enumerate(("76ff03", "ff4081", "40c4ff", "76ff03", "ffab40")):
        _bottle(ctx, part, (-0.5 + k * 0.22, 0.93, 0.565), color, height=0.12)
    for k in range(3):
        part.loft([((-0.4 + k * 0.12, 0.92, 0.88), 0.04, 0.04), ((-0.4 + k * 0.12, 0.92, 0.95), 0.04, 0.04)],
                  ctx.cloth("efebe9"), sides=7)
    _skull(ctx, part, (0.35, 0.93, 0.865), 0.9)
    # La scie d'os et les pinces, accrochées au mur de droite.
    steel = ctx.iron("b0bec5")
    part.slab([(0.97, -0.1, 0.9), (0.97, 0.2, 0.9), (0.97, 0.2, 0.82), (0.97, -0.1, 0.84)], (-0.01, 0, 0), steel)
    part.box((0.965, -0.16, 0.86), (0.02, 0.1, 0.05), ctx.wood())
    # Le seau de linges sanglants, devant.
    part.loft([((0.0, -0.88, 0.0), 0.09, 0.09), ((0.0, -0.88, 0.16), 0.11, 0.11)], ctx.planks("795548"), sides=8,
              cap_end=False)
    part.loft([((0.0, -0.88, 0.12), 0.1, 0.1), ((0.0, -0.88, 0.18), 0.06, 0.06)], ctx.cloth("a33a3a"), sides=7)
    _candle(ctx, part, (-0.9, -0.9, 0.0), height=0.2)
    _candle(ctx, part, (0.9, -0.9, 0.0), height=0.16)


def _mint(ctx):
    """L'Hôtel des monnaies : four à fondre l'or (creuset rougeoyant), presse à vis au
    milieu, balance, sacs et piles de pièces, lingots, moules."""
    part = ctx.base
    rng = random.Random(31)
    stone = ctx.stone("5a4c45")
    dark = ctx.wood("3e2723")
    iron = ctx.iron("4a5258")
    # Le four, dans le coin du fond à gauche, et son creuset d'or fondu.
    fx, fy = -0.68, 0.68
    part.loft([((fx, fy, 0.0), 0.3, 0.3), ((fx, fy, 0.45), 0.26, 0.26), ((fx, fy, 0.52), 0.3, 0.3)], stone, sides=4,
              twist=math.pi / 4)
    part.loft([((fx, fy, 0.52), 0.24, 0.24), ((fx - 0.05, fy + 0.05, 1.5), 0.1, 0.1)], ctx.stone("3a302c"), sides=4,
              twist=math.pi / 4, cap_start=False)
    part.flat([(fx + 0.2, fy - 0.2, 0.08), (fx + 0.05, fy - 0.29, 0.08), (fx + 0.05, fy - 0.29, 0.3),
               (fx + 0.2, fy - 0.2, 0.3)], ctx.mat("furnace_mouth", "ff6d00", emission=2.5), facing=(1, -1, 0))
    crucible = ctx.animated("flame", (fx, fy, 0.52))
    crucible.loft([((0, 0, 0.0), 0.12, 0.12), ((0, 0, 0.06), 0.13, 0.13)], ctx.mat("molten", "ffab00", emission=3.0),
                  sides=8)
    _flame(ctx, (fx + 0.08, fy - 0.05, 0.56), 0.05, outer="ff6d00")
    # La presse à vis au milieu : deux montants, une traverse, la vis et sa barre.
    for x in (-0.18, 0.18):
        part.box((x, 0.0, 0.4), (0.07, 0.12, 0.8), dark)
    part.box((0, 0.0, 0.78), (0.5, 0.14, 0.09), dark)
    part.box((0, 0.0, 0.18), (0.42, 0.22, 0.1), stone)
    part.loft([((0, 0, 0.3), 0.035, 0.035), ((0, 0, 0.92), 0.035, 0.035)], iron, sides=6)
    for k in range(6):
        part.loft([((0, 0, 0.36 + k * 0.07), 0.045, 0.045), ((0, 0, 0.38 + k * 0.07), 0.045, 0.045)], iron, sides=6,
                  cap_start=False, cap_end=False)
    part.loft([((-0.3, 0, 0.9), 0.015, 0.015), ((0.3, 0, 0.9), 0.015, 0.015)], iron, sides=4)
    for x in (-0.3, 0.3):
        part.loft([((x, 0, 0.9), 0.03, 0.03), ((x * 1.1, 0, 0.9), 0.0, 0.0)], ctx.mat("knob", "e0a526"), sides=5)
    part.loft([((0, 0, 0.24), 0.07, 0.07), ((0, 0, 0.26), 0.07, 0.07)], ctx.gold(), sides=8)
    # Les piles de pièces et les sacs d'or, dans les coins de devant.
    for cx, cy in ((-0.82, -0.82), (0.82, -0.8)):
        _coin_pile(ctx, part, (cx, cy, 0.0), (0.15, 0.15), 0.16, rng, 10)
        part.loft([((cx + 0.02, cy + 0.18, 0.0), 0.08, 0.08), ((cx + 0.02, cy + 0.18, 0.1), 0.1, 0.1),
                   ((cx + 0.02, cy + 0.18, 0.2), 0.04, 0.04), ((cx + 0.02, cy + 0.18, 0.24), 0.05, 0.05)],
                  ctx.mat("sack", "8d6e63", texture="cloth"), sides=7)
    # Les lingots empilés, la balance sur son établi (au fond à droite).
    for k, (x, y, z) in enumerate(((0.55, 0.85, 0.03), (0.7, 0.85, 0.03), (0.62, 0.85, 0.08))):
        part.box((x, y, z), (0.13, 0.07, 0.05), ctx.gold("ffc107", 0.2))
    tx, ty = 0.68, 0.55
    part.box((tx, ty, 0.45), (0.5, 0.3, 0.04), ctx.planks())
    for x in (-0.2, 0.2):
        part.box((tx + x, ty, 0.22), (0.04, 0.24, 0.44), dark)
    brass = ctx.mat("brass", "b8892e", texture="metal")
    part.loft([((tx, ty, 0.47), 0.012, 0.012), ((tx, ty, 0.75), 0.012, 0.012)], brass, sides=4)
    part.loft([((tx - 0.15, ty, 0.74), 0.008, 0.008), ((tx + 0.15, ty, 0.74), 0.008, 0.008)], brass, sides=4)
    for x in (-0.15, 0.15):
        part.loft([((tx + x, ty, 0.6), 0.05, 0.05), ((tx + x, ty, 0.62), 0.055, 0.055)], brass, sides=7,
                  cap_end=False)
    part.loft([((tx - 0.15, ty, 0.62), 0.03, 0.03), ((tx - 0.15, ty, 0.64), 0.0, 0.0)], ctx.gold(), sides=6,
              cap_end=False)
    _candle(ctx, part, (tx + 0.2, ty - 0.1, 0.47), height=0.1)


def _torture(ctx):
    """La Chambre de torture : chevalet au milieu, cage pendue qui se balance, brasero
    et fers rougis, chaînes au mur, râtelier d'outils, sang."""
    part = ctx.base
    wood = ctx.planks("5d4037")
    dark = ctx.wood("3e2723")
    iron = ctx.iron("37474f")
    blood = ctx.mat("blood_pool", "6a0000", emission=0.1)
    # Le chevalet, au milieu, le long de X.
    for x in (-0.38, 0.38):
        for y in (-0.15, 0.15):
            part.box((x, y, 0.17), (0.06, 0.06, 0.34), dark)
    for y in (-0.15, 0.15):
        part.box((0, y, 0.33), (0.86, 0.06, 0.05), wood)
    for x in (-0.38, 0.38):
        part.loft([((x, -0.2, 0.38), 0.04, 0.04), ((x, 0.2, 0.38), 0.04, 0.04)], dark, sides=6)
    for x in (-0.48, 0.48):
        part.box((x, -0.22, 0.38), (0.02, 0.02, 0.2), iron)
    rope = ctx.mat("rope", "8d6e63", texture="straw")
    part.loft([((-0.38, 0.0, 0.38), 0.008, 0.008), ((0.38, 0.0, 0.38), 0.008, 0.008)], rope, sides=4)
    part.flat([(-0.2, -0.3, 0.004), (0.1, -0.35, 0.004), (0.15, -0.5, 0.004), (-0.1, -0.55, 0.004),
               (-0.28, -0.45, 0.004)], blood, facing=(0, 0, 1))
    # La cage pendue à une potence, au fond à droite (elle se balance).
    px, py = 0.88, 0.88
    part.loft([((px, py, 0.0), 0.035, 0.035), ((px, py, 1.45), 0.03, 0.03)], dark, sides=5)
    part.loft([((px, py, 1.42), 0.025, 0.025), ((px - 0.4, py - 0.4, 1.42), 0.025, 0.025)], dark, sides=4)
    cage = ctx.animated("sway", (px - 0.36, py - 0.36, 1.4))
    cage.loft([((0, 0, 0.0), 0.006, 0.006), ((0, 0, -0.25), 0.006, 0.006)], iron, sides=3)
    for k in range(8):
        a = 2 * math.pi * k / 8
        x, y = 0.14 * math.cos(a), 0.14 * math.sin(a)
        cage.loft([((x, y, -0.3), 0.007, 0.007), ((x, y, -0.8), 0.007, 0.007)], iron, sides=3)
    for z in (-0.3, -0.8):
        cage.loft([((0, 0, z - 0.01), 0.145, 0.145), ((0, 0, z + 0.01), 0.145, 0.145)], iron, sides=8,
                  cap_start=False, cap_end=False)
    cage.loft([((0, 0, -0.3), 0.14, 0.14), ((0, 0, -0.25), 0.0, 0.0)], iron, sides=8, cap_end=False)
    _skull(ctx, cage, (0.02, 0.0, -0.79), 0.9)
    cage.box((-0.04, 0.03, -0.77), (0.14, 0.018, 0.018), ctx.mat("bone", "e0dccb", texture="rough"), rotation_z=0.7)
    # Le brasero et ses fers rougis, devant à gauche.
    bx, by = -0.82, -0.82
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        part.loft([((bx + 0.12 * math.cos(a), by + 0.12 * math.sin(a), 0.0), 0.015, 0.015),
                   ((bx + 0.05 * math.cos(a), by + 0.05 * math.sin(a), 0.45), 0.015, 0.015)], iron, sides=4)
    part.loft([((bx, by, 0.43), 0.07, 0.07), ((bx, by, 0.5), 0.16, 0.16), ((bx, by, 0.56), 0.18, 0.18)],
              ctx.iron("455a64"), sides=8, cap_end=False)
    part.loft([((bx, by, 0.53), 0.15, 0.15), ((bx, by, 0.55), 0.1, 0.1)], ctx.mat("embers", "bf360c", emission=1.5),
              sides=8)
    _flame(ctx, (bx, by, 0.55), 0.09, outer="ff3d00", inner="ffab00")
    hot = ctx.mat("hot_iron", "ff5722", emission=2.5)
    for k, a in enumerate((0.5, 1.2, 2.0)):
        tip_x, tip_y = bx + 0.05 * math.cos(a), by + 0.05 * math.sin(a)
        part.loft([((tip_x, tip_y, 0.56), 0.01, 0.01), ((tip_x + 0.2 * math.cos(a), tip_y + 0.2 * math.sin(a), 0.78),
                                                        0.01, 0.01)], iron, sides=4)
        part.loft([((tip_x, tip_y, 0.56), 0.016, 0.016), ((tip_x - 0.04 * math.cos(a), tip_y - 0.04 * math.sin(a), 0.53),
                                                          0.0, 0.0)], hot, sides=4, cap_end=False)
    # Les chaînes et fers au mur du fond.
    for x in (-0.55, -0.2):
        for k in range(7):
            part.box((x, 0.96, 1.0 - k * 0.06), (0.03, 0.012, 0.05) if k % 2 else (0.012, 0.03, 0.05), iron)
        _ring(part, (x, 0.95, 0.56), 0.05, 0.02, iron, sides=7)
    # Le râtelier d'outils sur le mur de gauche : pince, scie, marteau, tisonnier.
    part.box((-0.96, 0.3, 0.75), (0.03, 0.6, 0.06), dark)
    steel = ctx.iron("90a4ae")
    for k, y in enumerate((0.08, 0.22, 0.36, 0.5)):
        part.loft([((-0.94, y, 0.78), 0.01, 0.01), ((-0.94, y, 0.4 + 0.05 * k), 0.01, 0.01)], steel, sides=4)
        part.box((-0.94, y, 0.4 + 0.05 * k), (0.02, 0.06 if k % 2 else 0.03, 0.06), steel)
    _skull(ctx, part, (0.85, -0.85, 0.0), 1.1)


def _guardpost(ctx):
    """Le Poste de garde (1 x 2) : tour de guet au fond (plateforme, garde-corps, toit
    pointu, bannière), cor d'alarme sur son trépied, brasero, râtelier de lances."""
    part = ctx.base
    wood = ctx.planks("6d4c41")
    dark = ctx.wood("3e2723")
    iron = ctx.iron("37474f")
    # La tour : 4 poteaux, des croix, une plateforme à 1,3 m, un garde-corps et un toit.
    y0, y1 = 0.62, 0.95
    top = 1.3
    for x in (-0.4, 0.4):
        for y in (y0, y1):
            part.box((x, y, top / 2 + 0.2), (0.07, 0.07, top + 0.4), dark)
    for y in (y0, y1):
        brace = part
        brace.slab([(-0.38, y, 0.2), (-0.32, y, 0.2), (0.38, y, 1.05), (0.32, y, 1.05)], (0, 0.03, 0), dark)
    part.box((0, (y0 + y1) / 2, top), (0.9, 0.42, 0.05), wood)
    for y in (y0 - 0.02, y1 + 0.02):
        part.box((0, y, top + 0.22), (0.86, 0.03, 0.04), dark)
    for x in (-0.42, 0.42):
        part.box((x, (y0 + y1) / 2, top + 0.22), (0.03, 0.4, 0.04), dark)
    part.loft([((0, (y0 + y1) / 2, top + 0.6), 0.55, 0.3), ((0, (y0 + y1) / 2, top + 1.0), 0.0, 0.0)],
              ctx.mat("roof", "5d2a1a", texture="planks"), sides=4, twist=math.pi / 4, cap_end=False)
    part.cone((0, (y0 + y1) / 2, top + 0.98), (0, (y0 + y1) / 2, top + 1.15), 0.02, iron, sides=4)
    _banner_cloth(ctx, part, 0.0, y0 - 0.06, top + 0.18, 0.36, 0.55)
    # Une échelle contre la tour.
    for x in (-0.22, -0.06):
        part.loft([((x, y0 - 0.08, 0.0), 0.015, 0.015), ((x, y0 - 0.02, top), 0.015, 0.015)], dark, sides=4)
    for k in range(8):
        z = 0.12 + k * 0.15
        part.box((-0.14, y0 - 0.08 + 0.06 * z / top, z), (0.18, 0.02, 0.02), dark)
    # Le cor d'alarme sur son trépied, devant à droite.
    hx, hy = 0.3, -0.75
    for k in range(3):
        a = 2 * math.pi * k / 3
        part.loft([((hx + 0.12 * math.cos(a), hy + 0.12 * math.sin(a), 0.0), 0.012, 0.012),
                   ((hx, hy, 0.55), 0.012, 0.012)], dark, sides=4)
    horn = ctx.mat("horn", "cfc6b8", texture="rough")
    part.loft([((hx - 0.15, hy, 0.6), 0.02, 0.02), ((hx - 0.02, hy, 0.62), 0.04, 0.04), ((hx + 0.1, hy, 0.68), 0.06, 0.06),
               ((hx + 0.18, hy, 0.78), 0.1, 0.1)], horn, sides=8, cap_end=False)
    _ring(part, (hx + 0.18, hy, 0.775), 0.105, 0.025, ctx.mat("trim", "e0a526"), sides=8)
    # Le brasero, devant à gauche.
    bx, by = -0.3, -0.82
    part.loft([((bx, by, 0.0), 0.1, 0.1), ((bx, by, 0.06), 0.05, 0.05), ((bx, by, 0.5), 0.035, 0.035)], iron, sides=6)
    part.loft([((bx, by, 0.48), 0.05, 0.05), ((bx, by, 0.55), 0.13, 0.13), ((bx, by, 0.6), 0.15, 0.15)],
              iron, sides=8, cap_end=False)
    part.loft([((bx, by, 0.56), 0.12, 0.12), ((bx, by, 0.58), 0.08, 0.08)], ctx.mat("embers", "bf360c", emission=1.5),
              sides=8)
    _flame(ctx, (bx, by, 0.57), 0.08)
    # Le râtelier de lances, contre le bord droit (au milieu de la salle).
    steel = ctx.iron("cfd8dc")
    part.box((0.45, 0.0, 0.15), (0.06, 0.4, 0.04), dark)
    part.box((0.45, 0.0, 0.8), (0.06, 0.4, 0.04), dark)
    for k in range(3):
        y = -0.14 + k * 0.14
        part.loft([((0.45, y, 0.02), 0.012, 0.012), ((0.45, y, 1.1), 0.012, 0.012)], ctx.wood("8d6e63"), sides=4)
        part.cone((0.45, y, 1.1), (0.45, y, 1.24), 0.028, steel, sides=4)
    # Des sacs de sable et une caisse.
    sand = ctx.mat("sandbag", "a1887f", texture="cloth")
    for x, y in ((-0.38, 0.1), (-0.38, -0.12)):
        part.loft([((x, y, 0.0), 0.08, 0.1), ((x, y, 0.07), 0.09, 0.11), ((x, y, 0.12), 0.06, 0.08)], sand, sides=7)
    part.box((-0.36, 0.0, 0.22), (0.16, 0.2, 0.1), ctx.planks("8d6e63"))


def _mana_well(ctx):
    """Le Puits de mana : margelle de pierres runiques autour d'une eau bleue qui luit,
    cristal qui flotte au-dessus (il monte et descend), cristaux dans les coins,
    cercle de runes au sol."""
    part = ctx.base
    stone = ctx.stone("4f5966")
    rune = ctx.mat("rune_blue", "40c4ff", emission=2.5)
    mana = ctx.mat("mana_water", "29b6f6", emission=1.8, texture="slime")
    crystal = ctx.mat("crystal", "80d8ff", emission=2.2)
    # La margelle : 10 pierres taillées, chacune avec sa rune lumineuse.
    for k in range(10):
        a = 2 * math.pi * k / 10
        x, y = 0.3 * math.cos(a), 0.3 * math.sin(a)
        part.box((x, y, 0.15), (0.13, 0.1, 0.3), stone, rotation_z=a + math.pi / 2)
        part.box((x * 1.18, y * 1.18, 0.17), (0.04, 0.01, 0.07), rune, rotation_z=a + math.pi / 2)
    # Le rebord (un anneau : on voit l'eau au milieu), puis l'eau de mana qui luit.
    rim = ctx.stone("3d4550")
    outer = [(0.37 * math.cos(2 * math.pi * k / 20), 0.37 * math.sin(2 * math.pi * k / 20)) for k in range(20)]
    for k in range(20):
        (x0, y0), (x1, y1) = outer[k], outer[(k + 1) % 20]
        part.slab([(x0, y0, 0.3), (x1, y1, 0.3), (x1 * 0.62, y1 * 0.62, 0.3), (x0 * 0.62, y0 * 0.62, 0.3)],
                  (0, 0, 0.04), rim)
    part.loft([((0, 0, 0.22), 0.24, 0.24), ((0, 0, 0.25), 0.24, 0.24)], mana, sides=12)
    # Le cristal qui flotte au-dessus du puits (feu follet : il monte et descend).
    wisp = ctx.animated("wisp", (0, 0, 0.8), unique=True)
    wisp.loft([((0, 0, -0.2), 0.0, 0.0), ((0, 0, 0.0), 0.09, 0.09), ((0, 0, 0.22), 0.0, 0.0)], crystal, sides=6,
              cap_start=False, cap_end=False)
    for a in (0.0, 2.1, 4.2):
        x, y = 0.13 * math.cos(a), 0.13 * math.sin(a)
        wisp.loft([((x, y, -0.06), 0.0, 0.0), ((x, y, 0.0), 0.025, 0.025), ((x, y, 0.08), 0.0, 0.0)], crystal, sides=4,
                  cap_start=False, cap_end=False)
    # Des filets de mana qui montent du puits (animés comme des flammes).
    for a in (0.6, 2.6, 4.6):
        x, y = 0.15 * math.cos(a), 0.15 * math.sin(a)
        _flame(ctx, (x, y, 0.22), 0.05, outer="29b6f6", inner="e1f5fe")
    # Les grappes de cristaux dans les coins.
    for cx, cy in ((-0.82, -0.82), (0.82, -0.82), (-0.82, 0.82), (0.82, 0.82)):
        part.loft([((cx, cy, 0.0), 0.12, 0.12), ((cx, cy, 0.05), 0.08, 0.08)], ctx.stone("2e3640"), sides=6)
        for k, (dx, dy, h, tilt) in enumerate(((0, 0, 0.42, 0.0), (0.07, 0.03, 0.26, 0.1), (-0.06, 0.05, 0.3, -0.12),
                                               (0.02, -0.07, 0.22, 0.08))):
            base = (cx + dx, cy + dy, 0.03)
            tip = (cx + dx * 2.2 + tilt, cy + dy * 2.2, 0.03 + h)
            part.loft([(base, 0.04, 0.04), ((base[0] * 0.5 + tip[0] * 0.5, base[1] * 0.5 + tip[1] * 0.5,
                                             0.03 + h * 0.7), 0.045, 0.045), (tip, 0.0, 0.0)],
                      crystal, sides=5, cap_end=False)
    # Le cercle de runes au sol, entre la margelle et les coins.
    for k in range(16):
        a = 2 * math.pi * k / 16
        x, y = 0.62 * math.cos(a), 0.62 * math.sin(a)
        part.box((x, y, 0.004), (0.08, 0.025, 0.006), ctx.mat("rune_floor", "1e88e5", emission=1.2),
                 rotation_z=a + (math.pi / 2 if k % 2 else 0.0))


def _sarcophagus(ctx, part, x, occupied):
    """Un sarcophage de pierre le long de Y ; occupé : le couvercle a glissé et une lueur
    d'âme s'en échappe (animée comme une flamme)."""
    stone = ctx.stone("6b6670")
    dark = ctx.stone("3d3842")
    part.box((x, 0.0, 0.17), (0.34, 0.86, 0.34), stone)
    part.box((x, 0.0, 0.03), (0.38, 0.9, 0.06), dark)
    shift = 0.1 if occupied else 0.0
    lid_z = 0.37
    part.loft([((x, -0.43 + shift, lid_z), 0.17, 0.05), ((x, 0.43 + shift, lid_z), 0.17, 0.05)], dark, sides=6,
              twist=0.0)
    # Le gisant sculpté sur le couvercle : tête, mains jointes, épée.
    part.loft([((x, 0.28 + shift, lid_z + 0.04), 0.05, 0.05), ((x, 0.28 + shift, lid_z + 0.1), 0.045, 0.045)],
              stone, sides=6)
    part.box((x, 0.05 + shift, lid_z + 0.06), (0.1, 0.3, 0.05), stone)
    part.box((x, -0.2 + shift, lid_z + 0.055), (0.03, 0.34, 0.02), ctx.iron("90a4ae"))
    part.box((x, -0.05 + shift, lid_z + 0.06), (0.1, 0.02, 0.02), ctx.iron("90a4ae"))
    _skull(ctx, part, (x, -0.47, 0.08), 0.8)
    if occupied:
        # La fente du couvercle, d'où sort une lueur violette.
        part.flat([(x - 0.13, -0.43, lid_z + 0.001), (x + 0.13, -0.43, lid_z + 0.001), (x + 0.13, -0.33, lid_z + 0.001),
                   (x - 0.13, -0.33, lid_z + 0.001)], ctx.mat("soul_slit", "b388ff", emission=3.0), facing=(0, 0, 1))
        _flame(ctx, (x, -0.38, lid_z), 0.07, outer="7c4dff", inner="e1bee7")


def _crypt(ctx, occupied):
    """La Crypte : deux sarcophages le long des murs (occupés : une âme en sort), un
    ossuaire de crânes au fond, des cierges, un cercle gravé au sol."""
    part = ctx.base
    for k, x in enumerate((-0.8, 0.8)):
        _sarcophagus(ctx, part, x, k < occupied)
    # L'ossuaire : des niches pleines de crânes, au mur du fond.
    stone = ctx.stone("4a4550")
    part.box((0, 0.93, 0.55), (1.1, 0.12, 1.1), stone)
    for row in range(3):
        for col in range(4):
            x, z = -0.39 + col * 0.26, 0.25 + row * 0.3
            part.box((x, 0.865, z), (0.2, 0.01, 0.2), ctx.mat("niche", "15121a"))
            _skull(ctx, part, (x, 0.88, z - 0.09), 1.1)
    part.box((0, 0.9, 1.13), (1.2, 0.18, 0.06), ctx.stone("3d3842"))
    # Des cierges sur un chandelier de fer, au fond, et au pied des sarcophages.
    iron = ctx.iron("37474f")
    for x in (-0.5, 0.5):
        part.loft([((x, 0.72, 0.0), 0.08, 0.08), ((x, 0.72, 0.05), 0.03, 0.03), ((x, 0.72, 0.6), 0.02, 0.02)], iron,
                  sides=6)
        part.loft([((x - 0.12, 0.72, 0.6), 0.012, 0.012), ((x + 0.12, 0.72, 0.6), 0.012, 0.012)], iron, sides=4)
        for dx in (-0.12, 0.0, 0.12):
            _candle(ctx, part, (x + dx, 0.72, 0.6), height=0.12 if dx else 0.18)
    for x, y in ((-0.55, -0.85), (0.55, -0.85)):
        _candle(ctx, part, (x, y, 0.0), height=0.22)
        part.loft([((x, y, 0.0), 0.045, 0.045), ((x, y, 0.02), 0.045, 0.045)], ctx.mat("wax_pool", "eceff1"), sides=7)
    # Le cercle gravé au sol (pentacle de pierre sombre, faiblement lumineux).
    glow = ctx.mat("crypt_rune", "7c4dff", emission=0.8)
    for k in range(20):
        a = 2 * math.pi * k / 20
        part.box((0.38 * math.cos(a), -0.1 + 0.38 * math.sin(a), 0.004), (0.12, 0.02, 0.006), glow,
                 rotation_z=a + math.pi / 2)
    for k in range(5):
        a1 = math.pi / 2 + 2 * math.pi * k / 5
        a2 = math.pi / 2 + 2 * math.pi * (k + 2) / 5
        x1, y1 = 0.36 * math.cos(a1), -0.1 + 0.36 * math.sin(a1)
        x2, y2 = 0.36 * math.cos(a2), -0.1 + 0.36 * math.sin(a2)
        length = math.hypot(x2 - x1, y2 - y1)
        part.box(((x1 + x2) / 2, (y1 + y2) / 2, 0.005), (length, 0.018, 0.006), glow,
                 rotation_z=math.atan2(y2 - y1, x2 - x1))


BUILDERS = {
    "bed": _bed,
    "mushrooms_1": lambda ctx: _mushrooms(ctx, 1),
    "mushrooms_2": lambda ctx: _mushrooms(ctx, 2),
    "mushrooms_3": lambda ctx: _mushrooms(ctx, 3),
    "prison": _prison,
    "tomb_empty": lambda ctx: _tomb(ctx, False),
    "tomb_full": lambda ctx: _tomb(ctx, True),
    "wall_torch": _wall_torch,
    "torch": _torch,
    "banner": _banner,
    "treasury_0": lambda ctx: _treasury(ctx, 0),
    "treasury_1": lambda ctx: _treasury(ctx, 1),
    "treasury_2": lambda ctx: _treasury(ctx, 2),
    "treasury_3": lambda ctx: _treasury(ctx, 3),
    "library": _library,
    "workshop": _workshop,
    "training": _training,
    "temple": _temple,
    "throne": _throne,
    # Les antres (règles 2.7).
    "tavern": _tavern,
    "infirmary": _infirmary,
    "mint": _mint,
    "torture": _torture,
    "guardpost": _guardpost,
    "mana_well": _mana_well,
    "crypt_0": lambda ctx: _crypt(ctx, 0),
    "crypt_1": lambda ctx: _crypt(ctx, 1),
    "crypt_2": lambda ctx: _crypt(ctx, 2),
}
