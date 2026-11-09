"""Les cadres HD du HUD, modélisés dans Blender et rendus en images (assets/ui_hd/).

De la PIERRE ET DU FER : des moellons de pierre brune taillée, une bande de fer
rivetée bordée d'un liseré de sang, des équerres de fer aux coins ; le médaillon
garde ses cornes de fer, son anneau de claveaux et son crâne.

Images produites (fond transparent) :
    medallion.png            le médaillon du portrait du Seigneur (centre évidé)
    panel.png                le cadre des panneaux (découpé en 9 par le jeu)
    slot.png                 le creux des compteurs de la barre du haut (9 zones)
    button_<état>.png        les boutons : normal, hover, pressed, disabled (9 zones)
    bubble.png               la bulle de parole du Seigneur (9 zones)

Les images « 9 zones » (StyleBoxTexture dans Godot) : les coins restent nets, les
bords et le centre se RÉPÈTENT (motif périodique, voir _edge_band). Les ornements
sont donc dans les coins. Les marges sont dans MARGINS
(en pixels de l'image), à reporter dans scripts/ui.gd.

Usage, dans Blender (onglet Scripting, ou par MCP) :
    import sys; sys.path.insert(0, r"<projet>/tools/blender")
    import hud; hud.render_all(r"<projet>/assets/ui_hd")
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

# Taille des images, et marges « 9 zones » (pixels de l'image).
SIZES = {"panel": 256, "slot": 128, "button": 128, "bubble": 128, "medallion": 512}
# Le jeu les affiche à moitié de leur taille (deux fois plus fines : nettes sur téléphone).
MARGINS = {"panel": 64, "slot": 32, "button": 32, "bubble": 32}


# ---------------------------------------------------------------------------
# Scène, caméra, lumières, matériaux
# ---------------------------------------------------------------------------

def _new_scene():
    old = bpy.data.scenes.get("hud")
    if old:
        if bpy.context.window.scene == old:
            bpy.context.window.scene = next(s for s in bpy.data.scenes if s != old)
        for obj in list(old.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new("hud")
    bpy.context.window.scene = scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.get("hud_world") or bpy.data.worlds.new("hud_world")
    world.use_nodes = True
    background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.25, 0.18, 0.16, 1.0)
    background.inputs["Strength"].default_value = 0.6
    scene.world = world

    camera = bpy.data.objects.new("hud_cam", bpy.data.cameras.new("hud_cam"))
    camera.data.type = "ORTHO"
    camera.location = (0, 0, 5)
    scene.collection.objects.link(camera)
    scene.camera = camera
    # Lumière du haut à gauche (les biseaux s'éclairent en haut, s'ombrent en bas).
    key = bpy.data.objects.new("hud_key", bpy.data.lights.new("hud_key", "SUN"))
    key.data.energy = 6.0
    key.data.color = (1.0, 0.9, 0.8)
    key.data.angle = math.radians(8)
    key.rotation_euler = (math.radians(40), math.radians(-25), math.radians(20))
    scene.collection.objects.link(key)
    fill = bpy.data.objects.new("hud_fill", bpy.data.lights.new("hud_fill", "SUN"))
    fill.data.energy = 1.2
    fill.data.color = (1.0, 0.45, 0.2)  # Reflet de braise par en dessous.
    fill.rotation_euler = (math.radians(-50), math.radians(20), 0)
    scene.collection.objects.link(fill)
    return scene


def _srgb(hex_color):
    def channel(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(channel(int(hex_color[i:i + 2], 16)) for i in (0, 2, 4)) + (1.0,)


def _material(name, color, metal=0.0, rough=0.6, noise=0.0, bump=0.0, emission=0.0, scale=12.0):
    """Un matériau : couleur, métal, rugosité ; « noise » marbre la couleur (pierre),
    « bump » ajoute du relief (grain de la pierre, martelage du fer)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    for node in [n for n in nodes if n.type not in ("BSDF_PRINCIPLED", "OUTPUT_MATERIAL")]:
        nodes.remove(node)
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    base = _srgb(color)
    bsdf.inputs["Base Color"].default_value = base
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if noise > 0.0 or bump > 0.0:
        coords = nodes.new("ShaderNodeTexCoord")
        tex = nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = scale
        tex.inputs["Detail"].default_value = 8.0
        links.new(coords.outputs["Object"], tex.inputs["Vector"])
        if noise > 0.0:
            ramp = nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.elements[0].color = tuple(c * (1.0 - noise) for c in base[:3]) + (1.0,)
            ramp.color_ramp.elements[1].color = tuple(min(1.0, c * (1.0 + noise)) for c in base[:3]) + (1.0,)
            links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
            links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        if bump > 0.0:
            bump_node = nodes.new("ShaderNodeBump")
            bump_node.inputs["Strength"].default_value = bump
            links.new(tex.outputs["Fac"], bump_node.inputs["Height"])
            links.new(bump_node.outputs["Normal"], bsdf.inputs["Normal"])
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = base
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def _flat(name, color):
    """Une couleur unie : noire à la lumière, elle n'émet que sa propre couleur."""
    mat = _material(name, color, emission=1.0)
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    return mat


def _materials():
    return {
        "stone": _material("hud_stone", "2a201e", rough=0.85, noise=0.35, bump=0.35, scale=9.0),
        "stone_dark": _material("hud_stone_dark", "120c0b", rough=0.9, noise=0.25, bump=0.2, scale=14.0),
        # Les moellons : pierre brune taillée, trois teintes.
        "block": _material("hud_block", "564539", rough=0.85, noise=0.3, bump=0.45, scale=40.0),
        "block_alt": _material("hud_block_alt", "45372f", rough=0.85, noise=0.3, bump=0.45, scale=40.0),
        "block_dark": _material("hud_block_dark", "2f2621", rough=0.9, noise=0.3, bump=0.45, scale=40.0),
        "iron": _material("hud_iron", "4a4240", metal=0.85, rough=0.42, bump=0.08, scale=60.0),
        "iron_light": _material("hud_iron_light", "6e625c", metal=0.85, rough=0.38, bump=0.08, scale=60.0),
        "iron_dark": _material("hud_iron_dark", "2a2422", metal=0.8, rough=0.5, bump=0.08, scale=60.0),
        "rivet": _material("hud_rivet", "8d7a70", metal=0.9, rough=0.3),
        "gold": _material("hud_gold", "e0ad3a", metal=1.0, rough=0.28),
        "ember": _material("hud_ember", "d84315", emission=2.5),
        "blood": _material("hud_blood", "8b1a1a", rough=0.5),
        "blood_seam": _material("hud_blood_seam", "7a1414", emission=0.8),
        "gold_seam": _material("hud_gold_seam", "ffc94a", emission=3.5),
        "gem": _material("hud_gem", "ff1744", rough=0.1, emission=1.5),
        "bone": _material("hud_bone", "d8ccb0", rough=0.6, noise=0.12, bump=0.1, scale=20.0),
        # Les fonds : une couleur unie, insensible aux ombres (le jeu les répète).
        "mortar": _flat("hud_mortar", "0d0908"),
        "floor": _flat("hud_floor", "120d0c"),
        "hole": _flat("hud_hole", "080505"),
        "slab": _flat("hud_slab", "241c1a"),
        "slab_light": _flat("hud_slab_light", "33281f"),
        "slab_gold": _flat("hud_slab_gold", "4a2a12"),
    }


# ---------------------------------------------------------------------------
# Formes : plaques biseautées, barres, rivets
# ---------------------------------------------------------------------------

def _obj(scene, mesh_op, name, mat, location, scale=(1, 1, 1), bevel=0.0, segments=3, rotation=(0, 0, 0)):
    mesh_op(location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if obj.users_collection[0] != scene.collection:
        for coll in obj.users_collection:
            coll.objects.unlink(obj)
        scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if bevel > 0.0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def _box(scene, name, mat, center, size, bevel=0.0, segments=3):
    return _obj(scene, bpy.ops.mesh.primitive_cube_add, name, mat, center,
                (size[0] / 2, size[1] / 2, size[2] / 2), bevel, segments)


def _rivet(scene, mat, at, radius=0.02):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=radius, location=at)
    obj = bpy.context.active_object
    obj.scale.z = 0.6
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    _relink(scene, obj)
    return obj


def _relink(scene, obj):
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    scene.collection.objects.link(obj)


def _clear(scene):
    for obj in [o for o in scene.objects if o.type in ("MESH", "CURVE")]:
        bpy.data.objects.remove(obj, do_unlink=True)


def _render(scene, path, size, ortho, height=None):
    scene.render.resolution_x = size
    scene.render.resolution_y = height or size
    scene.camera.data.ortho_scale = ortho
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Rendu :", path)


# ---------------------------------------------------------------------------
# Cadres « pierre et fer » : moellons taillés, bande de fer rivetée, liseré de sang
# ---------------------------------------------------------------------------
#
# Chaque cadre est un carré de 1 x 1 (le rendu le cadre tout juste). Les bords se
# RÉPÈTENT (le jeu les répète au lieu de les étirer) : tout ce qui est posé sur le
# segment du milieu (de -0,25 à 0,25) est recopié à ±0,5, pour que le motif se
# raccorde sans couture. Les coins (0,25 x 0,25) portent les équerres de fer.

def _copy(scene, obj, offset):
    twin = obj.copy()  # Même maillage : les copies du motif sont identiques.
    twin.location = obj.location + Vector(offset)
    scene.collection.objects.link(twin)
    return twin


def _repeat(scene, obj, rot):
    """Recopie un morceau du motif à ±0,5 le long de son bord."""
    for shift in (-0.5, 0.5):
        _copy(scene, obj, rot @ Vector((shift, 0, 0)))


def _edges():
    """Les quatre bords : (angle, rotation) ; 0 = haut, puis gauche, bas, droite."""
    for edge in range(4):
        angle = edge * math.pi / 2
        yield angle, Matrix.Rotation(angle, 4, "Z")


def _masonry(scene, m, inset, band, seed, per_period=4, rows=2, mats=("block", "block_alt", "block_dark")):
    """Une bande de moellons taillés le long des quatre bords (en quinconce)."""
    rng = random.Random(seed)
    length = 0.5 / per_period
    row_h = band / rows
    gap = 0.012
    for angle, rot in _edges():
        for row in range(rows):
            shift = (length / 2) * (row % 2)
            across = 0.5 - inset - row_h * (row + 0.5)
            # Des moellons de longueurs inégales (la période de 0,5 reste exacte).
            cuts = sorted(rng.uniform(0.25, 0.75) * length + length * k for k in range(per_period))
            cuts = [0.0] + [c - cuts[0] for c in cuts[1:]] + [0.5]
            for k in range(per_period):
                size = cuts[k + 1] - cuts[k]
                t = -0.25 + cuts[k] + size / 2 + shift
                if t > 0.25:
                    t -= 0.5
                local = random.Random(rng.random())
                depth = 0.06 + local.uniform(-0.02, 0.02)
                block = _box(scene, "block", m[local.choice(mats)], (0, 0, 0),
                             (size - gap, row_h - gap * local.uniform(1.0, 2.0), depth), bevel=0.016, segments=3)
                block.location = rot @ Vector((t, across, depth / 2 - 0.03))
                block.rotation_euler = (local.uniform(-0.03, 0.03), local.uniform(-0.03, 0.03), angle)
                _repeat(scene, block, rot)
    # Le mortier sombre sous les moellons (uni : il se répète sans couture).
    for angle, rot in _edges():
        base = _box(scene, "mortar", m["mortar"], (0, 0, 0), (1.0 - 2 * inset, band, 0.02))
        base.location = rot @ Vector((0, 0.5 - inset - band / 2, -0.035))
        base.rotation_euler = (0, 0, angle)


def _iron_strip(scene, m, along, width, rivets_per_period=2, rivet=0.012, seam=True, mat="iron"):
    """Une bande de fer plate (côté intérieur), rivetée, avec un fin liseré de sang dessous."""
    for angle, rot in _edges():
        strip = _box(scene, "strip", m[mat], (0, 0, 0), (1.0, width, 0.02), bevel=0.004, segments=2)
        strip.location = rot @ Vector((0, along, 0.03))
        strip.rotation_euler = (0, 0, angle)
        if seam:
            line = _box(scene, "seam", m["blood_seam"], (0, 0, 0), (1.0, 0.012, 0.01))
            line.location = rot @ Vector((0, along - width / 2 - 0.006, 0.015))
            line.rotation_euler = (0, 0, angle)
        for k in range(rivets_per_period):
            t = -0.25 + 0.5 * (k + 0.5) / rivets_per_period
            r = _rivet(scene, m["rivet"], rot @ Vector((t, along, 0.045)), rivet)
            _repeat(scene, r, rot)


def _corner_brackets(scene, m, inset, size, thick, gold=False, rivet=0.016):
    """Les équerres de fer des quatre coins (en L, biseautées), avec des rivets."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx = sx * (0.5 - inset)
            cy = sy * (0.5 - inset)
            # Les deux bras du L.
            _box(scene, "bracket", m["iron"], (cx - sx * size / 2, cy - sy * thick / 2, 0.06),
                 (size, thick, 0.04), bevel=0.012)
            _box(scene, "bracket", m["iron"], (cx - sx * thick / 2, cy - sy * size / 2, 0.06),
                 (thick, size, 0.04), bevel=0.012)
            # Une plaque en losange au coin, et son gros rivet.
            boss = _box(scene, "boss", m["gold" if gold else "iron"], (cx - sx * thick / 2, cy - sy * thick / 2, 0.07),
                        (thick * 0.95, thick * 0.95, 0.03), bevel=0.008)
            boss.rotation_euler.z = math.pi / 4
            _rivet(scene, m["gold" if gold else "rivet"], (cx - sx * thick / 2, cy - sy * thick / 2, 0.09), rivet * 1.2)
            for along in (0.55, 0.9):
                _rivet(scene, m["rivet"], (cx - sx * size * along, cy - sy * thick / 2, 0.07), rivet)
                _rivet(scene, m["rivet"], (cx - sx * thick / 2, cy - sy * size * along, 0.07), rivet)


def _plate(scene, m, inset, mat="floor"):
    _box(scene, "plate", m[mat], (0, 0, -0.06), (1.0 - 2 * inset - 0.02, 1.0 - 2 * inset - 0.02, 0.04), bevel=0.0)


def render_panel(scene, m, out):
    """Le grand cadre : deux rangs de moellons, la bande de fer rivetée, des équerres."""
    _clear(scene)
    inset, band = 0.012, 0.15
    _plate(scene, m, 0.03)
    _masonry(scene, m, inset, band, seed=11, per_period=3, rows=2)
    _iron_strip(scene, m, 0.5 - inset - band - 0.025, 0.05, rivets_per_period=2, rivet=0.016)
    _corner_brackets(scene, m, inset, 0.235, 0.085, rivet=0.02)
    _render(scene, os.path.join(out, "panel.png"), SIZES["panel"], 1.0)


def render_slot(scene, m, out):
    """Le creux des compteurs : un rebord de fer riveté autour d'un fond noir."""
    _clear(scene)
    _plate(scene, m, 0.03, mat="hole")
    for angle, rot in _edges():
        rim = _box(scene, "rim", m["iron"], (0, 0, 0), (1.0, 0.16, 0.05), bevel=0.025, segments=3)
        rim.location = rot @ Vector((0, 0.5 - 0.02 - 0.08, 0.0))
        rim.rotation_euler = (0, 0, angle)
        line = _box(scene, "seam", m["blood_seam"], (0, 0, 0), (1.0, 0.02, 0.01))
        line.location = rot @ Vector((0, 0.5 - 0.18 - 0.01, -0.01))
        line.rotation_euler = (0, 0, angle)
    for sx in (-1, 1):
        for sy in (-1, 1):
            _rivet(scene, m["rivet"], (sx * 0.4, sy * 0.4, 0.05), 0.04)
    _render(scene, os.path.join(out, "slot.png"), SIZES["slot"], 1.0)


BUTTON_STATES = {
    # état : (fond, fer du rebord, liseré, rivets)
    "normal": ("slab", "iron", "blood_seam", "rivet"),
    "hover": ("slab_light", "iron_light", "ember", "rivet"),
    "pressed": ("slab_gold", "gold", "gold_seam", "gold"),
    "disabled": ("hole", "iron_dark", None, "iron_dark"),
}


def render_buttons(scene, m, out):
    """Les boutons : une dalle de pierre dans un rebord de fer biseauté, rivets aux coins.
    Enfoncé (outil choisi) : rebord d'or et dalle qui rougeoie, comme sur la photo."""
    for state, (slab, rim_mat, seam, rivet) in BUTTON_STATES.items():
        _clear(scene)
        _plate(scene, m, 0.03, mat=slab)
        for angle, rot in _edges():
            rim = _box(scene, "rim", m[rim_mat], (0, 0, 0), (1.0, 0.11, 0.06), bevel=0.028, segments=4)
            rim.location = rot @ Vector((0, 0.5 - 0.015 - 0.055, 0.0))
            rim.rotation_euler = (0, 0, angle)
            if seam:
                line = _box(scene, "seam", m[seam], (0, 0, 0), (1.0, 0.018, 0.01))
                line.location = rot @ Vector((0, 0.5 - 0.125 - 0.009, -0.02))
                line.rotation_euler = (0, 0, angle)
        for sx in (-1, 1):
            for sy in (-1, 1):
                _rivet(scene, m[rivet], (sx * 0.43, sy * 0.43, 0.06), 0.032)
        _render(scene, os.path.join(out, "button_%s.png" % state), SIZES["button"], 1.0)


def render_bubble(scene, m, out):
    """La bulle de parole du Seigneur : un petit cadre de moellons et de fer riveté."""
    _clear(scene)
    _plate(scene, m, 0.03)
    _masonry(scene, m, 0.015, 0.16, seed=13, per_period=2, rows=1)
    _iron_strip(scene, m, 0.5 - 0.015 - 0.16 - 0.02, 0.05, rivets_per_period=1, rivet=0.025)
    _corner_brackets(scene, m, 0.015, 0.26, 0.11, rivet=0.028)
    _render(scene, os.path.join(out, "bubble.png"), SIZES["bubble"], 1.0)


# ---------------------------------------------------------------------------
# Le médaillon du Seigneur
# ---------------------------------------------------------------------------

def _ring(scene, name, mat, radius, width, depth, z=0.0, bevel=0.01, vertices=96):
    """Un anneau plat (rayon moyen, largeur, épaisseur), biseauté."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius + width / 2, depth=depth, location=(0, 0, z))
    outer = bpy.context.active_object
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius - width / 2, depth=depth * 3,
                                        location=(0, 0, z))
    inner = bpy.context.active_object
    mod = outer.modifiers.new("hole", "BOOLEAN")
    mod.object = inner
    mod.operation = "DIFFERENCE"
    bpy.context.view_layer.objects.active = outer
    bpy.ops.object.modifier_apply(modifier="hole")
    bpy.data.objects.remove(inner, do_unlink=True)
    outer.name = name
    outer.data.materials.clear()  # Le booléen laisse un emplacement vide.
    outer.data.materials.append(mat)
    if bevel > 0.0:
        bev = outer.modifiers.new("bevel", "BEVEL")
        bev.width = bevel
        bev.segments = 3
        bev.limit_method = "ANGLE"
    for poly in outer.data.polygons:
        poly.use_smooth = True
    _relink(scene, outer)
    return outer


def _horn(scene, mat, tip_mat, side):
    """Une corne de fer courbe qui sort du haut du médaillon."""
    curve = bpy.data.curves.new("horn_curve", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 1.0
    curve.bevel_resolution = 6
    spline = curve.splines.new("BEZIER")
    points = [(0.52, 0.8, 0.05), (0.74, 1.0, 0.07), (0.82, 1.22, 0.08)]
    spline.bezier_points.add(len(points) - 1)
    for bp, p in zip(spline.bezier_points, points):
        bp.co = (side * p[0], p[1], p[2])
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    for bp, r in zip(spline.bezier_points, (0.1, 0.065, 0.0)):
        bp.radius = r
    obj = bpy.data.objects.new("horn", curve)
    scene.collection.objects.link(obj)
    curve.materials.append(mat)
    return obj


def render_medallion(scene, m, out):
    """Le cadre rond du portrait : pierre, fer riveté, liseré de braise, cornes,
    crâne et gemme. Le centre est vide (le visage 3D du jeu est dessous) ; le rayon
    intérieur est INNER (fraction du rayon de l'image), à reporter dans lord_portrait.gd."""
    _clear(scene)
    for obj in [o for o in scene.objects if o.type == "CURVE"]:
        bpy.data.objects.remove(obj, do_unlink=True)
    # De l'extérieur vers l'intérieur (rayon total de l'image : 1,0 ; cornes en plus).
    _ring(scene, "outer_iron", m["iron"], 0.92, 0.07, 0.1, z=0.0, bevel=0.02)
    # L'anneau de pierre : des moellons taillés en claveaux, comme une voûte.
    _ring(scene, "mortar", m["mortar"], 0.83, 0.13, 0.08, z=0.0, bevel=0.0)
    rng = random.Random(17)
    count = 20
    for k in range(count):
        angle = 2 * math.pi * k / count
        block = _box(scene, "voussoir", m[rng.choice(("block", "block_alt", "block_dark"))], (0, 0, 0),
                     (0.12, 2 * math.pi * 0.83 / count - 0.012, 0.13 + rng.uniform(-0.02, 0.02)), bevel=0.012)
        block.location = (math.cos(angle) * 0.83, math.sin(angle) * 0.83, 0.02)
        block.rotation_euler = (0, 0, angle)
    _ring(scene, "ember", m["ember"], 0.765, 0.016, 0.08, z=0.04, bevel=0.004)
    _ring(scene, "inner_iron", m["iron"], 0.738, 0.04, 0.12, z=0.05, bevel=0.01)
    _ring(scene, "inner_gold", m["gold"], 0.714, 0.012, 0.1, z=0.07, bevel=0.003)
    # Les rivets sur la pierre et sur le fer extérieur.
    for i in range(12):
        angle = 2 * math.pi * i / 12 + math.pi / 12
        _rivet(scene, m["rivet"], (math.cos(angle) * 0.92, math.sin(angle) * 0.92, 0.05), 0.024)
    for i in range(8):
        angle = 2 * math.pi * i / 8 + math.pi / 8
        if abs(math.sin(angle) + 1.0) < 0.3:
            continue  # Pas de rivet sous le crâne.
        # Des griffes de fer qui mordent sur la pierre.
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.04, depth=0.13,
                                        location=(math.cos(angle) * 0.83, math.sin(angle) * 0.83, 0.11),
                                        rotation=(0, math.radians(90), angle + math.pi))
        claw = bpy.context.active_object
        claw.data.materials.append(m["iron_dark"])
        _relink(scene, claw)
        _rivet(scene, m["gold"], (math.cos(angle) * 0.875, math.sin(angle) * 0.875, 0.1), 0.03)
    # Les cornes de fer au sommet.
    for side in (-1, 1):
        _horn(scene, m["iron_dark"], m["iron"], side)
    # Le crâne en bas, avec la gemme rouge du cœur au front.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.13, location=(0, -0.9, 0.14))
    skull = bpy.context.active_object
    skull.scale = (1.0, 0.95, 0.6)
    skull.data.materials.append(m["bone"])
    for poly in skull.data.polygons:
        poly.use_smooth = True
    _relink(scene, skull)
    _box(scene, "skull_jaw", m["bone"], (0, -1.01, 0.12), (0.13, 0.07, 0.07), bevel=0.02)
    for sx in (-1, 1):  # Les orbites.
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.035,
                                             location=(sx * 0.05, -0.92, 0.21))
        eye = bpy.context.active_object
        eye.data.materials.append(m["stone_dark"])
        _relink(scene, eye)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.04, location=(0, -0.82, 0.2))
    gem = bpy.context.active_object
    gem.data.materials.append(m["gem"])
    _relink(scene, gem)
    _render(scene, os.path.join(out, "medallion.png"), SIZES["medallion"], 2.5)


# Rayons (fractions de la demi-largeur de l'image, qui vaut 1,25) : le bord du
# cadre et l'ouverture où l'on voit le visage. À reporter dans lord_portrait.gd.
OUTER = 0.955 / 1.25
INNER = 0.708 / 1.25


def render_all(out):
    os.makedirs(out, exist_ok=True)
    scene = _new_scene()
    m = _materials()
    render_panel(scene, m, out)
    render_slot(scene, m, out)
    render_buttons(scene, m, out)
    render_bubble(scene, m, out)
    render_medallion(scene, m, out)
    return scene


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    render_all(os.path.join(os.path.dirname(os.path.dirname(here)), "assets", "ui_hd"))
