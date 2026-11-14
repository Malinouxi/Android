"""Briques communes pour modéliser les personnages du jeu en low-poly dans Blender.

Chaque personnage est un assemblage de PIÈCES RIGIDES accrochées à des PIVOTS
(objets vides) qui portent les noms attendus par scripts/view_3d.gd :
    body, leg_l, leg_r, arm_l, arm_r, head, weapon, wing_l, wing_r, tail
Les bipèdes (humanoid.py, demon.py, knight.py) remplacent ensuite ces pivots
par un squelette animé (rig.py, clips.py) ; les bêtes et le mobilier gardent
leurs pivots, que le jeu fait tourner lui-même.

Repères (Blender) : Z vers le haut, le personnage regarde vers -Y (vue de face).
À l'export glTF, -Y devient +Z, le « devant » des modèles dans Godot.
« _l » = côté -X (index 0 dans le jeu), « _r » = côté +X (index 1, l'arme).
Échelle : une case du jeu = 1 m ; un personnage de taille 8 fait ~0,9 m.
"""

import math

import bmesh
import bpy
from mathutils import Vector


# ---------------------------------------------------------------------------
# Scène et matériaux
# ---------------------------------------------------------------------------

def new_scene(name):
    """Une scène vide rien que pour ce personnage.

    Les noms d'objets sont communs à tout le fichier Blender : les scènes des
    personnages construits avant sont donc supprimées (sinon « arm_r » deviendrait
    « arm_r.001 » et le jeu ne trouverait plus ses pivots). Les autres scènes ne
    sont pas touchées.
    """
    for old in [s for s in bpy.data.scenes if s.get("lowpoly_character")]:
        if bpy.context.window.scene == old:
            bpy.context.window.scene = next(s for s in bpy.data.scenes if s != old)
        for obj in list(old.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(old)
    for mesh in [m for m in bpy.data.meshes if m.users == 0]:
        bpy.data.meshes.remove(mesh)
    scene = bpy.data.scenes.new(name)
    scene["lowpoly_character"] = True
    bpy.context.window.scene = scene
    return scene


def material(name, color, emission=0.0, double_sided=False, texture=None):
    """Un matériau mat (couleur « rrggbb »). emission > 0 : il brille (yeux, orbes).

    « texture » : le nom d'une texture peinte de textures.py (stone, planks, gold...),
    multipliée par la couleur. Les UV sont calculés par Part.finish.
    """
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    rgba = _srgb_to_linear(color)
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    for node in [n for n in nodes if n.type in ("TEX_IMAGE", "MIX")]:
        nodes.remove(node)
    bsdf.inputs["Base Color"].default_value = rgba
    if texture:
        import textures
        image_node = nodes.new("ShaderNodeTexImage")
        image_node.image = textures.blender_image(texture)
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        # La texture assombrit (sa moyenne est < 1) : on éclaircit la couleur d'autant.
        boost = 1.0 / textures.linear_mean(texture)
        mix.inputs[7].default_value = tuple(min(1.0, c * boost) for c in rgba[:3]) + (1.0,)
        links = mat.node_tree.links
        links.new(image_node.outputs["Color"], mix.inputs[6])
        links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        mat["uv_tile"] = textures.TILE[texture]
        if emission > 0.0:
            # Une lueur texturée (lave, bave, or) : une image déjà teintée, branchée
            # directement sur l'émission (c'est ce que l'export glTF sait lire).
            glow_node = nodes.new("ShaderNodeTexImage")
            glow_node.image = textures.blender_image(texture, tint=color)
            links.new(glow_node.outputs["Color"], bsdf.inputs["Emission Color"])
    elif "uv_tile" in mat:
        del mat["uv_tile"]
    bsdf.inputs["Roughness"].default_value = 0.85
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = rgba
    mat.use_backface_culling = not double_sided
    return mat


def _srgb_to_linear(hex_color):
    def channel(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (0, 2, 4))
    return (channel(r), channel(g), channel(b), 1.0)


# ---------------------------------------------------------------------------
# Pivots et pièces
# ---------------------------------------------------------------------------

def pivot(scene, name, parent=None, at=(0, 0, 0), rotation=(0, 0, 0)):
    """Un pivot (objet vide) ; « at » est relatif au parent."""
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "PLAIN_AXES"
    empty.empty_display_size = 0.05
    scene.collection.objects.link(empty)
    empty.parent = parent
    empty.location = at
    empty.rotation_euler = rotation
    return empty


class Part:
    """Une pièce rigide (un seul maillage, plusieurs matériaux) accrochée à un pivot.

    Les fonctions loft, box, cone... ajoutent des formes dans le repère du pivot.
    finish() crée l'objet Blender (ombrage plat, style low-poly).
    """

    def __init__(self, scene, name, parent):
        self.scene = scene
        self.name = name
        self.parent = parent
        self.bm = bmesh.new()
        self.materials = []
        self.flat_faces = []

    def _mat_index(self, mat):
        if mat not in self.materials:
            self.materials.append(mat)
        return self.materials.index(mat)

    def loft(self, sections, mat, sides=8, cap_start=True, cap_end=True, twist=None):
        """Un tube qui passe par des sections (centre, rayon x, rayon y).

        Les anneaux sont perpendiculaires au chemin ; pour un chemin vertical,
        le rayon x est le long de X et le rayon y le long de Y.
        """
        index = self._mat_index(mat)
        centers = [Vector(s[0]) for s in sections]
        twist = math.pi / sides if twist is None else twist
        rings = []
        for i, (center, rx, ry) in enumerate(sections):
            before = centers[max(i - 1, 0)]
            after = centers[min(i + 1, len(centers) - 1)]
            tangent = (after - before).normalized()
            reference = Vector((1, 0, 0)) if abs(tangent.x) < 0.9 else Vector((0, 0, 1))
            u = (reference - tangent * reference.dot(tangent)).normalized()
            v = tangent.cross(u)
            ring = []
            for k in range(sides):
                angle = twist + 2 * math.pi * k / sides
                point = Vector(center) + u * (rx * math.cos(angle)) + v * (ry * math.sin(angle))
                ring.append(self.bm.verts.new(point))
            rings.append(ring)
        for a, b in zip(rings, rings[1:]):
            for k in range(sides):
                k2 = (k + 1) % sides
                face = self.bm.faces.new((a[k], a[k2], b[k2], b[k]))
                face.material_index = index
        if cap_start:
            self.bm.faces.new(list(reversed(rings[0]))).material_index = index
        if cap_end:
            if sections[-1][1] < 1e-4 and sections[-1][2] < 1e-4:
                pass  # Pointe : l'anneau est réduit à un point, déjà fermé.
            else:
                self.bm.faces.new(rings[-1]).material_index = index
        return self

    def box(self, center, size, mat, rotation_z=0.0):
        index = self._mat_index(mat)
        cx, cy, cz = center
        sx, sy, sz = (s / 2 for s in size)
        cos, sin = math.cos(rotation_z), math.sin(rotation_z)
        verts = []
        for dx, dy, dz in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                           (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)):
            x, y = dx * sx, dy * sy
            verts.append(self.bm.verts.new((cx + x * cos - y * sin, cy + x * sin + y * cos, cz + dz * sz)))
        for quad in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            self.bm.faces.new([verts[i] for i in quad]).material_index = index
        return self

    def cone(self, base, tip, radius, mat, sides=5):
        """Un cône (griffe, pointe, corne droite) de « base » à « tip »."""
        return self.loft([(base, radius, radius), (tip, 0.0, 0.0)], mat, sides, cap_end=False)

    def flat(self, points, mat, facing=None):
        """Un polygone plat (yeux, bouche, membrane d'aile...).

        « facing » : la direction vers laquelle sa face visible doit regarder
        (sinon, donner un matériau double face).
        """
        index = self._mat_index(mat)
        face = self.bm.faces.new([self.bm.verts.new(p) for p in points])
        face.material_index = index
        face.normal_update()
        if facing is not None and face.normal.dot(Vector(facing)) < 0:
            face.normal_flip()
        self.flat_faces.append(face)
        return self

    def slab(self, points, thickness, mat, side_mat=None):
        """Une plaque épaisse (bouclier, lame) : le contour « points » est la face
        avant ; « thickness » (x, y, z) va de la face avant à la face arrière."""
        index = self._mat_index(mat)
        side_index = self._mat_index(side_mat or mat)
        offset = Vector(thickness)
        front = [self.bm.verts.new(p) for p in points]
        back = [self.bm.verts.new(Vector(p) + offset) for p in points]
        self.bm.faces.new(front).material_index = index
        self.bm.faces.new(list(reversed(back))).material_index = index
        for k in range(len(points)):
            k2 = (k + 1) % len(points)
            self.bm.faces.new((front[k2], front[k], back[k], back[k2])).material_index = side_index
        return self

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        flat = set(self.flat_faces)
        bmesh.ops.recalc_face_normals(self.bm, faces=[f for f in self.bm.faces if f not in flat])
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat in self.materials:
            mesh.materials.append(mat)
        for poly in mesh.polygons:
            poly.use_smooth = False
        if any("uv_tile" in mat for mat in self.materials):
            _box_uv(mesh)
        obj = bpy.data.objects.new(self.name, mesh)
        self.scene.collection.objects.link(obj)
        obj.parent = self.parent
        return obj


def _box_uv(mesh):
    """Des UV « en boîte » : chaque face est projetée sur le plan de son axe principal,
    à l'échelle de la texture de son matériau (une répétition = uv_tile mètres)."""
    layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        mat = mesh.materials[poly.material_index]
        tile = mat.get("uv_tile", 1.0) if mat else 1.0
        n = poly.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        for loop_index in poly.loop_indices:
            co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            if axis == 2:
                u, v = co.x, co.y
            elif axis == 1:
                u, v = co.x, co.z
            else:
                u, v = co.y, co.z
            layer.data[loop_index].uv = (u / tile, v / tile)


def mirrored(points, side):
    """Recopie des points (x, y, z) du côté « side » (-1 ou 1) : x est multiplié par side."""
    return [(x * side, y, z) for x, y, z in points]


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def export_glb(scene, path):
    """Exporte la scène du personnage en .glb (Y vers le haut, pour Godot)."""
    bpy.context.window.scene = scene
    for obj in scene.objects:
        obj.select_set(True)
    # Un bipède a un squelette (rig.py) : ses clips (clips.py, une piste NLA chacun)
    # partent avec lui. Les autres modèles restent en pièces rigides sur des pivots.
    animated = any(obj.type == "ARMATURE" for obj in scene.objects)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_active_scene=True,
        export_yup=True,
        export_apply=not animated,  # (Appliquer les modificateurs retirerait la peau.)
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=animated,
        export_animation_mode="NLA_TRACKS",
        export_skins=True,
        export_def_bones=False,  # Les os sans poids (root, grip_*) servent au jeu.
        export_optimize_animation_size=True,
        export_frame_step=2,  # 12 images/s : assez pour du low-poly, deux fois moins lourd.
    )
    print("Exporté :", path)
