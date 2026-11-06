"""Reconstruit et exporte TOUS les modèles low-poly : les personnages dans
assets/models/, le mobilier des salles dans assets/models/rooms/.

Dans Blender (onglet Scripting, ou par MCP) :
    import sys; sys.path.insert(0, r"<projet>/tools/blender")
    import build_all; build_all.run()
Ou en ligne de commande, sans ouvrir Blender :
    blender --background --python tools/blender/build_all.py
"""

import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import beasts  # noqa: E402
import cast  # noqa: E402
import demon  # noqa: E402
import humanoid  # noqa: E402
import knight  # noqa: E402
import lowpoly  # noqa: E402
import rooms  # noqa: E402

MODELS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "models")


def run():
    for module in (lowpoly, humanoid, cast, beasts, demon, knight, rooms):
        importlib.reload(module)
    os.makedirs(MODELS, exist_ok=True)
    path = lambda name: os.path.join(MODELS, name + ".glb")  # noqa: E731
    demon.build(path("demon"))
    knight.build(path("knight"))
    for name in cast.CHARACTERS:
        cast.build(name, path(name))
    for name in beasts.BUILDERS:
        beasts.build(name, path(name))
    os.makedirs(os.path.join(MODELS, "rooms"), exist_ok=True)
    for name in rooms.BUILDERS:
        rooms.build(name, path(os.path.join("rooms", name)))
    print("Modèles exportés dans", MODELS)


if __name__ == "__main__":
    run()
