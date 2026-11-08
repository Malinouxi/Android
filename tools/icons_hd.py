#!/usr/bin/env python3
"""Les ICÔNES HD de l'interface (128 x 128), dans le style « peinture » de l'interface.

REMPLACÉ par tools/blender/icons.py (icônes 3D de 256 x 256 rendues dans Blender) :
relancer ce script-ci écraserait les icônes Blender par les anciens dessins 2D.

Usage (depuis la racine du projet) :
    python3 tools/icons_hd.py

Chaque icône est dessinée 4 fois plus grande (512 x 512), puis réduite : les bords
sont alors bien lisses. Chaque pièce est remplie d'un dégradé (clair en haut,
sombre en bas), entourée d'un contour sombre, avec un reflet et une ombre portée.
Les images vont dans assets/icons_hd/<nom>.png.
"""

import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icons_hd")
BIG = 512   # Taille de travail.
SIZE = 128  # Taille finale.
OUTLINE = (20, 10, 8, 255)


def rgb(hex_color):
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class Icon:
    def __init__(self):
        self.image = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))

    def part(self, shape, xy, light, dark, outline=14, shine=True, **kwargs):
        """Une pièce : une forme (polygon, ellipse, rectangle, rounded_rectangle...)
        remplie d'un dégradé vertical, avec contour et reflet."""
        mask = Image.new("L", (BIG, BIG), 0)
        getattr(ImageDraw.Draw(mask), shape)(xy, fill=255, **kwargs)
        box = mask.getbbox()
        if box is None:
            return
        top, bottom = box[1], box[3]
        gradient = Image.new("RGBA", (BIG, BIG))
        g = ImageDraw.Draw(gradient)
        a, b = rgb(light), rgb(dark)
        for y in range(BIG):
            t = min(1.0, max(0.0, (y - top) / max(1, bottom - top)))
            g.line([(0, y), (BIG, y)], fill=tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4)))
        # Le contour : le masque élargi, en sombre, sous la pièce.
        if outline:
            grown = mask.filter(ImageFilter.MaxFilter(outline * 2 + 1))
            ring = Image.new("RGBA", (BIG, BIG), OUTLINE)
            self.image.paste(ring, (0, 0), grown)
        self.image.paste(gradient, (0, 0), mask)
        # Un reflet : le haut de la pièce, éclairci.
        if shine:
            eroded = mask.filter(ImageFilter.MinFilter(13))
            shifted = ImageChops.offset(eroded, 0, 18)
            highlight = ImageChops.subtract(eroded, shifted)
            light_layer = Image.new("RGBA", (BIG, BIG), (255, 255, 255, 90))
            self.image.paste(light_layer, (0, 0), highlight)

    def line(self, points, color, width):
        ImageDraw.Draw(self.image).line(points, fill=rgb(color), width=width, joint="curve")

    def dot(self, center, radius, color):
        x, y = center
        ImageDraw.Draw(self.image).ellipse([x - radius, y - radius, x + radius, y + radius], fill=rgb(color))

    def glow(self, center, radius, color):
        """Une lueur douce derrière l'icône."""
        layer = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
        x, y = center
        ImageDraw.Draw(layer).ellipse([x - radius, y - radius, x + radius, y + radius], fill=rgb(color)[:3] + (150,))
        layer = layer.filter(ImageFilter.GaussianBlur(radius * 0.35))
        self.image = Image.alpha_composite(layer, self.image)

    def finish(self):
        # Une ombre portée sous l'icône, puis la réduction (bords lisses).
        alpha = self.image.split()[3]
        shadow = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
        shadow.paste(Image.new("RGBA", (BIG, BIG), (0, 0, 0, 140)), (10, 16), alpha)
        shadow = shadow.filter(ImageFilter.GaussianBlur(10))
        result = Image.alpha_composite(shadow, self.image)
        return result.resize((SIZE, SIZE), Image.LANCZOS)


def rotate_points(points, angle, center=(256, 256)):
    cx, cy = center
    c, s = math.cos(angle), math.sin(angle)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in points]


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

def pickaxe():
    ic = Icon()
    ic.part("polygon", rotate_points([(236, 120), (276, 120), (276, 470), (236, 470)], 0.75), "#a1887f", "#5d4037")
    ic.part("polygon", rotate_points([(110, 150), (256, 95), (402, 150), (402, 178), (256, 140), (110, 178)], 0.75),
            "#cfd8dc", "#546e7a")
    return ic.finish()


def hand():
    ic = Icon()
    ic.glow((256, 270), 200, "#b71c1c")
    ic.part("rounded_rectangle", [150, 250, 370, 470], "#ef9a9a", "#b71c1c", radius=70)
    for i, (x, top) in enumerate([(160, 120), (215, 80), (270, 90), (325, 130)]):
        ic.part("rounded_rectangle", [x, top, x + 50, 300], "#ef9a9a", "#c62828", radius=25)
    ic.part("rounded_rectangle", [70, 250, 200, 310], "#ef9a9a", "#c62828", radius=28)
    return ic.finish()


def hammer():
    ic = Icon()
    ic.part("polygon", rotate_points([(236, 180), (276, 180), (276, 480), (236, 480)], -0.6), "#a1887f", "#4e342e")
    ic.part("polygon", rotate_points([(140, 90), (372, 90), (372, 200), (140, 200)], -0.6), "#b0bec5", "#455a64")
    return ic.finish()


def dagger():
    ic = Icon()
    ic.part("polygon", rotate_points([(236, 60), (256, 30), (276, 60), (276, 330), (236, 330)], 0.7), "#eceff1", "#78909c")
    ic.part("polygon", rotate_points([(176, 330), (336, 330), (336, 360), (176, 360)], 0.7), "#ffd54a", "#8d6e00")
    ic.part("polygon", rotate_points([(240, 360), (272, 360), (272, 470), (240, 470)], 0.7), "#6d4c41", "#3e2723")
    ic.dot(rotate_points([(256, 100)], 0.7)[0], 10, "#ff5252")
    return ic.finish()


# ---------------------------------------------------------------------------
# Salles
# ---------------------------------------------------------------------------

def chest():
    ic = Icon()
    ic.glow((256, 250), 190, "#ffb300")
    for i, (x, y) in enumerate([(170, 150), (250, 120), (330, 160), (210, 190), (300, 195)]):
        ic.part("ellipse", [x - 45, y - 30, x + 45, y + 30], "#fff59d", "#f9a825")
    ic.part("rounded_rectangle", [90, 210, 422, 450], "#a1662f", "#4e2a0e", radius=20)
    ic.part("rectangle", [90, 270, 422, 300], "#cfd8dc", "#546e7a")
    ic.part("rounded_rectangle", [226, 280, 286, 350], "#ffd54a", "#8d6e00", radius=10)
    return ic.finish()


def bed():
    ic = Icon()
    ic.part("rounded_rectangle", [60, 280, 452, 420], "#8d6e63", "#3e2723", radius=16)
    ic.part("rounded_rectangle", [80, 230, 440, 320], "#e8d9a8", "#a1887f", radius=20)
    ic.part("rounded_rectangle", [80, 190, 200, 290], "#ffffff", "#b0bec5", radius=30)
    ic.part("rounded_rectangle", [200, 220, 440, 330], "#9575cd", "#4527a0", radius=20)
    ic.part("rectangle", [60, 400, 100, 470], "#5d4037", "#2e1d16")
    ic.part("rectangle", [412, 400, 452, 470], "#5d4037", "#2e1d16")
    return ic.finish()


def mushroom():
    ic = Icon()
    ic.part("rounded_rectangle", [200, 260, 312, 470], "#fffde7", "#bcaaa4", radius=30)
    ic.part("pieslice", [60, 70, 452, 420], "#ff5252", "#8e1b1b", start=180, end=360)
    for x, y, r in [(150, 180, 28), (250, 130, 24), (350, 190, 30), (260, 220, 18)]:
        ic.dot((x, y), r, "#ffffff")
    return ic.finish()


def bookshelf():
    ic = Icon()
    ic.part("rounded_rectangle", [80, 50, 432, 470], "#8d6e63", "#3e2723", radius=12)
    colors = [("#ef5350", "#8e1b1b"), ("#42a5f5", "#0d47a1"), ("#66bb6a", "#1b5e20"), ("#ffca28", "#8d6e00"),
              ("#ab47bc", "#4a148c")]
    for row, top in enumerate([80, 210, 340]):
        ic.part("rectangle", [100, top, 412, top + 110], "#2a1c12", "#1a110b", outline=0, shine=False)
        x = 108
        i = row
        while x < 400:
            w = 36 + (i * 13) % 20
            light, dark = colors[i % len(colors)]
            ic.part("rectangle", [x, top + 12 + (i * 7) % 18, min(x + w, 404), top + 106], light, dark, outline=5)
            x += w + 6
            i += 1
    return ic.finish()


def anvil():
    ic = Icon()
    ic.glow((256, 230), 150, "#ff6d00")
    ic.part("polygon", [(60, 190), (380, 190), (460, 220), (380, 260), (320, 260), (300, 330), (210, 330),
                        (190, 260), (100, 260)], "#b0bec5", "#37474f")
    ic.part("rounded_rectangle", [170, 320, 340, 460], "#795548", "#3e2723", radius=10)
    ic.part("rounded_rectangle", [130, 160, 290, 195], "#ffab40", "#e65100", radius=10)
    for x, y in [(170, 110), (230, 80), (300, 100), (350, 130)]:
        ic.dot((x, y), 9, "#fff176")
    return ic.finish()


def dummy():
    ic = Icon()
    ic.part("rectangle", [240, 260, 272, 470], "#6d4c41", "#3e2723")
    ic.part("rounded_rectangle", [90, 210, 422, 250], "#8d6e63", "#4e342e", radius=10)
    ic.part("ellipse", [160, 180, 352, 380], "#e8c886", "#a0782f")
    ic.part("ellipse", [196, 60, 316, 180], "#e8c886", "#a0782f")
    ic.part("ellipse", [215, 235, 297, 317], "#ff5252", "#8e1b1b")
    ic.part("ellipse", [240, 260, 272, 292], "#ffffff", "#ffcdd2")
    return ic.finish()


def cage():
    ic = Icon()
    ic.part("rounded_rectangle", [80, 60, 432, 100], "#78909c", "#37474f", radius=10)
    ic.part("rounded_rectangle", [80, 420, 432, 460], "#78909c", "#37474f", radius=10)
    for x in range(110, 420, 60):
        ic.part("rounded_rectangle", [x, 90, x + 24, 430], "#cfd8dc", "#455a64", radius=10)
    ic.part("rounded_rectangle", [80, 245, 432, 275], "#90a4ae", "#455a64", radius=8)
    return ic.finish()


def temple():
    ic = Icon()
    ic.glow((256, 200), 170, "#7c4dff")
    ic.part("rectangle", [100, 250, 412, 450], "#9e9e9e", "#424242")
    ic.part("rectangle", [70, 220, 442, 270], "#bdbdbd", "#616161")
    ic.part("rectangle", [200, 270, 312, 450], "#9c27b0", "#4a148c")
    ic.part("rectangle", [244, 290, 268, 410], "#ffd54a", "#8d6e00", outline=6)
    ic.part("rectangle", [214, 320, 298, 344], "#ffd54a", "#8d6e00", outline=6)
    for x in (110, 380):
        ic.part("rectangle", [x, 120, x + 30, 220], "#fafafa", "#bdbdbd", outline=8)
        ic.part("ellipse", [x - 2, 70, x + 32, 125], "#ffeb3b", "#ff6f00", outline=6)
    return ic.finish()


def tomb():
    ic = Icon()
    ic.glow((256, 230), 170, "#76ff03")
    ic.part("pieslice", [140, 60, 372, 290], "#b0bec5", "#546e7a", start=180, end=360)
    ic.part("rectangle", [140, 175, 372, 420], "#b0bec5", "#546e7a")
    ic.part("rectangle", [240, 200, 272, 360], "#455a64", "#263238", outline=0)
    ic.part("rectangle", [195, 245, 317, 277], "#455a64", "#263238", outline=0)
    ic.part("rounded_rectangle", [80, 410, 432, 470], "#6d4c41", "#3e2723", radius=20)
    return ic.finish()


def graveyard():
    return tomb()


# ---------------------------------------------------------------------------
# Défenses
# ---------------------------------------------------------------------------

def spikes():
    ic = Icon()
    ic.part("rounded_rectangle", [60, 380, 452, 450], "#78909c", "#37474f", radius=10)
    for x in range(90, 430, 80):
        ic.part("polygon", [(x, 390), (x + 60, 390), (x + 30, 90)], "#eceff1", "#607d8b")
    return ic.finish()


def rune():
    ic = Icon()
    ic.glow((256, 256), 220, "#ff6f00")
    d = ImageDraw.Draw(ic.image)
    d.ellipse([50, 50, 462, 462], outline=rgb("#ff9100"), width=26)
    d.ellipse([120, 120, 392, 392], outline=rgb("#ffd54a"), width=12)
    star = [(256 + 180 * math.cos(math.radians(-90 + i * 144)), 256 + 180 * math.sin(math.radians(-90 + i * 144)))
            for i in range(6)]
    d.line(star, fill=rgb("#fff59d"), width=14, joint="curve")
    ic.dot((256, 256), 30, "#ffffff")
    return ic.finish()


def door():
    ic = Icon()
    ic.part("rounded_rectangle", [80, 60, 432, 470], "#90a4ae", "#37474f", radius=150)
    ic.part("rounded_rectangle", [130, 110, 382, 470], "#8d6e63", "#3e2723", radius=120)
    for y in (220, 360):
        ic.part("rectangle", [130, y, 382, y + 26], "#546e7a", "#263238", outline=6)
    ic.dot((330, 300), 18, "#ffd54a")
    return ic.finish()


def sacrifice_altar():
    ic = Icon()
    ic.glow((256, 250), 180, "#d50000")
    ic.part("rounded_rectangle", [80, 260, 432, 450], "#4a4a52", "#141418", radius=12)
    ic.part("rounded_rectangle", [50, 220, 462, 280], "#6a6a74", "#25252b", radius=12)
    ic.part("ellipse", [190, 90, 322, 220], "#f5f5f5", "#9e9e9e")
    ic.dot((228, 150), 18, "#ff1744")
    ic.dot((284, 150), 18, "#ff1744")
    ic.part("rectangle", [70, 240, 442, 256], "#ff1744", "#b71c1c", outline=0)
    return ic.finish()


def brazier():
    ic = Icon()
    ic.glow((256, 200), 190, "#ff3d00")
    # Trois pieds en fer, la vasque en pierre, et le feu rouge du cœur.
    ic.line([(170, 450), (220, 330)], "#2a2a30", 26)
    ic.line([(342, 450), (292, 330)], "#2a2a30", 26)
    ic.line([(256, 460), (256, 330)], "#2a2a30", 26)
    ic.part("polygon", [(120, 250), (392, 250), (350, 340), (162, 340)], "#7a7a84", "#2e2e34")
    ic.part("rounded_rectangle", [104, 232, 408, 262], "#9a9aa4", "#4a4a52", radius=10)
    ic.part("polygon", [(160, 240), (200, 130), (230, 180), (256, 60), (290, 170), (320, 120), (352, 240)],
            "#ffab40", "#d50000", shine=False)
    ic.part("polygon", [(210, 240), (240, 170), (256, 120), (276, 175), (304, 240)], "#fff59d", "#ff6d00",
            outline=0, shine=False)
    return ic.finish()


# ---------------------------------------------------------------------------
# Sorts et compteurs
# ---------------------------------------------------------------------------

def heal():
    ic = Icon()
    ic.glow((256, 256), 220, "#00e676")
    ic.part("rounded_rectangle", [196, 70, 316, 442], "#b9f6ca", "#00a152", radius=30)
    ic.part("rounded_rectangle", [70, 196, 442, 316], "#b9f6ca", "#00a152", radius=30)
    return ic.finish()


def bolt():
    ic = Icon()
    ic.glow((256, 256), 220, "#ffea00")
    ic.part("polygon", [(300, 30), (110, 290), (240, 290), (190, 480), (400, 200), (270, 200), (340, 30)],
            "#fffde7", "#ffab00")
    return ic.finish()


def haste():
    ic = Icon()
    ic.glow((256, 256), 200, "#00e5ff")
    for i, y in enumerate([150, 256, 362]):
        ic.part("polygon", [(60 + i * 40, y - 22), (300, y - 22), (300, y - 60), (452, y), (300, y + 60),
                            (300, y + 22), (60 + i * 40, y + 22)], "#e0f7fa", "#0097a7")
    return ic.finish()


def mana():
    ic = Icon()
    ic.glow((256, 300), 190, "#2979ff")
    ic.part("polygon", [(256, 40), (390, 260), (420, 330), (390, 410), (256, 470), (122, 410), (92, 330),
                        (122, 260)], "#82b1ff", "#0d47a1")
    return ic.finish()


def blood():
    ic = Icon()
    ic.glow((256, 300), 190, "#ff1744")
    ic.part("polygon", [(256, 40), (390, 260), (420, 330), (390, 410), (256, 470), (122, 410), (92, 330),
                        (122, 260)], "#ff5252", "#7f0000")
    return ic.finish()


def gold():
    ic = Icon()
    ic.glow((256, 256), 210, "#ffc400")
    for x, y in [(190, 330), (320, 330), (256, 210)]:
        ic.part("ellipse", [x - 110, y - 110, x + 110, y + 110], "#fff59d", "#c79100")
        ic.part("ellipse", [x - 70, y - 70, x + 70, y + 70], "#ffd54a", "#f9a825", outline=6)
    return ic.finish()


def skull():
    ic = Icon()
    ic.part("ellipse", [100, 50, 412, 360], "#f5f5f5", "#9e9e9e")
    ic.part("rounded_rectangle", [170, 300, 342, 450], "#eeeeee", "#9e9e9e", radius=30)
    ic.dot((195, 230), 50, "#1a1a1a")
    ic.dot((317, 230), 50, "#1a1a1a")
    for x in range(200, 330, 40):
        ic.part("rectangle", [x, 380, x + 22, 450], "#1a1a1a", "#1a1a1a", outline=0, shine=False)
    return ic.finish()


def demon():
    """Le maître : une tête de démon (emblème du jeu)."""
    ic = Icon()
    ic.glow((256, 270), 230, "#d50000")
    ic.part("polygon", [(130, 200), (40, 40), (190, 150)], "#e0e0e0", "#757575")
    ic.part("polygon", [(382, 200), (472, 40), (322, 150)], "#e0e0e0", "#757575")
    ic.part("ellipse", [110, 110, 402, 450], "#ef5350", "#8e1b1b")
    ic.part("polygon", [(160, 230), (240, 260), (160, 270)], "#ffeb3b", "#ff6f00", outline=6)
    ic.part("polygon", [(352, 230), (272, 260), (352, 270)], "#ffeb3b", "#ff6f00", outline=6)
    ic.part("rounded_rectangle", [180, 330, 332, 400], "#3b0a0a", "#1a0505", radius=20, shine=False)
    for x in range(195, 320, 34):
        ic.part("polygon", [(x, 330), (x + 24, 330), (x + 12, 365)], "#ffffff", "#e0e0e0", outline=3, shine=False)
    return ic.finish()


def worker():
    ic = Icon()
    ic.part("polygon", [(140, 230), (30, 150), (150, 290)], "#9ccc65", "#33691e")
    ic.part("polygon", [(372, 230), (482, 150), (362, 290)], "#9ccc65", "#33691e")
    ic.part("ellipse", [120, 110, 392, 430], "#9ccc65", "#33691e")
    ic.dot((205, 250), 30, "#ffeb3b")
    ic.dot((307, 250), 30, "#ffeb3b")
    ic.part("rounded_rectangle", [200, 330, 312, 360], "#33691e", "#1b3d0e", radius=10, shine=False)
    return ic.finish()


def heart():
    ic = Icon()
    ic.glow((256, 256), 230, "#ff1744")
    ic.part("polygon", [(256, 40), (420, 160), (380, 360), (256, 470), (132, 360), (92, 160)], "#ff5252", "#7f0000")
    ic.part("polygon", [(256, 70), (380, 165), (256, 230), (132, 165)], "#ff8a80", "#e53935", outline=0)
    return ic.finish()


def hourglass():
    ic = Icon()
    ic.part("rounded_rectangle", [110, 40, 402, 90], "#8d6e63", "#3e2723", radius=12)
    ic.part("rounded_rectangle", [110, 420, 402, 470], "#8d6e63", "#3e2723", radius=12)
    ic.part("polygon", [(150, 90), (362, 90), (270, 256), (362, 420), (150, 420), (242, 256)], "#e1f5fe", "#81d4fa")
    ic.part("polygon", [(190, 360), (322, 360), (350, 415), (162, 415)], "#ffd54a", "#c79100", outline=0)
    return ic.finish()


def pause():
    ic = Icon()
    ic.part("rounded_rectangle", [140, 100, 230, 412], "#eceff1", "#90a4ae", radius=16)
    ic.part("rounded_rectangle", [282, 100, 372, 412], "#eceff1", "#90a4ae", radius=16)
    return ic.finish()


ICONS = {
    "pickaxe": pickaxe, "hand": hand, "hammer": hammer, "dagger": dagger,
    "chest": chest, "bed": bed, "mushroom": mushroom, "bookshelf": bookshelf, "anvil": anvil,
    "dummy": dummy, "cage": cage, "temple": temple, "tomb": tomb,
    "spikes": spikes, "rune": rune, "door": door, "sacrifice_altar": sacrifice_altar,
    "heal": heal, "bolt": bolt, "haste": haste, "mana": mana, "blood": blood, "gold": gold,
    "skull": skull, "demon": demon, "worker": worker, "heart": heart, "hourglass": hourglass,
    "pause": pause, "brazier": brazier,
}


def make_all():
    os.makedirs(OUT, exist_ok=True)
    for name, draw in ICONS.items():
        draw().save(os.path.join(OUT, name + ".png"))
    print("Icônes HD générées dans", OUT)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1: # Seulement certaines icônes : python3 tools/icons_hd.py brazier
        os.makedirs(OUT, exist_ok=True)
        for name in sys.argv[1:]:
            ICONS[name]().save(os.path.join(OUT, name + ".png"))
    else:
        make_all()
