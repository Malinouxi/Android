"""Les ICÔNES HD de l'interface, modélisées en 3D dans Blender (assets/icons_hd/<nom>.png).

Remplace les dessins 2D de tools/icons_hd.py. Chaque icône est un petit objet en
3D (formes lisses, biseautées, métal et or qui brillent, magie qui luit), posé
sur un GALET de roche sombre, éclairé comme dans une caverne : lumière chaude en
haut à gauche, reflet froid derrière, braise par en dessous. Un contour sombre
(Freestyle) garde la silhouette lisible même quand l'icône est toute petite.
Images de 256 x 256 (fond transparent) : le jeu les affiche entre 32 et 64 pixels,
elles restent donc nettes sur un écran de téléphone.

Usage, dans Blender (onglet Scripting, ou par MCP) :
    import sys; sys.path.insert(0, r"<projet>/tools/blender")
    import icons; icons.render_all(r"<projet>/assets/icons_hd")
    icons.render_one("pickaxe", r"<projet>/assets/icons_hd")   # une seule
Ou en ligne de commande :
    blender --background --python tools/blender/icons.py

Repères : X vers la droite, Z vers le haut, la caméra regarde depuis -Y (un peu
au-dessus). L'objet tient dans x de -0,95 à 0,95 et z de -0,65 à 1,05 ; le galet
est en dessous (z autour de -0,8).
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

SIZE = 256           # Taille des images.
ORTHO = 2.2         # Largeur vue par la caméra (mètres).
LINE = 2.2           # Épaisseur du contour (pixels de l'image).


# ---------------------------------------------------------------------------
# Scène, caméra, lumières
# ---------------------------------------------------------------------------

def _new_scene(name="icons"):
    old = bpy.data.scenes.get(name)
    if old:
        if bpy.context.window.scene == old:
            bpy.context.window.scene = next(s for s in bpy.data.scenes if s != old)
        for obj in list(old.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new(name)
    bpy.context.window.scene = scene
    _setup(scene)
    return scene


def _setup(scene):
    """Caméra, lumières et réglages de rendu d'une icône (aussi pour la scène du Seigneur)."""
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = SIZE
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    # Le contour : silhouette et bords extérieurs seulement.
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = LINE
    layer = scene.view_layers[0]
    layer.use_freestyle = True
    settings = layer.freestyle_settings
    lineset = settings.linesets[0] if settings.linesets else settings.linesets.new("contour")
    lineset.select_by_visibility = True
    lineset.select_by_edge_types = True
    lineset.select_silhouette = True
    lineset.select_border = True
    lineset.select_crease = False
    lineset.linestyle.color = (0.04, 0.015, 0.01)
    lineset.linestyle.thickness = LINE

    world = bpy.data.worlds.get("icons_world") or bpy.data.worlds.new("icons_world")
    world.use_nodes = True
    background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.42, 0.33, 0.28, 1.0)
    background.inputs["Strength"].default_value = 1.0
    scene.world = world

    camera = bpy.data.objects.new("icon_cam", bpy.data.cameras.new("icon_cam"))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ORTHO
    target = Vector((0, 0, 0.12))
    camera.location = target + Vector((0, -8, 2.4))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera

    def sun(name, energy, color, rotation):
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        light.data.energy = energy
        light.data.color = color
        light.data.angle = math.radians(6)
        light.rotation_euler = [math.radians(a) for a in rotation]
        scene.collection.objects.link(light)

    sun("icon_key", 5.5, (1.0, 0.88, 0.75), (50, -35, -30))     # Chaude, en haut à gauche.
    sun("icon_rim", 3.0, (0.6, 0.75, 1.0), (-60, 30, 160))     # Froide, derrière : détache la silhouette.
    sun("icon_ember", 1.4, (1.0, 0.4, 0.15), (-110, 0, 10))    # Braise, par en dessous.


def _render(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Icône :", path)


# ---------------------------------------------------------------------------
# Matériaux
# ---------------------------------------------------------------------------

def _srgb(hex_color):
    def channel(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(channel(int(hex_color[i:i + 2], 16)) for i in (0, 2, 4)) + (1.0,)


def mat(name, color, metal=0.0, rough=0.5, emission=0.0, bump=0.0, scale=10.0, alpha=1.0, coat=0.0):
    """Un matériau. emission > 0 : il luit (magie, braise). bump : grain (pierre, bois)."""
    key = "icon_" + name
    m = bpy.data.materials.get(key) or bpy.data.materials.new(key)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    for node in [n for n in nodes if n.type not in ("BSDF_PRINCIPLED", "OUTPUT_MATERIAL")]:
        nodes.remove(node)
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    rgba = _srgb(color)
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if coat > 0.0 and "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emission
    else:
        bsdf.inputs["Emission Strength"].default_value = 0.0
    if bump > 0.0:
        coords = nodes.new("ShaderNodeTexCoord")
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = scale
        noise.inputs["Detail"].default_value = 6.0
        links.new(coords.outputs["Object"], noise.inputs["Vector"])
        bump_node = nodes.new("ShaderNodeBump")
        bump_node.inputs["Strength"].default_value = bump
        links.new(noise.outputs["Fac"], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], bsdf.inputs["Normal"])
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        else:
            m.blend_method = "BLEND"
    m.diffuse_color = rgba
    return m


def _palette():
    return {
        "stone": mat("stone", "4a403b", rough=0.9, bump=0.5, scale=6.0),
        "pebble": mat("pebble", "2f2826", rough=0.8, bump=0.6, scale=5.0),
        "stone_light": mat("stone_light", "8d847c", rough=0.85, bump=0.3, scale=8.0),
        "stone_dark": mat("stone_dark", "2b2624", rough=0.9, bump=0.4, scale=8.0),
        "moss": mat("moss", "3f6b2a", rough=0.95, bump=0.3, scale=20.0),
        "wood": mat("wood", "8a5530", rough=0.7, bump=0.25, scale=4.0),
        "wood_dark": mat("wood_dark", "5a3418", rough=0.75, bump=0.25, scale=4.0),
        "steel": mat("steel", "c9d2d8", metal=1.0, rough=0.25),
        "iron": mat("iron", "5a5450", metal=0.9, rough=0.45),
        "iron_dark": mat("iron_dark", "2e2a28", metal=0.85, rough=0.5),
        "gold": mat("gold", "ffd560", metal=1.0, rough=0.32, emission=0.25),
        "leather": mat("leather", "5c3a22", rough=0.6, bump=0.15, scale=30.0),
        "bone": mat("bone", "efe6d2", rough=0.55, bump=0.1, scale=12.0),
        "dark": mat("dark", "120807", rough=0.8),
        "red": mat("red", "d32f2f", rough=0.45, coat=0.4),
        "skin_red": mat("skin_red", "c62828", rough=0.55),
        "white": mat("white", "f4f1ea", rough=0.6),
        "straw": mat("straw", "d9b65a", rough=0.85, bump=0.4, scale=40.0),
        "cloth_purple": mat("cloth_purple", "7e57c2", rough=0.8, bump=0.1, scale=30.0),
        "cloth_beige": mat("cloth_beige", "e8d9a8", rough=0.85),
        "fire": mat("fire", "ff8f00", emission=4.0),
        "fire_red": mat("fire_red", "ff3d00", emission=4.0),
        "fire_core": mat("fire_core", "ffe082", emission=5.0),
        "ember": mat("ember", "bf360c", emission=2.0),
        "glow_green": mat("glow_green", "69f0ae", emission=3.0),
        "glow_purple": mat("glow_purple", "b388ff", emission=3.0),
        "glow_orange": mat("glow_orange", "ffab40", emission=5.0),
        "blood": mat("blood", "b71c1c", rough=0.2, coat=1.0),
        "gem_red": mat("gem_red", "ff1744", rough=0.08, emission=1.2, coat=1.0),
        "glass": mat("glass", "e1f5fe", rough=0.05, alpha=0.3, coat=1.0),
        "sand": mat("sand", "ffcc66", rough=0.9, emission=0.2),
        "earth": mat("earth", "4e342e", rough=0.95, bump=0.5, scale=12.0),
        "imp": mat("imp", "7cb342", rough=0.55),
        "imp_dark": mat("imp_dark", "33691e", rough=0.6),
        "eye": mat("eye", "ffeb3b", emission=3.0),
    }


# ---------------------------------------------------------------------------
# Formes
# ---------------------------------------------------------------------------

_SCENE = None


def _link(obj, parent=None):
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    _SCENE.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def _finish(obj, material, bevel=0.0, smooth=True, parent=None, segments=3):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    if bevel > 0.0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.harden_normals = True
    if smooth:
        n = len(obj.data.polygons)
        obj.data.polygons.foreach_set("use_smooth", [True] * n)
        if bevel > 0.0:
            obj.data.update()
            try:
                with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj],
                                               selected_editable_objects=[obj]):
                    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
            except (AttributeError, RuntimeError):
                pass
    return _link(obj, parent)


def _apply_scale(obj, scale):
    obj.scale = scale
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj],
                                   selected_editable_objects=[obj]):
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def box(material, center, size, rot=(0, 0, 0), bevel=0.03, parent=None):
    bpy.ops.mesh.primitive_cube_add(location=center, rotation=rot)
    obj = bpy.context.active_object
    _apply_scale(obj, (size[0] / 2, size[1] / 2, size[2] / 2))
    return _finish(obj, material, bevel, parent=parent)


def cyl(material, center, radius, depth, rot=(0, 0, 0), bevel=0.02, vertices=32, radius2=None, parent=None):
    """Un cylindre (ou un cône tronqué si radius2) ; son axe est Z avant rotation."""
    if radius2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center,
                                            rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius2, depth=depth,
                                        location=center, rotation=rot)
    return _finish(bpy.context.active_object, material, bevel, parent=parent)


def cone(material, center, radius, depth, rot=(0, 0, 0), vertices=24, parent=None):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0.0, depth=depth,
                                    location=center, rotation=rot)
    return _finish(bpy.context.active_object, material, 0.0, parent=parent)


def ball(material, center, radius, scale=(1, 1, 1), rot=(0, 0, 0), parent=None, flat=False, subdiv=None):
    if subdiv is not None:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=center, rotation=rot)
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=radius, location=center,
                                             rotation=rot)
    obj = bpy.context.active_object
    if scale != (1, 1, 1):
        _apply_scale(obj, scale)
    return _finish(obj, material, 0.0, smooth=not flat, parent=parent)


def ring(material, center, radius, thickness, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thickness, major_segments=48,
                                     minor_segments=12, location=center, rotation=rot)
    return _finish(bpy.context.active_object, material, 0.0, parent=parent)


def tube(material, points, radii, parent=None, caps=True, resolution=12):
    """Un tube lisse (poignée, corne, doigt, barreau courbe) qui passe par « points »,
    d'épaisseur « radii » (un rayon par point ; 0 = pointe)."""
    curve = bpy.data.curves.new("tube", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 1.0
    curve.bevel_resolution = 6
    curve.resolution_u = resolution
    curve.use_fill_caps = caps
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, p, r in zip(spline.bezier_points, points, radii):
        bp.co = p
        bp.radius = r
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    obj = bpy.data.objects.new("tube", curve)
    curve.materials.append(material)
    _SCENE.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def lathe(material, profile, center=(0, 0, 0), parent=None):
    """Une forme de révolution autour de Z (goutte, sablier) : profile = [(z, rayon), ...]."""
    return tube(material, [(center[0], center[1], center[2] + z) for z, _ in profile],
                [r for _, r in profile], parent=parent, resolution=16)


def plate(material, outline, depth, y=0.0, bevel=0.02, parent=None):
    """Une plaque épaisse découpée selon un contour 2D (x, z), dans le plan de face."""
    mesh = bpy.data.meshes.new("plate")
    bm = bmesh.new()
    verts = [bm.verts.new((x, y - depth / 2, z)) for x, z in outline]
    face = bm.faces.new(verts)
    bmesh.ops.reverse_faces(bm, faces=[face]) if face.normal.y > 0 else None
    result = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [e for e in result["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0, depth, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("plate", mesh)
    _SCENE.collection.objects.link(obj)
    return _finish(obj, material, bevel, parent=parent)


def group(location=(0, 0, 0), rotation_y=0.0, scale=1.0):
    """Un pivot pour assembler un objet debout, puis l'incliner d'un bloc."""
    empty = bpy.data.objects.new("group", None)
    _SCENE.collection.objects.link(empty)
    empty.location = location
    empty.rotation_euler = (0, rotation_y, 0)
    empty.scale = (scale, scale, scale)
    return empty


def pebble(m, width=0.75):
    """Le galet de roche sombre sous chaque icône (petit : l'objet reste lisible)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=1.0, location=(0, 0.1, -0.8))
    obj = bpy.context.active_object
    _apply_scale(obj, (width, 0.45, 0.17))
    tex = bpy.data.textures.get("icon_pebble") or bpy.data.textures.new("icon_pebble", "CLOUDS")
    tex.noise_scale = 0.35
    disp = obj.modifiers.new("rough", "DISPLACE")
    disp.texture = tex
    disp.strength = 0.07
    _finish(obj, m["pebble"], 0.0)
    return obj


def _diagonal(points, angle):
    """Tourne des points (x, z) autour de l'origine (pour les contours 2D)."""
    c, s = math.cos(angle), math.sin(angle)
    return [(x * c - z * s, x * s + z * c) for x, z in points]


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

def pickaxe(m):
    g = group((0.05, 0, 0.18), rotation_y=0.68, scale=0.92)
    cyl(m["wood"], (0, 0, -0.1), 0.065, 1.6, parent=g)
    cyl(m["leather"], (0, 0, -0.62), 0.075, 0.36, parent=g, bevel=0.01)
    tube(m["steel"], [(-0.78, 0, 0.5), (-0.4, 0, 0.72), (0, 0, 0.8), (0.4, 0, 0.72), (0.78, 0, 0.5)],
         [0.0, 0.07, 0.12, 0.07, 0.0], parent=g)
    box(m["iron"], (0, 0, 0.74), (0.2, 0.2, 0.26), bevel=0.04, parent=g)


def hammer(m):
    g = group((0.0, 0, 0.12), rotation_y=-0.62, scale=0.95)
    cyl(m["wood"], (0, 0, -0.1), 0.065, 1.5, parent=g)
    cyl(m["leather"], (0, 0, -0.6), 0.075, 0.34, parent=g, bevel=0.01)
    box(m["iron"], (0, 0, 0.72), (0.95, 0.36, 0.36), bevel=0.06, parent=g)
    for x in (-0.49, 0.49):
        box(m["steel"], (x, 0, 0.72), (0.08, 0.42, 0.42), bevel=0.03, parent=g)


def dagger(m):
    g = group((0.0, 0, 0.12), rotation_y=0.72, scale=0.98)
    plate(m["steel"], [(0, 1.0), (0.13, 0.78), (0.11, 0.05), (-0.11, 0.05), (-0.13, 0.78)], 0.07,
          bevel=0.03, parent=g)
    box(m["iron_dark"], (0, -0.04, 0.45), (0.035, 0.02, 0.6), bevel=0.005, parent=g)
    box(m["gold"], (0, 0, 0.0), (0.62, 0.14, 0.12), bevel=0.04, parent=g)
    for x in (-0.33, 0.33):
        ball(m["gold"], (x, 0, 0.03), 0.08, parent=g)
    cyl(m["leather"], (0, 0, -0.27), 0.065, 0.45, parent=g, bevel=0.01)
    for z in (-0.12, -0.42):
        ring(m["gold"], (0, 0, z), 0.068, 0.018, parent=g)
    ball(m["gold"], (0, 0, -0.56), 0.1, parent=g)
    ball(m["gem_red"], (0, -0.08, -0.56), 0.05, parent=g)


def hand(m):
    """La main du maître : une main de démon rouge, griffes noires."""
    skin = m["skin_red"]
    box(skin, (0.0, 0, -0.05), (0.62, 0.22, 0.58), bevel=0.12)
    cyl(skin, (0.0, 0.02, -0.5), 0.2, 0.4, bevel=0.06)
    ring(m["gold"], (0.0, 0.02, -0.42), 0.21, 0.04)
    for x, top, lean in [(-0.22, 0.75, -0.08), (-0.07, 0.92, -0.02), (0.08, 0.88, 0.03), (0.23, 0.7, 0.09)]:
        tip = (x + lean, -0.06, top)
        tube(skin, [(x, 0, 0.2), (x + lean * 0.5, -0.02, (0.2 + top) / 2), tip], [0.075, 0.068, 0.058])
        cone(m["dark"], (tip[0] + lean * 0.2, tip[1] - 0.02, tip[2] + 0.07), 0.05, 0.16,
             rot=(math.radians(-15), lean * 2, 0))
    tube(skin, [(-0.28, 0, -0.1), (-0.48, -0.02, 0.05), (-0.62, -0.05, 0.25)], [0.085, 0.075, 0.065])
    cone(m["dark"], (-0.66, -0.07, 0.33), 0.05, 0.16, rot=(0, -0.5, 0))


# ---------------------------------------------------------------------------
# Salles
# ---------------------------------------------------------------------------

def chest(m):
    box(m["wood"], (0, 0, -0.32), (1.4, 0.75, 0.62), bevel=0.05)
    for x in (-0.55, 0.0, 0.55):
        box(m["iron"], (x, 0, -0.32), (0.1, 0.79, 0.66), bevel=0.02)
    # Le couvercle ouvert, basculé vers l'arrière.
    lid = group((0, 0.38, 0.0))
    lid.rotation_euler = (math.radians(-65), 0, 0)
    box(m["wood"], (0, -0.38, 0.1), (1.42, 0.76, 0.2), bevel=0.05, parent=lid)
    for x in (-0.55, 0.55):
        box(m["iron"], (x, -0.38, 0.1), (0.1, 0.8, 0.24), bevel=0.02, parent=lid)
    # Le trésor qui déborde.
    for i, (x, y, z, tilt) in enumerate([(-0.35, -0.1, 0.05, 0.3), (0.0, -0.15, 0.12, -0.2), (0.35, -0.05, 0.04, 0.4),
                                         (-0.15, 0.1, 0.2, -0.5), (0.2, 0.1, 0.22, 0.2), (0.05, -0.25, 0.0, 0.1),
                                         (-0.48, -0.2, -0.02, -0.3), (0.5, -0.22, 0.0, 0.5)]):
        cyl(m["gold"], (x, y, z), 0.15, 0.04, rot=(tilt, tilt * 0.5, 0), bevel=0.01)
    ball(m["gem_red"], (-0.05, -0.2, 0.28), 0.1, subdiv=1, flat=True)
    ball(m["gold"], (0.32, -0.2, 0.25), 0.07)
    box(m["gold"], (0, -0.4, -0.18), (0.18, 0.06, 0.22), bevel=0.03)
    ball(m["dark"], (0, -0.44, -0.2), 0.03)


def bed(m):
    box(m["wood_dark"], (0, 0, -0.45), (1.7, 0.8, 0.22), bevel=0.04)
    for x in (-0.8, 0.8):
        for y in (-0.33, 0.33):
            box(m["wood_dark"], (x, y, -0.6), (0.12, 0.12, 0.2), bevel=0.02)
    box(m["wood"], (-0.86, 0, -0.1), (0.14, 0.84, 0.95), bevel=0.05)
    ball(m["gold"], (-0.86, -0.42, 0.4), 0.07)
    ball(m["gold"], (-0.86, 0.42, 0.4), 0.07)
    box(m["cloth_beige"], (0.03, 0, -0.27), (1.6, 0.72, 0.16), bevel=0.06)
    box(m["white"], (-0.55, 0, -0.1), (0.38, 0.6, 0.18), bevel=0.08)
    box(m["cloth_purple"], (0.25, 0, -0.18), (1.15, 0.78, 0.14), bevel=0.06)
    box(m["gold"], (0.25, -0.395, -0.22), (1.15, 0.01, 0.04), bevel=0.0)


def mushroom(m):
    def one(x, scale, cap):
        cyl(m["cloth_beige"], (x, 0, -0.62 + 0.4 * scale), 0.17 * scale, 0.8 * scale, radius2=0.12 * scale,
            bevel=0.03)
        ball(cap, (x, 0, -0.2 + 0.75 * scale), 0.6 * scale, scale=(1, 1, 0.62))
        cyl(m["cloth_beige"], (x, 0, -0.22 + 0.72 * scale), 0.55 * scale, 0.05, bevel=0.02)
        for a, e, r in [(-0.6, 0.6, 0.11), (0.1, 0.9, 0.09), (0.7, 0.5, 0.12), (-0.2, 0.35, 0.08), (0.35, 0.25, 0.07)]:
            px = x + math.sin(a) * math.cos(e) * 0.6 * scale
            pz = -0.2 + 0.75 * scale + math.sin(e) * 0.6 * scale * 0.62
            py = -math.cos(a) * math.cos(e) * 0.6 * scale
            ball(m["white"], (px, py, pz), r * scale, scale=(1, 1, 0.5))
    one(-0.15, 1.0, m["red"])
    one(0.62, 0.45, mat("glow_cap", "ff7043", emission=0.6))


def bookshelf(m):
    w, d, h, z0 = 1.25, 0.45, 1.55, -0.62
    box(m["wood_dark"], (0, 0.2, z0 + h / 2), (w, 0.05, h), bevel=0.01)
    for x in (-w / 2, w / 2):
        box(m["wood"], (x, 0, z0 + h / 2), (0.1, d, h), bevel=0.02)
    shelves = [z0, z0 + 0.52, z0 + 1.02, z0 + h]
    for z in shelves:
        box(m["wood"], (0, 0, z), (w + 0.05, d + 0.02, 0.07), bevel=0.02)
    colors = ["c62828", "1565c0", "2e7d32", "f9a825", "6a1b9a", "4e342e", "00838f"]
    i = 0
    for row in range(3):
        x = -w / 2 + 0.1
        while x < w / 2 - 0.14:
            width = 0.09 + (i * 0.037) % 0.06
            height = 0.33 + (i * 0.061) % 0.1
            lean = 0.18 if (i % 7 == 5) else 0.0
            book = mat("book_%d" % (i % len(colors)), colors[i % len(colors)], rough=0.6)
            box(book, (x + width / 2, -0.02, shelves[row] + 0.035 + height / 2), (width, 0.34, height),
                rot=(0, lean, 0), bevel=0.012)
            box(m["gold"], (x + width / 2, -0.192, shelves[row] + 0.035 + height * 0.7), (width * 0.8, 0.005, 0.03),
                rot=(0, lean, 0), bevel=0.0)
            x += width + 0.015
            i += 1


def anvil(m):
    cyl(m["wood_dark"], (0, 0, -0.45), 0.38, 0.4, bevel=0.03)
    profile = [(-0.95, 0.28), (-0.5, 0.18), (-0.35, 0.1), (-0.3, -0.05), (-0.22, -0.25), (0.22, -0.25),
               (0.3, -0.05), (0.42, 0.1), (0.62, 0.12), (0.62, 0.32), (-0.75, 0.32)]
    plate(m["iron_dark"], profile, 0.42, bevel=0.03)
    box(m["iron"], (0.0, 0, 0.33), (1.2, 0.44, 0.04), bevel=0.01)
    box(m["glow_orange"], (-0.05, 0, 0.42), (0.5, 0.16, 0.1), bevel=0.03)
    for x, z, r in [(-0.3, 0.75, 0.035), (0.05, 0.9, 0.03), (0.3, 0.7, 0.04), (0.45, 0.95, 0.025), (-0.15, 1.0, 0.025)]:
        ball(m["fire_core"], (x, -0.1, z), r)
    hammer_head = group((0.45, -0.25, 0.55), rotation_y=-0.9, scale=0.45)
    cyl(m["wood"], (0, 0, -0.2), 0.06, 1.0, parent=hammer_head)
    box(m["iron"], (0, 0, 0.35), (0.7, 0.28, 0.28), bevel=0.05, parent=hammer_head)


def dummy(m):
    cyl(m["wood_dark"], (0, 0.05, -0.15), 0.06, 1.1)
    cyl(m["wood"], (0, 0.0, 0.3), 0.05, 1.5, rot=(0, math.radians(90), 0))
    ball(m["straw"], (0, 0, 0.0), 0.36, scale=(1, 0.8, 1.25))
    for z in (-0.25, 0.25):
        ring(m["leather"], (0, 0, z), 0.31, 0.025, rot=(0, 0, 0))
    ball(m["straw"], (0, 0, 0.66), 0.22)
    ring(m["leather"], (0, 0, 0.5), 0.12, 0.025)
    for r, color in [(0.2, m["red"]), (0.14, m["white"]), (0.08, m["red"])]:
        cyl(color, (0, -0.28 - (0.2 - r) * 0.1, 0.05), r, 0.02, rot=(math.radians(90), 0, 0), bevel=0.0)
    for x in (-0.75, 0.75):
        ball(m["straw"], (x, 0, 0.3), 0.1, scale=(1.4, 1, 1))


def cage(m):
    iron = m["iron_dark"]
    cyl(iron, (0, 0, -0.55), 0.6, 0.12, bevel=0.03)
    ring(iron, (0, 0, 0.45), 0.57, 0.04)
    ring(iron, (0, 0, -0.05), 0.57, 0.03)
    for i in range(12):
        a = 2 * math.pi * i / 12
        x, y = math.cos(a) * 0.57, math.sin(a) * 0.57
        cyl(m["iron"], (x, y, -0.05), 0.028, 1.0, bevel=0.0, vertices=12)
        if i % 2 == 0:
            tube(m["iron"], [(x, y, 0.45), (x * 0.7, y * 0.7, 0.75), (0, 0, 0.88)], [0.025, 0.025, 0.025])
    ring(m["iron"], (0, 0, 0.98), 0.09, 0.025, rot=(math.radians(90), 0, 0))
    ball(m["bone"], (-0.15, 0.1, -0.38), 0.14, scale=(1, 1, 0.9))
    ball(m["dark"], (-0.2, -0.02, -0.36), 0.035)
    ball(m["dark"], (-0.1, -0.02, -0.36), 0.035)


def temple(m):
    box(m["stone_light"], (0, 0, -0.6), (1.7, 0.85, 0.12), bevel=0.02)
    box(m["stone_light"], (0, 0, -0.48), (1.5, 0.75, 0.12), bevel=0.02)
    box(m["glow_purple"], (0, 0.15, -0.05), (0.75, 0.05, 0.8), bevel=0.0)
    box(m["gold"], (0, 0.1, 0.0), (0.08, 0.05, 0.5), bevel=0.01)
    box(m["gold"], (0, 0.1, 0.1), (0.3, 0.05, 0.08), bevel=0.01)
    ring(m["gold"], (0, 0.1, 0.3), 0.08, 0.025, rot=(math.radians(90), 0, 0))
    for x in (-0.58, -0.32, 0.32, 0.58):
        cyl(m["stone_light"], (x, -0.1, -0.06), 0.085, 0.72, bevel=0.01)
        box(m["stone_light"], (x, -0.1, -0.4), (0.22, 0.22, 0.06), bevel=0.01)
        box(m["stone_light"], (x, -0.1, 0.32), (0.22, 0.22, 0.06), bevel=0.01)
    box(m["stone_light"], (0, 0, 0.42), (1.6, 0.8, 0.14), bevel=0.02)
    plate(m["stone_light"], [(-0.82, 0.49), (0.82, 0.49), (0, 0.92)], 0.78, bevel=0.02)
    ball(m["glow_purple"], (0, -0.42, 0.66), 0.07)
    for x in (-0.75, 0.75):
        cyl(m["white"], (x, -0.3, -0.33), 0.04, 0.18, bevel=0.0)
        cone(m["fire"], (x, -0.3, -0.18), 0.03, 0.1)


def tomb(m):
    ball(m["earth"], (0, 0.0, -0.62), 0.75, scale=(1.1, 0.6, 0.25))
    outline = [(-0.42, -0.55), (0.42, -0.55), (0.42, 0.45)]
    outline += [(math.cos(a) * 0.42, 0.45 + math.sin(a) * 0.42) for a in [math.radians(d) for d in range(15, 180, 15)]]
    outline += [(-0.42, 0.45)]
    plate(m["stone_light"], outline, 0.2, y=0.1, bevel=0.04)
    box(m["stone_dark"], (0, -0.005, 0.32), (0.09, 0.02, 0.6), bevel=0.0)
    box(m["stone_dark"], (0, -0.005, 0.45), (0.38, 0.02, 0.09), bevel=0.0)
    ball(m["moss"], (-0.35, -0.0, -0.45), 0.12, scale=(1.2, 0.8, 0.6))
    for x, z, r in [(0.6, 0.35, 0.08), (-0.62, 0.6, 0.06), (0.75, 0.75, 0.045)]:
        ball(m["glow_green"], (x, -0.2, z), r)


# ---------------------------------------------------------------------------
# Défenses
# ---------------------------------------------------------------------------

def spikes(m):
    box(m["iron_dark"], (0, 0.05, -0.55), (1.6, 0.7, 0.14), bevel=0.03)
    for x, y, h in [(-0.55, 0.2, 0.9), (0.0, 0.2, 1.0), (0.55, 0.2, 0.9), (-0.3, -0.12, 1.15), (0.3, -0.12, 1.15)]:
        cone(m["steel"], (x, y, -0.48 + h / 2), 0.13, h, vertices=8)
        ball(m["blood"], (x, y - 0.03, -0.48 + h * 0.85), 0.04, scale=(1, 1, 1.8))


def rune(m):
    g = group((0, 0, 0.05))
    g.rotation_euler = (math.radians(-12), 0, 0)
    cyl(m["stone_dark"], (0, 0, 0), 0.82, 0.14, rot=(math.radians(90), 0, 0), bevel=0.04, parent=g)
    ring(m["glow_orange"], (0, -0.08, 0), 0.68, 0.035, rot=(math.radians(90), 0, 0), parent=g)
    ring(m["fire"], (0, -0.08, 0), 0.45, 0.02, rot=(math.radians(90), 0, 0), parent=g)
    star = [(math.cos(math.radians(90 + i * 144)) * 0.62, -0.085, math.sin(math.radians(90 + i * 144)) * 0.62)
            for i in range(6)]
    for a, b in zip(star, star[1:]):
        tube(m["fire_core"], [a, b], [0.022, 0.022], parent=g)
    ball(m["fire_core"], (0, -0.1, 0), 0.09, parent=g)


def door(m):
    def arch(width, base, top, steps=12):
        r = width / 2
        pts = [(-r, base), (r, base), (r, top)]
        pts += [(math.cos(a) * r, top + math.sin(a) * r) for a in [math.pi * k / steps for k in range(1, steps)]]
        pts += [(-r, top)]
        return pts
    plate(m["stone_light"], arch(1.5, -0.65, 0.3), 0.3, y=0.12, bevel=0.04)
    plate(m["wood"], arch(1.1, -0.65, 0.3), 0.08, y=-0.05, bevel=0.015)
    for x in (-0.28, 0.0, 0.28):
        box(m["wood_dark"], (x, -0.095, -0.05), (0.02, 0.01, 1.2), bevel=0.0)
    for z in (-0.4, 0.2):
        box(m["iron_dark"], (0, -0.1, z), (1.1, 0.03, 0.1), bevel=0.01)
        for x in (-0.45, -0.15, 0.15, 0.45):
            ball(m["iron"], (x, -0.12, z), 0.025)
    ring(m["gold"], (0.32, -0.13, -0.1), 0.08, 0.018, rot=(math.radians(90), 0, 0))
    ball(m["gold"], (0.32, -0.12, -0.02), 0.035)


def sacrifice_altar(m):
    box(m["stone_dark"], (0, 0, -0.42), (1.3, 0.6, 0.45), bevel=0.04)
    box(m["stone_dark"], (0, 0, -0.14), (1.5, 0.72, 0.12), bevel=0.03)
    box(m["fire_red"], (0, -0.362, -0.14), (1.3, 0.01, 0.03), bevel=0.0)
    ball(m["blood"], (0.3, -0.33, -0.3), 0.04, scale=(1, 1, 2.5))
    ball(m["blood"], (-0.45, -0.33, -0.27), 0.03, scale=(1, 1, 2.0))
    _skull(m, (0, 0, 0.25), 0.62)
    for x in (-0.62, 0.62):
        cyl(m["white"], (x, 0.05, 0.02), 0.05, 0.22, bevel=0.0)
        cone(m["fire"], (x, 0.05, 0.2), 0.035, 0.12)


def brazier(m):
    for a in (90, 210, 330):
        x, y = math.cos(math.radians(a)), math.sin(math.radians(a))
        tube(m["iron_dark"], [(x * 0.2, y * 0.2, -0.05), (x * 0.4, y * 0.3, -0.4), (x * 0.5, y * 0.35, -0.65)],
             [0.045, 0.04, 0.05])
    cyl(m["iron"], (0, 0, 0.0), 0.28, 0.32, radius2=0.62, bevel=0.03)
    ring(m["iron_dark"], (0, 0, 0.16), 0.62, 0.04)
    ball(m["ember"], (0, 0, 0.14), 0.55, scale=(1, 1, 0.15))
    for x, y, h, r, mt in [(0, 0, 0.75, 0.3, "fire_red"), (-0.25, 0.05, 0.5, 0.2, "fire"), (0.25, 0.0, 0.55, 0.2, "fire"),
                           (0, -0.1, 0.45, 0.16, "fire_core")]:
        cone(m[mt], (x, y, 0.18 + h / 2), r, h, vertices=10)


# ---------------------------------------------------------------------------
# Sorts et compteurs
# ---------------------------------------------------------------------------

def heal(m):
    green = mat("heal", "00e676", rough=0.15, emission=1.2, coat=1.0)
    plus = [(-0.18, 0.75), (0.18, 0.75), (0.18, 0.33), (0.6, 0.33), (0.6, -0.03), (0.18, -0.03), (0.18, -0.45),
            (-0.18, -0.45), (-0.18, -0.03), (-0.6, -0.03), (-0.6, 0.33), (-0.18, 0.33)]
    plate(green, plus, 0.28, bevel=0.07)
    plate(mat("heal_core", "b9f6ca", emission=2.0), [(x * 0.55, 0.15 + (z - 0.15) * 0.55) for x, z in plus], 0.3,
          bevel=0.03)
    for x, z in [(-0.6, 0.75), (0.65, 0.65), (0.55, -0.4)]:
        ball(m["glow_green"], (x, -0.1, z), 0.05)


def bolt(m):
    shape = [(0.2, 1.0), (-0.42, 0.18), (-0.02, 0.18), (-0.28, -0.6), (0.48, 0.38), (0.08, 0.38), (0.42, 1.0)]
    plate(mat("bolt", "ffea00", rough=0.2, emission=2.5), [(x - 0.03, z) for x, z in shape], 0.2, bevel=0.04)


def haste(m):
    arrow = [(-0.6, 0.08), (0.2, 0.08), (0.2, 0.22), (0.62, 0.0), (0.2, -0.22), (0.2, -0.08), (-0.6, -0.08)]
    cyan = mat("haste", "00e5ff", rough=0.2, emission=1.5)
    for dz, dx in ((0.55, 0.15), (0.12, 0.3), (-0.31, 0.15)):
        plate(cyan, [(x + dx, z + dz) for x, z in arrow], 0.14, bevel=0.03)
        for k in range(2):
            box(mat("haste_trail", "84ffff", emission=1.0), (-0.72 + dx - k * 0.18, 0, dz), (0.1 - k * 0.03, 0.06, 0.05),
                bevel=0.01)


def _drop(color_hex):
    profile = [(-0.58, 0.0), (-0.55, 0.22), (-0.42, 0.44), (-0.2, 0.52), (0.05, 0.45), (0.3, 0.3), (0.55, 0.14),
               (0.92, 0.0)]
    lathe(mat("drop_" + color_hex, color_hex, rough=0.05, emission=0.8, coat=1.0), profile, (0, 0, 0.05))


def mana(m):
    _drop("2979ff")


def blood(m):
    _drop("d50000")


def gold(m):
    for x, count in ((-0.5, 4), (0.5, 3)):
        for k in range(count):
            cyl(m["gold"], (x + (k % 2) * 0.025, 0.1 - 0.02 * k, -0.6 + k * 0.1), 0.32, 0.09, bevel=0.02)
    coin = group((0.0, -0.25, 0.1))
    coin.rotation_euler = (math.radians(80), 0.18, 0)
    cyl(m["gold"], (0, 0, 0), 0.5, 0.1, bevel=0.025, parent=coin)
    ring(m["gold"], (0, 0, 0.055), 0.38, 0.03, parent=coin)
    ball(m["gem_red"], (0, 0, 0.07), 0.12, scale=(1, 1, 0.5), subdiv=1, flat=True, parent=coin)
    ball(m["gem_red"], (-0.62, -0.3, -0.48), 0.09, subdiv=1, flat=True)
    cyl(m["gold"], (0.55, -0.35, -0.55), 0.22, 0.06, rot=(0.4, 0.2, 0), bevel=0.015)


def _skull(m, center, s):
    cx, cy, cz = center
    bone = m["bone"]
    ball(bone, (cx, cy, cz + 0.12 * s), 0.5 * s, scale=(0.95, 1.0, 0.95))
    box(bone, (cx, cy - 0.12 * s, cz - 0.25 * s), (0.62 * s, 0.6 * s, 0.35 * s), bevel=0.12 * s)
    box(bone, (cx, cy - 0.08 * s, cz - 0.5 * s), (0.5 * s, 0.5 * s, 0.16 * s), bevel=0.06 * s)
    for x in (-0.19, 0.19):
        ball(m["dark"], (cx + x * s, cy - 0.38 * s, cz + 0.02 * s), 0.14 * s, scale=(1.0, 0.6, 0.95))
    cone(m["dark"], (cx, cy - 0.44 * s, cz - 0.17 * s), 0.07 * s, 0.12 * s, rot=(0, 0, 0), vertices=3)
    for k in range(5):
        box(m["white"], (cx + (-0.16 + k * 0.08) * s, cy - 0.42 * s, cz - 0.38 * s), (0.06 * s, 0.03 * s, 0.1 * s),
            bevel=0.01 * s)


def skull(m):
    _skull(m, (0, 0, 0.12), 1.15)


def worker(m):
    imp, dark = m["imp"], m["imp_dark"]
    ball(imp, (0, 0, 0.12), 0.55, scale=(1.0, 0.9, 0.92))
    for side in (-1, 1):
        tube(imp, [(side * 0.45, 0.05, 0.2), (side * 0.75, 0.05, 0.38), (side * 0.98, 0.1, 0.6)], [0.16, 0.08, 0.0])
        ball(m["eye"], (side * 0.2, -0.43, 0.22), 0.1, scale=(1.1, 0.6, 0.8))
        ball(m["dark"], (side * 0.2, -0.5, 0.22), 0.035)
        box(dark, (side * 0.2, -0.46, 0.36), (0.22, 0.08, 0.05), rot=(0, side * -0.35, 0), bevel=0.02)
    ball(dark, (0, -0.52, 0.08), 0.07, scale=(1.2, 1, 0.8))
    box(m["dark"], (0, -0.44, -0.12), (0.42, 0.1, 0.1), bevel=0.04)
    for x in (-0.12, 0.12):
        cone(m["white"], (x, -0.5, -0.1), 0.035, 0.08, rot=(math.radians(180), 0, 0), vertices=6)
    # Un casque de mineur avec sa bougie.
    ball(m["iron"], (0, 0.02, 0.42), 0.45, scale=(1.05, 1.0, 0.55))
    box(m["iron"], (0, -0.3, 0.32), (0.75, 0.25, 0.04), bevel=0.02)
    cyl(m["white"], (0, -0.2, 0.68), 0.05, 0.14, bevel=0.0)
    cone(m["fire"], (0, -0.2, 0.82), 0.04, 0.12)


def heart(m):
    for a in range(4):
        x, y = math.cos(math.radians(45 + a * 90)), math.sin(math.radians(45 + a * 90))
        tube(m["gold"], [(x * 0.3, y * 0.2, -0.55), (x * 0.5, y * 0.35, -0.1), (x * 0.38, y * 0.28, 0.35)],
             [0.05, 0.045, 0.0])
    ring(m["gold"], (0, 0, -0.55), 0.35, 0.06)
    cyl(m["stone_dark"], (0, 0, -0.62), 0.42, 0.1, bevel=0.03)
    ball(mat("heart_gem", "d50000", rough=0.05, emission=0.9, coat=1.0), (0, 0, 0.12), 0.5, scale=(0.85, 0.7, 1.15),
         subdiv=1, flat=True)


def hourglass(m):
    for z in (-0.6, 0.85):
        cyl(m["wood"], (0, 0, z), 0.52, 0.1, bevel=0.03)
    for a in (90, 210, 330):
        x, y = math.cos(math.radians(a)) * 0.45, math.sin(math.radians(a)) * 0.45
        cyl(m["wood_dark"], (x, y, 0.125), 0.035, 1.35, bevel=0.0)
    lathe(m["glass"], [(-0.55, 0.38), (-0.3, 0.37), (0.05, 0.06), (0.12, 0.05), (0.2, 0.06), (0.55, 0.37), (0.8, 0.38)])
    cyl(m["sand"], (0, 0, -0.42), 0.34, 0.22, radius2=0.04, bevel=0.0)
    cyl(m["sand"], (0, 0, 0.36), 0.08, 0.16, radius2=0.28, bevel=0.0)
    cyl(m["sand"], (0, 0, -0.1), 0.012, 0.45, bevel=0.0, vertices=8)


def pause(m):
    for x in (-0.27, 0.27):
        box(m["steel"], (x, 0, 0.18), (0.32, 0.3, 1.25), bevel=0.08)
        for z in (-0.3, 0.66):
            ball(m["gold"], (x, -0.16, z), 0.045)


def demon(m):
    """L'emblème du maître : le visage du Seigneur (tools/blender/lord.py), en buste."""
    import lord
    scene = lord.build()
    for name in ("lid_l", "lid_r"):
        bpy.data.objects[name].scale = (1, 1, 0.05)
    head = bpy.data.objects["head"]
    head.scale = (0.78, 0.78, 0.78)
    head.location = (0, 0, 0.05)
    _setup(scene)
    return scene


ICONS = {
    "pickaxe": pickaxe, "hand": hand, "hammer": hammer, "dagger": dagger,
    "chest": chest, "bed": bed, "mushroom": mushroom, "bookshelf": bookshelf, "anvil": anvil,
    "dummy": dummy, "cage": cage, "temple": temple, "tomb": tomb,
    "spikes": spikes, "rune": rune, "door": door, "sacrifice_altar": sacrifice_altar, "brazier": brazier,
    "heal": heal, "bolt": bolt, "haste": haste, "mana": mana, "blood": blood, "gold": gold,
    "skull": skull, "demon": demon, "worker": worker, "heart": heart, "hourglass": hourglass, "pause": pause,
}


def build(name):
    """Construit une icône dans sa scène (sans la rendre) : pour la regarder dans Blender."""
    global _SCENE
    if name == "demon":
        _SCENE = demon(None)
        _SCENE.name = "lord"
        m = _palette()
        pebble(m)
        return _SCENE
    _SCENE = _new_scene()
    m = _palette()
    ICONS[name](m)
    pebble(m)
    return _SCENE


def render_one(name, out):
    os.makedirs(out, exist_ok=True)
    scene = build(name)
    _render(scene, os.path.join(out, name + ".png"))


def render_all(out):
    for name in ICONS:
        render_one(name, out)


if __name__ == "__main__":
    import sys
    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)
    render_all(os.path.join(os.path.dirname(os.path.dirname(here)), "assets", "icons_hd"))
