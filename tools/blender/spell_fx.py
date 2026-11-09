"""Les EFFETS DES SORTS en 3D low-poly (assets/models/fx/<nom>.glb), affichés par
scripts/spell_fx_3d.gd quand le maître lance un sort (vue 3D).

Tous les matériaux sont ÉMISSIFS (ils brillent sans lumière, et le « glow » de
la vue 3D leur donne un halo) : un téléphone moyen de gamme les affiche sans
calcul d'éclairage coûteux. Peu de faces (quelques centaines par effet).

Modèles (1 case = 1 m, centrés sur l'origine, posés au sol en z = 0) :
  bolt         l'Éclair : un zigzag de foudre de 4 m de haut et son impact au sol ;
  web          la Toile : une toile d'araignée à plat (rayon 1 m) ;
  flames       le Brasier : 7 flammes (pivots flame_N, animées par le jeu) ;
  rocks        l'Effondrement : 7 rochers (pivots rock_N, qui tombent) ;
  ghost        la Terreur : un spectre hurlant qui monte et s'efface ;
  rune_circle  un cercle magique au sol (blanc : le jeu le teinte selon le sort) ;
  dome         le Sanctuaire : un dôme à facettes (blanc, le jeu le rend translucide) ;
  eye          l'Œil du maître : un grand œil qui flotte ;
  hand         Relever les morts : une main squelettique qui sort du sol.

Construire (Blender 4+, ou le module Python « bpy ») :
    import sys; sys.path.insert(0, r"<projet>/tools/blender")
    import spell_fx; spell_fx.build_all(r"<projet>/assets/models/fx")
"""

import math
import os
import random

import lowpoly as lp
from lowpoly import Part, pivot


def _mat(name, color, emission=2.0):
    return lp.material("fx_%s_%s" % (name, color), color, emission, double_sided=True)


class _Fx:
    def __init__(self, name):
        self.scene = lp.new_scene("fx_" + name)
        self.parts = []

    def part(self, name, parent=None):
        p = Part(self.scene, name + "_mesh", parent)
        self.parts.append(p)
        return p

    def pivot(self, name, at=(0, 0, 0)):
        return pivot(self.scene, name, None, at)

    def finish(self):
        for p in self.parts:
            if len(p.bm.verts):
                p.finish()
            else:
                p.bm.free()


# ---------------------------------------------------------------------------
# Les modèles
# ---------------------------------------------------------------------------

def bolt(fx):
    rng = random.Random(7)
    core = _mat("bolt_core", "ffffff", 6.0)
    glow = _mat("bolt_glow", "8fd3ff", 4.0)
    points = [(0.0, 0.0, 4.2)]
    for k in range(1, 9):
        z = 4.2 * (1.0 - k / 8.0)
        jitter = 0.0 if k == 8 else 0.32
        points.append((rng.uniform(-jitter, jitter), rng.uniform(-jitter, jitter) * 0.5, z))
    main = fx.part("bolt")
    for a, b in zip(points, points[1:]):
        main.loft([(a, 0.07, 0.07), (b, 0.07, 0.07)], core, sides=5)
        main.loft([(a, 0.16, 0.16), (b, 0.16, 0.16)], glow, sides=5)
    # Deux branches.
    for start, length in ((3, 0.9), (5, 0.7)):
        a = points[start]
        b = (a[0] + rng.choice((-1, 1)) * length, a[1], a[2] - length * 0.9)
        main.loft([(a, 0.05, 0.05), (b, 0.0, 0.0)], core, sides=4, cap_end=False)
    # L'impact : une étoile à plat.
    star = []
    for k in range(16):
        angle = 2 * math.pi * k / 16
        r = 0.75 if k % 2 == 0 else 0.25
        star.append((math.cos(angle) * r, math.sin(angle) * r, 0.02))
    main.flat(star, glow, facing=(0, 0, 1))


def web(fx):
    silk = _mat("silk", "f2f4ff", 1.6)
    p = fx.part("web")
    spokes = 10
    rng = random.Random(3)
    angles = [2 * math.pi * k / spokes + rng.uniform(-0.12, 0.12) for k in range(spokes)]
    for a in angles:
        p.box((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.02), (1.0, 0.025, 0.01), silk, rotation_z=a)
    for r in (0.2, 0.38, 0.56, 0.74, 0.92):
        for k in range(spokes):
            a1, a2 = angles[k], angles[(k + 1) % spokes] + (2 * math.pi if k == spokes - 1 else 0)
            sag = 0.9
            x1, y1 = math.cos(a1) * r, math.sin(a1) * r
            x2, y2 = math.cos(a2) * r, math.sin(a2) * r
            mid = ((x1 + x2) / 2 * sag, (y1 + y2) / 2 * sag)
            for (ax, ay), (bx, by) in (((x1, y1), mid), (mid, (x2, y2))):
                length = math.hypot(bx - ax, by - ay)
                p.box(((ax + bx) / 2, (ay + by) / 2, 0.025), (length + 0.01, 0.02, 0.01), silk,
                      rotation_z=math.atan2(by - ay, bx - ax))


def flames(fx):
    rng = random.Random(11)
    spots = [(0, 0, 1.0)] + [(math.cos(a) * 0.55, math.sin(a) * 0.55, 0.7)
                             for a in (0.3, 1.5, 2.6, 3.7, 4.8, 5.8)]
    for x, y, s in spots:
        node = fx.pivot("flame_%d" % len([1 for o in fx.scene.objects if o.name.startswith("flame_")]),
                        (x, y, 0))
        part = fx.part(node.name, node)
        size = 0.22 * s * rng.uniform(0.85, 1.15)
        part.loft([((0, 0, 0), size * 0.6, size * 0.6), ((0, 0, size * 0.8), size, size),
                   ((0, 0, size * 1.8), size * 0.45, size * 0.45), ((0, 0, size * 2.8), 0.0, 0.0)],
                  _mat("fire_out", "ff5a14", 4.0), sides=6, cap_end=False)
        part.loft([((0, 0, size * 0.2), size * 0.5, size * 0.5), ((0, 0, size * 1.0), size * 0.6, size * 0.6),
                   ((0, 0, size * 2.0), 0.0, 0.0)], _mat("fire_in", "ffd54a", 5.0), sides=5,
                  cap_end=False, twist=0.3)
    ember = fx.part("embers")
    # Quelques braises éparses au sol (pas un disque plein : il masquerait tout).
    for k in range(9):
        a = 2 * math.pi * k / 9 + 0.3
        d = 0.35 + 0.45 * ((k * 37) % 10) / 10.0
        ember.box((math.cos(a) * d, math.sin(a) * d, 0.02), (0.09, 0.07, 0.03), _mat("ember", "c43a0a", 1.2),
                  rotation_z=a)


def rocks(fx):
    rng = random.Random(5)
    stone = lp.material("fx_rock", "6d625a", 0.0, texture="stone")
    dark = lp.material("fx_rock_dark", "4a403b", 0.0, texture="stone")
    spots = [(0, 0, 0.3), (0.45, 0.2, 0.22), (-0.4, 0.3, 0.2), (0.2, -0.45, 0.24), (-0.35, -0.35, 0.18),
             (0.5, -0.3, 0.15), (-0.55, 0.0, 0.16)]
    for k, (x, y, r) in enumerate(spots):
        node = fx.pivot("rock_%d" % k, (x, y, r * 0.7))
        part = fx.part(node.name, node)
        sections = []
        sides = 6
        for i, h in enumerate((-0.7, -0.2, 0.35, 0.8)):
            w = r * (0.55, 1.0, 0.9, 0.35)[i] * rng.uniform(0.85, 1.15)
            sections.append(((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), h * r), w, w * 0.85))
        part.loft(sections, stone if k % 2 == 0 else dark, sides=sides, twist=rng.uniform(0, 1))


def ghost(fx):
    body = _mat("ghost", "c5b3ff", 1.8)
    dark = lp.material("fx_ghost_dark", "120818", 0.0, double_sided=True)
    eye = _mat("ghost_eye", "ff2bd6", 4.0)
    node = fx.pivot("spirit", (0, 0, 0))
    p = fx.part("spirit", node)
    p.loft([((0, 0, 0.15), 0.08, 0.08), ((0.05, 0, 0.45), 0.22, 0.2), ((0, 0, 0.9), 0.32, 0.28),
            ((0, 0, 1.3), 0.3, 0.27), ((0, 0, 1.55), 0.2, 0.18), ((0, 0, 1.68), 0.0, 0.0)], body, sides=8,
           cap_end=False)
    for side in (-1, 1):
        p.loft([((side * 0.25, 0, 1.1), 0.08, 0.08), ((side * 0.55, -0.1, 1.35), 0.06, 0.06),
                ((side * 0.72, -0.15, 1.65), 0.0, 0.0)], body, sides=5, cap_end=False)
        p.flat([(side * 0.08, -0.29, 1.32), (side * 0.2, -0.27, 1.38), (side * 0.18, -0.26, 1.22),
                (side * 0.08, -0.28, 1.2)], dark, facing=(0, -1, 0))
        p.box((side * 0.13, -0.3, 1.3), (0.04, 0.02, 0.04), eye)
    p.flat([(-0.09, -0.29, 1.12), (0.09, -0.29, 1.12), (0.06, -0.28, 0.92), (-0.06, -0.28, 0.92)], dark,
           facing=(0, -1, 0))


def rune_circle(fx):
    white = _mat("rune", "ffffff", 2.5)
    p = fx.part("circle")
    for r, w in ((0.95, 0.05), (0.72, 0.035)):
        sides = 40
        for k in range(sides):
            a1, a2 = 2 * math.pi * k / sides, 2 * math.pi * (k + 1) / sides
            pts = [(math.cos(a1) * (r - w), math.sin(a1) * (r - w), 0.02),
                   (math.cos(a2) * (r - w), math.sin(a2) * (r - w), 0.02),
                   (math.cos(a2) * r, math.sin(a2) * r, 0.02), (math.cos(a1) * r, math.sin(a1) * r, 0.02)]
            p.flat(pts, white, facing=(0, 0, 1))
    # Des runes entre les deux cercles.
    for k in range(12):
        a = 2 * math.pi * k / 12
        cx, cy = math.cos(a) * 0.83, math.sin(a) * 0.83
        p.box((cx, cy, 0.02), (0.05, 0.11, 0.01), white, rotation_z=a)
        p.box((cx + math.cos(a + 0.5) * 0.03, cy + math.sin(a + 0.5) * 0.03, 0.02), (0.08, 0.025, 0.01), white,
              rotation_z=a + 0.9)
    # Une étoile à 5 branches au centre.
    star = [(math.cos(math.pi / 2 + k * 4 * math.pi / 5) * 0.68, math.sin(math.pi / 2 + k * 4 * math.pi / 5) * 0.68)
            for k in range(6)]
    for (ax, ay), (bx, by) in zip(star, star[1:]):
        length = math.hypot(bx - ax, by - ay)
        p.box(((ax + bx) / 2, (ay + by) / 2, 0.02), (length, 0.035, 0.01), white,
              rotation_z=math.atan2(by - ay, bx - ax))


def dome(fx):
    white = _mat("dome", "ffffff", 1.5)
    p = fx.part("dome")
    rings = []
    for i in range(5):
        a = (math.pi / 2) * i / 4
        r, z = math.cos(a), math.sin(a)
        rings.append(((0, 0, z), max(r, 0.0), max(r, 0.0)))
    p.loft(rings, white, sides=10, cap_start=False, cap_end=False)


def eye(fx):
    white = _mat("eye_white", "fff3e0", 1.4)
    iris = _mat("eye_iris", "ff8f00", 4.0)
    pupil = lp.material("fx_eye_pupil", "100505", 0.0, double_sided=True)
    lid = _mat("eye_lid", "b71c1c", 1.2)
    node = fx.pivot("eye", (0, 0, 1.4))
    p = fx.part("eye", node)
    p.loft([((0, 0.25, 0), 0.0, 0.0), ((0, 0.15, 0), 0.45, 0.28), ((0, -0.05, 0), 0.62, 0.38),
            ((0, -0.2, 0), 0.4, 0.25), ((0, -0.24, 0), 0.0, 0.0)], white, sides=12, cap_end=False,
           cap_start=False)
    p.loft([((0, -0.2, 0), 0.0, 0.0), ((0, -0.24, 0), 0.26, 0.26), ((0, -0.25, 0), 0.0, 0.0)], iris,
           sides=12, cap_start=False, cap_end=False)
    p.box((0, -0.27, 0), (0.07, 0.01, 0.34), pupil)
    p.loft([((-0.66, -0.05, 0), 0.05, 0.05), ((0, -0.2, 0.36), 0.07, 0.07), ((0.66, -0.05, 0), 0.05, 0.05)],
           lid, sides=5)
    p.loft([((-0.66, -0.05, 0), 0.05, 0.05), ((0, -0.18, -0.34), 0.06, 0.06), ((0.66, -0.05, 0), 0.05, 0.05)],
           lid, sides=5)


def hand(fx):
    bone = _mat("bone", "efe6d2", 0.6)
    glow = _mat("grave_glow", "76ff03", 3.0)
    dirt = lp.material("fx_dirt", "4e342e", 0.0)
    fx.part("mound").loft([((0, 0, 0), 0.45, 0.45), ((0, 0, 0.08), 0.35, 0.35), ((0, 0, 0.12), 0.0, 0.0)], dirt,
                          sides=8, cap_end=False)
    node = fx.pivot("hand", (0, 0, 0))
    p = fx.part("hand", node)
    p.loft([((0, 0, -0.2), 0.05, 0.05), ((0, 0, 0.45), 0.045, 0.045)], bone, sides=5)
    p.box((0, 0, 0.55), (0.2, 0.06, 0.16), bone)
    for k, x in enumerate((-0.075, -0.025, 0.025, 0.075)):
        h = (0.2, 0.26, 0.25, 0.19)[k]
        p.loft([((x, 0, 0.62), 0.018, 0.018), ((x * 1.2, -0.02, 0.62 + h * 0.55), 0.016, 0.016),
                ((x * 1.3, -0.06, 0.62 + h), 0.0, 0.0)], bone, sides=4, cap_end=False)
    p.loft([((0.1, 0, 0.52), 0.02, 0.02), ((0.18, -0.02, 0.62), 0.016, 0.016), ((0.21, -0.06, 0.7), 0.0, 0.0)],
           bone, sides=4, cap_end=False)
    for a in range(6):
        ang = a * math.pi / 3
        fx.part("wisp_%d" % a).box((math.cos(ang) * 0.38, math.sin(ang) * 0.38, 0.12), (0.04, 0.04, 0.04), glow)


BUILDERS = {"bolt": bolt, "web": web, "flames": flames, "rocks": rocks, "ghost": ghost,
            "rune_circle": rune_circle, "dome": dome, "eye": eye, "hand": hand}


def build(name, export_path=None):
    fx = _Fx(name)
    BUILDERS[name](fx)
    fx.finish()
    if export_path:
        lp.export_glb(fx.scene, export_path)
    return fx.scene


def build_all(out):
    os.makedirs(out, exist_ok=True)
    for name in BUILDERS:
        build(name, os.path.join(out, name + ".glb"))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    import sys
    if here not in sys.path:
        sys.path.insert(0, here)
    build_all(os.path.join(os.path.dirname(os.path.dirname(here)), "assets", "models", "fx"))
