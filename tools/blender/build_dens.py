"""Construit les créatures et le mobilier des antres (règles 2.7) et, en option, des aperçus.

En ligne de commande, sans ouvrir Blender :
    blender --background --python tools/blender/build_dens.py
    blender --background --python tools/blender/build_dens.py -- --preview <dossier>
Exporte assets/models/<créature>.glb et assets/models/rooms/<salle>.glb ; avec --preview, rend aussi <dossier>/<nom>.png
(vue en plongée, pour vérifier le modèle sans lancer le jeu).
"""

import importlib
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import cast  # noqa: E402
import humanoid  # noqa: E402
import lowpoly  # noqa: E402
import rooms  # noqa: E402

MODELS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "models", "rooms")
CREATURES = ["goblin", "ghoul", "imp", "executioner", "gargoyle", "oracle", "necromancer"]
DENS = ["tavern", "infirmary", "mint", "torture", "guardpost", "mana_well", "crypt_0", "crypt_1", "crypt_2"]


def preview(scene, path, size=(2.0, 2.0)):
    """Un rendu rapide en plongée (3/4 avant), avec un sol sombre et deux lumières."""
    bpy.context.window.scene = scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = scene.render.resolution_y = 640
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("preview_world")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.02, 0.015, 0.015, 1.0)
    bg.inputs[1].default_value = 0.6
    scene.world = world
    floor = bpy.data.meshes.new("preview_floor")
    w, d = size
    floor.from_pydata([(-w / 2, -d / 2, 0), (w / 2, -d / 2, 0), (w / 2, d / 2, 0), (-w / 2, d / 2, 0)], [], [(0, 1, 2, 3)])
    floor_obj = bpy.data.objects.new("preview_floor", floor)
    floor_obj.data.materials.append(lowpoly.material("preview_floor", "3a3230"))
    scene.collection.objects.link(floor_obj)
    floor_obj.location.z = -0.002
    for name, rot, energy in (("key", (math.radians(50), 0, math.radians(-30)), 3.0),
                              ("fill", (math.radians(60), 0, math.radians(150)), 1.0)):
        light = bpy.data.lights.new(name, "SUN")
        light.energy = energy
        obj = bpy.data.objects.new(name, light)
        obj.rotation_euler = rot
        scene.collection.objects.link(obj)
    cam_data = bpy.data.cameras.new("preview_cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(w, d) * 1.55 + 0.4
    cam = bpy.data.objects.new("preview_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.rotation_euler = (math.radians(55), 0, math.radians(35))
    # Recul le long de l'axe de visée, centré un peu au-dessus du sol.
    direction = cam.rotation_euler.to_matrix() @ Vector((0, 0, -1))
    cam.location = Vector((0, 0, 0.5)) - direction * 7.0
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def run(preview_dir=None):
    for module in (lowpoly, humanoid, cast, rooms):
        importlib.reload(module)
    characters = os.path.dirname(MODELS)
    for name in CREATURES:
        scene = cast.build(name, os.path.join(characters, name + ".glb"))
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            preview(scene, os.path.join(preview_dir, "c_" + name + ".png"), (0.9, 0.9))
    os.makedirs(MODELS, exist_ok=True)
    for name in DENS:
        scene = rooms.build(name, os.path.join(MODELS, name + ".glb"))
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            size = (1.0, 2.0) if name == "guardpost" else (2.0, 2.0)
            preview(scene, os.path.join(preview_dir, name + ".png"), size)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    run(argv[argv.index("--preview") + 1] if "--preview" in argv else None)
