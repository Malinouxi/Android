"""Les fiches des personnages humanoïdes (couleurs reprises de voxel_models.gd),
avec leurs détails propres (fonctions « extra »). Le Démon et le Chevalier ont
leur propre script (demon.py, knight.py) ; les bêtes sont dans beasts.py.

Construire un personnage : cast.build("orc", r"<projet>/assets/models/orc.glb").
"""

import math

import humanoid
from humanoid import star
from lowpoly import mirrored


# ---------------------------------------------------------------------------
# Détails propres à chaque personnage
# ---------------------------------------------------------------------------

def _head_p(ctx):
    s = ctx.spec.get("head_scale", 1.0)
    return lambda x, y, z: (x * s, y * s, z * s)


def _worker(ctx):
    # Tablier de cuir et grosses mains de travailleur.
    body = ctx.part("body")
    body.slab([(-0.08, -0.08, 0.5), (0.08, -0.08, 0.5), (0.1, -0.09, 0.2), (-0.1, -0.09, 0.2)], (0, 0.01, 0),
              ctx.mat("apron", "a1887f"))


def _kobold(ctx):
    p = _head_p(ctx)
    head = ctx.part("head")
    horn = ctx.mat("horn", "c66900")
    for side in (-1, 1):
        head.loft([(p(0.05 * side, 0.02, 0.08), 0.02, 0.02), (p(0.07 * side, 0.07, 0.13), 0.013, 0.013),
                   (p(0.06 * side, 0.12, 0.15), 0.0, 0.0)], horn, sides=5, cap_end=False)
        head.loft([(p(0.08 * side, 0.02, 0.04), 0.012, 0.025), (p(0.14 * side, 0.05, 0.06), 0.0, 0.0)],
                  ctx.mat("skin"), sides=4, cap_end=False)
    # Crête dorsale.
    body = ctx.part("body")
    for z in (0.44, 0.52, 0.6):
        body.cone((0, 0.06, z), (0, 0.11, z + 0.03), 0.018, horn, sides=4)


def _orc(ctx):
    p = _head_p(ctx)
    head = ctx.part("head")
    hair = ctx.mat("hair", "212121")
    for k in range(5):  # Crête iroquoise.
        y = -0.06 + k * 0.04
        head.cone(p(0, y, 0.1), p(0, y + 0.02, 0.19 - abs(k - 2) * 0.012), 0.025, hair, sides=4)
    for side in (-1, 1):
        head.loft([(p(0.09 * side, 0.01, 0.03), 0.012, 0.025), (p(0.15 * side, 0.03, 0.05), 0.0, 0.0)],
                  ctx.mat("skin"), sides=4, cap_end=False)
    # Épaulière de cuir cloutée sur l'épaule gauche, ceinture d'os.
    arm = ctx.part("arm_l")
    leather = ctx.mat("pad", "4e342e")
    arm.loft([((-0.015, 0, 0.07), 0.04, 0.04), ((-0.025, 0, 0.04), 0.075, 0.075), ((-0.03, 0, -0.03), 0.08, 0.075)],
             leather, sides=6)
    for dy in (-0.03, 0.03):
        arm.cone((-0.07, dy, 0.03), (-0.12, dy, 0.06), 0.014, ctx.mat("spike", "bdbdbd"), sides=4)


def _warlock(ctx):
    # Runes lumineuses sur le devant de la robe.
    body = ctx.part("body")
    rune = ctx.mat("rune", "ce93d8", emission=2.5)
    for k, z in enumerate((0.42, 0.3, 0.18)):
        r = 0.022
        y = -0.085 - (0.44 - z) * 0.1
        body.flat([(0, y, z + r), (r, y, z), (0, y, z - r), (-r, y, z)], rune, facing=(0, -1, 0))
    body.loft([((0, 0, 0.32), 0.104, 0.077), ((0, 0, 0.35), 0.103, 0.076)], ctx.mat("sash", "ffee58"), sides=8)


def _vampire(ctx):
    p = _head_p(ctx)
    head = ctx.part("head")
    for side in (-1, 1):  # Crocs.
        head.cone(p(0.02 * side, -0.098, -0.045), p(0.02 * side, -0.1, -0.075), 0.007, ctx.mat("fang", "ffffff"), sides=3)
    head.box(p(0, -0.1, -0.045), (0.06, 0.008, 0.01), ctx.mat("lips", "8e0000"))
    # Grand col dressé de la cape, doublé de rouge.
    body = ctx.part("body")
    lining = ctx.mat("lining", "b71c1c", double_sided=True)
    for side in (-1, 1):
        body.slab(mirrored([(0.05, 0.03, 0.64), (0.15, 0.05, 0.62), (0.2, 0.08, 0.84), (0.08, 0.06, 0.8)], side),
                  (0, 0.012, 0), lining, ctx.mat("cape"))
    # Médaillon.
    body.loft([((0, -0.085, 0.56), 0.02, 0.006), ((0, -0.088, 0.56), 0.02, 0.006)],
              ctx.mat("medal", "ff1744", emission=1.5), sides=6, twist=0.0)


def _salamander(ctx):
    # Ventre clair, crête dorsale, flamme au bout de la queue.
    body = ctx.part("body")
    belly = ctx.mat("belly", "ffcc80")
    body.loft([((0, -0.05, 0.3), 0.07, 0.03), ((0, -0.072, 0.45), 0.085, 0.03), ((0, -0.07, 0.58), 0.08, 0.025)],
              belly, sides=6)
    crest = ctx.mat("crest", "ff9800")
    for z in (0.36, 0.44, 0.52, 0.6):
        body.cone((0, 0.06, z), (0, 0.12, z + 0.035), 0.02, crest, sides=4)
    p = _head_p(ctx)
    head = ctx.part("head")
    for k, y in enumerate((-0.02, 0.04, 0.09)):
        head.cone(p(0, y, 0.11), p(0, y + 0.03, 0.17 - k * 0.01), 0.02, crest, sides=4)
    tail = ctx.part("tail")
    flame = ctx.mat("flame", "ffab00", emission=5.0)
    tail.cone((0, 0.34, -0.13), (0, 0.37, -0.03), 0.04, flame, sides=5)
    tail.cone((0, 0.36, -0.14), (0.02, 0.42, -0.08), 0.025, flame, sides=4)


def _catcher(ctx):
    # Lanterne lumineuse à la ceinture et chaîne en bandoulière.
    body = ctx.part("body")
    iron = ctx.mat("iron", "37474f")
    body.loft([((-0.11, -0.03, 0.3), 0.02, 0.02), ((-0.11, -0.03, 0.26), 0.022, 0.022)], iron, sides=4)
    body.loft([((-0.11, -0.03, 0.26), 0.025, 0.025), ((-0.11, -0.03, 0.19), 0.025, 0.025)],
              ctx.mat("lantern", "80deea", emission=4.0), sides=6)
    body.loft([((-0.11, -0.03, 0.19), 0.028, 0.028), ((-0.11, -0.03, 0.175), 0.02, 0.02)], iron, sides=4)
    for k in range(7):
        t = k / 6
        x, z = -0.11 + 0.22 * t, 0.62 - 0.27 * t
        body.box((x, -0.088, z), (0.022, 0.012, 0.016), iron, rotation_z=0.0)


def _revenant(ctx):
    # Tunique déchirée et os qui dépassent.
    body = ctx.part("body")
    rag = ctx.mat("top")
    for k in range(5):
        x = -0.08 + k * 0.04
        body.flat([(x - 0.02, -0.075, 0.27), (x + 0.02, -0.075, 0.27), (x + 0.005, -0.08, 0.2 - 0.02 * (k % 2))],
                  rag, facing=(0, -1, 0))
    bone = ctx.mat("skin")
    for z in (0.5, 0.45):  # Côtes visibles par un trou de la tunique.
        body.box((0.05, -0.078, z), (0.06, 0.008, 0.012), bone)


def _golem(ctx):
    p = _head_p(ctx)
    rock = ctx.mat("rock", "9e9e9e")
    dark = ctx.mat("legs")
    rune = ctx.mat("rune", "4dd0e1", emission=3.0)
    body = ctx.part("body")
    # Blocs de roche sur les épaules et le dos, fissures lumineuses sur le torse.
    for x, y, z, size in ((-0.12, 0.03, 0.62, 0.09), (0.12, 0.02, 0.63, 0.1), (0.0, 0.07, 0.55, 0.11), (0.06, 0.07, 0.42, 0.08)):
        body.loft([((x, y, z - size / 2), size * 0.6, size * 0.55), ((x, y, z), size * 0.75, size * 0.7),
                   ((x, y, z + size / 2), size * 0.45, size * 0.4)], rock, sides=5)
    body.flat([(-0.05, -0.091, 0.55), (-0.02, -0.093, 0.52), (-0.04, -0.093, 0.47), (0.0, -0.093, 0.43),
               (-0.01, -0.093, 0.42), (-0.055, -0.093, 0.47), (-0.035, -0.093, 0.515)], rune, facing=(0, -1, 0))
    body.flat([(0.06, -0.093, 0.5), (0.085, -0.092, 0.46), (0.07, -0.093, 0.44)], rune, facing=(0, -1, 0))
    # Gros poings de pierre.
    for arm_name in ("arm_l", "arm_r"):
        ctx.part(arm_name).loft([((0, -0.01, -0.24), 0.06, 0.055), ((0, -0.015, -0.29), 0.07, 0.065),
                                 ((0, -0.015, -0.33), 0.05, 0.05)], dark, sides=5)
    head = ctx.part("head")
    head.box(p(0, -0.09, 0.07), (0.17, 0.04, 0.035), dark)  # Arcade de pierre.


def _adventurer(ctx):
    # Bandoulière, sacoche sur la hanche.
    body = ctx.part("body")
    strap = ctx.mat("strap", "4e342e")
    body.slab([(0.12, -0.08, 0.6), (0.15, -0.075, 0.57), (-0.09, -0.083, 0.3), (-0.12, -0.08, 0.33)], (0, 0.008, 0), strap)
    body.slab([(0.1, -0.06, 0.25), (0.16, -0.04, 0.25), (0.16, -0.04, 0.17), (0.1, -0.06, 0.17)], (-0.005, 0.05, 0),
              ctx.mat("bag", "795548"))


def _thief(ctx):
    # Bourses à la ceinture.
    body = ctx.part("body")
    pouch = ctx.mat("pouch", "5d4037")
    for x in (-0.08, 0.08):
        body.loft([((x, -0.06, 0.29), 0.022, 0.018), ((x, -0.065, 0.25), 0.03, 0.025), ((x, -0.062, 0.22), 0.02, 0.018)],
                  pouch, sides=5)


def _cleric(ctx):
    body = ctx.part("body")
    gold = ctx.mat("gold", "ffca28")
    body.slab([(-0.03, -0.083, 0.6), (0.03, -0.083, 0.6), (0.035, -0.12, 0.03), (-0.035, -0.12, 0.03)],
              (0, 0.005, 0), gold)
    star(body, (0, -0.092, 0.5), 0.04, ctx.mat("star", "ffffff"), "y")


def _archer(ctx):
    # Carquois de flèches dans le dos.
    body = ctx.part("body")
    leather = ctx.mat("quiver", "6d4c41")
    body.loft([((0.05, 0.1, 0.3), 0.035, 0.03), ((-0.04, 0.11, 0.6), 0.04, 0.035)], leather, sides=6)
    fletch = ctx.mat("fletch", "eceff1")
    for dx in (-0.015, 0.012, 0.0):
        body.cone((-0.045 + dx, 0.11 + dx, 0.6), (-0.06 + dx, 0.115 + dx, 0.68), 0.012, fletch, sides=3)
    body.slab([(-0.12, -0.082, 0.6), (-0.09, -0.083, 0.62), (0.12, -0.083, 0.31), (0.09, -0.082, 0.29)],
              (0, 0.008, 0), leather)


def _dwarf(ctx):
    body = ctx.part("body")
    body.loft([((0, 0, 0.29), 0.125, 0.085), ((0, 0, 0.33), 0.124, 0.084)], ctx.mat("belt2", "3e2723"), sides=8)
    body.box((0, -0.088, 0.31), (0.05, 0.012, 0.045), ctx.mat("buckle", "ffca28"))


def _mage(ctx):
    body = ctx.part("body")
    gold = ctx.mat("band", "ffca28")
    body.loft([((0, 0, 0.32), 0.104, 0.077), ((0, 0, 0.345), 0.103, 0.076)], gold, sides=8)
    p = _head_p(ctx)
    head = ctx.part("head")
    star(head, p(0.0, -0.13, 0.2), 0.03, ctx.mat("hat_star", "ffeb3b", emission=1.5), "y")


def _paladin(ctx):
    # Épaulières dorées et étoile du royaume sur le tabard.
    gold = ctx.mat("skin")
    for side, arm_name in ((-1, "arm_l"), (1, "arm_r")):
        ctx.part(arm_name).loft([((0.01 * side, 0, 0.065), 0.035, 0.035), ((0.02 * side, 0, 0.04), 0.07, 0.07),
                                 ((0.025 * side, 0, -0.01), 0.078, 0.076), ((0.025 * side, 0, -0.04), 0.068, 0.068)],
                                gold, sides=8)
    star(ctx.part("body"), (0, -0.083, 0.45), 0.045, ctx.mat("star", "1565c0"), "y")


def _giant(ctx):
    body = ctx.part("body")
    rope = ctx.mat("rope", "a1887f")
    body.loft([((0, 0, 0.29), 0.125, 0.08), ((0, 0, 0.32), 0.124, 0.079)], rope, sides=8)
    # Tunique en lambeaux.
    top = ctx.mat("top")
    for k in range(6):
        x = -0.1 + k * 0.04
        body.flat([(x - 0.022, -0.08, 0.28), (x + 0.022, -0.08, 0.28), (x, -0.085, 0.21 - 0.02 * (k % 2))],
                  top, facing=(0, -1, 0))


def _champion(ctx):
    steel = ctx.mat("steel", "b0bec5")
    for side, arm_name in ((-1, "arm_l"), (1, "arm_r")):
        ctx.part(arm_name).loft([((0.01 * side, 0, 0.065), 0.035, 0.035), ((0.02 * side, 0, 0.04), 0.07, 0.07),
                                 ((0.025 * side, 0, -0.01), 0.078, 0.076), ((0.025 * side, 0, -0.04), 0.068, 0.068)],
                                steel, sides=8)
    star(ctx.part("body"), (0, -0.083, 0.46), 0.05, ctx.mat("star", "ffca28"), "y")


def _monk(ctx):
    # Cordelière nouée et capuche rabattue sur la nuque.
    body = ctx.part("body")
    rope = ctx.mat("rope", "d7ccc8")
    body.loft([((0, 0, 0.32), 0.104, 0.078), ((0, 0, 0.345), 0.103, 0.077)], rope, sides=8)
    body.loft([((0.03, -0.08, 0.33), 0.008, 0.008), ((0.04, -0.09, 0.2), 0.008, 0.008)], rope, sides=4)
    body.loft([((0, 0.03, 0.6), 0.1, 0.07), ((0, 0.06, 0.66), 0.11, 0.07), ((0, 0.07, 0.7), 0.06, 0.04)],
              ctx.mat("robe"), sides=8, cap_start=False)


# --- Les créatures des antres (règles 2.7) ---------------------------------

def _goblin(ctx):
    # Tablier de brasseur taché de bière, petit tonnelet sur le dos, nez crochu.
    body = ctx.part("body")
    body.slab([(-0.09, -0.08, 0.52), (0.09, -0.08, 0.52), (0.12, -0.1, 0.16), (-0.12, -0.1, 0.16)], (0, 0.01, 0),
              ctx.mat("apron", "a1887f"))
    body.flat([(0.02, -0.103, 0.3), (0.07, -0.104, 0.27), (0.04, -0.105, 0.22)], ctx.mat("stain", "c88a12"),
              facing=(0, -1, 0))
    wood = ctx.mat("keg", "8d5a2b")
    body.loft([((-0.08, 0.13, 0.48), 0.07, 0.07), ((0.0, 0.14, 0.48), 0.08, 0.08), ((0.08, 0.13, 0.48), 0.07, 0.07)],
              wood, sides=8)
    for x in (-0.05, 0.05):
        body.loft([((x - 0.006, 0.14, 0.48), 0.082, 0.082), ((x + 0.006, 0.14, 0.48), 0.082, 0.082)],
                  ctx.mat("hoop", "37474f"), sides=8, cap_start=False, cap_end=False)
    p = _head_p(ctx)
    head = ctx.part("head")
    head.cone(p(0, -0.1, 0.0), p(0, -0.17, -0.04), 0.022, ctx.mat("skin"), sides=5)


def _ghoul(ctx):
    # Chair grise recousue, bandages, fioles vertes à la ceinture, longues griffes.
    p = _head_p(ctx)
    head = ctx.part("head")
    stitch = ctx.mat("stitch", "3e2723")
    head.box(p(0.03, -0.098, 0.07), (0.07, 0.006, 0.006), stitch)
    for k in range(4):
        head.box(p(0.005 + k * 0.018, -0.1, 0.07), (0.004, 0.006, 0.02), stitch)
    head.loft([(p(0, 0, 0.1), 0.1, 0.1), (p(0, 0, 0.125), 0.095, 0.095)], ctx.mat("bandage", "d7ccc8"), sides=8,
              cap_start=False, cap_end=False)
    body = ctx.part("body")
    vial = ctx.mat("vial", "76ff03", emission=2.5)
    for x in (-0.07, 0.0, 0.07):
        body.loft([((x, -0.085, 0.24), 0.015, 0.015), ((x, -0.088, 0.3), 0.016, 0.016)], vial, sides=5)
    for arm_name in ("arm_l", "arm_r"):
        arm = ctx.part(arm_name)
        arm.loft([((0, 0, -0.08), 0.053, 0.053), ((0, 0, -0.16), 0.05, 0.05)], ctx.mat("bandage", "d7ccc8"),
                 sides=6, cap_start=False, cap_end=False)
        for dx in (-0.02, 0.0, 0.02):
            arm.cone((dx, -0.015, -0.29), (dx, -0.03, -0.36), 0.008, ctx.mat("claw", "212121"), sides=3)


def _imp(ctx):
    # Bourse d'or à la ceinture, anneau d'or à l'oreille, pointe de queue en fer de lance.
    body = ctx.part("body")
    gold = ctx.mat("gold", "ffca28", emission=0.4)
    body.loft([((0.09, -0.06, 0.24), 0.03, 0.025), ((0.09, -0.065, 0.28), 0.04, 0.035),
               ((0.09, -0.06, 0.32), 0.015, 0.015)], ctx.mat("pouch", "6d4c41"), sides=6)
    body.loft([((0.09, -0.07, 0.25), 0.012, 0.012), ((0.09, -0.075, 0.27), 0.012, 0.012)], gold, sides=6)
    p = _head_p(ctx)
    head = ctx.part("head")
    head.loft([(p(0.1, 0, -0.02), 0.018, 0.018), (p(0.1, 0, -0.03), 0.018, 0.018)], gold, sides=6,
              cap_start=False, cap_end=False)
    for side in (-1, 1):
        head.loft([(p(0.09 * side, 0.005, 0.03), 0.015, 0.03), (p(0.17 * side, 0.03, 0.07), 0.0, 0.0)],
                  ctx.mat("skin"), sides=4, cap_end=False)
    tail = ctx.part("tail")
    tail.slab([(0, 0.33, -0.12), (0.04, 0.37, -0.1), (0, 0.44, -0.1), (-0.04, 0.37, -0.1)], (0, 0, 0.012),
              ctx.mat("tail"))


def _executioner(ctx):
    # Tablier de cuir taché de sang, sangles croisées sur le torse nu, gros ventre.
    body = ctx.part("body")
    leather = ctx.mat("leather", "3e2723")
    body.loft([((0, -0.01, 0.34), 0.12, 0.09), ((0, -0.03, 0.42), 0.14, 0.1), ((0, -0.01, 0.5), 0.13, 0.085)],
              ctx.mat("skin"), sides=8)
    body.slab([(-0.12, -0.11, 0.46), (0.12, -0.11, 0.46), (0.13, -0.12, 0.1), (-0.13, -0.12, 0.1)], (0, 0.012, 0),
              leather)
    blood = ctx.mat("blood", "8e0000")
    for x, z in ((0.04, 0.3), (-0.06, 0.2), (0.07, 0.15)):
        body.flat([(x - 0.025, -0.124, z), (x + 0.02, -0.124, z + 0.02), (x + 0.03, -0.124, z - 0.03),
                   (x - 0.01, -0.124, z - 0.04)], blood, facing=(0, -1, 0))
    for side in (-1, 1):
        body.slab([(0.14 * side, -0.085, 0.62), (0.1 * side, -0.088, 0.64), (-0.1 * side, -0.1, 0.44),
                   (-0.06 * side, -0.1, 0.42)], (0, 0.008, 0), leather)
    for x in (-0.1, 0.1):
        body.loft([((x, -0.1, 0.3), 0.006, 0.006), ((x, -0.1, 0.22), 0.006, 0.006), ((x - 0.02, -0.1, 0.2), 0.0, 0.0)],
                  ctx.mat("hook", "9e9e9e"), sides=4, cap_end=False)


def _gargoyle(ctx):
    # Bosses de pierre sur les épaules, mousse, griffes, fissures qui rougeoient.
    rock = ctx.mat("rock", "607d8b")
    body = ctx.part("body")
    for x, z, r in ((-0.15, 0.62, 0.07), (0.15, 0.62, 0.07), (0.0, 0.5, 0.06)):
        body.loft([((x, 0.04, z - r), r * 0.6, r * 0.5), ((x, 0.04, z), r, r * 0.9), ((x, 0.05, z + r * 0.7), 0.0, 0.0)],
                  rock, sides=5, cap_end=False)
    body.flat([(-0.05, -0.092, 0.55), (-0.02, -0.093, 0.5), (-0.04, -0.093, 0.44), (-0.03, -0.093, 0.44),
               (-0.01, -0.093, 0.5), (-0.035, -0.092, 0.55)], ctx.mat("crack", "ff6d00", emission=2.0),
              facing=(0, -1, 0))
    body.loft([((0.07, -0.05, 0.6), 0.03, 0.02), ((0.08, -0.06, 0.62), 0.025, 0.015)], ctx.mat("moss", "558b2f"),
              sides=5)
    for arm_name in ("arm_l", "arm_r"):
        arm = ctx.part(arm_name)
        for dx in (-0.025, 0.0, 0.025):
            arm.cone((dx, -0.02, -0.29), (dx * 1.3, -0.05, -0.37), 0.01, ctx.mat("claw", "263238"), sides=4)
    p = _head_p(ctx)
    head = ctx.part("head")
    head.box(p(0, -0.095, 0.07), (0.17, 0.035, 0.03), rock)
    for side in (-1, 1):
        head.cone(p(0.03 * side, -0.1, -0.05), p(0.035 * side, -0.11, -0.09), 0.01, ctx.mat("fang", "eceff1"), sides=3)


def _oracle(ctx):
    # Un troisième œil sur la capuche, des runes cyan sur la robe, une étole.
    p = _head_p(ctx)
    head = ctx.part("head")
    eye = ctx.mat("third_eye", "18ffff", emission=4.0)
    head.flat([p(-0.02, -0.122, 0.1), p(0.02, -0.122, 0.1), p(0.0, -0.121, 0.125), p(0.0, -0.123, 0.075)], eye,
              facing=(0, -1, 0))
    body = ctx.part("body")
    rune = ctx.mat("rune", "18ffff", emission=2.0)
    for z in (0.12, 0.2, 0.28):
        y = -0.1 - (0.32 - z) * 0.12
        body.flat([(-0.02, y, z + 0.02), (0.02, y, z + 0.02), (0.0, y, z - 0.02)], rune, facing=(0, -1, 0))
    stole = ctx.mat("stole", "00838f", double_sided=True)
    for side in (-1, 1):
        body.slab([(0.06 * side, -0.07, 0.64), (0.09 * side, -0.075, 0.64), (0.07 * side, -0.12, 0.2),
                   (0.04 * side, -0.115, 0.2)], (0, 0.006, 0), stole)


def _necromancer(ctx):
    # Épaulières en crânes, crâne à la ceinture, collier d'os, runes vertes.
    bone = ctx.mat("bone", "e0dccb")
    socket = ctx.mat("socket", "1a1a1a")
    for side, arm_name in ((-1, "arm_l"), (1, "arm_r")):
        arm = ctx.part(arm_name)
        arm.loft([((0.02 * side, 0, 0.03), 0.06, 0.055), ((0.025 * side, 0, 0.08), 0.065, 0.06),
                  ((0.025 * side, 0, 0.13), 0.0, 0.0)], bone, sides=6, cap_end=False)
        for dx in (-0.018, 0.018):
            arm.box((0.025 * side + dx, -0.055, 0.075), (0.016, 0.01, 0.016), socket)
    body = ctx.part("body")
    body.loft([((0.08, -0.085, 0.26), 0.035, 0.03), ((0.08, -0.09, 0.3), 0.04, 0.04), ((0.08, -0.085, 0.33), 0.0, 0.0)],
              bone, sides=6, cap_end=False)
    for k in range(7):
        a = math.pi * (0.15 + 0.7 * k / 6)
        body.loft([((0.1 * math.cos(a), -0.075 - 0.01 * math.sin(a), 0.66 - 0.06 * math.sin(a)), 0.01, 0.01),
                   ((0.1 * math.cos(a), -0.08 - 0.01 * math.sin(a), 0.63 - 0.06 * math.sin(a)), 0.008, 0.008)],
                  bone, sides=4)
    rune = ctx.mat("rune", "76ff03", emission=2.0)
    for z in (0.14, 0.22):
        y = -0.1 - (0.32 - z) * 0.12
        body.flat([(-0.025, y, z), (0.025, y, z), (0.0, y, z + 0.04)], rune, facing=(0, -1, 0))


def _kingdom_star(ctx, part, center):
    star(part, center, 0.06, ctx.mat("emblem", "ffca28"), "x")


# ---------------------------------------------------------------------------
# Les fiches
# ---------------------------------------------------------------------------

CHARACTERS = {
    # Ton camp
    "worker": {"skin": "7cb342", "top": "8d6e63", "legs": "5d4037", "boots": "3e2723", "head": "ears",
               "eyes": "ffeb3b", "weapon": "pickaxe", "head_scale": 1.1, "width": 0.9, "belt": "4e342e",
               "extra": _worker},
    "kobold": {"skin": "ff9800", "top": "ffb74d", "legs": "ff9800", "boots": "c66900", "head": "snout",
               "head_color": "ffa726", "tail": "ff9800", "eyes": "ffffff", "weapon": "dagger", "belt": "6d4c41",
               "extra": _kobold},
    "orc": {"skin": "4e7d2a", "top": "6d4c41", "legs": "5d4037", "boots": "3e2723", "head": "bald",
            "tusks": True, "eyes": "ff5252", "weapon": "axe", "width": 1.15, "belt": "3e2723", "extra": _orc},
    "warlock": {"skin": "2a1b3d", "robe": "5e35b1", "top": "5e35b1", "boots": "311b92", "head": "hood",
                "head_color": "4527a0", "eyes": "ffee58", "weapon": "staff", "orb": "ffee58", "extra": _warlock},
    "vampire": {"skin": "e0e0e0", "top": "311b92", "legs": "212121", "boots": "121212", "head": "spiky_hair",
                "head_color": "212121", "cape": "1a1a2e", "eyes": "ff1744", "belt": "121212", "extra": _vampire},
    "salamander": {"skin": "e64a19", "top": "e64a19", "legs": "bf360c", "boots": "7f2207", "head": "snout",
                   "head_color": "ff7043", "tail": "ff9800", "eyes": "ffeb3b", "extra": _salamander},
    "catcher": {"skin": "05080a", "robe": "1f3a44", "top": "1f3a44", "boots": "102027", "head": "hood",
                "head_color": "2f5d6b", "eyes": "ffeb3b", "weapon": "keys", "belt": "102027", "extra": _catcher},
    "revenant": {"skin": "d8d2bf", "top": "6d5a46", "legs": "d8d2bf", "boots": "3a2f26", "head": "skull",
                 "eyes": "76ff03", "weapon": "sword", "blade": "8d6e63", "hands": "d8d2bf", "belt": "3a2f26",
                 "extra": _revenant},
    # Les créatures des antres (règles 2.7).
    "goblin": {"skin": "8d9e3a", "top": "795548", "legs": "5d4037", "boots": "3e2723", "head": "ears",
               "eyes": "ff9800", "weapon": "hammer", "hammer": "8d6e63", "head_scale": 1.15, "width": 1.1,
               "belt": "4e342e", "extra": _goblin},
    "ghoul": {"skin": "a5b59a", "top": "4e5b4e", "legs": "3e4a3e", "boots": "263238", "head": "bald",
              "eyes": "b2ff59", "weapon": "dagger", "blade": "e0e0e0", "belt": "3e2723", "extra": _ghoul},
    "imp": {"skin": "c62828", "top": "b71c1c", "legs": "8e0000", "boots": "3e0000", "head": "horns",
            "head_color": "212121", "eyes": "ffeb3b", "weapon": "dagger", "wings": "4a0000", "wing_bone": "c62828",
            "tail": "c62828", "width": 0.85, "head_scale": 1.2, "belt": "ffca28", "extra": _imp},
    "executioner": {"skin": "c8a27a", "top": "c8a27a", "legs": "3e2723", "boots": "212121", "head": "hood",
                    "head_color": "1a1a1a", "eyes": "ff5252", "weapon": "axe", "blade": "9e9e9e", "width": 1.35,
                    "belt": "4e342e", "extra": _executioner},
    "gargoyle": {"skin": "78909c", "top": "78909c", "legs": "607d8b", "boots": "455a64", "head": "horns",
                 "head_color": "546e7a", "eyes": "ffab40", "wings": "546e7a", "wing_bone": "78909c", "tail": "607d8b",
                 "width": 1.2, "extra": _gargoyle},
    "oracle": {"skin": "102a43", "robe": "0d2b3e", "top": "0d2b3e", "boots": "06141f", "head": "hood",
               "head_color": "123b54", "eyes": "18ffff", "weapon": "staff", "orb": "18ffff", "staff": "37474f",
               "extra": _oracle},
    "necromancer": {"skin": "d8d2bf", "robe": "1b1b1b", "top": "1b1b1b", "boots": "0a0a0a", "head": "hood",
                    "head_color": "212121", "eyes": "76ff03", "weapon": "staff", "orb": "76ff03", "staff": "d8d2bf",
                    "cape": "2e0a3a", "extra": _necromancer},
    "golem": {"skin": "8d8d8d", "top": "8d8d8d", "legs": "757575", "boots": "616161", "head": "bald",
              "eyes": "4dd0e1", "width": 1.35, "head_scale": 0.85, "extra": _golem},
    # Les héros
    "adventurer": {"skin": "ffccbc", "top": "1e88e5", "legs": "5d4037", "boots": "3e2723", "head": "hair",
                   "head_color": "6d4c41", "eyes": "1a1a1a", "weapon": "sword", "belt": "4e342e",
                   "extra": _adventurer},
    "thief": {"skin": "ffccbc", "top": "37474f", "legs": "263238", "boots": "1c1c1c", "head": "hood",
              "head_color": "26a69a", "eyes": "ffffff", "weapon": "dagger", "belt": "1c1c1c", "width": 0.9,
              "extra": _thief},
    "cleric": {"skin": "ffccbc", "robe": "eceff1", "top": "eceff1", "boots": "8d6e63", "head": "hair",
               "head_color": "8d6e63", "eyes": "1a1a1a", "weapon": "staff", "orb": "ffca28", "staff": "d7ccc8",
               "extra": _cleric},
    "archer": {"skin": "ffccbc", "top": "2e7d32", "legs": "5d4037", "boots": "3e2723", "head": "hood",
               "head_color": "1b5e20", "face_visible": True, "eyes": "1a1a1a", "weapon": "bow", "belt": "4e342e",
               "extra": _archer},
    "dwarf": {"skin": "ffccbc", "top": "6d4c41", "legs": "4e342e", "boots": "3e2723", "head": "helmet",
              "head_color": "9e9e9e", "beard": "ff8f00", "eyes": "1a1a1a", "weapon": "axe", "width": 1.3,
              "head_scale": 1.1, "extra": _dwarf},
    "mage": {"skin": "ffccbc", "robe": "3949ab", "top": "3949ab", "boots": "1a237e", "head": "pointy_hat",
             "head_color": "283593", "hair": "6d4c41", "eyes": "1a1a1a", "weapon": "staff", "orb": "ff7043",
             "extra": _mage},
    "paladin": {"skin": "fbc02d", "top": "eceff1", "legs": "f9a825", "boots": "795548", "head": "helm_gold",
                "head_color": "fdd835", "eyes": "3e2a00", "weapon": "hammer", "shield": "1565c0",
                "rim": "fdd835", "emblem": _kingdom_star, "belt": "795548", "extra": _paladin},
    "giant": {"skin": "c8a27a", "top": "558b2f", "legs": "c8a27a", "boots": "3e2723", "head": "hair",
              "head_color": "4e342e", "eyes": "1a1a1a", "weapon": "club", "width": 1.3, "head_scale": 0.9,
              "extra": _giant},
    "champion": {"skin": "ffccbc", "top": "eceff1", "legs": "90a4ae", "boots": "37474f", "head": "crown",
                 "head_color": "ffca28", "hair": "8d6e63", "beard": "8d6e63", "cape": "1a237e", "eyes": "1a1a1a",
                 "weapon": "big_sword", "belt": "37474f", "extra": _champion},
    "monk": {"skin": "ffccbc", "robe": "795548", "top": "795548", "boots": "4e342e", "head": "tonsure",
             "head_color": "8d6e63", "eyes": "1a1a1a", "weapon": "keys", "extra": _monk},
}


def build(name, export_path=None):
    return humanoid.build(name, CHARACTERS[name], export_path)
