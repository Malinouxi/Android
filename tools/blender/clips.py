"""Les animations des bipèdes, cuites en clips (actions Blender) sur le squelette
de rig.py, puis exportées dans le .glb : le jeu les joue avec AnimationPlayer
(voir view_3d.gd, _animate_clips).

Chaque clip est une fonction f(t, length, c) -> {os: réglage} appelée à chaque
image ; « c » décrit le personnage (longueur des jambes, robe...). Un réglage :
    "r":   (tangage, lacet, roulis) en radians, dans le repère du parent au repos
           (comme les anciens pivots du jeu : tangage < 0 = bras/jambe vers l'avant,
           tangage > 0 = buste/tête penchés vers l'avant, lacet = tourner autour de
           la verticale, roulis > 0 = vers +X, la droite du personnage) ;
    "q":   une rotation (Quaternion) dans ce même repère ;
    "loc": (x, haut, avant) en mètres (root et hips seulement).
Un os absent reste au repos. Les ailes, la queue et la cape bougent toutes seules
(_secondary) si le clip ne les règle pas.

Les clips en boucle tournent juste (la dernière image = la première). « attack »
ne boucle pas : le jeu le cale sur la progression du coup (unit.attack_progress) ;
« die » non plus : il est joué une fois quand l'unité meurt, puis elle s'efface
(voir view_3d.gd, _fall_and_vanish).
"""

import math

import bpy
from mathutils import Quaternion, Vector

FPS = 24
TAU = 2.0 * math.pi
LOCATED = ("root", "hips")  # Les seuls os qui se déplacent (les autres tournent).


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

def rot(pitch=0.0, yaw=0.0, roll=0.0):
    """Tangage autour de X, lacet autour de la verticale, roulis autour de l'axe
    avant-arrière (même ordre que les rotations de Godot : lacet, tangage, roulis)."""
    return (Quaternion((0, 0, 1), yaw) @ Quaternion((1, 0, 0), pitch) @ Quaternion((0, -1, 0), roll))


def smooth(a, b, x):
    if x <= a:
        return 0.0
    if x >= b:
        return 1.0
    x = (x - a) / (b - a)
    return x * x * (3 - 2 * x)


def keys(x, points):
    """Une courbe douce passant par des points (x, valeur) triés."""
    if x <= points[0][0]:
        return points[0][1]
    for (x0, v0), (x1, v1) in zip(points, points[1:]):
        if x <= x1:
            return v0 + (v1 - v0) * smooth(x0, x1, x)
    return points[-1][1]


def out(side, value):
    """Un roulis (ou lacet) « vers l'extérieur » pour le côté l (-X) ou r (+X)."""
    return -value if side == "l" else value


def phase(t, length, period):
    """L'angle d'une oscillation de période ~« period », arrondie pour que le
    clip boucle juste."""
    n = max(1, round(length / period))
    return TAU * n * t / length


def arms(p, side, pitch, forearm=0.0, roll=0.0, yaw=0.0, hand=0.0):
    """Règle le bras « side » : épaule (tangage, roulis vers l'extérieur), coude, poignet."""
    p["upper_arm_" + side] = {"r": (pitch, out(side, yaw), out(side, roll))}
    p["forearm_" + side] = {"r": (forearm, 0.0, 0.0)}
    if hand:
        p["hand_" + side] = {"r": (hand, 0.0, 0.0)}


def legs(p, side, thigh, shin=0.0, foot=0.0, roll=0.0, yaw=0.0):
    p["thigh_" + side] = {"r": (thigh, out(side, yaw), out(side, roll))}
    p["shin_" + side] = {"r": (shin, 0.0, 0.0)}
    p["foot_" + side] = {"r": (foot, 0.0, 0.0)}


# ---------------------------------------------------------------------------
# Les clips
# ---------------------------------------------------------------------------

def idle(t, length, c):
    s = TAU * t / length
    p = {"hips": {"loc": (0, 0.006 * math.sin(2 * s), 0)},
         "chest": {"r": (0.02 * math.sin(2 * s), 0, 0)},
         "head": {"r": (0.03 * math.sin(s), 0.25 * math.sin(s), 0)}}
    arms(p, "l", 0.04 * math.sin(2 * s + 1), -0.15, 0.06)
    arms(p, "r", 0.04 * math.sin(2 * s + 2), -0.15, 0.06)
    return p


def walk(t, length, c):
    s = TAU * t / length
    sin, cos = math.sin(s), math.cos(s)
    p = {"hips": {"loc": (0, 0.02 * (abs(cos) - 0.6), 0), "r": (0, -0.12 * sin, 0)},
         "chest": {"r": (0.06, 0.16 * sin, 0)},
         "head": {"r": (-0.04, -0.04 * sin, 0)},
         "cape_1": {"r": (0.3 + 0.05 * math.sin(2 * s), 0, 0)},
         "cape_2": {"r": (0.12 + 0.08 * math.sin(2 * s - 1), 0, 0)}}
    # La jambe gauche est en arrière quand sin > 0 ; le genou plie quand elle revient.
    legs(p, "l", 0.6 * sin, 0.15 + 0.85 * max(0.0, -cos), 0.25 * max(0.0, sin))
    legs(p, "r", -0.6 * sin, 0.15 + 0.85 * max(0.0, cos), 0.25 * max(0.0, -sin))
    arms(p, "l", -0.5 * sin, -0.35, 0.08)
    arms(p, "r", 0.5 * sin, -0.35, 0.08)
    return p


def walk_tipsy(t, length, c):
    step = length / 8
    p = walk(t % step, step, c)
    s = TAU * t / length
    p["root"] = {"r": (0.04 * math.sin(s), 0, 0.14 * math.sin(2 * s))}
    p["head"] = {"r": (0.1, 0, 0.25 * math.sin(s + 1))}
    arms(p, "l", -0.2, -0.3, 0.5 * abs(math.sin(2 * s)))
    return p


def attack(t, length, c):
    k = t / length
    p = {"chest": {"r": (keys(k, [(0, 0), (0.35, -0.1), (0.6, 0.25), (1, 0)]),
                         keys(k, [(0, 0), (0.35, 0.35), (0.6, -0.3), (1, 0)]), 0)},
         "hips": {"loc": (0, 0, keys(k, [(0, 0), (0.35, -0.02), (0.6, 0.06), (1, 0)]))}}
    arms(p, "r", keys(k, [(0, 0), (0.35, -2.6), (0.6, -0.5), (1, 0)]),
         keys(k, [(0, -0.15), (0.35, -1.0), (0.6, -0.1), (1, -0.15)]), 0.1)
    arms(p, "l", keys(k, [(0, 0), (0.35, -0.5), (0.6, 0.2), (1, 0)]), -0.4, 0.1)
    legs(p, "r", keys(k, [(0, 0), (0.6, -0.35), (1, 0)]), keys(k, [(0, 0), (0.6, 0.35), (1, 0)]))
    legs(p, "l", keys(k, [(0, 0), (0.6, 0.15), (1, 0)]))
    return p


def sleep(t, length, c):
    # Couché sur le dos (le jeu bascule le modèle) : bras le long du corps, souffle lent.
    s = TAU * t / length
    p = {"hips": {"loc": (0, 0.008 * math.sin(s), 0)},
         "chest": {"r": (0.03 * math.sin(s), 0, 0)},
         "head": {"r": (-0.05, 0.15 * math.sin(s), 0)}}
    arms(p, "l", 0.1, -0.1, 0.05)
    arms(p, "r", 0.1, -0.1, 0.05)
    legs(p, "l", 0, 0.05)
    legs(p, "r", 0, 0.05)
    return p


def eat(t, length, c):
    s = TAU * t / length
    bite = max(0.0, math.sin(s))
    p = {"head": {"r": (0.05 + 0.06 * math.sin(2 * s), 0, 0)}, "chest": {"r": (0.05, 0, 0)}}
    arms(p, "l", -0.55 - 0.2 * bite, -1.75 - 0.35 * bite, -0.25)
    arms(p, "r", -0.3, -0.9, -0.15)
    return p


def drink(t, length, c):
    s = TAU * t / length
    gulp = smooth(0.0, 0.3, t) * (1.0 - smooth(1.8, 2.15, t))
    p = {"head": {"r": (0.05 - 0.5 * gulp, 0, 0)},
         "chest": {"r": (-0.12 * gulp, 0, 0)},
         "root": {"r": (0, 0, 0.05 * math.sin(s))}}
    arms(p, "l", -0.45 - 0.55 * gulp, -1.2 - 0.75 * gulp, -0.3)
    arms(p, "r", -0.2 + 0.1 * math.sin(2 * s), -0.4, 0.05)
    return p


def study(t, length, c):
    s = TAU * t / length
    flip = smooth(0.0, 0.2, t) * (1.0 - smooth(0.35, 0.6, t))  # Elle tourne une page.
    p = {"head": {"r": (0.45 + 0.05 * math.sin(s), 0, 0)}, "chest": {"r": (0.08, 0, 0)}}
    arms(p, "l", -0.35, -1.1, -0.3)
    arms(p, "r", -0.35 - 0.25 * flip, -1.1 + 0.3 * flip, -0.3 - 0.3 * flip)
    return p


def _blow(k):
    """Lever lentement (3/4 du temps), frapper d'un coup sec."""
    return k / 0.75 if k < 0.75 else 1.0 - (k - 0.75) / 0.25


def hammer(t, length, c):
    lift = _blow(t / length)
    p = {"chest": {"r": (0.18 - 0.22 * lift, 0, 0)}, "head": {"r": (0.2, 0, 0)}}
    arms(p, "r", -0.4 - 2.0 * lift, -0.3 - 0.8 * lift, 0.1)
    arms(p, "l", -0.6, -0.8, -0.1)
    return p


def coin(t, length, c):
    k = t / length
    right, left = _blow(k), _blow((k + 0.5) % 1.0)
    p = {"chest": {"r": (0.12, 0, 0)}, "head": {"r": (0.25, 0, 0)}}
    arms(p, "r", -0.4 - 1.6 * right, -0.4 - 0.5 * right)
    arms(p, "l", -0.4 - 1.2 * left, -0.4 - 0.5 * left)
    return p


def train(t, length, c):
    s = TAU * t / length
    k = (2.0 * t / length) % 1.0  # Deux coups par boucle.
    swing = math.sin(k * math.pi)
    p = {"hips": {"loc": (0, -0.03 * swing, 0.06 * swing)},
         "chest": {"r": (0.1 * swing, 0.3 * math.sin(s), 0)}}
    arms(p, "r", keys(k, [(0, -0.5), (0.4, -2.5), (0.65, -0.6), (1, -0.5)]),
         keys(k, [(0, -0.6), (0.4, -1.0), (0.65, -0.1), (1, -0.6)]), 0.1)
    arms(p, "l", -0.8, -1.0, -0.1)
    legs(p, "r", -0.45 * swing, 0.45 * swing)
    legs(p, "l", 0.3 * swing, 0.1 * swing)
    return p


def pray(t, length, c):
    s = TAU * t / length
    raise_ = 0.5 + 0.5 * math.sin(s)
    p = {"hips": {"loc": (0, -(0.55 * c["leg"] - 0.03), 0), "r": (0.15 * (1 - raise_), 0, 0)},
         "chest": {"r": (0.25 * (1 - raise_), 0, 0)},
         "head": {"r": (0.25 * (1 - raise_) - 0.15 * raise_, 0, 0)}}
    for side in ("l", "r"):
        # À genoux : cuisses droites, tibias à plat vers l'arrière.
        legs(p, side, -0.15 * (1 - raise_), 1.55, 0.9, 0.05)
        arms(p, side, -2.0 - 0.6 * raise_, -0.2, 0.3)
    return p


def tend(t, length, c):
    s = TAU * t / length
    p = {"hips": {"loc": (0, -0.035, -0.03), "r": (0.1, 0, 0)},
         "chest": {"r": (0.3, 0, 0)},
         "head": {"r": (0.2, 0, 0)}}
    for side in ("l", "r"):
        legs(p, side, -0.35, 0.5, -0.05, 0.05)
    arms(p, "l", -0.9 + 0.15 * math.sin(2 * s), -0.6, -0.15)
    arms(p, "r", -0.9 + 0.15 * math.sin(2 * s + math.pi), -0.6, -0.15)
    return p


def torture(t, length, c):
    lash = keys(t / length, [(0, 0), (0.7, 1), (0.8, 0.2), (1, 0)])
    p = {"chest": {"r": (0.1 * (1 - lash), 0.35 * lash, 0)}}
    arms(p, "r", -0.4 - 2.4 * lash, -0.2 - 0.6 * lash, 0.35 * lash)
    arms(p, "l", -0.4, -0.5)
    return p


def guard(t, length, c):
    s = TAU * t / length
    p = {"chest": {"r": (-0.05, 0, 0)}, "head": {"r": (0, 0.5 * math.sin(s), 0)}}
    arms(p, "r", -0.35, -1.1, 0.1)
    arms(p, "l", 0.05, -0.1, 0.05)
    for side in ("l", "r"):
        legs(p, side, 0, 0, 0, 0.06)
    return p


def meditate(t, length, c):
    s = TAU * t / length
    p = {"root": {"loc": (0, 0.1 + 0.05 * math.sin(2 * s), 0)},
         "hips": {"loc": (0, -0.1, 0), "r": (0, 0.3 * math.sin(s), 0)},
         "chest": {"r": (-0.03, 0, 0)},
         "head": {"r": (0.1, 0, 0)}}
    for side in ("l", "r"):
        # Jambes croisées : cuisses à plat et écartées, tibias repliés l'un devant l'autre.
        p["thigh_" + side] = {"r": (-1.45, out(side, 0.65), 0)}
        p["shin_" + side] = {"q": rot(2.5, out(side, -0.9), 0)}
        p["foot_" + side] = {"r": (-0.6, 0, 0)}
        arms(p, side, -0.35 - 0.05 * math.sin(2 * s), -0.9, 0.45)
    return p


def cast(t, length, c):
    s = TAU * t / length
    p = {"root": {"loc": (0, 0.02 * math.sin(3 * s), 0)},
         "chest": {"r": (-0.1, 0, 0)},
         "head": {"r": (-0.25, 0, 0)}}
    arms(p, "l", -2.5 + 0.3 * math.sin(s), -0.15, 0.4)
    arms(p, "r", -2.5 + 0.3 * math.sin(s + math.pi), -0.15, 0.4)
    return p


def tipsy(t, length, c):
    s = TAU * t / length
    p = {"root": {"r": (0.05 * math.sin(s), 0, 0.15 * math.sin(2 * s))},
         "hips": {"r": (0, 0, -0.05 * math.sin(2 * s))},
         "head": {"r": (0.1, 0, 0.25 * math.sin(s))}}
    arms(p, "l", -0.2, -0.3, 0.45 * abs(math.sin(2 * s)))
    arms(p, "r", -0.3, -0.6, 0.1)
    for side in ("l", "r"):
        legs(p, side, -0.1, 0.15, -0.05, 0.05)
    return p


# En fin de chute : (tangage, lacet vers l'extérieur) des ailes, tangage des deux os de la queue.
DIE_FALL = 1.0  # Durée de la chute (s) ; le clip dure le double.
DIE_WING = (0.3, -0.9)
DIE_TAIL = (-1.6, -0.3)


def die(t, length, c):
    # Il recule sous le coup, les genoux lâchent, il bascule sur le dos et rebondit un peu
    # (en 1 s), puis reste étendu : le jeu l'efface avant la fin du clip, car Godot remet
    # le modèle au repos quand un clip sans boucle se termine.
    k = min(1.0, t / DIE_FALL)
    fall = keys(k, [(0, 0), (0.25, -0.1), (0.75, -1.62), (0.86, -1.5), (1, -1.57)])
    buckle = keys(k, [(0, 0), (0.2, 0.15), (0.45, 1.0), (0.75, 0.35), (1, 0.25)])
    flail = keys(k, [(0, 0), (0.15, 1.0), (0.6, 0.7), (0.85, 1.0), (1, 0.85)])
    p = {"root": {"r": (fall, 0, keys(k, [(0, 0), (0.5, 0.1), (1, 0.15)])),
                  "loc": (0, keys(k, [(0, 0), (0.6, 0.0), (0.8, 0.07 + c["depth"]), (1, 0.06 + c["depth"])]),
                          keys(k, [(0, 0), (0.25, -0.05), (1, -0.1)]))},
         "hips": {"loc": (0, -0.1 * buckle, 0)},
         "chest": {"r": (keys(k, [(0, 0), (0.15, -0.35), (0.5, 0.2), (1, 0.05)]), 0.15 * flail, 0)},
         "head": {"r": (keys(k, [(0, 0), (0.15, -0.5), (0.6, 0.3), (0.85, -0.2), (1, 0.1)]),
                        keys(k, [(0, 0), (0.8, 0), (1, 0.6)]), 0)}}
    for side in ("l", "r"):
        legs(p, side, -0.55 * buckle, 1.0 * buckle, -0.2 * buckle, 0.08 * buckle)
        # Bras projetés en avant, puis retombés au sol, écartés.
        arms(p, side, keys(k, [(0, 0), (0.15, -0.8), (0.6, -0.6), (0.85, -0.15), (1, -0.05)]),
             keys(k, [(0, 0), (0.15, -0.6), (0.6, -0.5), (0.85, -0.1), (1, -0.05)]), 0.3 + 0.6 * flail)
    # Couché sur le dos : les ailes et la queue se rabattent au lieu de traverser le sol.
    down = smooth(0.3, 0.8, k)
    (wing_pitch, wing_yaw), (tail_pitch, tail_bend) = DIE_WING, DIE_TAIL
    for side in ("l", "r"):
        p["wing_" + side] = {"r": (wing_pitch * down, out(side, wing_yaw) * down, 0)}
    # L'arme, pointée vers l'avant (donc vers le ciel une fois couché), retombe le long du corps.
    p["hand_r"] = {"r": (1.4 * down, 0, 0)}
    p["tail_1"] = {"r": (tail_pitch * down, 0, 0)}
    p["tail_2"] = {"r": (tail_bend * down, 0, 0)}
    return p


# nom : (durée en secondes, fonction, en boucle)
CLIPS = {
    "idle": (4.8, idle, True),
    "walk": (14 / FPS, walk, True),
    "walk_tipsy": (8 * 14 / FPS, walk_tipsy, True),
    "attack": (8 / FPS, attack, False),
    "die": (2 * DIE_FALL, die, False),
    "sleep": (4.8, sleep, True),
    "lie": (4.8, sleep, True),
    "eat": (0.9, eat, True),
    "drink": (3.2, drink, True),
    "study": (4.0, study, True),
    "hammer": (1 / 1.4, hammer, True),
    "coin": (1 / 2.2, coin, True),
    "train": (1 / 0.9, train, True),
    "pray": (TAU / 1.3, pray, True),
    "tend": (TAU / 6.0, tend, True),
    "torture": (1.6, torture, True),
    "guard": (TAU / 1.1, guard, True),
    "meditate": (TAU / 0.8, meditate, True),
    "cast": (TAU / 2.4, cast, True),
    "tipsy": (TAU / 1.3, tipsy, True),
}


# ---------------------------------------------------------------------------
# Ailes, queue, cape : un mouvement continu dans tous les clips
# ---------------------------------------------------------------------------

def _secondary(p, t, length, bones):
    w = phase(t, length, TAU / 5.0)
    for side, sign in (("l", -1.0), ("r", 1.0)):
        wing = "wing_" + side
        if wing in bones and wing not in p:
            # Comme l'ancien pivot : battement autour de son axe avant, tourné de 0,5 rad.
            axis = Quaternion((0, 0, 1), 0.5 * sign) @ Vector((0, -1, 0))
            p[wing] = {"q": Quaternion(axis, 0.6 * math.sin(w) * sign)}
    w = phase(t, length, TAU / 4.0)
    if "tail_1" in bones and "tail_1" not in p:
        p["tail_1"] = {"r": (0, 0.3 * math.sin(w), 0)}
        p["tail_2"] = {"r": (0, 0.35 * math.sin(w - 0.9), 0)}
    w = phase(t, length, 2.4)
    if "cape_1" in bones and "cape_1" not in p:
        p["cape_1"] = {"r": (0.03 * math.sin(w), 0, 0.02 * math.sin(w + 1))}
        p["cape_2"] = {"r": (0.04 * math.sin(w - 0.8), 0, 0)}


# ---------------------------------------------------------------------------
# La cuisson
# ---------------------------------------------------------------------------

def bake(armature, context=None):
    """Crée une action par clip sur l'armature (rangées dans des pistes NLA, pour
    que l'export glTF les emporte toutes)."""
    bones = armature.data.bones
    rest = {b.name: b.matrix_local.to_quaternion() for b in bones}
    c = {"leg": bones["thigh_l"].head_local.z if "thigh_l" in bones else 0.3, "depth": 0.0}
    # Couché sur le dos (die) : on soulève d'autant que le dos dépasse derrière les talons.
    backs = [(armature.matrix_world.inverted() @ (o.matrix_world @ v.co)).y
             for o in armature.children if o.type == "MESH" and o.vertex_groups.get("chest")
             for v in o.data.vertices if any(g.group == o.vertex_groups["chest"].index for g in v.groups)]
    if backs:
        c["depth"] = max(0.0, max(backs) - 0.09)
    c.update(context or {})
    data = armature.animation_data_create()
    owner = armature.users_scene[0].name if armature.users_scene else armature.name
    for track in list(data.nla_tracks):
        data.nla_tracks.remove(track)
    for name, (length, func, loop) in CLIPS.items():
        data.action = None
        frames = max(2, 2 * round(length * FPS / 2))  # Pair : l'export garde une image sur deux.
        previous = {}
        for frame in range(frames + 1):
            t = frame * length / frames
            pose = func(t, length, c)
            _secondary(pose, t, length, bones)
            for pb in armature.pose.bones:
                entry = pose.get(pb.name, {})
                if "q" in entry:
                    q = entry["q"]
                elif "r" in entry:
                    q = rot(*entry["r"])
                else:
                    q = Quaternion()
                r = rest[pb.name]
                basis = r.inverted() @ q @ r
                if pb.name in previous:
                    basis.make_compatible(previous[pb.name])
                previous[pb.name] = basis
                pb.rotation_quaternion = basis
                pb.keyframe_insert("rotation_quaternion", frame=frame)
                if pb.name in LOCATED:
                    x, up, forward = entry.get("loc", (0, 0, 0))
                    pb.location = r.inverted() @ Vector((x, -forward, up))
                    pb.keyframe_insert("location", frame=frame)
        action = data.action
        # « vampire:walk » : une action par personnage, remplacée à chaque reconstruction
        # (l'export nomme le clip d'après la piste NLA : « walk »).
        full_name = "%s:%s" % (owner, name)
        old = bpy.data.actions.get(full_name)
        if old is not None and old != action:
            bpy.data.actions.remove(old)
        action.name = full_name
        action.use_fake_user = True
        action["loop"] = loop
        track = data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        strip.name = name
        track.mute = True
        data.action = None
    for pb in armature.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    return [name for name in CLIPS]
