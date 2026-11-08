"""Le Seigneur des Profondeurs, le visage du médaillon du HUD (voir scripts/lord_portrait.gd).

Même allure que la tête faite en code (peau rouge sombre, cornes crème à pointe
sombre, yeux jaunes, bouc), en plus agressif : arcade sourcilière lourde en V,
grandes cornes annelées, pommettes saillantes, babines retroussées sur deux rangées
de crocs, défenses inférieures, pupilles fendues, balafre, oreilles déchiquetées.

Les pièces mobiles sont accrochées à des pivots nommés, que lord_portrait.gd anime :
    head                 tout le visage (regard, respiration, rire, tremblement)
    jaw                  la mâchoire (rugir, rire, parler)
    brow_l, brow_r       les arcades (colère, inquiétude)
    lid_l, lid_r         les paupières (clignement, regard mi-clos)
    eye_l, eye_r         les yeux (leur couleur change avec l'humeur)
    pupil_l, pupil_r     les pupilles fendues (suivent le regard, se rétractent)
    lip_l, lip_r         les babines (se retroussent en grognant)
    nostril_l, nostril_r les naseaux (se dilatent, soufflent la fumée)
    ear_l, ear_r         les oreilles (frémissent, se couchent en colère)
    tongue               la langue fourchue (sort quand il rit)
    smoke                le point d'où part la fumée des naseaux

Repères : Z vers le haut, le visage regarde vers -Y. Mêmes dimensions que l'ancien
visage en code : la caméra du portrait n'a pas à changer.

Usage, dans Blender (onglet Scripting, ou par MCP) :
    import sys; sys.path.insert(0, r"<projet>/tools/blender")
    import lord; lord.build(r"<projet>/assets/models/lord.glb")
"""

import math

import lowpoly as lp
from lowpoly import Part, mirrored, pivot

SIDES = (-1, 1)  # -1 = _l (côté -X), 1 = _r.
SUFFIX = {-1: "_l", 1: "_r"}


def _materials():
    return {
        "skin": lp.material("lord_skin", "9c1f1f"),
        "dark": lp.material("lord_skin_dark", "5e0f12"),
        "deep": lp.material("lord_skin_deep", "3d0a0c"),
        "horn": lp.material("lord_horn", "e8dcc0"),
        "horn_ring": lp.material("lord_horn_ring", "b8a888"),
        "horn_tip": lp.material("lord_horn_tip", "3a2a22"),
        "socket": lp.material("lord_socket", "120303"),
        "eye": lp.material("lord_eye", "ffd54a", emission=2.5),
        "pupil": lp.material("lord_pupil", "0a0202"),
        "mouth": lp.material("lord_mouth", "1a0505"),
        "gum": lp.material("lord_gum", "5a0d14"),
        "tongue": lp.material("lord_tongue", "7a1a2a"),
        "teeth": lp.material("lord_teeth", "f5f0e0"),
        "scar": lp.material("lord_scar", "b8574c"),
        "beard": lp.material("lord_beard", "2a0a0a"),
        "iron": lp.material("lord_iron", "2e2a2a"),
        "gold": lp.material("lord_gold", "c9a227"),
        "gem": lp.material("lord_gem", "ff1744", emission=2.0),
    }


def build(export_path=None):
    scene = lp.new_scene("lord")
    m = _materials()
    head = pivot(scene, "head")

    _skull(scene, head, m)
    _horns(scene, head, m)
    _ears(scene, head, m)
    _eyes(scene, head, m)
    _brows(scene, head, m)
    _nose(scene, head, m)
    _mouth(scene, head, m)
    _jaw(scene, head, m)
    _collar(scene, head, m)

    if export_path:
        lp.export_glb(scene, export_path)
    return scene


# ---------------------------------------------------------------------------
# Crâne, pommettes, balafre
# ---------------------------------------------------------------------------

def _skull(scene, head, m):
    skull = Part(scene, "lord_skull", head)
    # Le crâne : un œuf un peu aplati sur les côtés, front fuyant vers l'arrière.
    skull.loft([
        ((0, 0.04, -0.2), 0.28, 0.3),
        ((0, 0.0, -0.06), 0.4, 0.4),
        ((0, 0.0, 0.1), 0.45, 0.43),
        ((0, 0.02, 0.28), 0.43, 0.42),
        ((0, 0.06, 0.45), 0.35, 0.34),
        ((0, 0.1, 0.57), 0.2, 0.2),
        ((0, 0.12, 0.61), 0.0, 0.0),
    ], m["skin"], sides=14)
    # Le front : une bosse osseuse au-dessus des arcades, avec une crête au milieu.
    skull.loft([((0, -0.3, 0.26), 0.2, 0.06), ((0, -0.28, 0.4), 0.15, 0.06),
                ((0, -0.18, 0.54), 0.06, 0.04)], m["dark"], sides=6)
    skull.cone((0, -0.33, 0.32), (0, -0.22, 0.6), 0.035, m["deep"], sides=4)
    for side in SIDES:
        # Les pommettes : des arêtes saillantes qui creusent les joues.
        skull.loft([(mirrored([(0.12, -0.34, -0.02)], side)[0], 0.07, 0.05),
                    (mirrored([(0.27, -0.3, 0.0)], side)[0], 0.09, 0.07),
                    (mirrored([(0.36, -0.22, 0.05)], side)[0], 0.0, 0.0)], m["skin"], sides=5)
        # Les tempes : trois petites cornes qui percent la peau.
        for i, (z, x) in enumerate([(0.3, 0.42), (0.18, 0.45), (0.06, 0.45)]):
            skull.cone(mirrored([(x - 0.03, -0.12, z)], side)[0],
                       mirrored([(x + 0.1 - i * 0.015, -0.16, z + 0.03)], side)[0],
                       0.035 - i * 0.006, m["horn_tip"], sides=4)
    # La balafre en travers de l'œil gauche (côté -X).
    skull.slab([(-0.3, -0.39, 0.42), (-0.285, -0.395, 0.43), (-0.1, -0.425, -0.0), (-0.115, -0.42, -0.01)],
               (0, 0.02, 0), m["scar"])
    for t in (0.25, 0.5, 0.75):  # Les points de la couture.
        x, z = -0.29 + 0.18 * t, 0.42 - 0.43 * t
        skull.box((x, -0.405 - 0.025 * t, z), (0.05, 0.012, 0.01), m["deep"])
    skull.finish()


# ---------------------------------------------------------------------------
# Cornes : grandes, annelées, qui s'écartent puis pointent vers l'avant
# ---------------------------------------------------------------------------

def _horns(scene, head, m):
    horns = Part(scene, "lord_horns", head)
    for side in SIDES:
        path = [
            ((0.22, 0.04, 0.4), 0.12),
            ((0.36, 0.06, 0.5), 0.11),
            ((0.5, 0.06, 0.6), 0.095),
            ((0.6, 0.02, 0.72), 0.08),
            ((0.64, -0.05, 0.84), 0.065),
            ((0.6, -0.13, 0.94), 0.048),
            ((0.52, -0.2, 1.0), 0.03),
        ]
        sections = [(mirrored([p], side)[0], r, r) for p, r in path]
        horns.loft(sections, m["horn"], sides=8)
        # Les anneaux de croissance, un peu plus gros et plus sombres.
        for (p, r), (q, _) in zip(path[:5], path[1:6]):
            a = mirrored([p], side)[0]
            b = mirrored([q], side)[0]
            mid = tuple(a[k] * 0.45 + b[k] * 0.55 for k in range(3))
            near = tuple(a[k] * 0.38 + b[k] * 0.62 for k in range(3))
            horns.loft([(mid, r * 0.92 + 0.012, r * 0.92 + 0.012), (near, r * 0.88 + 0.012, r * 0.88 + 0.012)],
                       m["horn_ring"], sides=8)
        # La pointe sombre.
        horns.loft([(mirrored([(0.52, -0.2, 1.0)], side)[0], 0.032, 0.032),
                    (mirrored([(0.42, -0.27, 1.05)], side)[0], 0.0, 0.0)], m["horn_tip"], sides=8,
                   cap_end=False)
        # La base : un anneau de chair sombre où la corne sort du crâne.
        horns.loft([(mirrored([(0.18, 0.03, 0.37)], side)[0], 0.15, 0.15),
                    (mirrored([(0.24, 0.04, 0.42)], side)[0], 0.13, 0.13)], m["dark"], sides=8)
    horns.finish()


# ---------------------------------------------------------------------------
# Oreilles : longues, pointues, entaillées
# ---------------------------------------------------------------------------

def _ears(scene, head, m):
    for side in SIDES:
        ear_pivot = pivot(scene, "ear" + SUFFIX[side], head, at=(side * 0.42, 0.0, 0.1))
        ear = Part(scene, "lord_ear" + SUFFIX[side], ear_pivot)
        outline = [(0.0, -0.06, 0.1), (0.14, -0.04, 0.12), (0.26, 0.0, 0.18), (0.36, 0.04, 0.3),
                   (0.3, 0.04, 0.2), (0.33, 0.05, 0.17),  # Une entaille.
                   (0.22, 0.04, 0.06), (0.1, 0.02, -0.04), (0.0, 0.02, -0.06)]
        ear.slab(mirrored(outline, side), (0, 0.04, 0), m["skin"], m["dark"])
        # L'intérieur de l'oreille, plus sombre.
        inner = [(0.03, -0.065, 0.06), (0.14, -0.05, 0.09), (0.25, -0.02, 0.17), (0.12, -0.04, 0.0)]
        ear.flat(mirrored(inner, side), m["deep"], facing=(0, -1, 0.2))
        # Deux anneaux d'or au lobe.
        for k in range(2):
            x = 0.06 + k * 0.06
            ear.loft([(mirrored([(x, -0.02, -0.02 - k * 0.02)], side)[0], 0.025, 0.025),
                      (mirrored([(x, 0.03, -0.02 - k * 0.02)], side)[0], 0.025, 0.025)], m["gold"], sides=6)
        ear.finish()


# ---------------------------------------------------------------------------
# Yeux : orbites creuses, yeux de braise, pupilles fendues, paupières
# ---------------------------------------------------------------------------

def _eyes(scene, head, m):
    sockets = Part(scene, "lord_sockets", head)
    for side in SIDES:
        x = side * 0.18
        tilt = (0, -side * 0.38, 0)  # Le coin intérieur plus bas que l'extérieur : regard mauvais.
        # L'orbite : une plaque sombre enfoncée dans le crâne, inclinée vers le nez.
        sockets.slab(mirrored([(0.05, -0.405, 0.15), (0.17, -0.4, 0.2), (0.3, -0.36, 0.25), (0.31, -0.35, 0.09),
                               (0.19, -0.39, 0.02), (0.06, -0.41, 0.05)], side), (0, 0.06, 0), m["socket"])
        eye_pivot = pivot(scene, "eye" + SUFFIX[side], head, at=(x, -0.4, 0.12), rotation=tilt)
        eye = Part(scene, "lord_eye" + SUFFIX[side], eye_pivot)
        # Un œil en amande, bombé.
        eye.loft([((0, 0.03, 0), 0.095, 0.034), ((0, 0.0, 0), 0.09, 0.03), ((0, -0.022, 0), 0.0, 0.0)],
                 m["eye"], sides=10, twist=0.0)
        eye.finish()
        pupil_pivot = pivot(scene, "pupil" + SUFFIX[side], eye_pivot, at=(0, -0.02, 0))
        pupil = Part(scene, "lord_pupil" + SUFFIX[side], pupil_pivot)
        pupil.loft([((0, 0.004, -0.034), 0.0, 0.0), ((0, -0.002, 0.0), 0.011, 0.005), ((0, 0.004, 0.034), 0.0, 0.0)],
                   m["pupil"], sides=4)
        pupil.finish()
        # La paupière : une plaque de peau qui descend depuis le haut de l'œil
        # (le jeu l'écrase en hauteur : échelle Z 0,05 = ouverte, 1 = fermée).
        lid_pivot = pivot(scene, "lid" + SUFFIX[side], head, at=(x, -0.425, 0.165), rotation=tilt)
        lid = Part(scene, "lord_lid" + SUFFIX[side], lid_pivot)
        lid.slab([(-0.11, 0.0, 0.0), (0.11, 0.0, 0.0), (0.1, 0.0, -0.1), (-0.1, 0.0, -0.1)], (0, 0.07, 0),
                 m["dark"])
        lid.finish()


def _brows(scene, head, m):
    for side in SIDES:
        brow_pivot = pivot(scene, "brow" + SUFFIX[side], head, at=(side * 0.18, -0.4, 0.24))
        brow = Part(scene, "lord_brow" + SUFFIX[side], brow_pivot)
        # Une arcade lourde en V : basse côté nez, relevée en pointe vers l'extérieur.
        front = [(-0.13, 0.0, -0.06), (0.04, -0.01, -0.01), (0.15, 0.0, 0.02), (0.24, 0.02, 0.11),
                 (0.16, 0.01, 0.07), (0.03, -0.01, 0.06), (-0.11, 0.0, 0.0)]
        brow.slab(mirrored(front, side), (0, 0.14, 0), m["dark"], m["deep"])
        # Les épines au bord de l'arcade.
        for x, z in ((0.0, 0.05), (0.1, 0.07)):
            brow.cone(mirrored([(x, 0.03, z)], side)[0], mirrored([(x + 0.05, 0.05, z + 0.08)], side)[0],
                      0.02, m["horn_tip"], sides=4)
        brow.finish()


# ---------------------------------------------------------------------------
# Nez : un museau écrasé, des naseaux qui se dilatent
# ---------------------------------------------------------------------------

def _nose(scene, head, m):
    nose = Part(scene, "lord_nose", head)
    # L'arête, du front au museau, puis le bout retroussé.
    nose.loft([((0, -0.4, 0.17), 0.04, 0.03), ((0, -0.46, 0.04), 0.07, 0.05), ((0, -0.5, -0.04), 0.1, 0.06),
               ((0, -0.48, -0.09), 0.08, 0.04)], m["skin"], sides=6)
    nose.finish()
    for side in SIDES:
        nostril_pivot = pivot(scene, "nostril" + SUFFIX[side], head, at=(side * 0.05, -0.53, -0.06))
        nostril = Part(scene, "lord_nostril" + SUFFIX[side], nostril_pivot)
        nostril.loft([((0, 0.03, 0), 0.03, 0.02), ((0, -0.005, 0), 0.026, 0.017)], m["mouth"], sides=6,
                     twist=side * 0.4)
        nostril.loft([((0, -0.0, 0), 0.04, 0.03), ((0, -0.015, 0), 0.034, 0.024)], m["dark"], sides=6,
                     cap_end=False, twist=side * 0.4)
        nostril.finish()
    pivot(scene, "smoke", head, at=(0, -0.55, -0.08))


# ---------------------------------------------------------------------------
# Bouche : fente, gencives, crocs du haut, babines qui se retroussent
# ---------------------------------------------------------------------------

def _mouth(scene, head, m):
    mouth = Part(scene, "lord_mouth", head)
    # Le fond de la gueule (visible quand la mâchoire s'ouvre).
    mouth.loft([((0, -0.15, -0.24), 0.26, 0.1), ((0, -0.36, -0.24), 0.22, 0.08)], m["mouth"], sides=10)
    # La gencive du haut et ses crocs.
    mouth.loft([((0, -0.33, -0.19), 0.22, 0.04), ((0, -0.44, -0.2), 0.17, 0.035)], m["gum"], sides=10)
    teeth = [(0.0, 0.035), (0.05, 0.04), (0.1, 0.11), (0.15, 0.05), (0.19, 0.04)]  # (x, longueur)
    for side in SIDES:
        for x, length in teeth:
            if x == 0.0 and side == 1:
                continue
            y = -0.45 + (x * x) * 2.2
            width = 0.03 if length > 0.08 else 0.018
            mouth.cone(mirrored([(x, y, -0.21)], side)[0], mirrored([(x * 0.98, y - 0.01, -0.21 - length)], side)[0],
                       width, m["teeth"], sides=4)
    mouth.finish()
    # Les babines : deux moitiés de lèvre supérieure, que le jeu relève (grognement).
    for side in SIDES:
        lip_pivot = pivot(scene, "lip" + SUFFIX[side], head, at=(side * 0.02, -0.46, -0.13))
        lip = Part(scene, "lord_lip" + SUFFIX[side], lip_pivot)
        lip.loft([(mirrored([(0.0, 0.0, 0.0)], side)[0], 0.035, 0.03),
                  (mirrored([(0.1, 0.02, -0.02)], side)[0], 0.04, 0.035),
                  (mirrored([(0.2, 0.1, -0.03)], side)[0], 0.035, 0.03),
                  (mirrored([(0.24, 0.17, -0.05)], side)[0], 0.0, 0.0)], m["dark"], sides=6)
        # Le pli de la babine jusqu'au museau.
        lip.loft([(mirrored([(0.05, 0.0, 0.03)], side)[0], 0.02, 0.015),
                  (mirrored([(0.04, 0.01, 0.09)], side)[0], 0.0, 0.0)], m["deep"], sides=4)
        lip.finish()


# ---------------------------------------------------------------------------
# Mâchoire : menton carré, défenses, bouc en pointes, langue fourchue
# ---------------------------------------------------------------------------

def _jaw(scene, head, m):
    jaw_pivot = pivot(scene, "jaw", head, at=(0, -0.05, -0.24))
    jaw = Part(scene, "lord_jaw", jaw_pivot)
    # La mâchoire : un fer à cheval du fond (charnière) au menton.
    jaw.loft([((0, 0.18, 0.02), 0.34, 0.1), ((0, -0.05, -0.04), 0.33, 0.13), ((0, -0.25, -0.1), 0.25, 0.12),
              ((0, -0.38, -0.14), 0.15, 0.09), ((0, -0.42, -0.15), 0.08, 0.05)], m["skin"], sides=8)
    # Le dessous du menton, plus sombre.
    jaw.flat([(-0.18, -0.32, -0.2), (0.18, -0.32, -0.2), (0.1, -0.1, -0.22), (-0.1, -0.1, -0.22)], m["dark"],
             facing=(0, 0, -1))
    # La gencive du bas et ses dents.
    jaw.loft([((0, -0.1, 0.02), 0.22, 0.03), ((0, -0.38, -0.02), 0.13, 0.03)], m["gum"], sides=8)
    for side in SIDES:
        for x in (0.04, 0.08, 0.15):
            y = -0.39 + x * x * 3.0
            jaw.cone(mirrored([(x, y, 0.0)], side)[0], mirrored([(x, y, 0.035)], side)[0], 0.015, m["teeth"], 4)
        # Les défenses : deux crocs du bas qui remontent devant la lèvre.
        jaw.loft([(mirrored([(0.12, -0.35, -0.01)], side)[0], 0.032, 0.032),
                  (mirrored([(0.14, -0.38, 0.09)], side)[0], 0.022, 0.022),
                  (mirrored([(0.17, -0.37, 0.17)], side)[0], 0.0, 0.0)], m["teeth"], sides=5)
        # Les crêtes du menton.
        jaw.cone(mirrored([(0.2, -0.24, -0.12)], side)[0], mirrored([(0.3, -0.26, -0.22)], side)[0], 0.035,
                 m["dark"], sides=4)
    # Le bouc : une pointe centrale tressée et deux pointes plus courtes.
    jaw.loft([((0, -0.38, -0.16), 0.07, 0.05), ((0, -0.4, -0.28), 0.05, 0.035), ((0, -0.37, -0.38), 0.03, 0.02),
              ((0, -0.33, -0.48), 0.0, 0.0)], m["beard"], sides=5)
    jaw.loft([((0, -0.39, -0.3), 0.055, 0.04), ((0, -0.39, -0.32), 0.055, 0.04)], m["gold"], sides=6)
    for side in SIDES:
        jaw.cone(mirrored([(0.08, -0.36, -0.15)], side)[0], mirrored([(0.13, -0.33, -0.34)], side)[0], 0.035,
                 m["beard"], sides=4)
    jaw.finish()
    # La langue fourchue, rangée dans la gueule (le jeu la fait sortir quand il rit).
    tongue_pivot = pivot(scene, "tongue", jaw_pivot, at=(0, -0.1, 0.02))
    tongue = Part(scene, "lord_tongue", tongue_pivot)
    tongue.loft([((0, 0.05, 0), 0.08, 0.025), ((0, -0.12, 0.0), 0.06, 0.02), ((0, -0.22, -0.01), 0.04, 0.015)],
                m["tongue"], sides=6)
    for side in SIDES:
        tongue.cone((0, -0.22, -0.01), (side * 0.04, -0.3, -0.02), 0.015, m["tongue"], sides=4)
    tongue.finish()


# ---------------------------------------------------------------------------
# Col : un gorgerin de fer à pointes, avec une gemme (ferme le bas du médaillon)
# ---------------------------------------------------------------------------

def _collar(scene, head, m):
    collar = Part(scene, "lord_collar", head)
    collar.loft([((0, 0.05, -0.2), 0.24, 0.24), ((0, 0.05, -0.5), 0.3, 0.28)], m["deep"], sides=10)
    collar.loft([((0, 0.06, -0.42), 0.4, 0.36), ((0, 0.06, -0.52), 0.48, 0.42), ((0, 0.06, -0.62), 0.52, 0.45)],
                m["iron"], sides=12)
    collar.loft([((0, 0.06, -0.43), 0.41, 0.37), ((0, 0.06, -0.455), 0.415, 0.375)], m["gold"], sides=12)
    for i in range(7):
        angle = math.radians(-90 + (i - 3) * 26)
        x, y = math.cos(angle) * 0.44, 0.06 + math.sin(angle) * 0.4
        collar.cone((x, y, -0.47), (x * 1.25, 0.06 + (y - 0.06) * 1.25, -0.3), 0.04, m["iron"], sides=4)
    collar.loft([((0, -0.37, -0.5), 0.05, 0.05), ((0, -0.42, -0.5), 0.035, 0.035)], m["gem"], sides=6)
    collar.finish()


def preview(resolution=512):
    """Construit le visage et pose la caméra et les lumières du portrait du jeu
    (lord_portrait.gd), paupières ouvertes : pour le regarder dans Blender."""
    import bpy
    scene = build()
    cam_data = bpy.data.cameras.new("portrait_cam")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.angle = math.radians(32)
    cam = bpy.data.objects.new("portrait_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, -2.5, 0.05)  # Godot (0, 0.05, 2.5).
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = resolution
    key = bpy.data.objects.new("portrait_key", bpy.data.lights.new("portrait_key", "SUN"))
    key.data.energy = 3.0
    key.data.color = (1.0, 0.85, 0.7)
    key.rotation_euler = (math.radians(60), 0, math.radians(-35))
    scene.collection.objects.link(key)
    rim = bpy.data.objects.new("portrait_rim", bpy.data.lights.new("portrait_rim", "POINT"))
    rim.data.energy = 150.0
    rim.data.color = (1.0, 0.35, 0.1)
    rim.location = (0.4, -0.8, -0.9)  # Godot (0.4, -0.9, 0.8) : la braise par en dessous.
    scene.collection.objects.link(rim)
    for name in ("lid_l", "lid_r"):
        bpy.data.objects[name].scale = (1, 1, 0.05)
    return scene
