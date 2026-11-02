#!/usr/bin/env python3
"""Génère tout le pixel art du jeu dans le dossier assets/.

Usage (depuis la racine du projet) :
    python3 tools/generate_art.py

Il faut Python 3 et la bibliothèque Pillow (pip install pillow).

Comment ça marche :
  - Les PERSONNAGES et les OBJETS sont dessinés « à la main » ci-dessous :
    chaque image est une liste de 16 lignes de 16 caractères, et chaque lettre
    correspond à une couleur de la palette (« . » = transparent).
    Pour modifier un dessin, change les lettres et relance le script !
  - Les TUILES du sol (terre, roche...) sont générées avec un peu de hasard,
    pour que deux cases voisines ne soient pas identiques.

Tu peux aussi remplacer n'importe quel fichier PNG de assets/ par ton propre
dessin (16 x 16 pixels) : le jeu l'utilisera tel quel.
"""

import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
SIZE = 16


def hex_color(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def from_ascii(rows, palette):
    """Transforme 16 lignes de lettres en image."""
    height = len(rows)
    width = len(rows[0])
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        if len(row) != width:
            raise ValueError("Ligne %d de longueur %d au lieu de %d : %r" % (y, len(row), width, row))
        for x, char in enumerate(row):
            if char == ".":
                continue
            image.putpixel((x, y), hex_color(palette[char]))
    return image


def save(image, *parts):
    path = os.path.join(ASSETS, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)


def bob_frame(image):
    """Deuxième image d'animation de marche : le haut du corps monte d'un pixel
    et les deux pieds s'écartent un peu."""
    frame = Image.new("RGBA", image.size, (0, 0, 0, 0))
    top = image.crop((0, 1, SIZE, 13))
    frame.paste(top, (0, 0))
    # La ligne de la taille est recopiée pour ne pas laisser de trou.
    frame.paste(image.crop((0, 12, SIZE, 13)), (0, 12))
    legs = image.crop((0, 13, SIZE, SIZE))
    frame.paste(legs, (0, 13))
    return frame


# ---------------------------------------------------------------------------
# Tuiles
# ---------------------------------------------------------------------------

def noise_tile(rng, colors, weights, light, dark, bevel=True):
    image = Image.new("RGBA", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            image.putpixel((x, y), hex_color(rng.choices(colors, weights)[0]))
    if bevel:
        for i in range(SIZE):
            image.putpixel((i, 0), hex_color(light))
            image.putpixel((0, i), hex_color(light))
            image.putpixel((i, SIZE - 1), hex_color(dark))
            image.putpixel((SIZE - 1, i), hex_color(dark))
    return image


def earth_tile(rng):
    image = noise_tile(rng, ["#6b4a2f", "#73502f", "#62432a", "#5a3d26"], [5, 3, 3, 1],
                       "#87603d", "#3f2a1a")
    # Quelques cailloux.
    for _ in range(3):
        x, y = rng.randint(2, 12), rng.randint(2, 12)
        image.putpixel((x, y), hex_color("#8d7a68"))
        image.putpixel((x + 1, y), hex_color("#6e5d4e"))
        image.putpixel((x, y + 1), hex_color("#4a3a2d"))
    return image


def gold_tile(rng):
    image = earth_tile(rng)
    spots = [(3, 3), (9, 5), (5, 10), (11, 11)]
    rng.shuffle(spots)
    for x, y in spots[:3]:
        x += rng.randint(-1, 1)
        y += rng.randint(-1, 1)
        for dx, dy, color in [(0, 0, "#ffe27a"), (1, 0, "#f2b632"), (0, 1, "#f2b632"),
                              (1, 1, "#c98a1c"), (2, 1, "#8a5d14"), (1, 2, "#8a5d14")]:
            image.putpixel((x + dx, y + dy), hex_color(color))
    return image


def rock_tile(rng):
    image = noise_tile(rng, ["#4a4a55", "#50505c", "#45454f"], [4, 2, 2], "#6a6a78", "#2c2c35")
    # Une fissure qui serpente.
    x, y = rng.randint(3, 12), 2
    while y < 13:
        image.putpixel((x, y), hex_color("#2a2a32"))
        image.putpixel((min(x + 1, 14), y), hex_color("#5c5c69"))
        y += 1
        x = max(2, min(13, x + rng.choice([-1, 0, 0, 1])))
    return image


def floor_tile(rng):
    """Dalles de pierre sombres."""
    image = Image.new("RGBA", (SIZE, SIZE), hex_color("#1d1916"))
    shades = ["#2b2622", "#2f2925", "#27221f"]
    stones = [(0, 0, 8, 8), (8, 0, 8, 8), (0, 8, 5, 8), (5, 8, 8, 8), (13, 8, 3, 8)]
    for sx, sy, w, h in stones:
        shade = hex_color(rng.choice(shades))
        for y in range(sy + 1, sy + h):
            for x in range(sx + 1, sx + w):
                if x < SIZE and y < SIZE:
                    image.putpixel((x, y), shade)
        for x in range(sx + 1, min(sx + w, SIZE)):
            image.putpixel((x, sy + 1), hex_color("#38312b"))
    return image


def pattern_tile(base, accent, pattern):
    image = Image.new("RGBA", (SIZE, SIZE), hex_color(base))
    for y in range(SIZE):
        for x in range(SIZE):
            if pattern(x, y):
                image.putpixel((x, y), hex_color(accent))
    return image


def make_tiles():
    rng = random.Random(42) # Toujours le même résultat.
    for i in range(3):
        save(earth_tile(rng), "tiles", "earth_%d.png" % i)
        save(floor_tile(rng), "tiles", "floor_%d.png" % i)
    for i in range(2):
        save(gold_tile(rng), "tiles", "gold_%d.png" % i)
        save(rock_tile(rng), "tiles", "rock_%d.png" % i)

    # Sols des salles.
    save(pattern_tile("#4f4020", "#6b5728", lambda x, y: x % 8 == 0 or y % 8 == 0), "tiles", "room_treasury.png")
    save(pattern_tile("#3d2f4d", "#4a3a5e", lambda x, y: (x + y) % 4 == 0), "tiles", "room_lair.png")
    save(pattern_tile("#33251a", "#2c4630", lambda x, y: y % 5 == 2 or (y % 5 == 3 and x % 3 == 0)),
         "tiles", "room_farm.png")


# ---------------------------------------------------------------------------
# Objets et décor (posés par-dessus le sol)
# ---------------------------------------------------------------------------

HEART = [
    "................",
    "................",
    ".......kk.......",
    "......krrk......",
    ".....krRRrk.....",
    "....krRWRrrk....",
    "...krRWRRrrrk...",
    "..krRRRRrrrrdk..",
    "..krrRRrrrrddk..",
    "...krrrrrrddk...",
    "....krrrrddk....",
    ".....krrddk.....",
    "......krdk......",
    ".......kk.......",
    "................",
    "................",
]
HEART_PALETTE = {"k": "#3b0a0a", "r": "#c62828", "R": "#ef5350", "W": "#ffcdd2", "d": "#8e1b1b"}

PORTAL = [
    "................",
    ".....kkkkkk.....",
    "...kkpppppPkk...",
    "..kpppPPPPPppk..",
    "..kpPPllllPPpk..",
    ".kpPPlllllllPpk.",
    ".kpPlllwwlllPpk.",
    ".kpPllwwwwllPpk.",
    ".kpPllwwwwllPpk.",
    ".kpPlllwwlllPpk.",
    ".kpPPlllllllPpk.",
    "..kpPPllllPPpk..",
    "..kppPPPPPPppk..",
    "...kkppppppkk...",
    ".....kkkkkk.....",
    "................",
]
PORTAL_PALETTE = {"k": "#1a0526", "p": "#4a148c", "P": "#7b1fa2", "l": "#ab47bc", "w": "#f3e5f5"}

ENTRANCE = [
    "................",
    "....ssssssss....",
    "...sSSSSSSSSs...",
    "..sSddddddddSs..",
    "..sSddddddddSs..",
    "..sSddddddddSs..",
    "..sSddddddddSs..",
    "..sSddddddddSs..",
    "..sSddddddddSs..",
    "..sSdddddddySs..",
    "..sSddddddddSs..",
    "..sSddddddddSs..",
    "..sSddddddddSs..",
    ".ssSSssssssSSss.",
    ".kkkkkkkkkkkkkk.",
    "................",
]
ENTRANCE_PALETTE = {"s": "#78909c", "S": "#b0bec5", "d": "#3e2723", "y": "#ffca28", "k": "#263238"}

BED = [
    "................",
    "................",
    "..kkkkkkkkkkkk..",
    "..kwwwwkhhhhhk..",
    "..kwWWwkhhhhhk..",
    "..kwwwwkhhhhhk..",
    "..kkkkkkhhhhhk..",
    "..kbbbbbbbbbbk..",
    "..kbBbbBbbBbbk..",
    "..kbbbbbbbbbbk..",
    "..kbBbbBbbBbbk..",
    "..kbbbbbbbbbbk..",
    "..kkkkkkkkkkkk..",
    "................",
    "................",
    "................",
]
BED_PALETTE = {"k": "#3e2723", "w": "#d7ccc8", "W": "#efebe9", "h": "#c8a165", "b": "#7e57c2", "B": "#5e35b1"}

MUSHROOM = [
    "..kkkk..",
    ".krRrrk.",
    "krWrrWrk",
    "kkkkkkkk",
    "..kssk..",
    "..kssk..",
    "..kSSk..",
    "...kk...",
]
MUSHROOM_PALETTE = {"k": "#3e1f1f", "r": "#e53935", "R": "#ef9a9a", "W": "#ffffff", "s": "#efebe9", "S": "#bcaaa4"}

COIN_SPOTS = [(6, 9), (3, 11), (9, 11), (5, 6), (9, 7)]


def coin_pile(count):
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    coin = from_ascii([
        ".kkkk.",
        "kyYYyk",
        "kyYyyk",
        "kyyyok",
        ".kkkk.",
    ], {"k": "#5d4037", "y": "#ffca28", "Y": "#fff59d", "o": "#f57f17"})
    for x, y in COIN_SPOTS[:count]:
        image.alpha_composite(coin, (x, y))
    return image


def make_props():
    save(from_ascii(HEART, HEART_PALETTE), "props", "heart.png")
    save(from_ascii(PORTAL, PORTAL_PALETTE), "props", "portal.png")
    save(from_ascii(ENTRANCE, ENTRANCE_PALETTE), "props", "entrance.png")
    save(from_ascii(BED, BED_PALETTE), "props", "bed.png")
    save(from_ascii(MUSHROOM, MUSHROOM_PALETTE), "props", "mushroom.png")
    for count in range(1, 6):
        save(coin_pile(count), "props", "gold_pile_%d.png" % count)


# ---------------------------------------------------------------------------
# Personnages (vus de face, 16 x 16)
# ---------------------------------------------------------------------------

CHARACTERS = {
    # L'ouvrier : un petit diablotin vert aux grandes oreilles.
    "worker": ([
        "................",
        "................",
        ".k............k.",
        ".kgk..kkkk...kgk",
        "..kgkkggggkkkgk.",
        "...kgggggggggk..",
        "....kgwkggwkgk..",
        "....kgkkggkkgk..",
        "....kggdddggk...",
        ".....kkggggkk...",
        "....kgkggggkgk..",
        "....kgkbbbbkgk..",
        ".....kbBbbBbk...",
        ".....kgk..kgk...",
        ".....kdk..kdk...",
        ".....kk....kk...",
    ], {"k": "#1b2b14", "g": "#7cb342", "d": "#4f7a26", "w": "#ffffff", "b": "#8d6e63", "B": "#5d4037"}),

    # Le kobold : petit lézard orange avec une queue.
    "kobold": ([
        "................",
        "................",
        "......kkkk......",
        ".....kooook.....",
        "....kooooook....",
        "....kowkkwok....",
        "....kooooook....",
        ".....kyyyyk.....",
        "....kkooookk....",
        "...kokyyyykok...",
        "...kokyyyykok...",
        "....kkooookkk...",
        ".....kooook.kok.",
        ".....kok.kok.kk.",
        ".....kOk.kOk....",
        ".....kk...kk....",
    ], {"k": "#3e1c00", "o": "#ff9800", "O": "#c66900", "y": "#ffe0b2", "w": "#ffffff"}),

    # L'orque : grand, vert foncé, avec des défenses.
    "orc": ([
        "................",
        ".....kkkkkk.....",
        "....kggggggk....",
        "...kgggggggk....",
        "...kgrkggrkgk...",
        "...kggggggggk...",
        "...kgwggggwgk...",
        "..kkkggkkggkkk..",
        ".kgkkbbbbbbkkgk.",
        ".kgkbbBbbBbbkgk.",
        ".kgkbbbbbbbbkgk.",
        ".kkkbbbbbbbbkkk.",
        "...kssssssssk...",
        "...kggk..kggk...",
        "...kddk..kddk...",
        "...kkk....kkk...",
    ], {"k": "#13200a", "g": "#4e7d2a", "d": "#33561a", "r": "#ff5252", "w": "#fffde7",
        "b": "#6d4c41", "B": "#9e9e9e", "s": "#3e2723"}),

    # Le sorcier : robe violette, capuche et bâton magique.
    "warlock": ([
        "...........y....",
        "......kk..yYy...",
        ".....kppk..k....",
        "....kppppk.k....",
        "...kppppppkk....",
        "...kpkkkkpkk....",
        "...kkcykyckk....",
        "....kkkkkkkk....",
        "...kppPPPppkk...",
        "..kpppPPPpppk...",
        "..kpkpPPPpkpk...",
        "..kskpPPPpkskk..",
        "...kpppPPpppk...",
        "...kpppPPpppkk..",
        "...kppppppppk...",
        "....kkkkkkkk....",
    ], {"k": "#1a0f26", "p": "#5e35b1", "P": "#8e6bd6", "c": "#2a1b3d", "y": "#ffee58",
        "Y": "#ffffff", "s": "#d7ccc8"}),

    # L'aventurier : tunique bleue et épée.
    "adventurer": ([
        "................",
        "......kkkk......",
        ".....khhhhk.....",
        "....khhhhhhk....",
        "....khsssshk....",
        "....ksksksk.....",
        "....kssssssk....",
        ".....kssssk.....",
        "....kkbbbbkk..k.",
        "...ksbbBBbbsk.kw",
        "...ksbbBBbbskkwk",
        "...kkbbbbbbkkwk.",
        "....kllllllkkk..",
        ".....kbk.kbk....",
        ".....kLk.kLk....",
        ".....kk...kk....",
    ], {"k": "#0d1b2a", "h": "#6d4c41", "s": "#ffccbc", "b": "#1e88e5", "B": "#90caf9",
        "l": "#5d4037", "L": "#3e2723", "w": "#eceff1"}),

    # La voleuse : capuche turquoise, cape et dague.
    "thief": ([
        "................",
        "......kkkk......",
        ".....kttttk.....",
        "....kttttttk....",
        "....ktkkkktk....",
        "....kksksskk....",
        "....ktssssttk...",
        "....kttsstttk...",
        "...kttTTTTttk...",
        "...ktkTTTTktk...",
        "...ksk TTkskkw..",
        "...kkkTTTTkkwk..",
        "....kTTTTTTkk...",
        ".....kTk.kTk....",
        ".....kdk.kdk....",
        ".....kk...kk....",
    ], {"k": "#06252a", "t": "#26a69a", "T": "#80deea", "s": "#ffccbc", "d": "#37474f",
        "w": "#eceff1"}),

    # Le chevalier : armure argentée, plumet rouge et bouclier.
    "knight": ([
        "......rr........",
        ".....rrkkk......",
        ".....kmmmmk.....",
        "....kmMMMMmk....",
        "....kmkkkkmk....",
        "....kmMMMMmk....",
        "....kmmmmmmk....",
        "..kkkkmmmmkkkk..",
        ".kbbbkMMMMkmmmk.",
        ".kbYbkmMMmkmMmk.",
        ".kbbbkmMMmkmmmk.",
        ".kkbkkmmmmkkkk..",
        "...kkmmmmmmk....",
        "....kmmk.kmmk...",
        "....kddk.kddk...",
        "....kkk...kkk...",
    ], {"k": "#1c2833", "m": "#90a4ae", "M": "#eceff1", "r": "#e53935", "b": "#1565c0",
        "Y": "#ffca28", "d": "#546e7a"}),
}


def make_characters():
    for name, (rows, palette) in CHARACTERS.items():
        rows = [r.replace(" ", ".") for r in rows]
        image = from_ascii(rows, palette)
        save(image, "units", "%s_0.png" % name)
        save(bob_frame(image), "units", "%s_1.png" % name)


# ---------------------------------------------------------------------------
# Défenses : pièges et porte
# ---------------------------------------------------------------------------

SPIKE_HOLES = [(4, 4), (8, 4), (12, 4), (6, 8), (10, 8), (4, 12), (8, 12), (12, 12)]


def spikes(raised):
    """Une plaque de métal percée ; si raised, des pointes sortent des trous."""
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(1, 15):
        for x in range(1, 15):
            border = x in (1, 14) or y in (1, 14)
            image.putpixel((x, y), hex_color("#263238" if border else "#546e7a"))
    for x, y in SPIKE_HOLES:
        image.putpixel((x, y), hex_color("#1c1c1c"))
        if raised:
            image.putpixel((x, y - 2), hex_color("#ffffff"))
            image.putpixel((x, y - 1), hex_color("#cfd8dc"))
            image.putpixel((x - 1, y), hex_color("#90a4ae"))
            image.putpixel((x, y), hex_color("#b0bec5"))
            image.putpixel((x + 1, y), hex_color("#78909c"))
    return image


def rune():
    """Un cercle magique orange gravé dans le sol."""
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow, core = hex_color("#ff6f00"), hex_color("#ffd54f")
    for y in range(SIZE):
        for x in range(SIZE):
            distance = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
            if 5.2 <= distance <= 6.4:
                image.putpixel((x, y), glow)
    for i in range(4, 12):
        image.putpixel((i, 7), core)   # trait horizontal
        image.putpixel((7, i), core)   # trait vertical
        image.putpixel((i, i), glow)   # diagonale
    return image


def door():
    """Une porte en bois vue de dessus, avec des bandes de fer et un cadre de pierre."""
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(SIZE):
        for x in range(SIZE):
            if x <= 1 or x >= 14:
                color = "#78909c" if (x in (0, 15) or y in (0, 15)) else "#b0bec5"
            elif y in (4, 11):
                color = "#37474f"           # bande de fer
            elif (x - 2) % 3 == 0:
                color = "#5d4037"           # séparation des planches
            else:
                color = "#8d6e63" if y % 5 else "#795548"
            image.putpixel((x, y), hex_color(color))
    for x in (3, 7, 12):
        image.putpixel((x, 4), hex_color("#b0bec5"))   # rivets
        image.putpixel((x, 11), hex_color("#b0bec5"))
    image.putpixel((11, 8), hex_color("#ffca28"))       # poignée
    return image


def make_defenses():
    save(spikes(False), "props", "spikes_down.png")
    save(spikes(True), "props", "spikes_up.png")
    save(rune(), "props", "rune.png")
    save(door(), "props", "door.png")


def main():
    make_tiles()
    make_props()
    make_characters()
    make_defenses()
    print("Images générées dans", ASSETS)


if __name__ == "__main__":
    main()
