"""Les ICÔNES HD de l'interface, modélisées en 3D dans Blender (assets/icons_hd/<nom>.png).

Remplace les dessins 2D de tools/icons_hd.py. Chaque icône est un petit objet en
3D (formes lisses, biseautées, métal et or qui brillent, magie qui luit), cadré
au plus près pour remplir la case, éclairé comme sur la photo de référence :
lumière chaude en haut à gauche, contre-jour rouge derrière, braise par en dessous. Un contour sombre
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
LINE = 3.4           # Épaisseur du contour (pixels de l'image).
THIN_LINES = {"pincers": 2.4, "web": 1.3, "cage": 1.6, "rune": 1.6, "bookshelf": 2.0, "recall": 2.2, "rally_flag": 2.4}  # Contour plus fin : objets ajourés.
MARGIN = 1.1         # Le cadrage serré : l'objet remplit la case, avec 10 % de marge.


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
    background.inputs["Color"].default_value = (0.8, 0.7, 0.64, 1.0)  # Ce que reflètent les métaux.
    background.inputs["Strength"].default_value = 1.1
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

    sun("icon_key", 6.5, (1.0, 0.86, 0.68), (50, -35, -30))     # Chaude, en haut à gauche.
    sun("icon_rim", 4.5, (1.0, 0.3, 0.15), (-60, 30, 160))     # Contre-jour rouge : détache la silhouette.
    sun("icon_ember", 1.2, (1.0, 0.45, 0.15), (-110, 0, 10))   # Braise, par en dessous.


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
        "wood": mat("wood", "7a3a22", rough=0.7, bump=0.25, scale=4.0),
        "wood_dark": mat("wood_dark", "5a3418", rough=0.75, bump=0.25, scale=4.0),
        "steel": mat("steel", "d8d2ca", metal=1.0, rough=0.22),
        "iron": mat("iron", "5a5450", metal=0.9, rough=0.45),
        "iron_dark": mat("iron_dark", "2e2a28", metal=0.85, rough=0.5),
        "gold": mat("gold", "ffcc4a", metal=1.0, rough=0.28, emission=0.3),
        "leather": mat("leather", "5c3a22", rough=0.6, bump=0.15, scale=30.0),
        "bone": mat("bone", "efe6d2", rough=0.55, bump=0.1, scale=12.0),
        "dark": mat("dark", "120807", rough=0.8),
        "red": mat("red", "c62020", rough=0.35, coat=0.8),
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
        "glow_blue": mat("glow_blue", "40c4ff", emission=3.0),
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
    iron = m["iron"]
    cyl(iron, (0, 0, -0.55), 0.6, 0.12, bevel=0.03)
    ring(iron, (0, 0, 0.45), 0.57, 0.04)
    ring(iron, (0, 0, -0.05), 0.57, 0.03)
    for i in range(12):
        a = 2 * math.pi * i / 12
        x, y = math.cos(a) * 0.57, math.sin(a) * 0.57
        cyl(m["steel"], (x, y, -0.05), 0.04, 1.0, bevel=0.0, vertices=12)
        if i % 2 == 0:
            tube(m["steel"], [(x, y, 0.45), (x * 0.7, y * 0.7, 0.75), (0, 0, 0.88)], [0.035, 0.035, 0.035])
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
    cyl(m["stone"], (0, 0, 0), 0.82, 0.14, rot=(math.radians(90), 0, 0), bevel=0.04, parent=g)
    ring(m["glow_orange"], (0, -0.08, 0), 0.68, 0.035, rot=(math.radians(90), 0, 0), parent=g)
    ring(m["fire"], (0, -0.08, 0), 0.45, 0.02, rot=(math.radians(90), 0, 0), parent=g)
    star = [(math.cos(math.radians(90 + i * 144)) * 0.62, -0.085, math.sin(math.radians(90 + i * 144)) * 0.62)
            for i in range(6)]
    for a, b in zip(star, star[1:]):
        tube(m["fire_core"], [a, b], [0.035, 0.035], parent=g)
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
    cyan = mat("haste", "ff9100", rough=0.2, emission=1.5)
    for dz, dx in ((0.55, 0.15), (0.12, 0.3), (-0.31, 0.15)):
        plate(cyan, [(x + dx, z + dz) for x, z in arrow], 0.14, bevel=0.03)
        for k in range(2):
            box(mat("haste_trail", "ffd180", emission=1.0), (-0.72 + dx - k * 0.18, 0, dz), (0.1 - k * 0.03, 0.06, 0.05),
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


# --- Les nouveaux sorts (spells.gd) ---------------------------------------------

def web(m):
    silk = mat("silk", "f5f5ff", rough=0.3, emission=1.6)
    center = (0.0, 0.0, 0.22)
    spokes = 8
    for k in range(spokes):
        a = math.radians(k * 360 / spokes + 10)
        tube(silk, [center, (math.cos(a) * 0.82, 0, center[2] + math.sin(a) * 0.8)], [0.05, 0.04])
    for r in (0.22, 0.42, 0.62, 0.8):
        pts = []
        for k in range(spokes + 1):
            a = math.radians(k * 360 / spokes + 10)
            sag = 0.88 if k % 2 else 1.0
            pts.append((math.cos(a) * r * sag, -0.01, center[2] + math.sin(a) * r * sag))
        tube(silk, pts, [0.04] * len(pts), resolution=6)
    # Une araignée au centre, et une goutte de rosée magique.
    ball(m["dark"], (0.18, -0.08, 0.38), 0.13, scale=(1, 0.8, 1.1))
    ball(m["dark"], (0.18, -0.12, 0.2), 0.09)
    for side in (-1, 1):
        for k in range(3):
            tube(m["dark"], [(0.18, -0.1, 0.32 - k * 0.06), (0.18 + side * 0.18, -0.12, 0.38 - k * 0.08),
                             (0.18 + side * 0.28, -0.12, 0.22 - k * 0.1)], [0.025, 0.02, 0.0])
    ball(m["eye"], (0.14, -0.2, 0.22), 0.025)
    ball(m["eye"], (0.22, -0.2, 0.22), 0.025)
    ball(m["glow_purple"], (-0.45, -0.05, -0.1), 0.06)


def firestorm(m):
    ball(m["ember"], (0, 0.05, -0.5), 0.8, scale=(1, 0.5, 0.12))
    flames = [(0, 0.0, 1.05, 0.34, "fire_red"), (-0.45, 0.05, 0.75, 0.25, "fire_red"),
              (0.45, 0.05, 0.8, 0.26, "fire_red"), (-0.22, -0.12, 0.6, 0.2, "fire"),
              (0.25, -0.12, 0.65, 0.2, "fire"), (-0.68, -0.05, 0.45, 0.16, "fire"),
              (0.7, -0.05, 0.42, 0.15, "fire"), (0.0, -0.22, 0.45, 0.16, "fire_core")]
    for x, y, h, r, mt in flames:
        cone(m[mt], (x, y, -0.48 + h / 2), r, h, vertices=10)
    for x, z in [(-0.5, 0.55), (0.35, 0.8), (0.65, 0.4), (-0.15, 0.95)]:
        ball(m["glow_orange"], (x, -0.25, z), 0.04)


def terror(m):
    ghost = mat("ghost", "b39ddb", rough=0.4, emission=0.9, alpha=0.85)
    ball(ghost, (0, 0, 0.42), 0.5, scale=(0.9, 0.75, 1.0))
    lathe(ghost, [(-0.55, 0.0), (-0.45, 0.25), (-0.2, 0.38), (0.15, 0.44), (0.4, 0.42)], (0, 0, 0))
    for x in (-0.3, -0.1, 0.1, 0.3):
        cone(ghost, (x, 0, -0.6), 0.1, 0.22, rot=(math.radians(180), 0, 0), vertices=8)
    for x in (-0.18, 0.18):
        ball(m["dark"], (x, -0.33, 0.55), 0.11, scale=(0.9, 0.5, 1.3), rot=(0, x * 1.2, 0))
        ball(m["glow_purple"], (x, -0.4, 0.53), 0.03)
    ball(m["dark"], (0, -0.33, 0.18), 0.13, scale=(0.8, 0.5, 1.5))
    for side in (-1, 1):
        tube(ghost, [(side * 0.38, -0.05, 0.25), (side * 0.7, -0.1, 0.45), (side * 0.85, -0.12, 0.75)],
             [0.1, 0.07, 0.02])


def collapse(m):
    box(m["stone_dark"], (0, 0.1, 0.95), (1.7, 0.4, 0.18), bevel=0.04)
    for x, z in [(-0.6, 0.82), (0.1, 0.8), (0.55, 0.83)]:
        cone(m["stone_dark"], (x, 0.0, z - 0.08), 0.08, 0.2, rot=(math.radians(180), 0, 0), vertices=6)
    rocks = [(-0.35, 0.45, 0.22), (0.3, 0.2, 0.18), (-0.05, -0.05, 0.14), (0.6, 0.55, 0.11),
             (-0.65, 0.1, 0.12), (-0.3, -0.45, 0.25), (0.25, -0.5, 0.28), (0.7, -0.52, 0.16),
             (-0.7, -0.5, 0.15)]
    for k, (x, z, r) in enumerate(rocks):
        ball(m["stone_light"] if k % 3 == 0 else m["stone"], (x, -0.05, z), r, subdiv=1, flat=True,
             rot=(k * 0.7, k * 1.3, k * 0.4))
    dust = mat("dust", "bcaaa4", rough=1.0, alpha=0.5)
    for x, z in [(-0.5, -0.3), (0.5, -0.35), (0.0, -0.3)]:
        ball(dust, (x, 0.15, z), 0.22, scale=(1.4, 0.6, 0.7))


def possession(m):
    box(m["wood"], (0, 0, 0.95), (1.2, 0.12, 0.12), bevel=0.03)
    box(m["wood"], (0, 0, 0.95), (0.12, 0.7, 0.12), bevel=0.03)
    string = mat("string", "fff3e0", rough=0.6, emission=0.3)
    soul = mat("soul", "ff1744", rough=0.1, emission=2.5, coat=1.0)
    ball(soul, (0, -0.05, -0.05), 0.32, subdiv=2, flat=True)
    ball(m["dark"], (0, -0.3, -0.03), 0.1, scale=(0.5, 0.4, 1.2))
    for x in (-0.55, 0.0, 0.55):
        tube(string, [(x, 0, 0.9), ((x * 0.4), -0.05, 0.3), (x * 0.3, -0.05, 0.22)], [0.012, 0.012, 0.012])
    for x, z in [(-0.5, -0.4), (0.55, -0.3), (0.35, 0.35)]:
        ball(m["glow_orange"], (x, -0.2, z), 0.035)


def whip(m):
    cyl(m["leather"], (-0.45, 0, -0.35), 0.09, 0.6, rot=(0, math.radians(-35), 0), bevel=0.02)
    ring(m["gold"], (-0.62, 0, -0.6), 0.1, 0.03, rot=(0, math.radians(-35) + math.pi / 2, 0))
    ring(m["gold"], (-0.28, 0, -0.1), 0.1, 0.03, rot=(0, math.radians(-35) + math.pi / 2, 0))
    lash = mat("lash", "6d4c41", rough=0.5)
    tube(lash, [(-0.25, 0, -0.08), (0.1, -0.05, 0.5), (0.6, -0.05, 0.85), (0.85, -0.05, 0.4),
                (0.55, -0.05, 0.1), (0.75, -0.05, -0.25)], [0.07, 0.06, 0.05, 0.035, 0.02, 0.0])
    for x, z in [(0.85, -0.3), (0.7, -0.4), (0.92, -0.15)]:
        ball(m["glow_orange"], (x, -0.15, z), 0.035)


def _drumstick(m, x, angle):
    stick = group((x, 0, -0.05), rotation_y=angle)
    meat = mat("meat", "a0522d", rough=0.45, coat=0.5)
    ball(meat, (0, 0, 0.32), 0.3, scale=(0.85, 0.8, 1.2), parent=stick)
    cyl(m["bone"], (0, 0, -0.25), 0.07, 0.5, bevel=0.02, parent=stick)
    for dx in (-0.07, 0.07):
        ball(m["bone"], (dx, 0, -0.52), 0.08, parent=stick)


def feast(m):
    _drumstick(m, -0.42, math.radians(-30))
    _drumstick(m, 0.42, math.radians(30))
    cap = mat("cap", "c62828", rough=0.5)
    ball(cap, (0, -0.3, -0.35), 0.22, scale=(1, 1, 0.55))
    cyl(m["cloth_beige"], (0, -0.3, -0.5), 0.08, 0.2, bevel=0.02)
    for x, z in [(-0.06, -0.28), (0.08, -0.32)]:
        ball(m["white"], (x, -0.5, z), 0.035)


def eye(m):
    ball(m["white"], (0, 0, 0.2), 0.6, scale=(1.25, 0.5, 0.75))
    iris = mat("iris", "ff8f00", rough=0.15, emission=2.2, coat=1.0)
    ball(iris, (0, -0.2, 0.2), 0.36, scale=(1, 0.35, 1))
    ball(m["dark"], (0, -0.32, 0.2), 0.13, scale=(0.3, 0.3, 2.2))
    lid = m["skin_red"]
    tube(lid, [(-0.82, -0.05, 0.2), (0, -0.25, 0.68), (0.82, -0.05, 0.2)], [0.06, 0.09, 0.06])
    tube(lid, [(-0.82, -0.05, 0.2), (0, -0.22, -0.22), (0.82, -0.05, 0.2)], [0.06, 0.08, 0.06])
    for k in range(5):
        a = math.radians(30 + k * 30)
        tube(m["dark"], [(math.cos(a) * 0.55, -0.2, 0.2 + math.sin(a) * 0.5),
                         (math.cos(a) * 0.72, -0.2, 0.2 + math.sin(a) * 0.68)], [0.025, 0.0])


def summon(m):
    ghost = dict(m)
    ghost["imp"] = mat("ghost_imp", "69f0ae", rough=0.4, emission=1.0, alpha=0.75)
    ghost["imp_dark"] = mat("ghost_imp_dark", "1b5e20", rough=0.5, emission=0.4, alpha=0.8)
    ghost["iron"] = mat("ghost_iron", "a5d6a7", metal=0.6, rough=0.4, alpha=0.8)
    worker(ghost)
    for k in range(3):
        a = math.radians(200 + k * 50)
        ball(m["glow_green"], (math.cos(a) * 0.8, -0.2, -0.35 + k * 0.05), 0.05)


def transmute(m):
    blue = mat("drop_2979ff", "2979ff", rough=0.05, emission=0.8, coat=1.0)
    drop = [(-0.58, 0.0), (-0.55, 0.16), (-0.42, 0.3), (-0.2, 0.35), (0.05, 0.3), (0.3, 0.2), (0.55, 0.1),
            (0.8, 0.0)]
    lathe(blue, drop, (-0.5, 0, 0.3))
    arrow = [(-0.25, 0.04), (0.1, 0.04), (0.1, 0.13), (0.3, 0.0), (0.1, -0.13), (0.1, -0.04), (-0.25, -0.04)]
    plate(m["glow_orange"], [(x, z + 0.25) for x, z in arrow], 0.08, bevel=0.015)
    coin = group((0.5, -0.05, 0.15))
    coin.rotation_euler = (math.radians(80), 0.25, 0)
    cyl(m["gold"], (0, 0, 0), 0.38, 0.09, bevel=0.025, parent=coin)
    ring(m["gold"], (0, 0, 0.05), 0.28, 0.025, parent=coin)
    for k in range(3):
        cyl(m["gold"], (0.5 + (k % 2) * 0.03, 0.1, -0.55 + k * 0.08), 0.28, 0.07, bevel=0.02)


def raise_dead(m):
    ball(m["earth"], (0, 0.05, -0.45), 0.75, scale=(1, 0.6, 0.35))
    bone = m["bone"]
    tube(bone, [(0.05, 0, -0.5), (0.02, 0, -0.1), (0.0, 0, 0.15)], [0.09, 0.08, 0.07])
    box(bone, (0, -0.02, 0.28), (0.34, 0.12, 0.26), bevel=0.05)
    for k, x in enumerate((-0.13, -0.04, 0.05, 0.14)):
        h = (0.38, 0.46, 0.44, 0.34)[k]
        tube(bone, [(x, -0.02, 0.4), (x * 1.2, -0.05, 0.4 + h * 0.55), (x * 1.3, -0.1, 0.4 + h)],
             [0.035, 0.03, 0.022])
    tube(bone, [(0.17, -0.02, 0.25), (0.32, -0.05, 0.38), (0.38, -0.1, 0.5)], [0.035, 0.03, 0.022])
    for x, z in [(-0.5, -0.1), (0.5, 0.1), (-0.3, 0.55), (0.35, 0.7)]:
        ball(m["glow_green"], (x, -0.25, z), 0.045)


def convert(m):
    for side in (-1, 1):
        link = group((side * 0.38, 0, 0.18 - side * 0.12))
        link.rotation_euler = (0, side * 0.6, 0)
        ring(m["steel"], (0, 0, 0), 0.28, 0.08, rot=(math.radians(90), 0, 0), parent=link)
        ring(m["steel"], (side * 0.42, 0, 0), 0.22, 0.07, rot=(0, math.radians(90), 0), parent=link)
    for x, z in [(0, 0.15), (-0.08, 0.35), (0.1, -0.05), (0.02, 0.6)]:
        ball(m["glow_purple"], (x, -0.25, z), 0.05)
    ball(m["glow_purple"], (0, -0.1, 0.18), 0.12)


def sanctuary(m):
    shield = [(-0.55, 0.85), (0.55, 0.85), (0.6, 0.3), (0.45, -0.15), (0.0, -0.55), (-0.45, -0.15), (-0.6, 0.3)]
    plate(mat("shield", "5e35b1", rough=0.35, metal=0.3, emission=0.3), shield, 0.18, bevel=0.05)
    plate(m["gold"], [(x * 0.82, 0.2 + (z - 0.2) * 0.82) for x, z in shield], 0.2, y=0.0, bevel=0.02)
    plate(mat("shield_inner", "7e57c2", rough=0.35, emission=0.5),
          [(x * 0.7, 0.2 + (z - 0.2) * 0.7) for x, z in shield], 0.24, bevel=0.02)
    star = []
    for k in range(10):
        a = math.radians(90 + k * 36)
        r = 0.3 if k % 2 == 0 else 0.13
        star.append((math.cos(a) * r, 0.25 + math.sin(a) * r))
    plate(mat("star", "fff59d", emission=3.0), star, 0.3, bevel=0.01)


def recall(m):
    red = mat("recall", "ff1744", emission=2.0)
    pts = []
    for k in range(40):
        t = k / 39.0
        a = t * math.pi * 3.2
        r = 0.78 * (1.0 - t) + 0.08
        pts.append((math.cos(a) * r, -0.02, 0.2 + math.sin(a) * r * 0.85))
    tube(red, pts, [0.06 * (1.0 - k / 39.0) + 0.015 for k in range(40)], resolution=4)
    ball(mat("heart_gem", "d50000", rough=0.05, emission=0.9, coat=1.0), (0, -0.05, 0.2), 0.2,
         scale=(0.85, 0.7, 1.15), subdiv=1, flat=True)



# --- Les icônes de la colonne de gauche et du journal (comme sur la photo) -----

def tools(m):
    """Actions : le marteau et la pioche croisés, manches laqués de rouge."""
    pick = group((0.02, 0.0, 0.16), rotation_y=0.72, scale=0.95)
    cyl(m["red"], (0, 0, -0.1), 0.1, 1.6, parent=pick)
    cyl(m["iron_dark"], (0, 0, -0.66), 0.115, 0.28, parent=pick, bevel=0.01)
    tube(m["steel"], [(-0.78, 0, 0.5), (-0.4, 0, 0.72), (0, 0, 0.8), (0.4, 0, 0.72), (0.78, 0, 0.5)],
         [0.0, 0.08, 0.13, 0.08, 0.0], parent=pick)
    box(m["iron"], (0, 0, 0.74), (0.22, 0.22, 0.28), bevel=0.04, parent=pick)
    ham = group((-0.02, -0.12, 0.16), rotation_y=-0.72, scale=0.95)
    cyl(m["red"], (0, 0, -0.1), 0.1, 1.5, parent=ham)
    cyl(m["iron_dark"], (0, 0, -0.62), 0.115, 0.28, parent=ham, bevel=0.01)
    box(m["iron"], (0, 0, 0.72), (0.9, 0.38, 0.38), bevel=0.06, parent=ham)
    for x in (-0.47, 0.47):
        box(m["steel"], (x, 0, 0.72), (0.09, 0.44, 0.44), bevel=0.03, parent=ham)
    ball(m["gold"], (0, -0.22, 0.72), 0.07, parent=ham)


def arch(m):
    """Salles : une arche de pierre taillée, l'intérieur rougeoie (une salle du donjon)."""
    r_out, r_in, base, top = 0.85, 0.52, -0.7, 0.2
    steps = 9
    for k in range(steps):  # Les claveaux de la voûte.
        a0, a1 = math.pi * k / steps, math.pi * (k + 1) / steps
        pts = [(math.cos(a0) * r_in, top + math.sin(a0) * r_in), (math.cos(a0) * r_out, top + math.sin(a0) * r_out),
               (math.cos(a1) * r_out, top + math.sin(a1) * r_out), (math.cos(a1) * r_in, top + math.sin(a1) * r_in)]
        plate(m["stone_light"] if k % 2 else m["stone"], pts, 0.3, y=0.05, bevel=0.025)
    for x in (-1, 1):  # Les piédroits.
        for j in range(3):
            z0 = base + j * 0.3
            box(m["stone"] if (j + (x > 0)) % 2 else m["stone_light"], (x * (r_in + r_out) / 2, 0.05, z0 + 0.15),
                (r_out - r_in - 0.02, 0.3, 0.28), bevel=0.025)
    box(m["stone_dark"], (0, 0.05, base - 0.06), (2 * r_out + 0.1, 0.36, 0.12), bevel=0.03)
    inside = [(-r_in, base), (r_in, base), (r_in, top)]
    inside += [(math.cos(math.pi * k / 16) * r_in, top + math.sin(math.pi * k / 16) * r_in) for k in range(1, 16)]
    inside += [(-r_in, top)]
    plate(mat("arch_glow", "ff3d00", emission=2.2), inside, 0.05, y=0.2, bevel=0.0)
    plate(m["dark"], [(x * 0.8, base + (z - base) * 0.85) for x, z in inside], 0.05, y=0.17, bevel=0.0)
    box(m["gold"], (0, -0.12, top + r_out - 0.08), (0.16, 0.08, 0.2), bevel=0.03)  # La clé de voûte.


def trident(m):
    """Défenses : le trident rouge du maître, collier d'or."""
    red_metal = mat("trident", "d50000", metal=0.6, rough=0.3, coat=0.8)
    cyl(m["iron_dark"], (0, 0, -0.35), 0.1, 1.0)
    ball(m["gold"], (0, 0, -0.88), 0.14)
    cyl(m["gold"], (0, 0, 0.16), 0.15, 0.16, bevel=0.03)
    # La traverse courbe qui porte les trois pointes.
    tube(red_metal, [(-0.5, 0, 0.6), (-0.46, 0, 0.32), (-0.28, 0, 0.22), (0, 0, 0.2), (0.28, 0, 0.22),
                     (0.46, 0, 0.32), (0.5, 0, 0.6)], [0.1, 0.11, 0.12, 0.13, 0.12, 0.11, 0.1], caps=True)
    cyl(red_metal, (0, 0, 0.5), 0.12, 0.6, bevel=0.02)
    for x, z, h in ((-0.5, 0.58, 0.36), (0.0, 0.78, 0.42), (0.5, 0.58, 0.36)):
        plate(red_metal, [(x - 0.2, z), (x - 0.08, z - 0.08), (x + 0.08, z - 0.08), (x + 0.2, z), (x, z + h)], 0.16,
              bevel=0.03)


def scroll(m):
    """Le codex : un parchemin déroulé, sceau de cire rouge."""
    paper = mat("parchment", "e8d3a2", rough=0.8, bump=0.15, scale=12.0)
    plate(paper, [(-0.55, 0.62), (0.55, 0.62), (0.6, 0.0), (0.55, -0.62), (-0.55, -0.62), (-0.5, 0.0)], 0.04,
          bevel=0.01)
    for z in (0.66, -0.66):
        cyl(m["wood"], (0, 0, z), 0.11, 1.3, rot=(0, math.radians(90), 0), bevel=0.02)
        for x in (-0.72, 0.72):
            ball(m["gold"], (x, 0, z), 0.1)
    ink = mat("ink", "4e2a1a", rough=0.6)
    for k, z in enumerate((0.35, 0.18, 0.01, -0.16)):
        box(ink, (-0.08 + (k % 2) * 0.05, -0.03, z), (0.7 - (k % 2) * 0.2, 0.01, 0.045), bevel=0.0)
    cyl(m["red"], (0.28, -0.06, -0.38), 0.17, 0.06, rot=(math.radians(90), 0, 0), bevel=0.02)
    ball(m["blood"], (0.28, -0.1, -0.38), 0.07, scale=(1, 0.5, 1))


def _arrow(m, up):
    sign = 1 if up else -1
    tri = [(-0.62, -0.42 * sign), (0.62, -0.42 * sign), (0.0, 0.62 * sign)]
    plate(m["gold"], [(x * 1.12, z * 1.12 + 0.02 * sign) for x, z in tri], 0.12, y=0.05, bevel=0.03)
    plate(mat("arrow_red", "e53935", rough=0.25, coat=1.0, emission=0.35), tri, 0.2, y=-0.02, bevel=0.05)


def arrow_up(m):
    _arrow(m, True)


def arrow_down(m):
    _arrow(m, False)


# ---------------------------------------------------------------------------
# Les antres (règles 2.7)
# ---------------------------------------------------------------------------

def mug(m):
    """Taverne : une grosse chope de bois cerclée de fer, mousse qui déborde."""
    cyl(m["wood"], (0, 0, -0.15), 0.42, 0.95, bevel=0.04)
    for z in (-0.5, 0.2):
        cyl(m["iron"], (0, 0, z), 0.44, 0.08, bevel=0.01)
    tube(m["wood_dark"], [(0.4, 0, 0.15), (0.72, 0, 0.1), (0.75, 0, -0.25), (0.4, 0, -0.35)], [0.08, 0.08, 0.08, 0.08])
    for x, z, r in ((0, 0.38, 0.4), (-0.25, 0.42, 0.22), (0.22, 0.45, 0.22), (0.05, 0.6, 0.2)):
        ball(m["white"], (x, -0.02, z), r, scale=(1, 1, 0.7))
    ball(m["white"], (-0.35, -0.3, 0.12), 0.1, scale=(0.8, 0.8, 1.6))


def salve(m):
    """Infirmerie : un pot d'onguent vert et un rouleau de bandage taché de sang."""
    cyl(m["stone_light"], (-0.15, 0, -0.25), 0.42, 0.7, radius2=0.36, bevel=0.04)
    cyl(m["glow_green"], (-0.15, 0, 0.12), 0.36, 0.06, bevel=0.0)
    ball(m["glow_green"], (-0.15, 0, 0.17), 0.2, scale=(1, 1, 0.5))
    cyl(m["leather"], (-0.15, 0, 0.12), 0.42, 0.06, bevel=0.01, radius2=0.4)
    cyl(m["cloth_beige"], (0.48, -0.25, -0.38), 0.28, 0.45, rot=(math.radians(90), 0, math.radians(20)), bevel=0.03)
    ball(m["blood"], (0.5, -0.5, -0.3), 0.09, scale=(1, 0.3, 1))
    box(m["cloth_beige"], (0.3, -0.5, -0.62), (0.5, 0.2, 0.04), rot=(0, 0, math.radians(20)), bevel=0.01)


def coin_press(m):
    """Hôtel des monnaies : une pile de pièces frappées au trident, et un marteau de frappe."""
    for k in range(6):
        cyl(m["gold"], (-0.15 + 0.02 * (k % 2), 0, -0.6 + k * 0.13), 0.42, 0.11, bevel=0.02)
    cyl(m["gold"], (0.45, -0.1, -0.15), 0.36, 0.1, rot=(math.radians(70), 0, math.radians(-20)), bevel=0.02)
    box(m["red"], (0.45, -0.17, -0.15), (0.06, 0.02, 0.32), rot=(math.radians(-20), 0, math.radians(-20)), bevel=0.0)
    hammer = group((-0.1, -0.1, 0.45), rotation_y=math.radians(-35))
    box(m["iron"], (0, 0, 0.0), (0.55, 0.28, 0.28), bevel=0.04, parent=hammer)
    cyl(m["wood"], (0.0, 0, -0.45), 0.06, 0.8, bevel=0.01, parent=hammer)


def pincers(m):
    """Chambre de torture : des tenailles rougies au feu."""
    for side in (-1, 1):
        tube(m["iron_dark"], [(0.1 * side, 0, -0.7), (0.15 * side, 0, -0.1), (-0.05 * side, 0, 0.35),
                              (-0.18 * side, 0, 0.75)], [0.07, 0.07, 0.06, 0.05])
    ball(m["iron"], (0, -0.02, 0.0), 0.11)
    for side in (-1, 1):
        cone(m["glow_orange"], (-0.2 * side, 0, 0.85), 0.07, 0.25)
    ball(m["blood"], (0.35, -0.1, -0.5), 0.08)
    ball(m["blood"], (0.38, -0.1, -0.65), 0.05)


def watch_horn(m):
    """Poste de garde : le cor d'alarme recourbé, embouchure et pavillon d'or."""
    tube(m["bone"], [(-0.75, 0, -0.35), (-0.4, 0, -0.45), (0.0, 0, -0.3), (0.35, 0, 0.05), (0.55, 0, 0.45)],
         [0.06, 0.1, 0.16, 0.24, 0.34])
    ring(m["gold"], (0.55, 0, 0.45), 0.34, 0.06, rot=(0, math.radians(-35), 0))
    ring(m["gold"], (-0.05, 0, -0.32), 0.17, 0.04, rot=(0, math.radians(70), 0))
    cyl(m["gold"], (-0.78, 0, -0.34), 0.07, 0.12, rot=(0, math.radians(80), 0), bevel=0.01)
    tube(m["leather"], [(-0.4, 0, -0.45), (-0.2, 0, -0.75), (0.2, 0, -0.65), (0.35, 0, 0.05)], [0.03] * 4)


def rally_flag(m):
    """Poste de défense (règles 2.9) : l'étendard de guerre du maître, planté dans un socle de
    pierre. Hampe de fer noir à pointe d'or, bannière rouge à queue d'aronde, trident d'or."""
    cloth = mat("rally_cloth", "c62020", rough=0.6, bump=0.15, scale=30.0, coat=0.3)
    # Le socle et la hampe, à gauche : la bannière flotte vers la droite.
    cyl(m["stone_light"], (-0.55, 0, -0.72), 0.3, 0.16, bevel=0.04, vertices=8)
    cyl(m["stone"], (-0.55, 0, -0.6), 0.19, 0.1, bevel=0.03, vertices=8)
    cyl(m["iron_dark"], (-0.55, 0, 0.22), 0.065, 1.62)
    for z in (0.93, -0.12):
        cyl(m["gold"], (-0.55, 0, z), 0.09, 0.07, bevel=0.02)
    ball(m["gold"], (-0.55, 0, 1.06), 0.09)
    plate(m["gold"], [(-0.66, 1.12), (-0.55, 1.08), (-0.44, 1.12), (-0.55, 1.42)], 0.1, bevel=0.02)
    # La bannière (un peu tournée : elle prend le vent).
    banner = group((0.0, -0.02, 0.0), rotation_y=math.radians(-4))
    plate(cloth, [(-0.5, 0.9), (0.72, 0.86), (0.44, 0.36), (0.72, -0.14), (-0.5, -0.1)], 0.07, bevel=0.015,
          parent=banner)
    plate(m["gold"], [(-0.5, 0.92), (0.73, 0.88), (0.69, 0.8), (-0.5, 0.82)], 0.09, bevel=0.01, parent=banner)
    # Le trident d'or, brodé d'une seule pièce (sa silhouette reste nette en petit).
    thread = mat("rally_thread", "ffd54f", metal=0.3, rough=0.35, emission=0.8)
    half = [(0.07, -0.36), (0.07, 0.03), (0.2, 0.07), (0.27, 0.18), (0.27, 0.3), (0.35, 0.3), (0.22, 0.56),
            (0.15, 0.3), (0.15, 0.17), (0.07, 0.15), (0.07, 0.34), (0.14, 0.34), (0.0, 0.62)]
    outline = half + [(-x, z) for x, z in reversed(half[:-1])]
    s = 0.82
    plate(thread, [(0.04 + x * s, 0.36 + z * s) for x, z in outline], 0.05, y=-0.045, bevel=0.008, parent=banner)


def mana_crystal(m):
    """Puits de mana : un grand cristal bleu qui flotte au-dessus d'une margelle runique."""
    lathe(m["glow_blue"], [(0.05, 0.0), (0.45, 0.32), (0.95, 0.0)], center=(0, 0, 0.0))
    cyl(m["stone"], (0, 0, -0.55), 0.7, 0.3, bevel=0.05)
    cyl(m["glow_blue"], (0, 0, -0.39), 0.55, 0.03, bevel=0.0)
    for k in range(5):
        a = math.radians(200 + k * 35)
        box(m["glow_blue"], (0.7 * math.cos(a), 0.7 * math.sin(a), -0.55), (0.1, 0.03, 0.12), rot=(0, 0, a + math.pi / 2),
            bevel=0.0)
    for x in (-0.55, 0.55):
        cone(m["glow_blue"], (x, 0, 0.15), 0.08, 0.3)


def sarcophagus(m):
    """Crypte : un sarcophage dressé, couvercle entrouvert, une âme violette qui s'échappe."""
    plate(m["stone_light"], [(-0.42, -0.75), (0.42, -0.75), (0.5, 0.55), (0.3, 0.9), (-0.3, 0.9), (-0.5, 0.55)],
          0.35, y=0.15, bevel=0.03)
    lid = group((0.0, -0.08, 0.0), rotation_y=math.radians(10))
    plate(m["stone"], [(-0.38, -0.7), (0.38, -0.7), (0.45, 0.5), (0.27, 0.82), (-0.27, 0.82), (-0.45, 0.5)],
          0.1, y=0.0, bevel=0.02, parent=lid)
    _skull(m, (0.0, -0.14, 0.5), 0.55)
    box(m["iron"], (0, -0.14, -0.15), (0.08, 0.04, 0.6), bevel=0.01)
    box(m["iron"], (0, -0.14, 0.05), (0.32, 0.04, 0.06), bevel=0.01)
    for x, z, r in ((0.58, 0.2, 0.14), (0.7, 0.5, 0.1), (0.62, 0.8, 0.07)):
        ball(m["glow_purple"], (x, -0.1, z), r)


ICONS = {
    "pickaxe": pickaxe, "hand": hand, "hammer": hammer, "dagger": dagger,
    "chest": chest, "bed": bed, "mushroom": mushroom, "bookshelf": bookshelf, "anvil": anvil,
    "dummy": dummy, "cage": cage, "temple": temple, "tomb": tomb,
    "spikes": spikes, "rune": rune, "door": door, "sacrifice_altar": sacrifice_altar, "brazier": brazier,
    "heal": heal, "bolt": bolt, "haste": haste, "mana": mana, "blood": blood, "gold": gold,
    "skull": skull, "demon": demon, "worker": worker, "heart": heart, "hourglass": hourglass, "pause": pause,
    "web": web, "firestorm": firestorm, "terror": terror, "collapse": collapse, "possession": possession,
    "whip": whip, "feast": feast, "eye": eye, "summon": summon, "transmute": transmute, "raise": raise_dead,
    "convert": convert, "sanctuary": sanctuary, "recall": recall,
    "tools": tools, "arch": arch, "trident": trident, "scroll": scroll,
    "arrow_up": arrow_up, "arrow_down": arrow_down,
    "mug": mug, "salve": salve, "coin_press": coin_press, "pincers": pincers, "watch_horn": watch_horn,
    "mana_crystal": mana_crystal, "sarcophagus": sarcophagus, "rally_flag": rally_flag,
}


def build(name):
    """Construit une icône dans sa scène (sans la rendre) : pour la regarder dans Blender.
    Plus de galet sous l'objet : il remplit la case, comme les icônes de la photo."""
    global _SCENE
    if name == "demon":
        _SCENE = demon(None)
        _SCENE.name = "lord"
    else:
        _SCENE = _new_scene()
        m = _palette()
        ICONS[name](m)
    line = THIN_LINES.get(name, LINE)
    _SCENE.render.line_thickness = line
    for lineset in _SCENE.view_layers[0].freestyle_settings.linesets:
        lineset.linestyle.thickness = line
    _fit(_SCENE)
    return _SCENE


def _fit(scene):
    """Cadre la caméra au plus près de l'objet (vu par la caméra), avec MARGIN de marge."""
    bpy.context.view_layer.update()
    cam = scene.camera
    to_cam = cam.matrix_world.inverted()
    xs, ys = [], []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in scene.objects:
        if obj.type not in ("MESH", "CURVE") or obj.hide_render or not obj.visible_get():
            continue
        evaluated = obj.evaluated_get(depsgraph)
        for corner in evaluated.bound_box:
            point = to_cam @ (obj.matrix_world @ Vector(corner))
            xs.append(point.x)
            ys.append(point.y)
    if not xs:
        return
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    cam.location = cam.matrix_world @ Vector((cx, cy, 0))
    cam.data.ortho_scale = max(max(xs) - min(xs), max(ys) - min(ys)) * MARGIN


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
