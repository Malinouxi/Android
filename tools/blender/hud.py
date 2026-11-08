"""Les cadres HD du HUD, modélisés dans Blender et rendus en images (assets/ui_hd/).

Une CAVERNE : bords en roche de basalte taillée à facettes, fissures de lave qui
rougeoient entre les roches, stalactites, grappes de cristaux dans les coins ; le
médaillon garde son fer riveté, entouré de rochers et de cristaux.

Images produites (fond transparent) :
    medallion.png            le médaillon du portrait du Seigneur (centre évidé)
    panel.png                le cadre des panneaux (découpé en 9 par le jeu)
    slot.png                 le creux des compteurs de la barre du haut (9 zones)
    button_<état>.png        les boutons : normal, hover, pressed, disabled (9 zones)
    bubble.png               la bulle de parole du Seigneur (9 zones)
    fringe.png               les stalactites sous la barre du haut (répétées en largeur)

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
SIZES = {"panel": 256, "slot": 128, "button": 128, "bubble": 128, "medallion": 512, "fringe": 256}
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
        "iron": _material("hud_iron", "3a3330", metal=0.85, rough=0.45, noise=0.15, bump=0.15, scale=30.0),
        "iron_dark": _material("hud_iron_dark", "1e1a19", metal=0.8, rough=0.5, bump=0.1, scale=30.0),
        "rivet": _material("hud_rivet", "8d6e63", metal=0.9, rough=0.3),
        "gold": _material("hud_gold", "d4a534", metal=1.0, rough=0.28),
        "ember": _material("hud_ember", "c2410c", emission=2.2),
        "blood": _material("hud_blood", "8b1a1a", rough=0.5),
        "gem": _material("hud_gem", "ff1744", rough=0.1, emission=1.5),
        "bone": _material("hud_bone", "d8ccb0", rough=0.6, noise=0.12, bump=0.1, scale=20.0),
        "wood": _material("hud_wood", "7a2e1c", rough=0.7, noise=0.2, bump=0.1, scale=6.0),
        # La caverne : basalte à facettes, fissures de lave, cristaux.
        "basalt": _material("hud_basalt", "4f423b", rough=0.8, noise=0.25, bump=0.3, scale=25.0),
        "basalt_light": _material("hud_basalt_light", "7a675c", rough=0.75, noise=0.25, bump=0.3, scale=25.0),
        "basalt_alt": _material("hud_basalt_alt", "655349", rough=0.75, noise=0.25, bump=0.3, scale=25.0),
        "basalt_dark_alt": _material("hud_basalt_dark_alt", "3d322e", rough=0.85, noise=0.2, bump=0.3, scale=25.0),
        "basalt_dark": _material("hud_basalt_dark", "2e2522", rough=0.85, noise=0.2, bump=0.3, scale=25.0),
        "gold_rock": _material("hud_gold_rock", "6b5222", metal=0.4, rough=0.5, noise=0.3, bump=0.3, scale=25.0),
        "lava": _material("hud_lava", "ff5a1f", emission=4.0),
        "lava_dim": _material("hud_lava_dim", "6e2a12", emission=0.5),
        "blood_seam": _material("hud_blood_seam", "8b1a1a", emission=1.2),
        "gold_seam": _material("hud_gold_seam", "ffc94a", emission=4.0),
        "crystal_red": _material("hud_crystal_red", "c2185b", rough=0.1, emission=0.9),
        "crystal_gold": _material("hud_crystal_gold", "ffd54a", rough=0.1, emission=2.0),
        # Les fonds : une couleur unie, insensible aux ombres (le jeu les répète).
        "cave_floor": _flat("hud_cave_floor", "15100f"),
        "cave_hole": _flat("hud_cave_hole", "0b0807"),
        "cave_slab": _flat("hud_cave_slab", "2c2321"),
        "cave_slab_light": _flat("hud_cave_slab_light", "3d302c"),
        "cave_slab_gold": _flat("hud_cave_slab_gold", "4a3218"),
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
# Cadres « caverne » : roche taillée, fissures de lave, stalactites, cristaux
# ---------------------------------------------------------------------------
#
# Chaque cadre est un carré de 1 x 1 (le rendu le cadre tout juste). La bande de
# roches de chaque bord se RÉPÈTE (le jeu la répète au lieu de l'étirer) : les
# roches du segment du milieu (de -0,25 à 0,25) sont recopiées à ±0,5, pour que
# le motif se raccorde sans couture. Les coins (0,25 x 0,25) portent les ornements.

def _rock(scene, mat, at, size, rng, squash=0.7, facets=1):
    """Un rocher à facettes (une icosphère cabossée), posé en « at »."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=facets, radius=1.0, location=(0, 0, 0))
    obj = bpy.context.active_object
    for v in obj.data.vertices:
        v.co *= 1.0 + rng.uniform(-0.22, 0.22)
    obj.scale = (size * rng.uniform(0.85, 1.25), size * rng.uniform(0.75, 1.1), size * squash)
    obj.rotation_euler = (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0, math.pi))
    obj.location = at
    obj.data.materials.append(mat)
    _relink(scene, obj)
    return obj


def _copy(scene, obj, offset):
    twin = obj.copy()  # Même maillage : les copies du motif sont identiques.
    twin.location = obj.location + Vector(offset)
    scene.collection.objects.link(twin)
    return twin


def _edge_band(scene, m, band, rock_mat, seam_mat, seed, rock_size, count, inset=0.02):
    """Les quatre bords : une bande de roches, une fissure lumineuse côté intérieur.
    Le motif est le même sur chaque bord, tourné, et périodique (période 0,5)."""
    rng = random.Random(seed)
    pattern = []
    for k in range(count):
        t = -0.25 + (k + rng.uniform(0.1, 0.9)) * 0.5 / count
        across = rng.uniform(0.2, 1.05) * band
        size = rock_size * rng.uniform(0.8, 1.4)
        pattern.append((t, across, size, rng.random() * 1e6))
    for edge in range(4):
        angle = edge * math.pi / 2  # 0 : haut, puis gauche, bas, droite (sens trigonométrique).
        rot = Matrix.Rotation(angle, 4, "Z")
        # La bande de fond (continue : pas de trou entre les roches).
        base = _box(scene, "band", m["basalt_dark"], (0, 0, 0), (1.0 - 2 * inset, band, 0.04), bevel=0.0)
        base.location = rot @ Vector((0, 0.5 - inset - band / 2, -0.02))
        base.rotation_euler = (0, 0, angle)
        if seam_mat:
            seam = _box(scene, "seam", m[seam_mat], (0, 0, 0), (1.0 - 2 * (inset + band), 0.03, 0.02), bevel=0.0)
            seam.location = rot @ Vector((0, 0.5 - inset - band - 0.008, -0.025))
            seam.rotation_euler = (0, 0, angle)
        for t, across, size, rock_seed in pattern:
            local = random.Random(rock_seed)
            shade = m[rock_mat] if local.random() < 0.65 else m.get(rock_mat + "_alt", m[rock_mat])
            rock = _rock(scene, shade, rot @ Vector((t, 0.5 - inset - across, 0.0)), size, local)
            rock.rotation_euler.z += angle
            for shift in (-0.5, 0.5):
                _copy(scene, rock, rot @ Vector((shift, 0, 0)))
            # Une petite braise entre deux roches, de temps en temps.
            if seam_mat and local.random() < 0.35:
                ember = _rock(scene, m[seam_mat], rot @ Vector((t + size * 0.9, 0.5 - inset - across, -0.01)),
                              size * 0.25, local, squash=0.5, facets=1)
                for shift in (-0.5, 0.5):
                    _copy(scene, ember, rot @ Vector((shift, 0, 0)))


def _stalactite(scene, mat, top, length, radius, rng, direction=(0, -1, 0)):
    """Une stalactite : un cône irrégulier qui pend depuis « top »."""
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=radius, radius2=0.0, depth=length)
    obj = bpy.context.active_object
    for v in obj.data.vertices:
        if v.co.z < length * 0.4:
            v.co.x *= 1.0 + rng.uniform(-0.25, 0.25)
            v.co.y *= 1.0 + rng.uniform(-0.25, 0.25)
    d = Vector(direction).normalized()
    obj.rotation_euler = Vector((0, 0, 1)).rotation_difference(d).to_euler()
    obj.rotation_euler.rotate_axis("Z", rng.uniform(0, 1))
    obj.location = Vector(top) + d * (length / 2)
    obj.data.materials.append(mat)
    _relink(scene, obj)
    return obj


def _crystals(scene, mat, base, rng, count=3, size=0.06, lean=0.0):
    """Une grappe de cristaux (prismes à six faces à pointe), qui luisent."""
    for k in range(count):
        h = size * rng.uniform(1.6, 2.6)
        r = size * rng.uniform(0.25, 0.4)
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=r, depth=h)
        prism = bpy.context.active_object
        bm = bmesh.new()
        bm.from_mesh(prism.data)
        cap = [f for f in bm.faces if f.normal.z > 0.9]
        bmesh.ops.poke(bm, faces=cap, offset=r * 1.2)
        bm.to_mesh(prism.data)
        bm.free()
        tilt = lean + (k - (count - 1) / 2) * 0.45 + rng.uniform(-0.15, 0.15)
        prism.rotation_euler = (math.radians(70), 0, tilt)
        prism.location = Vector(base) + Vector((math.sin(tilt) * h * 0.3, -math.cos(tilt) * h * 0.3, 0.03))
        prism.data.materials.append(mat)
        _relink(scene, prism)


def _corner_ornaments(scene, m, inset, band, rng, top_style, bottom_style, scale=1.0):
    """Les coins : gros rochers, et une stalactite (haut) ou des cristaux (bas)."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = Vector((sx * (0.5 - inset - band * 0.55), sy * (0.5 - inset - band * 0.55), 0.01))
            _rock(scene, m["basalt"], c, band * 0.75 * scale, rng, squash=0.8)
            _rock(scene, m["basalt_light"], c + Vector((-sx * band * 0.5, sy * band * 0.15, 0.02)), band * 0.45 * scale,
                  rng, squash=0.7)
            style = top_style if sy > 0 else bottom_style
            inward = Vector((-sx, -sy, 0)).normalized()
            if style == "stalactite":
                for k, (dx, length) in enumerate(((-0.45, 1.7), (-0.05, 1.1))):
                    _stalactite(scene, m["basalt_light"], c + Vector((sx * band * dx, -band * 0.3, 0.04 + k * 0.01)),
                                band * length * scale, band * 0.24 * scale, rng)
            elif style:
                _crystals(scene, m[style], c + inward * band * 0.5, rng, count=3, size=band * 0.5 * scale,
                          lean=math.atan2(-sx, sy) * 0.4)


def _plate(scene, m, inset, mat="cave_floor"):
    _box(scene, "plate", m[mat], (0, 0, -0.06), (1.0 - 2 * inset - 0.02, 1.0 - 2 * inset - 0.02, 0.04), bevel=0.0)


def render_panel(scene, m, out):
    _clear(scene)
    rng = random.Random(7)
    band = 0.12
    _plate(scene, m, 0.03)
    _edge_band(scene, m, band, "basalt", "lava", seed=11, rock_size=0.05, count=5)
    _corner_ornaments(scene, m, 0.02, band, rng, "stalactite", "crystal_red")
    _render(scene, os.path.join(out, "panel.png"), SIZES["panel"], 1.0)


def render_slot(scene, m, out):
    _clear(scene)
    rng = random.Random(3)
    _plate(scene, m, 0.03, mat="cave_hole")
    _edge_band(scene, m, 0.1, "basalt_dark", "blood_seam", seed=5, rock_size=0.05, count=4)
    _corner_ornaments(scene, m, 0.02, 0.1, rng, None, None, scale=0.8)
    _render(scene, os.path.join(out, "slot.png"), SIZES["slot"], 1.0)


BUTTON_STATES = {
    # état : (fond, roches, fissure, cristaux)
    "normal": ("cave_slab", "basalt", "lava_dim", None),
    "hover": ("cave_slab_light", "basalt_light", "lava", None),
    "pressed": ("cave_slab_gold", "gold_rock", "gold_seam", "crystal_gold"),
    "disabled": ("cave_hole", "basalt_dark", None, None),
}


def render_buttons(scene, m, out):
    for state, (slab, rock, seam, crystal) in BUTTON_STATES.items():
        _clear(scene)
        rng = random.Random(21)
        _plate(scene, m, 0.03, mat=slab)
        _edge_band(scene, m, 0.11, rock, seam, seed=23, rock_size=0.065, count=3)
        _corner_ornaments(scene, m, 0.02, 0.11, rng, None, crystal, scale=0.9)
        _render(scene, os.path.join(out, "button_%s.png" % state), SIZES["button"], 1.0)


def render_bubble(scene, m, out):
    _clear(scene)
    rng = random.Random(9)
    _plate(scene, m, 0.03)
    _edge_band(scene, m, 0.1, "basalt", "lava", seed=13, rock_size=0.06, count=3)
    _corner_ornaments(scene, m, 0.02, 0.1, rng, None, None, scale=0.85)
    _render(scene, os.path.join(out, "bubble.png"), SIZES["bubble"], 1.0)


def render_fringe(scene, m, out):
    """Les stalactites qui pendent sous la barre du haut (motif répété en largeur,
    période 1 : chaque pièce est recopiée à ±1)."""
    _clear(scene)
    rng = random.Random(31)
    height = 0.25  # L'image fait 4 fois plus large que haut.
    top = height / 2
    pieces = []
    for k in range(7):
        x = -0.5 + (k + rng.uniform(0.15, 0.85)) / 7
        pieces.append(_rock(scene, m["basalt"], (x, top - 0.02, 0.0), rng.uniform(0.035, 0.06), rng, squash=0.8))
        length = rng.uniform(0.07, 0.19)
        pieces.append(_stalactite(scene, m["basalt_light"], (x + rng.uniform(-0.02, 0.02), top - 0.03, 0.01),
                                  length, rng.uniform(0.018, 0.03), rng))
        if rng.random() < 0.5:
            drop = _rock(scene, m["lava"], (pieces[-1].location.x, top - 0.03 - length - 0.012, 0.01), 0.008, rng,
                         squash=1.2)
            pieces.append(drop)
    for piece in pieces:
        for shift in (-1.0, 1.0):
            _copy(scene, piece, (shift, 0, 0))
    _render(scene, os.path.join(out, "fringe.png"), SIZES["fringe"], 1.0, height=SIZES["fringe"] // 4)


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
    # La caverne : des rochers accrochés autour de l'anneau, et deux grappes de cristaux.
    rng = random.Random(17)
    for k in range(16):
        angle = math.radians(200 + k * 140 / 15)  # Le bas et les côtés (le haut garde ses cornes).
        if abs(math.degrees(angle) - 270) < 14:
            continue  # La place du crâne.
        radius = 0.97 + rng.uniform(-0.02, 0.03)
        _rock(scene, m["basalt" if k % 3 else "basalt_light"], (math.cos(angle) * radius, math.sin(angle) * radius, 0.02),
              rng.uniform(0.06, 0.1), rng, squash=0.8)
    for angle in (205, 335):
        a = math.radians(angle)
        _crystals(scene, m["crystal_red"], (math.cos(a) * 1.0, math.sin(a) * 1.0, 0.06), rng, count=3, size=0.07,
                  lean=a - math.pi / 2)
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
    render_fringe(scene, m, out)
    render_medallion(scene, m, out)
    return scene


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    render_all(os.path.join(os.path.dirname(os.path.dirname(here)), "assets", "ui_hd"))
