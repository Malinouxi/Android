"""Le Chevalier, en low-poly : armure de plates, heaume à visière et plumet rouge,
surcot bleu, épée longue et écu (couleurs de sa fiche dans voxel_models.gd).

Usage, dans Blender (onglet Scripting, ou par MCP) :
    import sys; sys.path.insert(0, r"<projet>/tools/blender")
    import knight; knight.build(r"<projet>/assets/models/knight.glb")
Le personnage est construit dans sa propre scène « knight ».
"""

import lowpoly as lp
from lowpoly import Part, mirrored, pivot

# Hauteurs des pivots (mêmes que voxel_models.gd, convertis : Godot y -> Blender z).
HIP = 0.3
SHOULDER = 0.58
NECK = 0.74


def build(export_path=None):
    scene = lp.new_scene("knight")
    m = {
        "steel": lp.material("knight_steel", "b0bec5"),
        "plate": lp.material("knight_plate", "90a4ae"),
        "dark": lp.material("knight_dark", "455a64"),
        "slit": lp.material("knight_slit", "1c2833"),
        "plume": lp.material("knight_plume", "e53935"),
        "blue": lp.material("knight_blue", "1565c0"),
        "gold": lp.material("knight_gold", "ffca28"),
        "leather": lp.material("knight_leather", "5d4037"),
    }

    body = pivot(scene, "body")
    _torso(scene, body, m)
    for name, side in (("leg_l", -1), ("leg_r", 1)):
        _leg(scene, pivot(scene, name, body, (0.08 * side, 0, HIP)), m, side)
    for name, side in (("arm_l", -1), ("arm_r", 1)):
        _arm(scene, pivot(scene, name, body, (0.185 * side, 0, SHOULDER)), m, side)
    # L'épée dans la main droite : pointée vers l'avant quand le bras pend (comme voxel_models.gd).
    _sword(scene, pivot(scene, "weapon", scene.objects["arm_r"], (0, -0.02, -0.27), (1.2, 0, 0)), m)
    _shield(scene, scene.objects["arm_l"], m)
    _head(scene, pivot(scene, "head", body, (0, 0, NECK)), m)

    if export_path:
        lp.export_glb(scene, export_path)
    return scene


def _star(part, center, size, mat, axis):
    """Un losange étoilé à quatre branches (l'emblème du royaume), à plat.
    « axis » = 'y' (sur la poitrine, regarde vers -Y) ou 'x' (sur l'écu, regarde vers -X)."""
    cx, cy, cz = center
    long, short = size, size * 0.3
    if axis == "y":
        points = [(cx, cy, cz + long), (cx + short, cy, cz + short), (cx + long * 0.8, cy, cz),
                  (cx + short, cy, cz - short), (cx, cy, cz - long), (cx - short, cy, cz - short),
                  (cx - long * 0.8, cy, cz), (cx - short, cy, cz + short)]
        part.flat(points, mat, facing=(0, -1, 0))
    else:
        points = [(cx, cy, cz + long), (cx, cy + short, cz + short), (cx, cy + long * 0.8, cz),
                  (cx, cy + short, cz - short), (cx, cy, cz - long), (cx, cy - short, cz - short),
                  (cx, cy - long * 0.8, cz), (cx, cy - short, cz + short)]
        part.flat(points, mat, facing=(-1, 0, 0))


def _torso(scene, body, m):
    part = Part(scene, "torso_mesh", body)
    # Cuirasse : bassin, taille, plastron bombé, épaules, gorgerin.
    part.loft([
        ((0, 0, 0.27), 0.1, 0.07),
        ((0, 0, 0.34), 0.095, 0.068),
        ((0, -0.005, 0.44), 0.125, 0.085),
        ((0, -0.005, 0.53), 0.152, 0.088),
        ((0, 0, 0.6), 0.155, 0.08),
        ((0, 0, 0.64), 0.09, 0.065),
        ((0, 0, 0.68), 0.055, 0.055),
    ], m["steel"], sides=8)
    # Surcot bleu sans manches, évasé en bas, et ceinture de cuir à boucle dorée.
    part.loft([
        ((0, 0, 0.2), 0.125, 0.09),
        ((0, 0, 0.3), 0.105, 0.077),
        ((0, -0.005, 0.42), 0.13, 0.09),
        ((0, -0.005, 0.5), 0.148, 0.092),
    ], m["blue"], sides=8, cap_start=False, cap_end=False)
    part.loft([((0, 0, 0.29), 0.11, 0.081), ((0, 0, 0.32), 0.108, 0.08)], m["leather"], sides=8)
    part.box((0, -0.083, 0.305), (0.035, 0.008, 0.03), m["gold"])
    _star(part, (0, -0.097, 0.42), 0.045, m["gold"], "y")
    part.finish()


def _leg(scene, leg, m, side):
    part = Part(scene, leg.name + "_mesh", leg)
    # Cuissard, genouillère, jambière, soleret pointu.
    part.loft([
        ((0, 0, 0.0), 0.06, 0.062),
        ((0, -0.005, -0.1), 0.055, 0.058),
        ((0, 0, -0.13), 0.042, 0.045),
        ((0, 0.005, -0.19), 0.045, 0.048),
        ((0, 0, -0.245), 0.035, 0.038),
    ], m["plate"], sides=7)
    part.cone((0, -0.03, -0.12), (0, -0.07, -0.12), 0.035, m["steel"], sides=5)
    part.loft([((0, 0.02, -0.25), 0.042, 0.04), ((0, -0.01, -0.28), 0.048, 0.06),
               ((0, -0.03, -0.3), 0.045, 0.06)], m["dark"], sides=6)
    part.cone((0, -0.06, -0.29), (0, -0.11, -0.295), 0.025, m["dark"], sides=4)
    part.finish()


def _arm(scene, arm, m, side):
    part = Part(scene, arm.name + "_mesh", arm)
    # Spalière ronde en dôme, bras, cubitière, canon d'avant-bras, gantelet.
    part.loft([
        ((0.01 * side, 0, 0.06), 0.035, 0.035),
        ((0.02 * side, 0, 0.04), 0.07, 0.07),
        ((0.025 * side, 0, -0.01), 0.08, 0.078),
        ((0.025 * side, 0, -0.04), 0.07, 0.07),
    ], m["steel"], sides=8)
    part.loft([
        ((0, 0, -0.02), 0.05, 0.05),
        ((0, 0, -0.12), 0.044, 0.044),
        ((0, 0.005, -0.15), 0.033, 0.035),
        ((0, 0, -0.2), 0.04, 0.04),
        ((0, -0.005, -0.24), 0.035, 0.035),
    ], m["plate"], sides=6)
    part.cone((0, 0.025, -0.135), (0, 0.06, -0.14), 0.026, m["steel"], sides=5)
    part.loft([((0, -0.005, -0.235), 0.045, 0.045), ((0, -0.01, -0.29), 0.04, 0.045)], m["dark"], sides=6)
    part.finish()


def _sword(scene, weapon, m):
    part = Part(scene, "sword_mesh", weapon)
    part.loft([((0, 0, -0.06), 0.018, 0.018), ((0, 0, -0.045), 0.022, 0.022)], m["gold"], sides=5)
    part.loft([((0, 0, -0.05), 0.013, 0.013), ((0, 0, 0.01), 0.014, 0.014)], m["leather"], sides=5)
    part.box((0, 0, 0.02), (0.13, 0.025, 0.022), m["gold"])
    # Lame en losange, effilée jusqu'à la pointe.
    part.loft([((0, 0, 0.03), 0.028, 0.008), ((0, 0, 0.32), 0.022, 0.007), ((0, 0, 0.38), 0.0, 0.0)],
              m["steel"], sides=4, twist=0.0, cap_end=False)
    part.finish()


def _shield(scene, arm_l, m):
    """L'écu bleu cerclé d'acier, sur l'extérieur du bras gauche (face vers -X)."""
    part = Part(scene, "shield_mesh", arm_l)
    outline = [(-0.14, -0.06), (0.06, -0.06), (0.06, -0.16), (0.035, -0.245), (-0.04, -0.32),
               (-0.115, -0.245), (-0.14, -0.16)]
    center = -0.04
    rim = [(center + (y - center) * 1.1, -0.18 + (z + 0.18) * 1.08) for y, z in outline]
    part.slab([(-0.085, y, z) for y, z in rim], (0.02, 0, 0), m["steel"])
    part.slab([(-0.092, y, z) for y, z in outline], (0.006, 0, 0), m["blue"], m["steel"])
    _star(part, (-0.094, center, -0.17), 0.06, m["gold"], "x")
    part.finish()


def _head(scene, head, m):
    part = Part(scene, "head_mesh", head)
    # Heaume fermé, arrondi en haut, avec une crête.
    part.loft([
        ((0, 0, -0.09), 0.09, 0.09),
        ((0, 0, -0.04), 0.105, 0.105),
        ((0, 0, 0.06), 0.105, 0.105),
        ((0, 0, 0.12), 0.085, 0.085),
        ((0, 0, 0.15), 0.045, 0.045),
    ], m["steel"], sides=8)
    part.loft([((0, -0.08, 0.1), 0.012, 0.03), ((0, 0.0, 0.16), 0.012, 0.03), ((0, 0.08, 0.1), 0.012, 0.03)],
              m["plate"], sides=4)
    # Fente de la visière (les « yeux » sombres de la fiche) et trous d'aération.
    part.box((0, -0.098, 0.03), (0.16, 0.012, 0.022), m["slit"])
    part.box((0, -0.1, 0.0), (0.012, 0.012, 0.03), m["plate"])
    for side in (-1, 1):
        for k in range(3):
            part.box(mirrored([(0.035 + 0.018 * k, -0.094, -0.035)], side)[0], (0.008, 0.01, 0.008), m["slit"])
    # Plumet rouge qui retombe vers l'arrière.
    part.loft([
        ((0, -0.02, 0.15), 0.014, 0.025),
        ((0, 0.04, 0.22), 0.02, 0.045),
        ((0, 0.12, 0.21), 0.018, 0.04),
        ((0, 0.17, 0.12), 0.01, 0.02),
        ((0, 0.18, 0.06), 0.0, 0.0),
    ], m["plume"], sides=6, cap_end=False)
    part.finish()
