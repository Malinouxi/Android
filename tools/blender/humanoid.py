"""Le corps humanoïde low-poly commun à la plupart des personnages.

Une FICHE (dictionnaire) décrit le personnage, comme CHARACTERS dans
voxel_models.gd : couleurs, couvre-chef, arme... (voir cast.py). Le corps est
construit avec les mêmes pivots et aux mêmes hauteurs que le modèle en blocs :
    body > leg_l, leg_r, arm_l, arm_r (> weapon), head, wing_l, wing_r, tail

Clés de la fiche (couleurs « rrggbb ») :
  skin, top, legs, boots, robe (au lieu d'un pantalon), belt, head_color, eyes,
  cape, tail, wings, beard, shield, orb, blade ;
  head : "ears", "horns", "hood", "helmet", "helm_gold", "crown", "hair",
         "long_hair", "pointy_hat", "tonsure", "skull", "snout", "spiky_hair", "bald" ;
  weapon : "sword", "big_sword", "dagger", "axe", "pickaxe", "staff", "bow",
           "club", "hammer", "keys" (rien : mains nues) ;
  width (carrure, 1 par défaut), head_scale, tusks, hands (couleur des mains),
  extra : fonction(ctx) qui ajoute des détails propres au personnage.
"""

import math

import clips
import lowpoly as lp
import rig
from lowpoly import Part, mirrored, pivot

HIP = 0.3
SHOULDER = 0.58
NECK = 0.74


class Context:
    """Ce qu'une fonction « extra » reçoit : la scène, les pivots, les pièces
    (encore ouvertes : on peut y ajouter des formes) et les matériaux."""

    def __init__(self, scene, spec):
        self.scene = scene
        self.spec = spec
        self.pivots = {}
        self.parts = {}
        self.materials = {}

    def mat(self, key, color=None, emission=0.0, double_sided=False):
        """Le matériau « key » du personnage (couleur prise dans la fiche si non donnée)."""
        name = "%s_%s" % (self.scene.name, key)
        if name not in self.materials:
            hex_color = color or self.spec[key]
            self.materials[name] = lp.material(name, hex_color, emission, double_sided)
        return self.materials[name]

    def part(self, pivot_name):
        """La pièce accrochée au pivot (créée au besoin)."""
        if pivot_name not in self.parts:
            self.parts[pivot_name] = Part(self.scene, pivot_name + "_mesh", self.pivots[pivot_name])
        return self.parts[pivot_name]


def build(name, spec, export_path=None):
    scene = lp.new_scene(name)
    ctx = Context(scene, spec)
    w = spec.get("width", 1.0)
    body = ctx.pivots["body"] = pivot(scene, "body")
    for side, pivot_name in ((-1, "leg_l"), (1, "leg_r")):
        ctx.pivots[pivot_name] = pivot(scene, pivot_name, body, (0.08 * side * w, 0, HIP))
    for side, pivot_name in ((-1, "arm_l"), (1, "arm_r")):
        ctx.pivots[pivot_name] = pivot(scene, pivot_name, body, (0.19 * side * w, 0, SHOULDER))
    ctx.pivots["head"] = pivot(scene, "head", body, (0, 0, NECK))

    _torso(ctx, w)
    for side, pivot_name in ((-1, "leg_l"), (1, "leg_r")):
        _leg(ctx, pivot_name, side, w)
    for side, pivot_name in ((-1, "arm_l"), (1, "arm_r")):
        _arm(ctx, pivot_name, side, w)
    _head(ctx)
    if "cape" in spec:
        _cape(ctx, w)
    if "wings" in spec:
        _wings(ctx)
    if "tail" in spec:
        ctx.pivots["tail"] = pivot(scene, "tail", body, (0, 0.08, 0.3))
        _tail(ctx)
    if spec.get("weapon"):
        # Dans la main droite, pointée vers l'avant quand le bras pend (comme voxel_models.gd).
        ctx.pivots["weapon"] = pivot(scene, "weapon", ctx.pivots["arm_r"], (0, -0.02, -0.27), (1.2, 0, 0))
        WEAPONS[spec["weapon"]](ctx, ctx.part("weapon"))
    if "shield" in spec:
        _shield(ctx)
    if "extra" in spec:
        spec["extra"](ctx)
    for part in ctx.parts.values():
        part.finish()
    # Les pivots deviennent un squelette, avec ses animations (rig.py, clips.py).
    clips.bake(rig.build(scene))
    if export_path:
        lp.export_glb(scene, export_path)
    return scene


# ---------------------------------------------------------------------------
# Le corps
# ---------------------------------------------------------------------------

def _torso(ctx, w):
    spec = ctx.spec
    part = ctx.part("body")
    top = ctx.mat("top")
    part.loft([
        ((0, 0, 0.26), 0.1 * w, 0.07),
        ((0, 0, 0.34), 0.095 * w, 0.068),
        ((0, -0.005, 0.44), 0.12 * w, 0.078),
        ((0, -0.005, 0.53), 0.14 * w, 0.082),
        ((0, 0, 0.6), 0.14 * w, 0.075),
        ((0, 0, 0.645), 0.085 * w, 0.06),
        ((0, 0, 0.68), 0.045, 0.045),
    ], top, sides=8)
    if "robe" in spec:
        # La robe tombe jusqu'aux pieds, évasée.
        part.loft([
            ((0, 0, 0.02), 0.15 * w, 0.12),
            ((0, 0, 0.18), 0.13 * w, 0.1),
            ((0, 0, 0.32), 0.1 * w, 0.075),
            ((0, -0.005, 0.44), 0.123 * w, 0.081),
        ], ctx.mat("robe"), sides=8, cap_end=False)
    if "belt" in spec:
        z = 0.31 if "robe" not in spec else 0.33
        part.loft([((0, 0, z - 0.015), 0.104 * w, 0.074), ((0, 0, z + 0.015), 0.103 * w, 0.073)],
                  ctx.mat("belt"), sides=8)
        part.box((0, -0.075, z), (0.03, 0.01, 0.026), ctx.mat("buckle", "ffca28"))


def _leg(ctx, pivot_name, side, w):
    spec = ctx.spec
    part = ctx.part(pivot_name)
    boots = ctx.mat("boots")
    if "robe" not in spec:
        part.loft([
            ((0, 0, 0.0), 0.055 * w, 0.058),
            ((0, -0.005, -0.1), 0.05 * w, 0.054),
            ((0, 0, -0.14), 0.04 * w, 0.044),
            ((0, 0.005, -0.19), 0.042 * w, 0.045),
        ], ctx.mat("legs"), sides=6)
        part.loft([((0, 0.005, -0.18), 0.045 * w, 0.048), ((0, 0, -0.25), 0.042 * w, 0.045)], boots, sides=6)
    # Le pied (sous la robe, seul le bout dépasse).
    part.loft([((0, 0.015, -0.24), 0.042 * w, 0.04), ((0, -0.015, -0.285), 0.048 * w, 0.062),
               ((0, -0.03, -0.3), 0.044 * w, 0.058)], boots, sides=6)


def _arm(ctx, pivot_name, side, w):
    spec = ctx.spec
    part = ctx.part(pivot_name)
    sleeve = ctx.mat("robe" if "robe" in spec else "top")
    hands = ctx.mat("hands", spec.get("hands", spec["skin"]))
    part.loft([
        ((0.01 * side, 0, 0.04), 0.035 * w, 0.035),
        ((0.01 * side, 0, 0.0), 0.05 * w, 0.05),
        ((0.005 * side, 0, -0.12), 0.042 * w, 0.042),
        ((0, 0, -0.2), 0.04 * w, 0.04),
        ((0, -0.005, -0.235), 0.04 * w, 0.04 * w),
    ], sleeve, sides=6)
    if "robe" in spec:
        # Manche évasée.
        part.loft([((0, 0, -0.17), 0.045 * w, 0.045), ((0, -0.005, -0.24), 0.06 * w, 0.06)],
                  sleeve, sides=6, cap_start=False, cap_end=False)
    part.loft([((0, -0.005, -0.23), 0.032 * w, 0.032), ((0, -0.012, -0.275), 0.04 * w, 0.036),
               ((0, -0.015, -0.3), 0.028 * w, 0.028)], hands, sides=6)


def _head(ctx):
    spec = ctx.spec
    s = spec.get("head_scale", 1.0)
    part = ctx.part("head")
    kind = spec.get("head", "")
    skin = ctx.mat("skin")

    def p(x, y, z):
        return (x * s, y * s, z * s)

    if kind == "skull":
        part.loft([
            (p(0, -0.01, -0.09), 0.055 * s, 0.05 * s),
            (p(0, -0.005, -0.05), 0.08 * s, 0.08 * s),
            (p(0, 0, 0.0), 0.1 * s, 0.1 * s),
            (p(0, 0.005, 0.08), 0.1 * s, 0.1 * s),
            (p(0, 0.01, 0.13), 0.055 * s, 0.06 * s),
        ], skin, sides=8)
        for side in (-1, 1):  # Orbites creuses.
            part.flat(mirrored([p(0.015, -0.103, 0.035), p(0.065, -0.096, 0.04), p(0.06, -0.099, -0.005),
                                p(0.02, -0.103, -0.005)], side), ctx.mat("socket", "1a1a1a"), facing=(0, -1, 0))
        part.flat([p(-0.012, -0.105, -0.02), p(0.012, -0.105, -0.02), p(0, -0.105, -0.045)],
                  ctx.mat("socket", "1a1a1a"), facing=(0, -1, 0))
        for k in range(6):
            x = -0.04 + k * 0.016
            part.box(p(x, -0.077, -0.075), (0.011 * s, 0.01 * s, 0.018 * s), ctx.mat("teeth", "fff3d6"))
        _eyes(ctx, part, s, y=-0.106, z=0.018, width=0.022, height=0.014)
        return

    # Le crâne : mâchoire, pommettes, front.
    part.loft([
        (p(0, -0.01, -0.1), 0.06 * s, 0.06 * s),
        (p(0, -0.005, -0.06), 0.095 * s, 0.092 * s),
        (p(0, 0, 0.03), 0.105 * s, 0.1 * s),
        (p(0, 0.005, 0.09), 0.095 * s, 0.095 * s),
        (p(0, 0.01, 0.13), 0.05 * s, 0.05 * s),
    ], skin, sides=8)
    if kind == "snout":
        hat = ctx.mat("head_color")
        part.loft([(p(0, -0.06, -0.02), 0.07 * s, 0.05 * s), (p(0, -0.15, -0.035), 0.05 * s, 0.035 * s),
                   (p(0, -0.19, -0.04), 0.03 * s, 0.025 * s)], hat, sides=6, twist=0.0)
        for side in (-1, 1):
            part.box(p(0.02 * side, -0.188, -0.025), (0.008 * s, 0.006 * s, 0.006 * s), ctx.mat("socket", "1a1a1a"))
        _eyes(ctx, part, s, y=-0.097, z=0.035, width=0.03, height=0.022, spread=0.055)
    else:
        part.loft([(p(0, -0.09, 0.015), 0.014 * s, 0.01 * s), (p(0, -0.113, -0.015), 0.018 * s, 0.014 * s)],
                  skin, sides=5)
        _eyes(ctx, part, s)
    hat = ctx.mat("head_color") if "head_color" in ctx.spec else None
    HEADGEAR.get(kind, lambda *a: None)(ctx, part, s, p, hat, skin)
    if "beard" in spec:
        part.loft([(p(0, -0.085, -0.03), 0.09 * s, 0.03 * s), (p(0, -0.1, -0.1), 0.08 * s, 0.035 * s),
                   (p(0, -0.09, -0.19), 0.05 * s, 0.03 * s), (p(0, -0.075, -0.24), 0.0, 0.0)],
                  ctx.mat("beard"), sides=6, cap_end=False)
        part.box(p(0, -0.103, -0.035), (0.08 * s, 0.015 * s, 0.018 * s), ctx.mat("beard"))
    if spec.get("tusks"):
        for side in (-1, 1):
            part.cone(p(0.04 * side, -0.09, -0.06), p(0.05 * side, -0.105, -0.01), 0.011 * s,
                      ctx.mat("tusk", "fffde7"), sides=4)


def _eyes(ctx, part, s, y=-0.103, z=0.025, width=0.028, height=0.018, spread=0.042):
    """Deux yeux en amande ; des yeux clairs brillent (dans l'ombre des capuches)."""
    color = ctx.spec.get("eyes", "1a1a1a")
    value = max(int(color[i:i + 2], 16) for i in (0, 2, 4)) / 255.0
    eye = ctx.mat("eyes", color, emission=3.0 if value > 0.6 else 0.0)
    for side in (-1, 1):
        cx = spread * side
        part.flat([(s * (cx - width / 2), s * y, s * (z + height / 2)),
                   (s * (cx + width / 2), s * y, s * (z + height / 2)),
                   (s * (cx + width / 2 * 0.7), s * y, s * (z - height / 2)),
                   (s * (cx - width / 2 * 0.7), s * y, s * (z - height / 2))], eye, facing=(0, -1, 0))


# ---------------------------------------------------------------------------
# Couvre-chefs
# ---------------------------------------------------------------------------

def _ears(ctx, part, s, p, hat, skin):
    for side in (-1, 1):
        part.loft([(p(0.09 * side, 0.005, 0.03), 0.015 * s, 0.03 * s), (p(0.2 * side, 0.03, 0.08), 0.0, 0.0)],
                  skin, sides=4, cap_end=False)


def _horns(ctx, part, s, p, hat, skin):
    for side in (-1, 1):
        part.loft([(p(0.05 * side, 0.01, 0.09), 0.022 * s, 0.022 * s), (p(0.08 * side, 0.04, 0.15), 0.015 * s, 0.015 * s),
                   (p(0.085 * side, 0.08, 0.19), 0.0, 0.0)], hat, sides=5, cap_end=False)


def _hair(ctx, part, s, p, hat, skin):
    part.loft([(p(0, 0.01, 0.06), 0.112 * s, 0.108 * s), (p(0, 0.01, 0.11), 0.1 * s, 0.1 * s),
               (p(0, 0.015, 0.15), 0.055 * s, 0.055 * s)], hat, sides=8)
    part.loft([(p(0, 0.05, 0.1), 0.1 * s, 0.06 * s), (p(0, 0.06, -0.03), 0.1 * s, 0.055 * s),
               (p(0, 0.05, -0.07), 0.08 * s, 0.04 * s)], hat, sides=6)
    part.box(p(0, -0.085, 0.085), (0.15 * s, 0.04 * s, 0.035 * s), hat)


def _long_hair(ctx, part, s, p, hat, skin):
    _hair(ctx, part, s, p, hat, skin)
    part.loft([(p(0, 0.06, 0.0), 0.11 * s, 0.06 * s), (p(0, 0.07, -0.12), 0.1 * s, 0.05 * s),
               (p(0, 0.06, -0.2), 0.08 * s, 0.03 * s)], hat, sides=6)


def _spiky_hair(ctx, part, s, p, hat, skin):
    part.loft([(p(0, 0.01, 0.07), 0.11 * s, 0.106 * s), (p(0, 0.015, 0.13), 0.08 * s, 0.08 * s)], hat, sides=8)
    for x, y, z in ((0, 0.0, 0.17), (-0.06, 0.02, 0.15), (0.06, 0.02, 0.15), (-0.04, 0.07, 0.14), (0.04, 0.07, 0.14)):
        part.cone(p(x * 0.7, y, 0.11), p(x * 1.3, y + 0.04, z + 0.02), 0.03 * s, hat, sides=4)
    # Pointe de cheveux sur le front (en V).
    part.flat([p(-0.06, -0.097, 0.075), p(0.06, -0.097, 0.075), p(0, -0.106, 0.045)], hat, facing=(0, -1, 0))


def _hood(ctx, part, s, p, hat, skin):
    # Le capuchon englobe la tête ; le visage est dans l'ombre (seuls les yeux ressortent).
    part.loft([
        (p(0, 0.0, -0.11), 0.1 * s, 0.1 * s),
        (p(0, 0.005, -0.03), 0.13 * s, 0.123 * s),
        (p(0, 0.01, 0.08), 0.125 * s, 0.12 * s),
        (p(0, 0.03, 0.15), 0.07 * s, 0.07 * s),
        (p(0, 0.09, 0.17), 0.0, 0.0),
    ], hat, sides=8, cap_end=False)
    # « face_visible » : un visage éclairé (sinon, de l'ombre).
    shadow = skin if ctx.spec.get("face_visible") else ctx.mat("hood_shadow", "120c10")
    part.flat([p(-0.07, -0.124, 0.07), p(0.07, -0.124, 0.07), p(0.085, -0.122, 0.0), p(0.06, -0.12, -0.07),
               p(0, -0.118, -0.095), p(-0.06, -0.12, -0.07), p(-0.085, -0.122, 0.0)], shadow, facing=(0, -1, 0))
    _eyes(ctx, part, s, y=-0.127, z=0.025, width=0.03, height=0.016)


def _helmet(ctx, part, s, p, hat, skin):
    # Casque rond de nain, avec bord et nasal.
    part.loft([(p(0, 0, 0.045), 0.118 * s, 0.113 * s), (p(0, 0, 0.11), 0.105 * s, 0.1 * s),
               (p(0, 0.005, 0.16), 0.055 * s, 0.055 * s), (p(0, 0.005, 0.175), 0.0, 0.0)], hat, sides=8, cap_end=False)
    part.loft([(p(0, 0, 0.035), 0.125 * s, 0.12 * s), (p(0, 0, 0.06), 0.125 * s, 0.12 * s)], hat, sides=8)
    part.box(p(0, -0.115, 0.03), (0.025 * s, 0.012 * s, 0.07 * s), hat)
    for side in (-1, 1):
        part.cone(p(0.11 * side, 0, 0.1), p(0.17 * side, 0.01, 0.17), 0.022 * s, ctx.mat("horn", "eeeeee"), sides=5)


def _helm_gold(ctx, part, s, p, hat, skin):
    # Grand heaume doré, fente en croix.
    part.loft([(p(0, 0, -0.1), 0.095 * s, 0.095 * s), (p(0, 0, -0.04), 0.112 * s, 0.112 * s),
               (p(0, 0, 0.07), 0.112 * s, 0.112 * s), (p(0, 0, 0.12), 0.09 * s, 0.09 * s),
               (p(0, 0, 0.15), 0.05 * s, 0.05 * s)], hat, sides=8)
    slit = ctx.mat("slit", "3e2a00")
    part.box(p(0, -0.105, 0.03), (0.15 * s, 0.012 * s, 0.02 * s), slit)
    part.box(p(0, -0.105, -0.01), (0.02 * s, 0.012 * s, 0.07 * s), slit)
    part.loft([(p(0, -0.09, 0.11), 0.012 * s, 0.03 * s), (p(0, 0, 0.16), 0.012 * s, 0.03 * s),
               (p(0, 0.09, 0.11), 0.012 * s, 0.03 * s)], ctx.mat("trim", "eceff1"), sides=4)


def _crown(ctx, part, s, p, hat, skin):
    _hair(ctx, part, s, p, ctx.mat("hair", ctx.spec.get("hair", "8d6e63")), skin)
    gold = ctx.mat("crown", ctx.spec["head_color"], emission=0.4)
    part.loft([(p(0, 0.01, 0.1), 0.108 * s, 0.104 * s), (p(0, 0.01, 0.14), 0.108 * s, 0.104 * s)],
              gold, sides=8, cap_start=False, cap_end=False)
    for k in range(8):
        angle = math.pi / 8 + k * math.pi / 4
        x, y = 0.105 * math.cos(angle), 0.01 + 0.1 * math.sin(angle)
        part.cone(p(x, y, 0.135), p(x * 1.05, y * 1.05, 0.19), 0.022 * s, gold, sides=4)
    part.box(p(0, -0.106, 0.12), (0.025 * s, 0.01 * s, 0.025 * s), ctx.mat("jewel", "e53935", emission=1.0))


def _pointy_hat(ctx, part, s, p, hat, skin):
    _long_hair(ctx, part, s, p, ctx.mat("hair", ctx.spec.get("hair", "6d4c41")), skin)
    part.loft([(p(0, 0, 0.08), 0.21 * s, 0.21 * s), (p(0, 0, 0.1), 0.2 * s, 0.2 * s)], hat, sides=10)
    part.loft([(p(0, 0, 0.1), 0.12 * s, 0.12 * s), (p(0, 0.01, 0.2), 0.085 * s, 0.085 * s),
               (p(0, 0.04, 0.31), 0.045 * s, 0.045 * s), (p(0, 0.11, 0.38), 0.0, 0.0)], hat, sides=8, cap_end=False)
    part.loft([(p(0, 0, 0.1), 0.122 * s, 0.122 * s), (p(0, 0, 0.125), 0.118 * s, 0.118 * s)],
              ctx.mat("band", ctx.spec.get("band", "ffca28")), sides=8, cap_start=False, cap_end=False)


def _tonsure(ctx, part, s, p, hat, skin):
    part.loft([(p(0, 0.01, 0.03), 0.108 * s, 0.104 * s), (p(0, 0.01, 0.09), 0.1 * s, 0.098 * s)],
              hat, sides=8, cap_start=False, cap_end=False)


def _bald(ctx, part, s, p, hat, skin):
    pass


HEADGEAR = {
    "ears": _ears, "horns": _horns, "hair": _hair, "long_hair": _long_hair, "spiky_hair": _spiky_hair,
    "hood": _hood, "helmet": _helmet, "helm_gold": _helm_gold, "crown": _crown,
    "pointy_hat": _pointy_hat, "tonsure": _tonsure, "bald": _bald,
}


# ---------------------------------------------------------------------------
# Cape, ailes, queue, bouclier
# ---------------------------------------------------------------------------

def _cape(ctx, w):
    part = ctx.part("body")
    cape = ctx.mat("cape", double_sided=True)
    part.slab([(-0.15 * w, 0.075, 0.62), (0.15 * w, 0.075, 0.62), (0.2 * w, 0.12, 0.12),
               (0.07, 0.125, 0.08), (-0.07, 0.125, 0.08), (-0.2 * w, 0.12, 0.12)], (0, 0.012, 0), cape)


def _wings(ctx):
    body = ctx.pivots["body"]
    for side, pivot_name in ((-1, "wing_l"), (1, "wing_r")):
        wing = ctx.pivots[pivot_name] = pivot(ctx.scene, pivot_name, body, (0.09 * side, 0.09, 0.55), (0, 0, 0.5 * side))
        part = ctx.part(pivot_name)
        outline = [(0.0, 0, 0.04), (0.17, 0, 0.14), (0.4, 0, 0.24), (0.33, 0, 0.07), (0.36, 0, -0.04),
                   (0.25, 0, 0.02), (0.24, 0, -0.12), (0.15, 0, -0.02), (0.1, 0, -0.12), (0.03, 0, -0.04)]
        part.flat(mirrored(outline, side), ctx.mat("wings", double_sided=True))
        for chain in ([(0.0, 0, 0.04), (0.17, 0, 0.14), (0.4, 0, 0.24)], [(0.17, 0, 0.14), (0.36, 0, -0.04)],
                      [(0.17, 0, 0.14), (0.24, 0, -0.12)], [(0.17, 0, 0.14), (0.1, 0, -0.12)]):
            points = mirrored(chain, side)
            part.loft([(pt, 0.011, 0.011) for pt in points[:-1]] + [(points[-1], 0.004, 0.004)],
                      ctx.mat("wing_bone", ctx.spec.get("wing_bone", ctx.spec["skin"])), sides=4)


def _tail(ctx):
    part = ctx.part("tail")
    part.loft([
        ((0, 0.0, 0.0), 0.035, 0.035),
        ((0, 0.09, -0.09), 0.028, 0.028),
        ((0, 0.19, -0.15), 0.02, 0.02),
        ((0, 0.29, -0.16), 0.012, 0.012),
        ((0, 0.36, -0.13), 0.0, 0.0),
    ], ctx.mat("tail"), sides=6, cap_end=False)


def _shield(ctx):
    """Un écu cerclé d'acier, sur l'extérieur du bras gauche (face vers -X)."""
    part = ctx.part("arm_l")
    outline = [(-0.14, -0.06), (0.06, -0.06), (0.06, -0.16), (0.035, -0.245), (-0.04, -0.32),
               (-0.115, -0.245), (-0.14, -0.16)]
    center = -0.04
    rim = [(center + (y - center) * 1.1, -0.18 + (z + 0.18) * 1.08) for y, z in outline]
    steel = ctx.mat("steel", ctx.spec.get("rim", "b0bec5"))
    part.slab([(-0.08, y, z) for y, z in rim], (0.02, 0, 0), steel)
    part.slab([(-0.087, y, z) for y, z in outline], (0.006, 0, 0), ctx.mat("shield"), steel)
    emblem = ctx.spec.get("emblem")
    if emblem:
        emblem(ctx, part, (-0.089, center, -0.17))


def star(part, center, size, mat, facing):
    """L'étoile à quatre branches du royaume, à plat, tournée vers « facing » (-X ou -Y)."""
    cx, cy, cz = center
    long, short = size, size * 0.3
    if facing == "y":
        offsets = [(0, long), (short, short), (long * 0.8, 0), (short, -short), (0, -long), (-short, -short),
                   (-long * 0.8, 0), (-short, short)]
        part.flat([(cx + a, cy, cz + b) for a, b in offsets], mat, facing=(0, -1, 0))
    else:
        offsets = [(0, long), (short, short), (long * 0.8, 0), (short, -short), (0, -long), (-short, -short),
                   (-long * 0.8, 0), (-short, short)]
        part.flat([(cx, cy + a, cz + b) for a, b in offsets], mat, facing=(-1, 0, 0))


# ---------------------------------------------------------------------------
# Armes (repère du pivot « weapon » : l'arme s'étend vers +Z)
# ---------------------------------------------------------------------------

def _grip(ctx, part, length=0.06):
    part.loft([((0, 0, -length), 0.014, 0.014), ((0, 0, 0.01), 0.015, 0.015)], ctx.mat("grip", "5d4037"), sides=5)


def _sword(ctx, part):
    _grip(ctx, part)
    part.loft([((0, 0, -0.07), 0.018, 0.018), ((0, 0, -0.055), 0.02, 0.02)], ctx.mat("guard", "8d6e63"), sides=5)
    part.box((0, 0, 0.018), (0.11, 0.022, 0.02), ctx.mat("guard", "8d6e63"))
    part.loft([((0, 0, 0.03), 0.024, 0.007), ((0, 0, 0.29), 0.019, 0.006), ((0, 0, 0.34), 0.0, 0.0)],
              ctx.mat("blade", ctx.spec.get("blade", "cfd8dc")), sides=4, twist=0.0, cap_end=False)


def _big_sword(ctx, part):
    _grip(ctx, part, 0.1)
    gold = ctx.mat("guard", "ffca28")
    part.loft([((0, 0, -0.12), 0.022, 0.022), ((0, 0, -0.1), 0.024, 0.024)], gold, sides=5)
    part.box((0, 0, 0.02), (0.17, 0.028, 0.026), gold)
    part.loft([((0, 0, 0.035), 0.034, 0.009), ((0, 0, 0.46), 0.027, 0.008), ((0, 0, 0.53), 0.0, 0.0)],
              ctx.mat("blade", ctx.spec.get("blade", "eceff1")), sides=4, twist=0.0, cap_end=False)


def _dagger(ctx, part):
    _grip(ctx, part, 0.04)
    part.box((0, 0, 0.012), (0.06, 0.016, 0.014), ctx.mat("guard", "8d6e63"))
    part.loft([((0, 0, 0.02), 0.018, 0.005), ((0, 0, 0.13), 0.012, 0.004), ((0, 0, 0.17), 0.0, 0.0)],
              ctx.mat("blade", ctx.spec.get("blade", "cfd8dc")), sides=4, twist=0.0, cap_end=False)


def _axe(ctx, part):
    wood = ctx.mat("wood", "8d6e63")
    part.loft([((0, 0, -0.06), 0.016, 0.016), ((0, 0, 0.33), 0.016, 0.016)], wood, sides=5)
    steel = ctx.mat("blade", ctx.spec.get("blade", "cfd8dc"))
    # Le fer (vers -Y du pivot : vers l'avant quand l'arme pointe vers le haut).
    part.slab([(-0.008, 0.01, 0.24), (-0.008, 0.01, 0.32), (-0.008, -0.07, 0.36), (-0.008, -0.1, 0.28),
               (-0.008, -0.07, 0.2)], (0.016, 0, 0), steel)
    part.cone((0, 0.015, 0.28), (0, 0.06, 0.28), 0.014, steel, sides=4)


def _pickaxe(ctx, part):
    part.loft([((0, 0, -0.06), 0.016, 0.016), ((0, 0, 0.29), 0.016, 0.016)], ctx.mat("wood", "8d6e63"), sides=5)
    iron = ctx.mat("iron", "9e9e9e")
    part.loft([((0, -0.15, 0.24), 0.0, 0.0), ((0, -0.07, 0.28), 0.016, 0.016), ((0, 0, 0.29), 0.022, 0.022),
               ((0, 0.07, 0.28), 0.016, 0.016), ((0, 0.15, 0.24), 0.0, 0.0)], iron, sides=4,
              cap_start=False, cap_end=False)


def _club(ctx, part):
    wood = ctx.mat("wood", ctx.spec.get("club", "795548"))
    part.loft([((0, 0, -0.05), 0.018, 0.018), ((0, 0, 0.12), 0.024, 0.024), ((0, 0, 0.26), 0.045, 0.045),
               ((0, 0, 0.33), 0.04, 0.04), ((0, 0, 0.35), 0.0, 0.0)], wood, sides=6, cap_end=False)
    for k, z in enumerate((0.2, 0.27)):
        part.cone((0.03, 0, z), (0.055, 0, z + 0.01), 0.012, ctx.mat("knot", "4e342e"), sides=4)


def _hammer(ctx, part):
    part.loft([((0, 0, -0.06), 0.016, 0.016), ((0, 0, 0.3), 0.016, 0.016)], ctx.mat("wood", "8d6e63"), sides=5)
    head = ctx.mat("hammer", ctx.spec.get("hammer", "bdbdbd"))
    part.loft([((0, -0.07, 0.29), 0.045, 0.045), ((0, 0.07, 0.29), 0.045, 0.045)], head, sides=6)
    part.loft([((0, -0.075, 0.29), 0.035, 0.035), ((0, -0.085, 0.29), 0.03, 0.03)],
              ctx.mat("gold", "ffca28"), sides=6)


def _staff(ctx, part):
    wood = ctx.mat("staff", ctx.spec.get("staff", "6d4c41"))
    part.loft([((0, 0, -0.16), 0.014, 0.014), ((0, 0, 0.3), 0.016, 0.016), ((0, 0, 0.44), 0.02, 0.02)],
              wood, sides=5)
    for k in range(3):  # Trois griffes qui tiennent l'orbe.
        angle = k * 2 * math.pi / 3
        dx, dy = math.cos(angle), math.sin(angle)
        part.loft([((0, 0, 0.43), 0.01, 0.01), ((0.04 * dx, 0.04 * dy, 0.48), 0.008, 0.008),
                   ((0.02 * dx, 0.02 * dy, 0.53), 0.0, 0.0)], wood, sides=4, cap_end=False)
    orb = ctx.mat("orb", ctx.spec.get("orb", "ffee58"), emission=4.0)
    part.loft([((0, 0, 0.45), 0.0, 0.0), ((0, 0, 0.47), 0.035, 0.035), ((0, 0, 0.51), 0.035, 0.035),
               ((0, 0, 0.53), 0.0, 0.0)], orb, sides=6, cap_start=False, cap_end=False)


def _bow(ctx, part):
    wood = ctx.mat("wood", "8d6e63")
    points = [(0, 0.04, -0.12), (0, 0.0, -0.02), (0, -0.015, 0.1), (0, 0.0, 0.22), (0, 0.04, 0.32)]
    part.loft([(pt, 0.012, 0.012) for pt in points], wood, sides=4)
    part.loft([((0, 0.045, -0.12), 0.003, 0.003), ((0, 0.045, 0.32), 0.003, 0.003)],
              ctx.mat("string", "eceff1"), sides=3)


def _keys(ctx, part):
    gold = ctx.mat("keys", "ffca28", emission=0.6)
    part.loft([((0, 0, 0.0), 0.035, 0.035), ((0, 0, 0.012), 0.035, 0.035)], gold, sides=8)
    for k, angle in enumerate((-0.5, 0.0, 0.5)):
        dx, dz = math.sin(angle), math.cos(angle)
        base = (0.03 * dx, 0, 0.03 * dz)
        tip = (0.11 * dx, 0, 0.11 * dz)
        part.loft([(base, 0.006, 0.006), (tip, 0.006, 0.006)], gold, sides=4)
        part.box((tip[0], 0.012, tip[2]), (0.012, 0.025, 0.012), gold)


WEAPONS = {
    "sword": _sword, "big_sword": _big_sword, "dagger": _dagger, "axe": _axe, "pickaxe": _pickaxe,
    "club": _club, "hammer": _hammer, "staff": _staff, "bow": _bow, "keys": _keys,
}
