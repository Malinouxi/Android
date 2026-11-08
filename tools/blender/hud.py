"""Les cadres HD du HUD, modélisés dans Blender et rendus en images (assets/ui_hd/).

Pierre volcanique, fer forgé riveté, liseré de braise, or : le thème « Seigneur des
Profondeurs » de scripts/ui.gd, mais en vrai relief (biseaux, rivets, reflets).

Images produites (fond transparent) :
    medallion.png            le médaillon du portrait du Seigneur (centre évidé)
    panel.png                le cadre des panneaux (découpé en 9 par le jeu)
    slot.png                 le creux des compteurs de la barre du haut (9 zones)
    button_<état>.png        les boutons : normal, hover, pressed, disabled (9 zones)
    bubble.png               la bulle de parole du Seigneur (9 zones)

Les images « 9 zones » (StyleBoxTexture dans Godot) : les coins restent nets, les
bords et le centre s'étirent. Les ornements sont donc tous dans les coins, et les
bords sont réguliers sur toute leur longueur. Les marges sont dans MARGINS
(en pixels de l'image), à reporter dans scripts/ui.gd.

Usage, dans Blender (onglet Scripting, ou par MCP) :
    import sys; sys.path.insert(0, r"<projet>/tools/blender")
    import hud; hud.render_all(r"<projet>/assets/ui_hd")
"""

import math
import os

import bpy
from mathutils import Vector

# Taille des images, et marges « 9 zones » (pixels de l'image).
SIZES = {"panel": 192, "slot": 128, "button": 128, "bubble": 128, "medallion": 512}
# Le jeu les affiche à moitié de leur taille (deux fois plus fines : nettes sur téléphone).
MARGINS = {"panel": 36, "slot": 22, "button": 24, "bubble": 26}


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
    key.data.energy = 4.0
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


def _materials():
    return {
        "stone": _material("hud_stone", "2a201e", rough=0.85, noise=0.35, bump=0.35, scale=9.0),
        "stone_dark": _material("hud_stone_dark", "120c0b", rough=0.9, noise=0.25, bump=0.2, scale=14.0),
        "iron": _material("hud_iron", "3a3330", metal=0.85, rough=0.45, noise=0.15, bump=0.15, scale=30.0),
        "iron_dark": _material("hud_iron_dark", "1e1a19", metal=0.8, rough=0.5, bump=0.1, scale=30.0),
        "rivet": _material("hud_rivet", "8d6e63", metal=0.9, rough=0.3),
        "gold": _material("hud_gold", "d4a534", metal=1.0, rough=0.28),
        "ember": _material("hud_ember", "c2410c", emission=2.2),
        "blood": _material("hud_blood", "8b1a1a", rough=0.5),
        "gem": _material("hud_gem", "ff1744", rough=0.1, emission=1.5),
        "bone": _material("hud_bone", "d8ccb0", rough=0.6, noise=0.12, bump=0.1, scale=20.0),
        "wood": _material("hud_wood", "7a2e1c", rough=0.7, noise=0.2, bump=0.1, scale=6.0),
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
    for obj in [o for o in scene.objects if o.type == "MESH"]:
        bpy.data.objects.remove(obj, do_unlink=True)


def _render(scene, path, size, ortho):
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.camera.data.ortho_scale = ortho
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Rendu :", path)


# ---------------------------------------------------------------------------
# Cadres « 9 zones » : un carré de 1 x 1 (le rendu le cadre tout juste)
# ---------------------------------------------------------------------------

def _frame(scene, m, border, plate, rim, corner, inset_line=None, plate_mat="stone_dark", rivets=True):
    """Un cadre carré : plaque de fond, bordure biseautée, liseré, coins ornés.

    border : largeur de la bordure ; rim : matériau de la bordure ; corner : taille
    des renforts de coin (doit rester dans la marge 9 zones)."""
    half = 0.5
    _box(scene, "plate", m[plate_mat], (0, 0, -0.05), (1.0 - border, 1.0 - border, 0.05), bevel=0.01)
    if plate:
        plate(scene, m)
    # La bordure : quatre barres biseautées (aux coins, elles se chevauchent).
    for axis in (0, 1):
        for sign in (-1, 1):
            center = [0.0, 0.0, 0.0]
            center[axis] = sign * (half - border / 2)
            size = [1.0, 1.0, 0.06]
            size[axis] = border
            _box(scene, "rim", m[rim], tuple(center), tuple(size), bevel=border * 0.3, segments=4)
    if inset_line:
        inset = half - border - 0.006
        for axis in (0, 1):
            for sign in (-1, 1):
                center = [0.0, 0.0, 0.0]
                center[axis] = sign * inset
                size = [2 * inset + 0.012, 2 * inset + 0.012, 0.02]
                size[axis] = 0.012
                _box(scene, "line", m[inset_line], tuple(center), tuple(size), bevel=0.003)
    if corner > 0.0:
        for sx in (-1, 1):
            for sy in (-1, 1):
                c = (sx * (half - corner / 2), sy * (half - corner / 2), 0.03)
                _box(scene, "corner", m["iron"], c, (corner, corner, 0.07), bevel=corner * 0.18, segments=4)
                # Une pointe de fer en diagonale vers le centre (dans la marge).
                bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=corner * 0.22, depth=corner * 0.55,
                                                location=(sx * (half - corner * 0.95), sy * (half - corner * 0.95), 0.05),
                                                rotation=(0, math.radians(90), math.atan2(sy, sx) + math.pi))
                spike = bpy.context.active_object
                spike.data.materials.append(m["iron_dark"])
                _relink(scene, spike)
                if rivets:
                    _rivet(scene, m["rivet"], (c[0], c[1], 0.075), radius=corner * 0.2)


def _plate_glow(scene, m):
    pass


def render_panel(scene, m, out):
    _clear(scene)
    _frame(scene, m, border=0.085, plate=None, rim="iron", corner=0.17, inset_line="ember")
    _render(scene, os.path.join(out, "panel.png"), SIZES["panel"], 1.0)


def render_slot(scene, m, out):
    _clear(scene)
    # Un creux : plaque très sombre, bordure de fer fine, plus basse que le fond.
    _frame(scene, m, border=0.08, plate=None, rim="iron_dark", corner=0.0, inset_line="blood",
           plate_mat="stone_dark", rivets=False)
    _render(scene, os.path.join(out, "slot.png"), SIZES["slot"], 1.0)


BUTTON_STATES = {
    # état : (matériau de la dalle, matériau de la bordure, liseré)
    "normal": ("stone", "wood", None),
    "hover": ("stone_light", "wood_light", "ember"),
    "pressed": ("wood", "gold", "gold"),
    "disabled": ("stone_dark", "iron_dark", None),
}


def render_buttons(scene, m, out):
    m = dict(m)
    m["stone_light"] = _material("hud_stone_light", "3d2f2b", rough=0.8, noise=0.3, bump=0.3, scale=9.0)
    m["wood_light"] = _material("hud_wood_light", "a0442a", rough=0.6, noise=0.2, bump=0.1, scale=6.0)
    for state, (plate, rim, line) in BUTTON_STATES.items():
        _clear(scene)
        _frame(scene, m, border=0.1, plate=None, rim=rim, corner=0.0, inset_line=line, plate_mat=plate,
               rivets=False)
        # Un rivet dans chaque coin de la bordure.
        for sx in (-1, 1):
            for sy in (-1, 1):
                _rivet(scene, m["gold" if state == "pressed" else "rivet"], (sx * 0.45, sy * 0.45, 0.04), 0.03)
        _render(scene, os.path.join(out, "button_%s.png" % state), SIZES["button"], 1.0)


def render_bubble(scene, m, out):
    _clear(scene)
    _frame(scene, m, border=0.07, plate=None, rim="iron", corner=0.0, inset_line="ember", rivets=False)
    for sx in (-1, 1):
        for sy in (-1, 1):
            _rivet(scene, m["rivet"], (sx * 0.465, sy * 0.465, 0.04), 0.025)
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
    _ring(scene, "stone", m["stone"], 0.83, 0.12, 0.14, z=0.02, bevel=0.03)
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
