"""Les bêtes en low-poly : l'Araignée, la Chauve-souris et le Cerbère.

Leurs pivots reprennent ceux de voxel_models.gd (_spider, _bat, _cerberus) :
  araignée : leg_0..leg_7 (4 à gauche, de l'avant vers l'arrière, puis 4 à droite),
             que le jeu fait balayer à l'horizontale ;
  chauve-souris : wing_l, wing_r (le jeu soulève le corps : elle vole) ;
  Cerbère : leg_0..leg_3 (gauche avant, gauche arrière, droite avant, droite arrière),
            head_l, head, head_r, tail.

Construire : beasts.build("spider", r"<projet>/assets/models/spider.glb").
"""

import math

import lowpoly as lp
from lowpoly import Part, mirrored, pivot


def build(name, export_path=None):
    scene = lp.new_scene(name)
    BUILDERS[name](scene)
    if export_path:
        lp.export_glb(scene, export_path)
    return scene


def _spider(scene):
    body = pivot(scene, "body")
    shell = lp.material("spider_shell", "6a3d8f")
    dark = lp.material("spider_dark", "2a1838")
    head_mat = lp.material("spider_head", "4a2a66")
    eye = lp.material("spider_eye", "ff1744", emission=4.0)
    mark = lp.material("spider_mark", "e040fb", emission=1.5)
    fang = lp.material("spider_fang", "1a0f22")
    part = Part(scene, "body_mesh", body)
    # Abdomen (gros, à l'arrière), céphalothorax (devant).
    part.loft([((0, 0.3, 0.24), 0.0, 0.0), ((0, 0.25, 0.27), 0.12, 0.11), ((0, 0.12, 0.3), 0.18, 0.15),
               ((0, -0.0, 0.26), 0.15, 0.12), ((0, -0.06, 0.22), 0.07, 0.06)], shell, sides=8,
              cap_start=False, twist=0.0)
    # Motif en chevrons sur le dos.
    for k, y in enumerate((0.04, 0.12, 0.2)):
        w = 0.07 - k * 0.015
        z = 0.44 - k * 0.012
        part.flat([(-w, y, z - 0.012), (0, y + 0.03, z), (w, y, z - 0.012), (0, y + 0.012, z - 0.005)],
                  mark, facing=(0, 0, 1))
    part.loft([((0, -0.06, 0.2), 0.08, 0.07), ((0, -0.15, 0.22), 0.11, 0.09), ((0, -0.24, 0.2), 0.08, 0.07),
               ((0, -0.29, 0.18), 0.0, 0.0)], head_mat, sides=8, cap_end=False)
    # Huit yeux rouges et deux crochets.
    for side in (-1, 1):
        for x, z, r in ((0.03, 0.245, 0.016), (0.065, 0.23, 0.012), (0.02, 0.27, 0.01), (0.05, 0.262, 0.009)):
            y = -0.255 + 0.6 * (0.03 - x) * 0.5 - (0.0 if z < 0.25 else -0.02)
            part.loft([((x * side, y + 0.01, z), r, r), ((x * side, y - 0.004, z), r * 0.8, r * 0.8)],
                      eye, sides=5)
        part.loft([((0.025 * side, -0.27, 0.17), 0.018, 0.018), ((0.03 * side, -0.31, 0.13), 0.01, 0.01),
                   ((0.015 * side, -0.3, 0.09), 0.0, 0.0)], fang, sides=4, cap_end=False)
    part.finish()
    # Les pattes : la hanche, le genou levé, la pointe au sol (vers l'avant ou l'arrière).
    index = 0
    for side in (-1, 1):
        for i in range(4):
            y = -(0.12 - i * 0.1)
            leg = pivot(scene, "leg_%d" % index, body, (0.12 * side, y, 0.22))
            index += 1
            spread = (1.5 - i) * 0.09  # Les pattes avant pointent vers l'avant, les arrière vers l'arrière.
            leg_part = Part(scene, leg.name + "_mesh", leg)
            leg_part.loft([
                ((0, 0, 0), 0.022, 0.022),
                ((0.13 * side, -spread * 0.6, 0.12), 0.02, 0.02),
                ((0.17 * side, -spread * 0.8, 0.13), 0.018, 0.018),
                ((0.28 * side, -spread * 1.3, -0.08), 0.012, 0.012),
                ((0.31 * side, -spread * 1.5, -0.22), 0.0, 0.0),
            ], dark, sides=5, cap_end=False)
            leg_part.loft([((0.165 * side, -spread * 0.78, 0.13), 0.024, 0.024),
                           ((0.175 * side, -spread * 0.82, 0.13), 0.024, 0.024)], shell, sides=5)
            leg_part.finish()


def _bat(scene):
    body = pivot(scene, "body")  # Le jeu le soulève à 0,45 (elle vole).
    fur = lp.material("bat_fur", "6d5a85")
    dark = lp.material("bat_dark", "5d4a75")
    membrane = lp.material("bat_wing", "3e2f52", double_sided=True)
    eye = lp.material("bat_eye", "ff5252", emission=4.0)
    fang = lp.material("bat_fang", "ffffff")
    part = Part(scene, "body_mesh", body)
    part.loft([((0, 0.01, -0.13), 0.0, 0.0), ((0, 0.01, -0.09), 0.07, 0.065), ((0, 0, 0.0), 0.09, 0.08),
               ((0, -0.01, 0.07), 0.075, 0.07)], fur, sides=7, cap_start=False)
    # Tête : museau retroussé, très grandes oreilles, crocs.
    part.loft([((0, -0.015, 0.07), 0.07, 0.065), ((0, -0.03, 0.15), 0.08, 0.075), ((0, -0.03, 0.21), 0.05, 0.05)],
              dark, sides=7)
    part.loft([((0, -0.08, 0.14), 0.035, 0.025), ((0, -0.115, 0.13), 0.03, 0.022)], dark, sides=5)
    part.box((0, -0.123, 0.135), (0.03, 0.006, 0.012), lp.material("bat_nose", "2a1f38"))
    for side in (-1, 1):
        part.loft([((0.04 * side, -0.02, 0.19), 0.025, 0.03), ((0.07 * side, -0.01, 0.27), 0.03, 0.02),
                   ((0.08 * side, 0.0, 0.33), 0.0, 0.0)], dark, sides=4, cap_end=False)
        part.flat(mirrored([(0.025, -0.1, 0.17), (0.055, -0.093, 0.175), (0.05, -0.095, 0.155),
                            (0.028, -0.1, 0.155)], side), eye, facing=(0, -1, 0))
        part.cone((0.015 * side, -0.11, 0.115), (0.015 * side, -0.112, 0.09), 0.006, fang, sides=3)
        # Petites pattes griffues repliées.
        part.cone((0.03 * side, 0.02, -0.1), (0.035 * side, 0.03, -0.15), 0.012, dark, sides=4)
    part.finish()
    for side, name in ((-1, "wing_l"), (1, "wing_r")):
        wing = pivot(scene, name, body, (0.07 * side, 0, 0.04))
        wing_part = Part(scene, name + "_mesh", wing)
        outline = [(0.0, 0, 0.05), (0.14, 0, 0.12), (0.4, 0, 0.1), (0.36, 0, -0.03), (0.33, 0, -0.12),
                   (0.24, 0, -0.05), (0.2, 0, -0.15), (0.12, 0, -0.06), (0.06, 0, -0.12), (0.0, 0, -0.06)]
        wing_part.flat(mirrored(outline, side), membrane)
        for chain in ([(0, 0, 0.05), (0.14, 0, 0.12), (0.4, 0, 0.1)], [(0.14, 0, 0.12), (0.33, 0, -0.12)],
                      [(0.14, 0, 0.12), (0.2, 0, -0.15)], [(0.14, 0, 0.12), (0.06, 0, -0.12)]):
            points = mirrored(chain, side)
            wing_part.loft([(pt, 0.01, 0.01) for pt in points[:-1]] + [(points[-1], 0.004, 0.004)], dark, sides=4)
        wing_part.cone(mirrored([(0.14, 0, 0.12)], side)[0], mirrored([(0.16, 0, 0.17)], side)[0], 0.01, dark, sides=4)
        wing_part.finish()


def _cerberus(scene):
    body = pivot(scene, "body")
    fur = lp.material("cerberus_fur", "3b2a2a")
    dark = lp.material("cerberus_dark", "2a1d1d")
    mane = lp.material("cerberus_mane", "1c1212")
    collar = lp.material("cerberus_collar", "4e342e")
    spike = lp.material("cerberus_spike", "bdbdbd")
    eye = lp.material("cerberus_eye", "ff3d00", emission=4.0)
    mouth = lp.material("cerberus_mouth", "8e1b1b")
    tooth = lp.material("cerberus_tooth", "fff3d6")
    part = Part(scene, "body_mesh", body)
    # Tronc de molosse : poitrail large, taille fine, croupe.
    part.loft([((0, 0.36, 0.44), 0.08, 0.08), ((0, 0.28, 0.43), 0.15, 0.14), ((0, 0.1, 0.42), 0.14, 0.13),
               ((0, -0.08, 0.44), 0.17, 0.16), ((0, -0.2, 0.47), 0.17, 0.15), ((0, -0.27, 0.5), 0.12, 0.12)],
              fur, sides=8, twist=0.0)
    # Crinière sombre en pointes sur le dos et le garrot.
    for k, y in enumerate((-0.18, -0.1, -0.02, 0.06, 0.14)):
        part.cone((0, y, 0.58 - k * 0.02), (0, y + 0.06, 0.66 - k * 0.025), 0.035, mane, sides=4)
    # Collier clouté.
    part.loft([((0, -0.245, 0.455), 0.178, 0.158), ((0, -0.26, 0.48), 0.172, 0.152)], collar, sides=8, twist=0.0)
    for k in range(6):
        angle = math.pi * (0.15 + 0.7 * k / 5)
        part.cone((0.18 * math.cos(angle), -0.255, 0.455 + 0.13 * math.sin(angle) - 0.05),
                  (0.23 * math.cos(angle), -0.27, 0.455 + 0.17 * math.sin(angle) - 0.05), 0.014, spike, sides=4)
    part.finish()
    # Pattes (même ordre que le jeu : gauche avant, gauche arrière, droite avant, droite arrière).
    index = 0
    for x in (-0.12, 0.12):
        for y in (-0.18, 0.26):
            leg = pivot(scene, "leg_%d" % index, body, (x, y, 0.3))
            index += 1
            leg_part = Part(scene, leg.name + "_mesh", leg)
            back = y > 0
            leg_part.loft([((0, 0, 0.12), 0.06, 0.07), ((0, 0.02 if back else -0.01, 0.0), 0.05, 0.055),
                           ((0, 0.04 if back else 0.0, -0.12), 0.035, 0.035), ((0, 0.0, -0.25), 0.03, 0.03)],
                          fur, sides=6)
            leg_part.loft([((0, 0.0, -0.25), 0.035, 0.035), ((0, -0.03, -0.29), 0.045, 0.055),
                           ((0, -0.05, -0.3), 0.04, 0.045)], dark, sides=6)
            for dx in (-0.025, 0.0, 0.025):
                leg_part.cone((dx, -0.08, -0.29), (dx, -0.1, -0.3), 0.008, tooth, sides=3)
            leg_part.finish()
    # Trois têtes de molosse, gueules ouvertes.
    for name, x, z in (("head_l", -0.15, 0.62), ("head", 0.0, 0.68), ("head_r", 0.15, 0.62)):
        head = pivot(scene, name, body, (x, -0.3, z))
        head_part = Part(scene, name + "_mesh", head)
        head_part.loft([((0, 0.12, -0.12), 0.06, 0.06), ((0, 0.06, -0.05), 0.07, 0.07)], fur, sides=6, twist=0.0)
        head_part.loft([((0, 0.06, -0.02), 0.07, 0.07), ((0, 0.0, 0.0), 0.085, 0.08), ((0, -0.05, 0.01), 0.075, 0.07)],
                       fur, sides=7)
        head_part.loft([((0, -0.05, 0.0), 0.055, 0.04), ((0, -0.14, -0.005), 0.042, 0.032)], dark, sides=6)
        head_part.loft([((0, -0.05, -0.05), 0.045, 0.02), ((0, -0.13, -0.075), 0.035, 0.015)], dark, sides=6)
        head_part.flat([(-0.03, -0.13, -0.035), (0.03, -0.13, -0.035), (0.03, -0.12, -0.06), (-0.03, -0.12, -0.06)],
                       mouth, facing=(0, -1, 0))
        head_part.box((0, -0.143, 0.005), (0.03, 0.012, 0.02), mane)
        for side in (-1, 1):
            head_part.cone((0.025 * side, -0.125, -0.03), (0.025 * side, -0.128, -0.06), 0.007, tooth, sides=3)
            head_part.flat(mirrored([(0.025, -0.072, 0.04), (0.06, -0.06, 0.05), (0.055, -0.065, 0.025),
                                     (0.03, -0.072, 0.022)], side), eye, facing=(0, -1, 0))
            head_part.loft([((0.05 * side, 0.02, 0.06), 0.02, 0.025), ((0.07 * side, 0.04, 0.13), 0.0, 0.0)],
                           dark, sides=4, cap_end=False)
        head_part.finish()
    tail = pivot(scene, "tail", body, (0, 0.36, 0.5))
    tail_part = Part(scene, "tail_mesh", tail)
    tail_part.loft([((0, 0, 0), 0.03, 0.03), ((0, 0.1, 0.06), 0.025, 0.025), ((0, 0.18, 0.15), 0.02, 0.02),
                    ((0, 0.2, 0.24), 0.0, 0.0)], fur, sides=5, cap_end=False)
    tail_part.cone((0, 0.18, 0.15), (0, 0.24, 0.19), 0.03, mane, sides=4)
    tail_part.finish()


BUILDERS = {"spider": _spider, "bat": _bat, "cerberus": _cerberus}
