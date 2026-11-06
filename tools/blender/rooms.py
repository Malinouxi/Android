"""Le mobilier des salles en low-poly (assets/models/rooms/<nom>.glb).

Objets d'une case (centrés sur la case, 1 m de côté) :
  bed (Repaire), mushrooms_1..3 (Champignonnière), prison (une cellule),
  tomb_empty, tomb_full (Cimetière).
Objets de plusieurs cases, centrés sur leur milieu, le côté LONG le long de Y
(le jeu les tourne d'un quart de tour s'ils sont posés dans l'autre sens) :
  treasury_0..3 (Trésor 1 x 2, rempli de 0 à 3), library (2 x 3),
  workshop (2 x 2), training (2 x 4), temple (2 x 3).

Les parties animées sont des pivots nommés, que view_3d.gd fait bouger :
  flame_* (flammes qui vacillent vers le haut : l'origine est à leur base),
  sway_* (mannequins qui se balancent), wisp (feu follet qui flotte).

Repère : Blender Y = -Z de Godot (voir lowpoly.py). Les mises en place reprennent
celles des modèles en blocs de voxel_models.gd.

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

    def mat(self, key, color, emission=0.0, double_sided=False):
        return lp.material("room_%s" % key, color, emission, double_sided)

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


# ---------------------------------------------------------------------------
# Petites formes réutilisées
# ---------------------------------------------------------------------------

def _flame(ctx, at, size, outer="ff9800", inner="ffeb3b"):
    """Une flamme en goutte (pivot flame_N à sa base)."""
    part = ctx.animated("flame", at)
    part.loft([((0, 0, 0), size * 0.55, size * 0.55), ((0, 0, size * 0.7), size, size),
               ((0, 0, size * 1.6), size * 0.45, size * 0.45), ((0, 0, size * 2.4), 0.0, 0.0)],
              ctx.mat("fire_%s" % outer, outer, emission=3.0), sides=6, cap_end=False)
    part.loft([((0, 0, size * 0.3), size * 0.5, size * 0.5), ((0, 0, size * 0.9), size * 0.6, size * 0.6),
               ((0, 0, size * 1.9), 0.0, 0.0)], ctx.mat("fire_%s" % inner, inner, emission=3.5), sides=5,
              cap_end=False, twist=0.3)
    return part


def _candle(ctx, part, at, wax="eceff1", fire="ffb300", height=0.14):
    x, y, z = at
    part.loft([((x, y, z), 0.025, 0.025), ((x, y, z + height), 0.022, 0.022)], ctx.mat("wax_%s" % wax, wax), sides=6)
    _flame(ctx, (x, y, z + height), 0.022, outer=fire)


def _plank_box(part, center, size, mat, rim_mat=None):
    """Une caisse : une boîte, et des renforts sur les arêtes verticales."""
    part.box(center, size, mat)
    if rim_mat:
        cx, cy, cz = center
        sx, sy, sz = size
        for dx in (-1, 1):
            for dy in (-1, 1):
                part.box((cx + dx * sx / 2, cy + dy * sy / 2, cz), (0.03, 0.03, sz + 0.005), rim_mat)


def _coin_pile(ctx, part, center, radius, height, rng, coins):
    """Un monticule d'or : un dôme à facettes, et des pièces et gemmes posées dessus."""
    gold = ctx.mat("gold", "e8a317", emission=0.12)
    shine = ctx.mat("gold_shine", "ffcc33", emission=0.3)
    cx, cy, cz = center
    rx, ry = radius
    part.loft([((cx, cy, cz), rx, ry), ((cx, cy, cz + height * 0.45), rx * 0.78, ry * 0.78),
               ((cx, cy, cz + height * 0.8), rx * 0.42, ry * 0.42), ((cx, cy, cz + height), 0.0, 0.0)],
              gold, sides=9, cap_end=False)
    for _ in range(coins):
        a = rng.uniform(0, 2 * math.pi)
        t = rng.uniform(0.0, 0.95)
        x, y = cx + math.cos(a) * rx * t, cy + math.sin(a) * ry * t
        # Hauteur de la surface du dôme à cette distance (approchée).
        z = cz + height * max(0.0, 1.0 - t ** 1.6) + 0.004
        r = rng.uniform(0.025, 0.04)
        part.loft([((x, y, z - 0.005), r, r), ((x, y, z + 0.006), r, r)], shine, sides=6)
    gems = ("e53935", "1e88e5", "43a047")
    for k in range(max(1, coins // 12)):
        a = rng.uniform(0, 2 * math.pi)
        t = rng.uniform(0.2, 0.7)
        x, y = cx + math.cos(a) * rx * t, cy + math.sin(a) * ry * t
        z = cz + height * (1.0 - t ** 1.6)
        color = gems[k % len(gems)]
        part.loft([((x, y, z - 0.01), 0.0, 0.0), ((x, y, z + 0.025), 0.03, 0.03), ((x, y, z + 0.05), 0.0, 0.0)],
                  ctx.mat("gem_%s" % color, color, emission=1.5), sides=4, cap_start=False, cap_end=False)


# ---------------------------------------------------------------------------
# Objets d'une case
# ---------------------------------------------------------------------------

def _bed(ctx):
    part = ctx.base
    wood = ctx.mat("wood", "6d4c41")
    dark = ctx.mat("wood_dark", "4e342e")
    # Cadre sur quatre pieds, paillasse, oreiller, couverture violette qui retombe.
    for x in (-0.33, 0.33):
        for y in (-0.19, 0.19):
            part.box((x, y, 0.08), (0.06, 0.06, 0.16), dark)
    part.box((0, 0, 0.13), (0.7, 0.42, 0.06), wood)
    part.loft([((0, 0, 0.16), 0.33, 0.19), ((0, 0, 0.22), 0.32, 0.18), ((0, 0, 0.24), 0.3, 0.16)],
              ctx.mat("straw", "c8a165"), sides=8, twist=0.0)
    part.loft([((-0.24, 0, 0.23), 0.08, 0.14), ((-0.24, 0, 0.29), 0.07, 0.12)], ctx.mat("pillow", "d7ccc8"),
              sides=6, twist=0.0)
    blanket = ctx.mat("blanket", "7e57c2")
    part.slab([(-0.1, -0.205, 0.255), (0.33, -0.205, 0.255), (0.33, 0.205, 0.255), (-0.1, 0.205, 0.255)],
              (0, 0, 0.025), blanket)
    for side in (-1, 1):
        part.slab([(-0.1, 0.205 * side, 0.27), (0.33, 0.205 * side, 0.27), (0.33, 0.215 * side, 0.15),
                   (-0.1, 0.215 * side, 0.15)], (0, 0.01 * side, 0), blanket)
    # Tête de lit sombre ornée d'un crâne cornu.
    part.slab([(-0.36, -0.21, 0.13), (-0.36, 0.21, 0.13), (-0.36, 0.21, 0.42), (-0.36, 0.08, 0.48),
               (-0.36, -0.08, 0.48), (-0.36, -0.21, 0.42)], (0.035, 0, 0), dark)
    bone = ctx.mat("bone", "e0dccb")
    part.loft([((-0.32, 0, 0.36), 0.045, 0.05), ((-0.31, 0, 0.42), 0.05, 0.05), ((-0.315, 0, 0.45), 0.03, 0.03)],
              bone, sides=6)
    for side in (-1, 1):
        part.cone((-0.32, 0.035 * side, 0.43), (-0.31, 0.09 * side, 0.5), 0.012, bone, sides=4)
        part.box((-0.272, 0.018 * side, 0.405), (0.012, 0.018, 0.016), ctx.mat("socket", "1a1a1a"))


MUSHROOM_SPOTS = [(-0.2, -0.15), (0.18, 0.15), (0.1, -0.22)]


def _mushrooms(ctx, count):
    part = ctx.base
    soil = ctx.mat("soil", "3e2b20")
    moss = ctx.mat("moss", "33691e")
    stem = ctx.mat("stem", "efebe9")
    cap = ctx.mat("cap", "e53935")
    dot = ctx.mat("cap_dot", "ffffff")
    rng = random.Random(3)
    # Le carré de terre et quelques touffes de mousse.
    part.loft([((0, 0, 0.0), 0.42, 0.42), ((0, 0, 0.03), 0.4, 0.4)], soil, sides=8)
    for x, y in ((0.25, -0.05), (-0.05, 0.25), (-0.28, 0.22)):
        part.loft([((x, y, 0.025), 0.06, 0.05), ((x, y, 0.05), 0.03, 0.025)], moss, sides=5)
    for i in range(count):
        x, y = MUSHROOM_SPOTS[i]
        scale = (1.0, 0.85, 0.7)[i]
        h = 0.17 * scale
        part.loft([((x, y, 0.02), 0.045 * scale, 0.045 * scale), ((x, y, h * 0.5), 0.035 * scale, 0.035 * scale),
                   ((x, y, h), 0.04 * scale, 0.04 * scale)], stem, sides=6)
        part.loft([((x, y, h - 0.01), 0.06 * scale, 0.06 * scale), ((x, y, h + 0.01), 0.13 * scale, 0.13 * scale),
                   ((x, y, h + 0.06 * scale), 0.1 * scale, 0.1 * scale), ((x, y, h + 0.1 * scale), 0.0, 0.0)],
                  cap, sides=8, cap_end=False)
        for k in range(4):
            a = rng.uniform(0, 2 * math.pi)
            r = 0.07 * scale
            px, py = x + math.cos(a) * r, y + math.sin(a) * r
            pz = h + 0.065 * scale
            part.loft([((px, py, pz), 0.016 * scale, 0.016 * scale), ((px * 1.0, py, pz + 0.012), 0.012 * scale,
                                                                        0.012 * scale)], dot, sides=5)
        # Un petit champignon à côté du grand.
        sx, sy = x + 0.09, y - 0.06
        part.loft([((sx, sy, 0.02), 0.018, 0.018), ((sx, sy, 0.07), 0.015, 0.015)], stem, sides=5)
        part.loft([((sx, sy, 0.065), 0.045, 0.045), ((sx, sy, 0.1), 0.0, 0.0)], cap, sides=6, cap_end=False)


def _prison(ctx):
    part = ctx.base
    iron = ctx.mat("iron", "78909c")
    dark = ctx.mat("iron_dark", "455a64")
    # Sol de paille, barreaux sur les quatre côtés, cadres haut et bas, porte avec serrure.
    part.loft([((0, 0, 0.0), 0.36, 0.36), ((0, 0, 0.015), 0.34, 0.34)], ctx.mat("straw", "c8a165"), sides=7)
    e = 0.45
    for z in (0.03, 0.9):
        for s in (-1, 1):
            part.box((0, s * e, z), (2 * e + 0.04, 0.05, 0.04), dark)
            part.box((s * e, 0, z), (0.05, 2 * e + 0.04, 0.04), dark)
    for k in range(7):
        t = -e + k * (2 * e / 6)
        for s in (-1, 1):
            part.loft([((t, s * e, 0.02), 0.014, 0.014), ((t, s * e, 0.91), 0.014, 0.014)], iron, sides=5)
            if abs(t) < e - 0.01:
                part.loft([((s * e, t, 0.02), 0.014, 0.014), ((s * e, t, 0.91), 0.014, 0.014)], iron, sides=5)
            part.cone((t, s * e, 0.91), (t, s * e, 0.97), 0.016, iron, sides=4)
    part.box((0, -e, 0.48), (2 * e, 0.04, 0.035), dark)
    part.box((0.15, -e - 0.025, 0.48), (0.07, 0.03, 0.08), ctx.mat("lock", "ffca28"))
    # Une chaîne qui pend du plafond de la cellule, et un seau.
    for k in range(5):
        part.box((0.3, 0.3, 0.86 - k * 0.05), (0.025, 0.012, 0.04) if k % 2 else (0.012, 0.025, 0.04), dark)
    part.loft([((-0.28, 0.28, 0.0), 0.06, 0.06), ((-0.28, 0.28, 0.12), 0.07, 0.07)], ctx.mat("bucket", "6d4c41"),
              sides=7, cap_end=False)


def _tomb(ctx, full):
    part = ctx.base
    stone = ctx.mat("tomb_stone", "7d8580")
    carve = ctx.mat("tomb_carve", "4f5650")
    # La stèle arrondie, gravée d'une croix, sur un socle.
    part.box((0, 0.25, 0.04), (0.38, 0.14, 0.08), stone)
    outline = [(-0.15, 0.08), (0.15, 0.08), (0.15, 0.36), (0.1, 0.44), (0, 0.47), (-0.1, 0.44), (-0.15, 0.36)]
    part.slab([(x, 0.2, z) for x, z in outline], (0, 0.09, 0), stone)
    part.box((0, 0.195, 0.33), (0.12, 0.01, 0.025), carve)
    part.box((0, 0.195, 0.31), (0.025, 0.01, 0.13), carve)
    moss = ctx.mat("moss", "33691e")
    part.box((-0.12, 0.2, 0.12), (0.06, 0.1, 0.05), moss)
    if full:
        # Un monticule de terre fraîche, des fleurs, et le feu follet vert.
        part.loft([((0, -0.08, 0.0), 0.18, 0.27), ((0, -0.08, 0.06), 0.15, 0.24), ((0, -0.08, 0.1), 0.09, 0.17)],
                  ctx.mat("earth", "5d4430"), sides=8, twist=0.0)
        for x, y, color in ((0.05, -0.15, "ffeb3b"), (-0.06, 0.0, "e1bee7")):
            part.loft([((x, y, 0.09), 0.004, 0.004), ((x, y, 0.15), 0.004, 0.004)], moss, sides=3)
            part.loft([((x, y, 0.145), 0.02, 0.02), ((x, y, 0.16), 0.0, 0.0)], ctx.mat("flower_" + color, color),
                      sides=5, cap_end=False)
        wisp = ctx.animated("wisp", (0.1, -0.1, 0.3), unique=True)
        wisp.loft([((0, 0, -0.06), 0.0, 0.0), ((0, 0, -0.02), 0.05, 0.05), ((0, 0, 0.03), 0.045, 0.045),
                   ((0, 0, 0.09), 0.0, 0.0)], ctx.mat("wisp", "76ff03", emission=5.0), sides=6,
                  cap_start=False, cap_end=False)
    else:
        # La fosse ouverte, le tas de terre et la pelle plantée.
        part.flat([(-0.17, -0.33, 0.004), (0.17, -0.33, 0.004), (0.17, 0.16, 0.004), (-0.17, 0.16, 0.004)],
                  ctx.mat("pit", "1e140c"), facing=(0, 0, 1))
        part.loft([((0.3, -0.25, 0.0), 0.12, 0.14), ((0.3, -0.25, 0.08), 0.08, 0.09), ((0.3, -0.25, 0.12), 0.0, 0.0)],
                  ctx.mat("earth", "6d5641"), sides=7, cap_end=False)
        wood = ctx.mat("wood", "6d4c41")
        part.loft([((0.3, -0.3, 0.06), 0.012, 0.012), ((0.33, -0.33, 0.42), 0.012, 0.012)], wood, sides=4)
        part.slab([(0.285, -0.32, 0.0), (0.345, -0.28, 0.0), (0.35, -0.28, 0.1), (0.29, -0.32, 0.1)],
                  (0.006, 0.006, 0), ctx.mat("iron", "78909c"))


# ---------------------------------------------------------------------------
# Objets de plusieurs cases (largeur w le long de X, profondeur d le long de Y)
# ---------------------------------------------------------------------------

def _treasury(ctx, level):
    w, d = 1.0, 2.0
    part = ctx.base
    rng = random.Random(7)
    wood = ctx.mat("chest_wood", "8d5a2b")
    lid_wood = ctx.mat("chest_lid", "7a4a22")
    iron = ctx.mat("chest_iron", "546e7a")
    chest_y = d * 0.5 - 0.35
    # Le coffre ouvert, cerclé de fer, avec sa serrure dorée.
    part.box((0, chest_y, 0.18), (0.62, 0.4, 0.36), wood)
    for z in (0.09, 0.3):
        part.box((0, chest_y, z), (0.64, 0.42, 0.045), iron)
    for x in (-0.2, 0.2):
        part.box((x, chest_y, 0.18), (0.045, 0.42, 0.37), iron)
    part.box((0, chest_y - 0.212, 0.27), (0.07, 0.01, 0.08), ctx.mat("lock", "ffca28"))
    # Le couvercle bombé, ouvert vers l'arrière.
    hinge_y, hinge_z = chest_y + 0.2, 0.36
    part.slab([(-0.31, hinge_y, hinge_z), (-0.31, hinge_y + 0.07, hinge_z + 0.05), (-0.31, hinge_y + 0.09, hinge_z + 0.2),
               (-0.31, hinge_y + 0.07, hinge_z + 0.35), (-0.31, hinge_y, hinge_z + 0.4)], (0.62, 0, 0), lid_wood)
    part.box((0, hinge_y + 0.05, hinge_z + 0.2), (0.64, 0.05, 0.04), iron)
    if level <= 0:
        return
    # De l'or dans le coffre, puis un tas qui coule jusqu'au bout de la place.
    _coin_pile(ctx, part, (0, chest_y, 0.3), (0.27, 0.17), 0.04 + 0.04 * level, rng, 5 * level)
    height = 0.12 + 0.12 * level
    _coin_pile(ctx, part, (0, -0.1 - 0.05 * level, 0.0), (0.28 + 0.06 * level, 0.42 + 0.12 * level), height,
               rng, 14 + 10 * level)
    if level >= 2:
        _coin_pile(ctx, part, (0.22, chest_y - 0.35, 0.0), (0.16, 0.16), 0.1 + 0.03 * level, rng, 6)
    if level >= 3:
        # Une couronne et un calice posés au sommet.
        crown = ctx.mat("crown", "ffc107", emission=0.2)
        top = (0.0, -0.25, height + 0.0)
        part.loft([((top[0], top[1], top[2] - 0.02), 0.06, 0.06), ((top[0], top[1], top[2] + 0.03), 0.06, 0.06)],
                  crown, sides=8, cap_start=False, cap_end=False)
        for k in range(5):
            a = 2 * math.pi * k / 5
            part.cone((top[0] + 0.06 * math.cos(a), top[1] + 0.06 * math.sin(a), top[2] + 0.025),
                      (top[0] + 0.062 * math.cos(a), top[1] + 0.062 * math.sin(a), top[2] + 0.07), 0.015, crown, sides=3)
        cx, cy = -0.25, 0.1
        part.loft([((cx, cy, 0.12), 0.04, 0.04), ((cx, cy, 0.13), 0.012, 0.012), ((cx, cy, 0.2), 0.012, 0.012),
                   ((cx, cy, 0.22), 0.045, 0.045), ((cx, cy, 0.28), 0.05, 0.05)], crown, sides=7, cap_end=False)


def _rug(ctx, part, center, size, color="7f1d2d", border="ffca28"):
    cx, cy = center
    sx, sy = size
    part.box((cx, cy, 0.008), (sx + 0.06, sy + 0.06, 0.012), ctx.mat("rug_border", border))
    part.box((cx, cy, 0.012), (sx, sy, 0.014), ctx.mat("rug", color))


def _library(ctx):
    w, d = 2.0, 3.0
    part = ctx.base
    wood = ctx.mat("lib_wood", "5d3a24")
    shelf_mat = ctx.mat("lib_shelf", "3e2716")
    colors = ["8e1b1b", "1a3a6b", "2e5b2a", "8d6e00", "4a148c", "6d4c41", "b71c1c", "00695c"]
    rng = random.Random(11)
    _rug(ctx, part, (0, 0), (w * 0.36, d - 0.5))
    for side in (-1, 1):
        x = side * (w * 0.5 - 0.2)
        # Le meuble : fond, montants, corniche.
        part.box((x + side * 0.13, 0, 0.7), (0.04, d - 0.2, 1.4), wood)
        for y in (-(d - 0.2) / 2, 0.0, (d - 0.2) / 2):
            part.box((x, y, 0.7), (0.3, 0.05, 1.4), wood)
        part.box((x, 0, 1.42), (0.34, d - 0.12, 0.06), wood)
        for shelf in range(4):
            z = 0.12 + shelf * 0.32
            part.box((x, 0, z - 0.02), (0.3, d - 0.2, 0.03), shelf_mat)
            # Les livres, de hauteurs et couleurs variées, parfois penchés.
            for half in (-1, 1):
                y = 0.04 * half if half > 0 else -(d - 0.2) / 2 + 0.04
                end = (d - 0.2) / 2 - 0.04 if half > 0 else -0.04
                while y < end - 0.05:
                    thick = rng.uniform(0.045, 0.075)
                    height = rng.uniform(0.18, 0.26)
                    if rng.random() < 0.08:
                        y += 0.07  # Un trou dans le rayonnage.
                        continue
                    color = rng.choice(colors)
                    part.box((x - side * 0.01, y + thick / 2, z + height / 2), (0.22, thick, height),
                             ctx.mat("book_" + color, color))
                    y += thick + 0.005
    # Le pupitre au milieu, un livre ouvert et une bougie, une pile de livres au sol.
    part.loft([((0, 0, 0.0), 0.14, 0.14), ((0, 0, 0.04), 0.12, 0.12)], wood, sides=6)
    part.loft([((0, 0, 0.04), 0.045, 0.045), ((0, 0, 0.58), 0.045, 0.045)], wood, sides=6)
    part.slab([(-0.26, -0.2, 0.56), (0.26, -0.2, 0.56), (0.26, 0.2, 0.66), (-0.26, 0.2, 0.66)], (0, 0, 0.04), wood)
    page = ctx.mat("page", "efe6d8")
    for side in (-1, 1):
        part.slab([(0.0, -0.13, 0.605), (0.17 * side, -0.13, 0.615), (0.17 * side, 0.13, 0.67), (0.0, 0.13, 0.66)],
                  (0, 0, 0.012), page)
    part.box((0.0, 0.0, 0.62), (0.012, 0.27, 0.04), ctx.mat("book_8e1b1b", "8e1b1b"))
    _candle(ctx, part, (0.2, 0.12, 0.68))
    for k, color in enumerate(("1a3a6b", "8e1b1b", "2e5b2a")):
        part.box((0.35, -0.75, 0.03 + k * 0.05), (0.26 - k * 0.03, 0.18, 0.05), ctx.mat("book_" + color, color),
                 rotation_z=0.3 * k)


def _workshop(ctx):
    w, d = 2.0, 2.0
    part = ctx.base
    stone = ctx.mat("forge_stone", "4e4440")
    stone_dark = ctx.mat("forge_dark", "3a302c")
    # La forge en pierre (coin arrière gauche), ses braises, sa hotte et son conduit.
    fx, fy = -w * 0.5 + 0.45, d * 0.5 - 0.4
    part.loft([((fx, fy, 0.0), 0.4, 0.34), ((fx, fy, 0.5), 0.38, 0.32), ((fx, fy, 0.56), 0.4, 0.34)],
              stone, sides=4, twist=math.pi / 4)
    for k in range(4):  # Pierres en relief.
        part.box((fx - 0.2 + 0.13 * k, fy - 0.33, 0.12 + 0.12 * (k % 2)), (0.1, 0.03, 0.07), stone_dark)
    coals = ctx.animated("flame", (fx, fy, 0.55))
    coals.loft([((0, 0, 0.0), 0.3, 0.24), ((0, 0, 0.04), 0.24, 0.19), ((0, 0, 0.08), 0.0, 0.0)],
               ctx.mat("coals", "e64a19", emission=2.0), sides=7, cap_end=False)
    coals.cone((0.05, 0.0, 0.04), (0.05, 0.0, 0.2), 0.06, ctx.mat("fire_ffab00", "ffab00", emission=3.0), sides=5)
    coals.cone((-0.08, 0.06, 0.03), (-0.08, 0.06, 0.15), 0.05, ctx.mat("fire_ffab00", "ffab00", emission=3.0), sides=5)
    part.loft([((fx, fy + 0.05, 0.95), 0.3, 0.25), ((fx, fy + 0.07, 1.2), 0.13, 0.11),
               ((fx, fy + 0.08, 1.6), 0.12, 0.1)], stone_dark, sides=4, twist=math.pi / 4, cap_start=False)
    for x in (-0.28, 0.28):
        part.box((fx + x, fy + 0.05, 0.75), (0.06, 0.06, 0.4), stone_dark)
    # L'enclume sur sa souche, une pièce rougeoyante dessus, le marteau posé.
    ax, ay = 0.15, -0.1
    part.loft([((ax, ay, 0.0), 0.15, 0.15), ((ax, ay, 0.22), 0.13, 0.13)], ctx.mat("stump", "795548"), sides=7)
    steel = ctx.mat("anvil", "607d8b")
    part.box((ax, ay, 0.28), (0.14, 0.12, 0.12), steel)
    part.slab([(ax - 0.2, ay - 0.08, 0.34), (ax + 0.15, ay - 0.08, 0.34), (ax + 0.3, ay - 0.08, 0.39),
               (ax + 0.15, ay - 0.08, 0.43), (ax - 0.2, ay - 0.08, 0.43)], (0, 0.16, 0), steel)
    glow = ctx.animated("flame", (ax, ay, 0.43))
    glow.box((0, 0, 0.01), (0.18, 0.04, 0.02), ctx.mat("hot_iron", "ff5722", emission=2.5))
    wood = ctx.mat("wood", "6d4c41")
    part.loft([((ax + 0.05, ay + 0.2, 0.01), 0.012, 0.012), ((ax + 0.3, ay + 0.25, 0.02), 0.012, 0.012)], wood, sides=4)
    part.box((ax + 0.32, ay + 0.255, 0.035), (0.05, 0.09, 0.05), steel)
    # L'établi avec ses outils (devant à droite), un tonneau et des lingots.
    bx, by = w * 0.5 - 0.55, -d * 0.5 + 0.3
    part.box((bx, by, 0.55), (0.9, 0.36, 0.06), wood)
    for x in (-0.38, 0.38):
        for y in (-0.13, 0.13):
            part.box((bx + x, by + y, 0.26), (0.06, 0.06, 0.52), ctx.mat("wood_dark", "4e342e"))
    part.box((bx, by, 0.15), (0.8, 0.3, 0.03), ctx.mat("wood_dark", "4e342e"))
    part.box((bx - 0.15, by, 0.6), (0.3, 0.05, 0.03), ctx.mat("blade", "b0bec5"))
    part.box((bx + 0.2, by - 0.02, 0.6), (0.05, 0.2, 0.04), ctx.mat("grip", "8d6e63"))
    part.box((bx + 0.2, by + 0.09, 0.61), (0.11, 0.05, 0.05), steel)
    rx, ry = -w * 0.5 + 0.3, -d * 0.5 + 0.3
    barrel = ctx.mat("barrel", "795548")
    part.loft([((rx, ry, 0.0), 0.15, 0.15), ((rx, ry, 0.25), 0.18, 0.18), ((rx, ry, 0.5), 0.15, 0.15)], barrel, sides=8)
    for z in (0.08, 0.42):
        part.loft([((rx, ry, z - 0.015), 0.163, 0.163), ((rx, ry, z + 0.015), 0.163, 0.163)],
                  ctx.mat("iron_dark", "455a64"), sides=8, cap_start=False, cap_end=False)
    ingot = ctx.mat("ingot", "b0bec5")
    for k, (x, y, z) in enumerate(((0.55, 0.45, 0.025), (0.7, 0.45, 0.025), (0.62, 0.45, 0.075))):
        part.box((x, y, z), (0.12, 0.06, 0.05), ingot)


def _dummy(ctx, at):
    """Un mannequin d'entraînement (pivot sway_N au pied)."""
    part = ctx.animated("sway", at)
    wood = ctx.mat("wood", "6d4c41")
    straw = ctx.mat("dummy_straw", "d4a85a")
    rope = ctx.mat("rope", "8d6e63")
    part.loft([((0, 0, 0.0), 0.05, 0.05), ((0, 0, 0.9), 0.035, 0.035)], wood, sides=5)
    part.box((0, 0, 0.6), (0.52, 0.05, 0.05), wood)
    part.loft([((0, 0, 0.42), 0.12, 0.09), ((0, 0, 0.6), 0.15, 0.11), ((0, 0, 0.76), 0.12, 0.09)], straw, sides=7)
    for z in (0.47, 0.71):
        part.loft([((0, 0, z - 0.01), 0.13, 0.1), ((0, 0, z + 0.01), 0.13, 0.1)], rope, sides=7,
                  cap_start=False, cap_end=False)
    part.loft([((0, 0, 0.78), 0.06, 0.06), ((0, 0, 0.86), 0.09, 0.09), ((0, 0, 0.95), 0.0, 0.0)], straw, sides=6,
              cap_end=False)
    # La cible rouge et blanche sur le torse (vers l'avant : -Y).
    part.loft([((0, -0.1, 0.6), 0.075, 0.075), ((0, -0.115, 0.6), 0.075, 0.075)], ctx.mat("target_red", "c62828"),
              sides=8, twist=0.0)
    part.loft([((0, -0.115, 0.6), 0.045, 0.045), ((0, -0.12, 0.6), 0.045, 0.045)], ctx.mat("target_white", "eeeeee"),
              sides=8, twist=0.0)


def _training(ctx):
    w, d = 2.0, 4.0
    part = ctx.base
    wood = ctx.mat("wood", "6d4c41")
    # Le sable de l'arène, la palissade sur les grands côtés.
    part.box((0, 0, 0.008), (w - 0.2, d - 0.2, 0.016), ctx.mat("sand", "b8955a"))
    rng = random.Random(5)
    for _ in range(14):
        x, y = rng.uniform(-0.8, 0.8), rng.uniform(-1.8, 1.8)
        part.box((x, y, 0.018), (rng.uniform(0.05, 0.12), 0.03, 0.004), ctx.mat("sand_dark", "9c7a45"),
                 rotation_z=rng.uniform(0, 3))
    for side in (-1, 1):
        x = side * (w * 0.5 - 0.12)
        n = int(d / 0.4)
        for i in range(n + 1):
            y = -d * 0.5 + 0.12 + i * (d - 0.24) / n
            part.loft([((x, y, 0.0), 0.035, 0.035), ((x, y, 0.42), 0.035, 0.035), ((x, y, 0.48), 0.0, 0.0)],
                      wood, sides=5, cap_end=False)
        for z in (0.2, 0.36):
            part.box((x, 0, z), (0.04, d - 0.2, 0.05), wood)
    for y in (-d * 0.25, d * 0.15):
        _dummy(ctx, (0, y, 0.0))
    # Le râtelier d'armes au bout : épées, lances, une hache.
    ry = d * 0.5 - 0.2
    for x in (-0.38, 0.38):
        part.box((x, ry, 0.4), (0.05, 0.05, 0.8), wood)
    for z in (0.2, 0.7):
        part.box((0, ry, z), (0.8, 0.06, 0.05), wood)
    steel = ctx.mat("blade", "cfd8dc")
    for k in range(5):
        x = -0.28 + k * 0.14
        if k % 2 == 0:
            part.loft([((x, ry - 0.04, 0.12), 0.01, 0.01), ((x, ry - 0.04, 0.95), 0.01, 0.01)], wood, sides=4)
            part.cone((x, ry - 0.04, 0.95), (x, ry - 0.04, 1.08), 0.025, steel, sides=4)
        else:
            part.loft([((x, ry - 0.04, 0.1), 0.012, 0.012), ((x, ry - 0.04, 0.22), 0.012, 0.012)],
                      ctx.mat("grip", "8d6e63"), sides=4)
            part.box((x, ry - 0.04, 0.23), (0.09, 0.02, 0.02), ctx.mat("guard", "8d6e63"))
            part.loft([((x, ry - 0.04, 0.24), 0.022, 0.006), ((x, ry - 0.04, 0.68), 0.016, 0.005),
                       ((x, ry - 0.04, 0.74), 0.0, 0.0)], steel, sides=4, twist=0.0, cap_end=False)


def _temple(ctx):
    w, d = 2.0, 3.0
    part = ctx.base
    stone = ctx.mat("temple_stone", "5f5a5f")
    stone_light = ctx.mat("temple_stone_light", "726c72")
    back = d * 0.5
    _rug(ctx, part, (0, -0.3), (w * 0.34, d - 0.8))
    # L'estrade à deux marches.
    part.box((0, back - 0.6, 0.06), (w - 0.3, 1.0, 0.12), stone)
    part.box((0, back - 0.5, 0.18), (w - 0.6, 0.7, 0.12), stone_light)
    # L'autel drapé de violet, deux bougies.
    part.box((0, back - 0.45, 0.45), (0.7, 0.4, 0.42), ctx.mat("altar", "78909c"))
    part.box((0, back - 0.45, 0.67), (0.76, 0.46, 0.04), ctx.mat("altar_top", "90a4ae"))
    part.slab([(-0.16, back - 0.672, 0.66), (0.16, back - 0.672, 0.66), (0.16, back - 0.672, 0.3),
               (0.0, back - 0.672, 0.24), (-0.16, back - 0.672, 0.3)], (0, 0.012, 0), ctx.mat("drape", "6a1b9a"))
    for x in (-0.28, 0.28):
        _candle(ctx, part, (x, back - 0.45, 0.69))
    # La statue cornue derrière l'autel, aux yeux verts.
    statue = ctx.mat("statue", "4a4248")
    sy = back - 0.15
    part.box((0, sy, 0.36), (0.36, 0.3, 0.12), statue)
    part.loft([((0, sy, 0.42), 0.13, 0.1), ((0, sy, 0.62), 0.17, 0.11), ((0, sy, 0.86), 0.2, 0.12),
               ((0, sy, 0.92), 0.08, 0.07)], statue, sides=6)
    part.loft([((0, sy, 0.9), 0.09, 0.09), ((0, sy - 0.02, 1.0), 0.11, 0.1), ((0, sy, 1.12), 0.07, 0.07)],
              statue, sides=6)
    bone = ctx.mat("horn", "cfc6b8")
    eye = ctx.mat("statue_eye", "76ff03", emission=4.0)
    for side in (-1, 1):
        part.loft([((0.07 * side, sy, 1.08), 0.03, 0.03), ((0.15 * side, sy + 0.02, 1.18), 0.022, 0.022),
                   ((0.16 * side, sy + 0.05, 1.3), 0.0, 0.0)], bone, sides=5, cap_end=False)
        part.flat([(0.02 * side, sy - 0.112, 1.03), (0.065 * side, sy - 0.1, 1.04), (0.06 * side, sy - 0.104, 1.015),
                   (0.025 * side, sy - 0.11, 1.012)], eye, facing=(0, -1, 0))
        part.loft([((0.19 * side, sy, 0.84), 0.05, 0.05), ((0.24 * side, sy - 0.08, 0.62), 0.04, 0.04)], statue, sides=5)
    # Deux colonnes aux coins de l'estrade, et les braseros aux flammes vertes.
    for side in (-1, 1):
        cx = side * (w * 0.5 - 0.2)
        part.box((cx, back - 0.15, 0.04), (0.24, 0.24, 0.08), stone_light)
        part.loft([((cx, back - 0.15, 0.08), 0.08, 0.08), ((cx, back - 0.15, 1.3), 0.07, 0.07)], stone_light, sides=6)
        part.box((cx, back - 0.15, 1.33), (0.22, 0.22, 0.06), stone_light)
        bx, by = side * (w * 0.5 - 0.3), -d * 0.15
        iron = ctx.mat("brazier", "37474f")
        for k in range(3):
            a = 2 * math.pi * k / 3 + 0.5
            part.loft([((bx + 0.12 * math.cos(a), by + 0.12 * math.sin(a), 0.0), 0.015, 0.015),
                       ((bx + 0.05 * math.cos(a), by + 0.05 * math.sin(a), 0.48), 0.015, 0.015)], iron, sides=4)
        part.loft([((bx, by, 0.46), 0.08, 0.08), ((bx, by, 0.52), 0.17, 0.17), ((bx, by, 0.6), 0.2, 0.2)],
                  ctx.mat("brazier_bowl", "455a64"), sides=8, cap_end=False)
        part.loft([((bx, by, 0.56), 0.17, 0.17), ((bx, by, 0.58), 0.12, 0.12)], ctx.mat("coals_green", "1b5e20",
                                                                                          emission=1.0), sides=8)
        _flame(ctx, (bx, by, 0.57), 0.1, outer="76ff03", inner="ccff90")


BUILDERS = {
    "bed": _bed,
    "mushrooms_1": lambda ctx: _mushrooms(ctx, 1),
    "mushrooms_2": lambda ctx: _mushrooms(ctx, 2),
    "mushrooms_3": lambda ctx: _mushrooms(ctx, 3),
    "prison": _prison,
    "tomb_empty": lambda ctx: _tomb(ctx, False),
    "tomb_full": lambda ctx: _tomb(ctx, True),
    "treasury_0": lambda ctx: _treasury(ctx, 0),
    "treasury_1": lambda ctx: _treasury(ctx, 1),
    "treasury_2": lambda ctx: _treasury(ctx, 2),
    "treasury_3": lambda ctx: _treasury(ctx, 3),
    "library": _library,
    "workshop": _workshop,
    "training": _training,
    "temple": _temple,
}
