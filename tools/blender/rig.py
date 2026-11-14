"""Le squelette commun à tous les bipèdes (humanoid.py, demon.py, knight.py).

Les scripts de modélisation construisent d'abord le personnage en pièces
accrochées à des pivots (body, leg_*, arm_*, head, weapon, wing_*, tail).
build(scene) remplace ensuite ces pivots par une armature et « peint » les
poids de chaque pièce : les bras plient au coude, les jambes au genou, la cape
et la queue ondulent. clips.py y ajoute les animations jouées par le jeu.

Les os (Blender : Z vers le haut, le personnage regarde vers -Y) :
    root (au sol)
    └─ hips (bassin)
       ├─ thigh_l > shin_l > foot_l        (idem _r)
       ├─ tail_1 > tail_2                  (si queue)
       └─ chest
          ├─ head
          ├─ upper_arm_l > forearm_l > hand_l > grip_l     (idem _r)
          ├─ cape_1 > cape_2               (si cape)
          └─ wing_l, wing_r                (si ailes)
grip_l / grip_r : les points de prise des mains, sans rotation au repos (comme
les anciens pivots) ; l'arme est accrochée à grip_r, et le jeu y attache les
objets tenus (chope, grimoire, fouet...) avec des BoneAttachment3D.
"""

import bmesh
import bpy
from mathutils import Matrix, Vector

# Les os dont l'orientation au repos est celle du personnage (os pointé vers +Y,
# roulis nul : matrice identité). Le jeu y accroche des objets.
IDENTITY_BONES = ("root", "grip_l", "grip_r")
# Largeur des fondus de poids autour d'une articulation (mètres).
BLEND = 0.025


def build(scene, name="rig"):
    """Crée l'armature de la scène, y attache les pièces et supprime les pivots."""
    pivots = {obj.name: obj for obj in scene.objects if obj.type == "EMPTY"}
    meshes = [o for o in scene.objects if o.type == "MESH"]
    bpy.context.view_layer.update()

    # Les pièces passent en coordonnées du personnage (plus de parents).
    owner = {}
    for obj in meshes:
        owner[obj.name] = obj.parent.name if obj.parent else "body"
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.data.transform(world)
        obj.matrix_world = Matrix.Identity(4)

    layout = _layout(pivots, meshes, owner)
    armature = _armature(scene, name, layout)
    for obj in meshes:
        _skin(obj, owner[obj.name], layout, armature)
    for pivot in pivots.values():
        bpy.data.objects.remove(pivot, do_unlink=True)
    return armature


# ---------------------------------------------------------------------------
# La place des os
# ---------------------------------------------------------------------------

def _pos(pivots, name):
    return pivots[name].matrix_world.translation.copy()


def _layout(pivots, meshes, owner):
    """{os: (tête, queue, parent)} en coordonnées du personnage."""
    bones = {"root": (Vector((0, 0, 0)), Vector((0, 0.1, 0)), None)}
    hip_z = (_pos(pivots, "leg_l").z + _pos(pivots, "leg_r").z) / 2
    neck = _pos(pivots, "head")
    waist_z = hip_z + 0.27 * (neck.z - hip_z)
    bones["hips"] = (Vector((0, 0, hip_z)), Vector((0, 0, waist_z)), "root")
    bones["chest"] = (Vector((0, 0, waist_z)), Vector((0, 0, neck.z - 0.02)), "hips")
    bones["head"] = (neck, neck + Vector((0, 0, 0.2)), "chest")

    for side in ("l", "r"):
        # Les jambes touchent le sol : leur longueur est la hauteur de la hanche.
        hip = _pos(pivots, "leg_" + side)
        length = hip.z
        knee = hip + Vector((0, -0.003, -0.45 * length))
        ankle = hip + Vector((0, 0.003, -0.8 * length))
        bones["thigh_" + side] = (hip, knee, "hips")
        bones["shin_" + side] = (knee, ankle, "thigh_" + side)
        bones["foot_" + side] = (ankle, Vector((ankle.x, ankle.y - 0.07, 0.0)), "shin_" + side)
        # Les bras : la main tient l'arme à 90 % de la longueur (0,27 m pour 0,3 m).
        shoulder = _pos(pivots, "arm_" + side)
        grip = shoulder + Vector((0, -0.02, -0.27))
        if side == "r" and "weapon" in pivots:
            grip = _pos(pivots, "weapon")
        length = (shoulder.z - grip.z) / 0.9
        elbow = shoulder + Vector((0, 0.003, -0.4 * length))
        wrist = shoulder + Vector((0, -0.005, -0.77 * length))
        hand = shoulder + Vector((0, -0.015, -length))
        bones["upper_arm_" + side] = (shoulder, elbow, "chest")
        bones["forearm_" + side] = (elbow, wrist, "upper_arm_" + side)
        bones["hand_" + side] = (wrist, hand, "forearm_" + side)
        bones["grip_" + side] = (grip, grip + Vector((0, 0.05, 0)), "hand_" + side)

    for side in ("l", "r"):
        wing = "wing_" + side
        if wing in pivots:
            start = _pos(pivots, wing)
            # Vers le bout de l'aile (l'axe X du pivot, tourné de 0,5 rad).
            outward = pivots[wing].matrix_world.to_3x3() @ Vector((0.3 if side == "r" else -0.3, 0, 0.1))
            bones[wing] = (start, start + outward, "chest")

    if "tail" in pivots:
        start = _pos(pivots, "tail")
        points = [v.co.copy() for o in meshes if owner[o.name] == "tail" for v in o.data.vertices]
        end = max(points, key=lambda p: (p - start).length)
        middle = min(points, key=lambda p: abs((p - start).length - 0.45 * (end - start).length))
        bones["tail_1"] = (start, middle, "hips")
        bones["tail_2"] = (middle, end, "tail_1")

    cape = list(_cape_points(meshes, owner))
    if cape:
        top = max(p.z for p in cape)
        bottom = min(p.z for p in cape)
        y = sum(p.y for p in cape) / len(cape)
        middle = (top + bottom) / 2
        bones["cape_1"] = (Vector((0, y, top)), Vector((0, y, middle)), "chest")
        bones["cape_2"] = (Vector((0, y, middle)), Vector((0, y, bottom)), "cape_1")
    return bones


def _cape_points(meshes, owner):
    for obj in meshes:
        if owner[obj.name] != "body":
            continue
        for poly in obj.data.polygons:
            mats = obj.data.materials
            mat = mats[poly.material_index] if poly.material_index < len(mats) else None
            if mat is not None and mat.name.endswith("_cape"):
                for i in poly.vertices:
                    yield obj.data.vertices[i].co.copy()


def _armature(scene, name, layout):
    data = bpy.data.armatures.new(name)
    data.display_type = "STICK"
    armature = bpy.data.objects.new(name, data)
    scene.collection.objects.link(armature)
    armature.show_in_front = True
    previous = bpy.context.view_layer.objects.active
    bpy.context.window.scene = scene
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    edit = data.edit_bones
    for bone_name, (head, tail, _parent) in layout.items():
        bone = edit.new(bone_name)
        bone.head, bone.tail = head, tail
        bone.roll = 0.0
        bone.use_deform = bone_name not in ("root",)
    for bone_name, (_head, _tail, parent) in layout.items():
        if parent:
            edit[bone_name].parent = edit[parent]
            edit[bone_name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    if previous is not None and previous.name in scene.objects:
        bpy.context.view_layer.objects.active = previous
    for bone in armature.pose.bones:
        bone.rotation_mode = "QUATERNION"
    return armature


# ---------------------------------------------------------------------------
# Les poids
# ---------------------------------------------------------------------------

def _chain(z, joints, names):
    """Poids le long d'un membre vertical : « joints » sont les hauteurs des
    articulations (de haut en bas), « names » les os entre elles (un de plus)."""
    for k, joint in enumerate(joints):
        if z > joint + BLEND:
            return {names[k]: 1.0}
        if z > joint - BLEND:
            t = (joint + BLEND - z) / (2 * BLEND)
            return {names[k]: 1.0 - t, names[k + 1]: t}
    return {names[-1]: 1.0}


def _islands(bm):
    """Les morceaux d'un maillage (sommets reliés), en listes de sommets."""
    seen = set()
    islands = []
    for vert in bm.verts:
        if vert.index in seen:
            continue
        stack, island = [vert], []
        seen.add(vert.index)
        while stack:
            v = stack.pop()
            island.append(v)
            for edge in v.link_edges:
                other = edge.other_vert(v)
                if other.index not in seen:
                    seen.add(other.index)
                    stack.append(other)
        islands.append(island)
    return islands


def _skin(obj, owner, layout, armature):
    """Les groupes de sommets d'une pièce, selon le pivot qui la portait."""
    weights = {}  # index du sommet -> {os: poids}
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    cape_verts = set()
    robe_verts = set()
    for face in bm.faces:
        mats = obj.data.materials
        mat = mats[face.material_index].name if face.material_index < len(mats) and mats[face.material_index] else ""
        if mat.endswith("_cape"):
            cape_verts.update(v.index for v in face.verts)
        elif mat.endswith("_robe"):
            robe_verts.update(v.index for v in face.verts)

    side = None
    if owner[-2:] in ("_l", "_r"):
        side = owner[-1]
    if owner.startswith("arm_"):
        limb = ["upper_arm_" + side, "forearm_" + side, "hand_" + side]
    elif owner.startswith("leg_"):
        limb = ["thigh_" + side, "shin_" + side, "foot_" + side]
    else:
        limb = None

    def limb_weights(z):
        joints = [layout[limb[1]][0].z, layout[limb[2]][0].z]
        return _chain(z, joints, limb)

    for island in _islands(bm):
        coords = [v.co for v in island]
        lo = Vector([min(c[i] for c in coords) for i in range(3)])
        hi = Vector([max(c[i] for c in coords) for i in range(3)])
        center = sum(coords, Vector()) / len(coords)
        span = hi - lo
        # Un tube de membre (manche, jambe) plie ; un objet (bouclier, botte,
        # main, brassard) reste rigide, sur l'os où se trouve son centre.
        bends = span.z > 0.12 and max(span.x, span.y) < 0.15
        for v in island:
            i = v.index
            if owner == "weapon":
                weights[i] = {"grip_r": 1.0}
            elif owner == "head":
                weights[i] = {"head": 1.0}
            elif owner.startswith("wing_"):
                weights[i] = {owner: 1.0}
            elif owner == "tail":
                start = layout["tail_1"][0]
                full = (layout["tail_2"][1] - start).length
                d = (v.co - start).length / max(full, 1e-4)
                weights[i] = _chain(-d, [-0.45], ["tail_1", "tail_2"])  # Du pied au bout de la queue.
            elif limb:
                weights[i] = limb_weights(v.co.z if bends else center.z)
                if not bends:
                    best = max(weights[i], key=weights[i].get)
                    weights[i] = {best: 1.0}
            else:
                weights[i] = _body_weights(v.co, i in cape_verts, i in robe_verts, layout)
    bm.free()

    groups = {}
    for i, entry in weights.items():
        for bone, w in entry.items():
            if w <= 0.0:
                continue
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([i], w, "REPLACE")
    obj.parent = armature
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature


def _body_weights(co, is_cape, is_robe, layout):
    waist = layout["chest"][0].z
    hip = layout["hips"][0].z
    if is_cape and "cape_1" in layout:
        top = layout["cape_1"][0].z
        middle = layout["cape_2"][0].z
        if co.z > top - 0.04:
            return {"chest": 1.0}
        return _chain(co.z, [top - 0.06, middle], ["chest", "cape_1", "cape_2"])
    entry = _chain(co.z, [waist], ["chest", "hips"])
    if is_robe and co.z < hip:
        # Le bas de la robe suit un peu la jambe de son côté.
        follow = min(1.0, (hip - co.z) / hip) * min(1.0, abs(co.x) / 0.1) * 0.6
        thigh = "thigh_l" if co.x < 0 else "thigh_r"
        entry = {"hips": 1.0 - follow, thigh: follow}
    return entry
