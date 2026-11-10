"""Découpe les ICÔNES PEINTES du HUD dans les planches de référence (tools/reference/).

hud_panel.png range ses icônes dans des cadres de pierre, sur 5 rangées de 10 : on
découpe l'intérieur de chaque cadre utile. hud_panel_2.png pose 13 objets sur un
fond sombre, sans cadre : on découpe un carré autour de chacun. Chaque image est
mise à 256 pixels et ses bords sont adoucis (coins arrondis, fondu), pour qu'elle
se pose proprement dans les boutons du jeu, qui ont déjà leur propre cadre.

Résultat : assets/icons_panel/<nom>.png. Le jeu prend d'abord une icône de ce
dossier, sinon celle d'assets/icons_hd/ (voir Hud.hd dans scripts/hud.gd).

Usage : python3 tools/panel_icons.py            (il faut Pillow)
        python3 tools/panel_icons.py <dossier>  (une planche de contrôle en plus)
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REFERENCE = os.path.join(ROOT, "tools", "reference")
OUT = os.path.join(ROOT, "assets", "icons_panel")

SIZE = 256      # Taille des images (comme assets/icons_hd).
RADIUS = 30     # Coins arrondis (pixels de l'image finale).
FEATHER = 5     # Fondu des bords (pixels de l'image finale).

# nom -> (gauche, haut, droite, bas) : l'intérieur du cadre, en pixels de la planche.
# Rangée 1 et 2 : « Instructions / Construction » ; 3 et 4 : « Sorts » ; 5 : « Commandes ».
BOXES = {
    "pickaxe": (75, 105, 169, 190),          # Creuser
    "tools": (223, 105, 312, 190),           # Construire
    "wrecking_ball": (364, 105, 460, 193),   # Démolir
    "door": (510, 107, 598, 192),            # Porte
    "wall": (647, 104, 742, 188),            # Mur
    "spikes": (790, 106, 883, 188),          # Piège
    "tower": (938, 105, 1032, 190),          # Tour
    "sacrifice_altar": (1077, 103, 1172, 188),  # Bassin de sang
    "mana_well": (1227, 102, 1320, 188),     # Réservoir de mana
    "throne": (1368, 101, 1462, 188),        # Salle du trône
    "cage": (79, 266, 169, 348),             # Salle des créatures
    "spell_room": (219, 266, 314, 348),      # Salle des sorts
    "chest": (365, 267, 459, 348),           # Stockage
    "gold": (506, 268, 600, 348),            # Trésorerie
    "torture": (647, 267, 740, 348),         # Chambre de souffrance
    "demon_statue": (790, 268, 883, 349),    # Statue démoniaque
    "arch": (936, 267, 1020, 349),           # Entrée du donjon
    "demon": (70, 507, 161, 587),            # Colère démoniaque
    "summon": (217, 507, 304, 587),          # Invocation de créature
    "blood": (356, 505, 449, 582),           # Drain de vie
    "shield": (502, 507, 594, 588),          # Sort de protection
    "quake": (647, 503, 742, 588),           # Tremblement de terre
    "brazier": (795, 505, 888, 589),         # Explosion chaotique
    "portal": (1087, 506, 1178, 583),        # Téléportation
    "madness": (1375, 506, 1468, 587),       # Folie
    "skull": (71, 657, 164, 732),            # Malédiction
    "heal": (214, 657, 304, 732),            # Soin démoniaque
    "hourglass": (358, 657, 448, 734),       # Ralentissement
    "eye": (502, 658, 598, 736),             # Révélations
    "fire_rain": (795, 659, 888, 734),       # Pluie de feu
    "storm": (943, 659, 1035, 736),          # Tempête de ténèbres
    "panic": (1089, 654, 1183, 735),         # Vent de panique
    "chains": (1239, 657, 1331, 736),        # Paralysie
    "pentagram": (1376, 655, 1469, 735),     # Bénédiction du démon
    "move": (216, 872, 305, 951),            # Déplacer
    "pause": (1089, 872, 1179, 951),         # Pause
    "fast": (1236, 872, 1327, 951),          # Vitesse rapide
    "scroll": (1374, 873, 1460, 951),        # Menu
}

# La deuxième planche (hud_panel_2.png) : nom -> (gauche, haut, droite, bas), un carré par objet.
BOXES_2 = {
    "bed": (15, 28, 335, 348),
    "mushroom": (328, 45, 618, 335),
    "bookshelf": (596, 12, 926, 342),
    "anvil": (922, 40, 1232, 350),
    "dummy": (1226, 22, 1536, 352),
    "tomb": (5, 362, 325, 682),
    "mug": (322, 378, 622, 678),
    "salve": (578, 368, 878, 678),
    "coin_press": (862, 362, 1198, 698),
    "sarcophagus": (1200, 372, 1530, 702),
    "whip": (15, 690, 345, 1020),
    "feast": (366, 672, 752, 1024),
    "raise": (810, 688, 1146, 1024),
}


def _mask(width, height):
    """Le masque des bords : coins arrondis, puis un léger fondu vers la transparence."""
    mask = Image.new("L", (width, height), 0)
    inset = FEATHER
    ImageDraw.Draw(mask).rounded_rectangle((inset, inset, width - 1 - inset, height - 1 - inset), RADIUS, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(FEATHER / 2.0))


def cut(panel, box):
    tile = panel.crop(box)
    scale = SIZE / max(tile.size)
    width, height = round(tile.width * scale), round(tile.height * scale)
    tile = tile.resize((width, height), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 60, 2))
    tile.putalpha(_mask(width, height))
    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    icon.paste(tile, ((SIZE - width) // 2, (SIZE - height) // 2))
    return icon


def main():
    os.makedirs(OUT, exist_ok=True)
    icons = {}
    for file_name, boxes in (("hud_panel.png", BOXES), ("hud_panel_2.png", BOXES_2)):
        panel = Image.open(os.path.join(REFERENCE, file_name)).convert("RGB")
        for name, box in boxes.items():
            icons[name] = cut(panel, box)
            icons[name].save(os.path.join(OUT, name + ".png"), optimize=True)
    print("%d icônes dans %s" % (len(icons), OUT))
    if len(sys.argv) > 1:  # Planche de contrôle : toutes les icônes sur un fond de bouton.
        columns = 8
        rows = (len(icons) + columns - 1) // columns
        sheet = Image.new("RGB", (columns * 200, rows * 200), (58, 44, 40))
        for index, name in enumerate(icons):
            small = icons[name].resize((192, 192), Image.LANCZOS)
            sheet.paste(small, (index % columns * 200 + 4, index // columns * 200 + 4), small)
        os.makedirs(sys.argv[1], exist_ok=True)
        sheet.save(os.path.join(sys.argv[1], "icons_panel.png"))


if __name__ == "__main__":
    main()
