"""Le Démon, en low-poly : grand diable rouge cornu, ailes de chauve-souris, queue
en pointe de flèche, massue cloutée (couleurs de sa fiche dans voxel_models.gd).

Usage, dans Blender (onglet Scripting, ou par MCP) :
    import sys; sys.path.insert(0, r"<projet>/tools/blender")
    import demon; demon.build(r"<projet>/assets/models/demon.glb")
Le personnage est construit dans sa propre scène « demon ».
"""

import math

import lowpoly as lp
from lowpoly import Part, mirrored, pivot

# Hauteurs des pivots (mêmes que voxel_models.gd, convertis : Godot y -> Blender z).
HIP = 0.3
SHOULDER = 0.6
NECK = 0.72


def build(export_path=None):
    scene = lp.new_scene("demon")
    m = {
        "skin": lp.material("demon_skin", "c62828"),
        "torso": lp.material("demon_torso", "b71c1c"),
        "legs": lp.material("demon_legs", "8e1b1b"),
        "hoof": lp.material("demon_hoof", "3b0a0a"),
        "spade": lp.material("demon_spade", "3b0a0a", double_sided=True),
        "horn": lp.material("demon_horn", "ffd54f"),
        "horn_tip": lp.material("demon_horn_tip", "5d4037"),
        "wing": lp.material("demon_wing", "4a0e0e", double_sided=True),
        "eye": lp.material("demon_eye", "ffeb3b", emission=3.0),
        "mouth": lp.material("demon_mouth", "1a0505"),
        "teeth": lp.material("demon_teeth", "fff3d6"),
        "cloth": lp.material("demon_cloth", "3e2a1e"),
        "belt": lp.material("demon_belt", "21140d"),
        "wood": lp.material("demon_wood", "795548"),
        "iron": lp.material("demon_iron", "616161"),
    }

    body = pivot(scene, "body")
    _torso(scene, body, m)
    for name, side in (("leg_l", -1), ("leg_r", 1)):
        _leg(scene, pivot(scene, name, body, (0.085 * side, 0, HIP)), m, side)
    for name, side in (("arm_l", -1), ("arm_r", 1)):
        arm = pivot(scene, name, body, (0.205 * side, 0.0, SHOULDER))
        _arm(scene, arm, m, side)
    # L'arme dans la main droite : pointée vers l'avant quand le bras pend (comme voxel_models.gd).
    weapon = pivot(scene, "weapon", scene.objects["arm_r"], (0, -0.02, -0.29), (1.2, 0, 0))
    _club(scene, weapon, m)
    _head(scene, pivot(scene, "head", body, (0, -0.025, NECK)), m)
    for name, side in (("wing_l", -1), ("wing_r", 1)):
        wing = pivot(scene, name, body, (0.09 * side, 0.09, 0.55), (0, 0, 0.5 * side))
        _wing(scene, wing, m, side)
    _tail(scene, pivot(scene, "tail", body, (0, 0.08, 0.3)), m)

    if export_path:
        lp.export_glb(scene, export_path)
    return scene


def _torso(scene, body, m):
    part = Part(scene, "torso_mesh", body)
    # Bassin, taille fine, cage thoracique, pectoraux larges (le haut penche en avant).
    part.loft([
        ((0, 0.0, 0.26), 0.105, 0.075),
        ((0, 0.0, 0.33), 0.1, 0.07),
        ((0, -0.01, 0.42), 0.13, 0.08),
        ((0, -0.02, 0.52), 0.18, 0.095),
        ((0, -0.015, 0.6), 0.2, 0.09),
        ((0, 0.0, 0.65), 0.15, 0.075),
        ((0, -0.015, 0.69), 0.06, 0.05),
    ], m["torso"], sides=8)
    # Abdominaux et pectoraux en relief.
    for z in (0.36, 0.41):
        for side in (-1, 1):
            part.box((0.035 * side, -0.075 - (z - 0.36) * 0.15, z), (0.05, 0.02, 0.04), m["skin"])
    for side in (-1, 1):
        part.box((0.07 * side, -0.105, 0.535), (0.11, 0.025, 0.08), m["skin"], rotation_z=0.12 * side)
    # Pagne : ceinture, pan avant et pan arrière en lambeaux.
    part.loft([((0, 0, 0.255), 0.115, 0.085), ((0, 0, 0.3), 0.112, 0.082)], m["belt"], sides=8)
    part.flat([(-0.07, -0.088, 0.27), (0.07, -0.088, 0.27), (0.06, -0.1, 0.14), (0.02, -0.1, 0.17),
               (-0.01, -0.1, 0.13), (-0.06, -0.1, 0.16)], m["cloth"], facing=(0, -1, 0))
    part.flat([(-0.08, 0.088, 0.27), (0.08, 0.088, 0.27), (0.07, 0.1, 0.15), (0.0, 0.1, 0.12),
               (-0.07, 0.1, 0.16)], m["cloth"], facing=(0, 1, 0))
    part.loft([((0, 0, 0.18), 0.1, 0.075), ((0, 0, 0.26), 0.116, 0.086)], m["cloth"], sides=8)
    # Épines le long du dos.
    for z in (0.43, 0.5, 0.57, 0.63):
        part.cone((0, 0.07, z), (0, 0.13, z + 0.04), 0.018, m["horn_tip"], sides=4)
    part.finish()


def _leg(scene, leg, m, side):
    part = Part(scene, leg.name + "_mesh", leg)
    # Cuisse musclée, genou, mollet vers l'arrière (patte de bouc), cheville fine.
    part.loft([
        ((0, 0, 0.0), 0.068, 0.072),
        ((0.005 * side, -0.01, -0.07), 0.07, 0.075),
        ((0, -0.02, -0.14), 0.045, 0.05),
        ((0, 0.015, -0.2), 0.045, 0.045),
        ((0, 0.0, -0.255), 0.028, 0.03),
    ], m["legs"], sides=7)
    # Sabot fendu.
    for toe in (-1, 1):
        part.loft([((0.017 * toe, -0.015, -0.255), 0.022, 0.03),
                   ((0.019 * toe, -0.03, -0.3), 0.024, 0.04)], m["hoof"], sides=5)
    part.finish()


def _arm(scene, arm, m, side):
    part = Part(scene, arm.name + "_mesh", arm)
    # Épaule ronde (deltoïde), biceps, coude, avant-bras épais, poignet.
    part.loft([
        ((0.01 * side, 0, 0.045), 0.04, 0.04),
        ((0.02 * side, 0, 0.0), 0.068, 0.065),
        ((0.015 * side, 0, -0.06), 0.06, 0.055),
        ((0.01 * side, 0.005, -0.13), 0.04, 0.042),
        ((0.005 * side, -0.005, -0.18), 0.05, 0.05),
        ((0, -0.01, -0.24), 0.034, 0.034),
    ], m["skin"], sides=7)
    # Main et griffes.
    part.loft([((0, -0.012, -0.24), 0.04, 0.035), ((0, -0.02, -0.29), 0.045, 0.04),
               ((0, -0.025, -0.31), 0.03, 0.03)], m["skin"], sides=6)
    for k, dx in enumerate((-0.025, 0.0, 0.025)):
        part.cone((dx, -0.045, -0.3), (dx, -0.065, -0.34 + 0.005 * abs(k - 1)), 0.009, m["teeth"], sides=4)
    part.finish()


def _club(scene, weapon, m):
    part = Part(scene, "club_mesh", weapon)
    part.loft([((0, 0, -0.04), 0.018, 0.018), ((0, 0, 0.2), 0.022, 0.022)], m["wood"], sides=6)
    part.loft([((0, 0, 0.18), 0.03, 0.03), ((0, 0, 0.26), 0.055, 0.055), ((0, 0, 0.34), 0.05, 0.05),
               ((0, 0, 0.36), 0.03, 0.03)], m["wood"], sides=7)
    for z, turn in ((0.25, 0.0), (0.31, 0.45)):
        for k in range(5):
            angle = turn + k * 2 * math.pi / 5
            dx, dy = math.cos(angle), math.sin(angle)
            part.cone((0.045 * dx, 0.045 * dy, z), (0.085 * dx, 0.085 * dy, z), 0.012, m["iron"], sides=4)
    part.cone((0, 0, 0.35), (0, 0, 0.4), 0.014, m["iron"], sides=4)
    part.finish()


def _head(scene, head, m):
    part = Part(scene, "head_mesh", head)
    # Crâne : mâchoire carrée et large en bas, front bas, nuque.
    part.loft([
        ((0, -0.03, -0.075), 0.055, 0.05),
        ((0, -0.01, -0.035), 0.095, 0.085),
        ((0, 0.0, 0.025), 0.1, 0.09),
        ((0, 0.01, 0.08), 0.085, 0.085),
        ((0, 0.015, 0.115), 0.05, 0.055),
    ], m["skin"], sides=8)
    # Arcades sourcilières froncées (en V) et yeux brillants en amande.
    for side in (-1, 1):
        part.loft([(mirrored([(0.012, -0.098, 0.052)], side)[0], 0.014, 0.012),
                   (mirrored([(0.085, -0.082, 0.078)], side)[0], 0.01, 0.01)], m["torso"], sides=5)
        part.flat(mirrored([(0.018, -0.104, 0.04), (0.075, -0.092, 0.058), (0.068, -0.095, 0.03),
                            (0.028, -0.104, 0.024)], side), m["eye"], facing=(0, -1, 0))
    # Nez court et narines.
    part.loft([((0, -0.09, 0.03), 0.018, 0.012), ((0, -0.112, -0.005), 0.022, 0.016)], m["torso"], sides=5)
    # Grand sourire : bouche sombre et rangée de crocs.
    part.flat([(-0.085, -0.088, -0.012), (-0.04, -0.101, -0.022), (0.04, -0.101, -0.022),
               (0.085, -0.088, -0.012), (0.05, -0.095, -0.055), (-0.05, -0.095, -0.055)], m["mouth"], facing=(0, -1, 0))
    for k in range(7):
        x = -0.06 + k * 0.02
        y = -0.104 + 0.012 * abs(x) / 0.06
        length = 0.025 if k in (1, 5) else 0.016
        part.cone((x, y, -0.02), (x, y - 0.002, -0.02 - length), 0.008, m["teeth"], sides=3)
    # Oreilles pointues.
    for side in (-1, 1):
        part.loft([((0.09 * side, 0.01, 0.02), 0.012, 0.025), ((0.15 * side, 0.03, 0.06), 0.0, 0.0)],
                  m["skin"], sides=4, cap_end=False)
    # Cornes recourbées vers l'arrière puis le haut.
    for side in (-1, 1):
        part.loft([
            ((0.055 * side, 0.0, 0.085), 0.03, 0.03),
            ((0.1 * side, 0.03, 0.15), 0.024, 0.024),
            ((0.125 * side, 0.07, 0.22), 0.017, 0.017),
        ], m["horn"], sides=6, cap_end=False)
        part.loft([((0.125 * side, 0.07, 0.22), 0.017, 0.017), ((0.12 * side, 0.1, 0.28), 0.0, 0.0)],
                  m["horn_tip"], sides=6, cap_start=False, cap_end=False)
    part.finish()


def _wing(scene, wing, m, side):
    part = Part(scene, wing.name + "_mesh", wing)
    # Membrane de chauve-souris (plan XZ du pivot), festonnée entre les doigts.
    outline = [(0.0, 0, 0.04), (0.17, 0, 0.14), (0.4, 0, 0.24), (0.33, 0, 0.07), (0.36, 0, -0.04),
               (0.25, 0, 0.02), (0.24, 0, -0.12), (0.15, 0, -0.02), (0.1, 0, -0.12), (0.03, 0, -0.04)]
    part.flat(mirrored(outline, side), m["wing"])
    # L'os du bras et les doigts.
    bones = [[(0.0, 0, 0.04), (0.17, 0, 0.14), (0.4, 0, 0.24)],
             [(0.17, 0, 0.14), (0.36, 0, -0.04)], [(0.17, 0, 0.14), (0.24, 0, -0.12)],
             [(0.17, 0, 0.14), (0.1, 0, -0.12)]]
    for chain in bones:
        points = mirrored(chain, side)
        sections = [(p, 0.012, 0.012) for p in points[:-1]] + [(points[-1], 0.004, 0.004)]
        part.loft(sections, m["legs"], sides=4)
    part.cone(mirrored([(0.17, 0, 0.14)], side)[0], mirrored([(0.2, 0, 0.2)], side)[0], 0.012,
              m["horn_tip"], sides=4)
    part.finish()


def _tail(scene, tail, m):
    part = Part(scene, "tail_mesh", tail)
    part.loft([
        ((0, 0.0, 0.0), 0.028, 0.028),
        ((0, 0.09, -0.08), 0.022, 0.022),
        ((0, 0.19, -0.13), 0.017, 0.017),
        ((0, 0.29, -0.11), 0.013, 0.013),
        ((0, 0.35, -0.04), 0.01, 0.01),
    ], m["legs"], sides=6)
    # Pointe en fer de flèche (dans le plan de la queue).
    part.flat([(0, 0.33, -0.06), (0.045, 0.36, -0.03), (0, 0.4, 0.04), (-0.045, 0.36, -0.03)], m["spade"])
    part.finish()
