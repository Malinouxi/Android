"""Les TEXTURES PEINTES des modèles (256 x 256, raccordables), calculées avec numpy.

Elles sont plutôt claires et peu colorées : la couleur vient du matériau, qui
les multiplie (une même pierre sert pour un autel gris et une forge brune).
Utilisées par lowpoly.material(..., texture="stone") ; aussi exportées en PNG
pour les murs et les sols du jeu (export_tiles).

  stone     : moellons irréguliers, joints creusés, arêtes éclairées
  flagstone : grandes dalles usées (sols)
  planks    : planches à veines et rainures sombres
  grain     : bois veiné sans planches (poteaux, meubles)
  metal     : fer martelé, rayures
  gold      : pièces d'or entassées
  cloth     : tissu tramé
  straw     : paille en brins
  leather   : cuir marbré
  rough     : pierre brute / terre
  slime     : liquide tourbillonnant (chaudrons, bassins)
"""

import math
import os

import numpy as np

S = 256


def _rng(seed):
    return np.random.default_rng(seed)


def _smooth_noise(rng, cells, size=S):
    """Bruit doux et raccordable : une grille aléatoire agrandie (interpolation cosinus)."""
    grid = rng.random((cells, cells))
    coords = np.arange(size) * cells / size
    i0 = np.floor(coords).astype(int)
    t = coords - i0
    t = (1 - np.cos(t * math.pi)) / 2
    i1 = (i0 + 1) % cells
    rows = grid[i0][:, i0] * (1 - t)[None, :] + grid[i0][:, i1] * t[None, :]
    rows1 = grid[i1][:, i0] * (1 - t)[None, :] + grid[i1][:, i1] * t[None, :]
    return rows * (1 - t)[:, None] + rows1 * t[:, None]


def _fbm(rng, octaves=(4, 8, 16, 32), weights=(0.45, 0.28, 0.17, 0.1)):
    out = np.zeros((S, S))
    for cells, weight in zip(octaves, weights):
        out += _smooth_noise(rng, cells) * weight
    return out


def _blocks(rng, rows, min_w, max_w, mortar=0.06):
    """Une maçonnerie raccordable : pour chaque pixel, l'identifiant de son bloc et
    sa distance (0..1) au bord le plus proche."""
    block_id = np.zeros((S, S), dtype=int)
    edge = np.zeros((S, S))
    h = S // rows
    ys = np.arange(S)
    xs = np.arange(S)
    next_id = 0
    for r in range(rows):
        widths = []
        while S - sum(widths) > max_w:
            widths.append(int(rng.integers(min_w, max_w)))
        widths.append(S - sum(widths))  # Le dernier bloc comble la rangée.
        if widths[-1] < min_w // 2 and len(widths) > 1:
            widths[-2] += widths.pop()
        offset = int(rng.integers(0, S))
        start = 0
        for w in widths:
            cols = (xs[start:start + w] + offset) % S
            y0, y1 = r * h, (r + 1) * h
            local_x = np.arange(w)
            dx = np.minimum(local_x + 0.5, w - local_x - 0.5) / (h * 0.5)
            dy = np.minimum(ys[y0:y1] - y0 + 0.5, y1 - ys[y0:y1] - 0.5) / (h * 0.5)
            d = np.minimum(dy[:, None], dx[None, :])
            block_id[y0:y1][:, cols] = next_id
            edge[y0:y1][:, cols] = d
            next_id += 1
            start += w
    return block_id, edge


def _masonry(seed, rows, min_w, max_w, base=0.8, joint=0.22, bevel=0.16, variation=0.24):
    rng = _rng(seed)
    block_id, edge = _blocks(rng, rows, min_w, max_w)
    tones = 1.0 + rng.uniform(-variation, variation, block_id.max() + 1)
    noise = _fbm(rng, (4, 8, 16, 64), (0.3, 0.3, 0.2, 0.2))
    # Chaque pierre a sa propre « bosse » : plus claire au centre, plus sombre aux bords.
    value = base * tones[block_id] * (0.62 + 0.6 * noise) * (0.82 + 0.18 * np.clip(edge * 2, 0, 1))
    # Le joint creusé, puis un biseau éclairé en haut à gauche, ombré en bas à droite.
    inside = np.clip((edge - 0.08) / 0.18, 0, 1)
    value = joint + (value - joint) * inside
    grad_y = np.roll(edge, 1, axis=0) - np.roll(edge, -1, axis=0)
    grad_x = np.roll(edge, 1, axis=1) - np.roll(edge, -1, axis=1)
    rim = np.clip(1 - edge / 0.35, 0, 1) * (edge > 0.08)
    value += bevel * rim * np.sign(grad_y + grad_x) * -1
    # Des fissures et des taches de mousse sombre.
    cracks = _smooth_noise(rng, 24)
    value *= 1 - 0.3 * (np.abs(cracks - 0.5) < 0.004) * (edge > 0.2)
    return np.clip(value, 0, 1)


def stone():
    return _masonry(1, rows=5, min_w=55, max_w=110)


def flagstone():
    return _masonry(2, rows=2, min_w=100, max_w=180, base=0.8, bevel=0.1, variation=0.14)


def _wood(seed, planks):
    rng = _rng(seed)
    y = np.arange(S)[:, None] / S
    x = np.arange(S)[None, :] / S
    warp = _fbm(rng, (4, 8), (0.7, 0.3))
    rings = np.sin((x * 3 + warp * 2.2) * math.pi * 10 + y * 2)
    grain = 0.78 + 0.1 * rings + 0.12 * _fbm(rng, (8, 64), (0.4, 0.6))
    if planks:
        lanes = (np.arange(S) * planks // S)
        tone = 1 + rng.uniform(-0.12, 0.12, planks)
        grain = grain * tone[lanes][:, None]
        seam = (np.arange(S) % (S // planks))
        grain[(seam < 3) | (seam > S // planks - 2), :] *= 0.45
        # Des clous aux extrémités.
        for k in range(planks):
            for cx in (int(S * 0.15), int(S * 0.85)):
                cy = int((k + 0.5) * S / planks)
                grain[cy - 2:cy + 2, cx - 2:cx + 2] = 0.35
    return np.clip(grain, 0, 1)


def planks():
    return _wood(3, planks=4)


def grain():
    return _wood(4, planks=0)


def metal():
    rng = _rng(5)
    value = 0.72 + 0.18 * _fbm(rng, (6, 12, 48), (0.4, 0.35, 0.25))
    # Coups de marteau : des cuvettes légèrement plus claires au centre.
    for _ in range(40):
        cx, cy, r = rng.integers(0, S), rng.integers(0, S), rng.integers(8, 20)
        yy, xx = np.ogrid[:S, :S]
        d = np.sqrt(((xx - cx + S // 2) % S - S // 2) ** 2 + ((yy - cy + S // 2) % S - S // 2) ** 2) / r
        value += 0.06 * np.clip(1 - d, 0, 1) ** 2
    for _ in range(25):  # Rayures.
        x0, y0 = rng.integers(0, S, 2)
        angle, length = rng.uniform(0, math.pi), rng.integers(20, 80)
        for t in range(length):
            x = int(x0 + t * math.cos(angle)) % S
            y = int(y0 + t * math.sin(angle)) % S
            value[y, x] += 0.12
    return np.clip(value, 0, 1)


def gold():
    rng = _rng(6)
    value = 0.55 + 0.15 * _fbm(rng)
    yy, xx = np.ogrid[:S, :S]
    for _ in range(170):
        cx, cy = rng.integers(0, S, 2)
        r = rng.integers(9, 16)
        dx = (xx - cx + S // 2) % S - S // 2
        dy = ((yy - cy + S // 2) % S - S // 2) * rng.uniform(1.0, 1.6)  # Pièces vues de biais.
        d = np.sqrt(dx ** 2 + dy ** 2) / r
        coin = d < 1
        light = 0.82 + 0.25 * np.clip(-(dx + dy) / (r * 1.4), -1, 1)
        rim = (d > 0.78) & coin
        value = np.where(coin, np.where(rim, 0.98, light), value)
    return np.clip(value, 0, 1)


def cloth():
    rng = _rng(7)
    x = np.arange(S)
    weave = (np.sin(x * math.pi / 2)[None, :] * np.sin(x * math.pi / 2)[:, None])
    value = 0.82 + 0.06 * weave + 0.14 * (_fbm(rng) - 0.5)
    value += 0.05 * np.sin(np.arange(S)[:, None] / S * math.pi * 6 + _fbm(rng, (4,), (1,)) * 4)
    return np.clip(value, 0, 1)


def straw():
    rng = _rng(8)
    value = np.full((S, S), 0.7)
    for _ in range(500):
        x0, y0 = rng.integers(0, S, 2)
        angle = rng.normal(0.25, 0.35)
        length = rng.integers(25, 90)
        tone = rng.uniform(0.75, 1.0)
        for t in range(length):
            x = int(x0 + t * math.cos(angle)) % S
            y = int(y0 + t * math.sin(angle)) % S
            value[y, x] = tone
            value[(y + 1) % S, x] = tone * 0.8
    return np.clip(value, 0, 1)


def leather():
    rng = _rng(9)
    return np.clip(0.74 + 0.22 * (_fbm(rng, (8, 16, 64), (0.3, 0.3, 0.4)) - 0.5) * 2 * 0.6, 0, 1)


def rough():
    rng = _rng(10)
    value = 0.62 + 0.38 * _fbm(rng, (4, 8, 16, 64), (0.35, 0.3, 0.2, 0.15))
    return np.clip(value, 0, 1)


def slime():
    rng = _rng(11)
    warp = _fbm(rng, (4, 8), (0.6, 0.4))
    x = np.arange(S)[None, :] / S
    y = np.arange(S)[:, None] / S
    swirl = np.sin((x + warp) * math.pi * 6) * np.sin((y + warp * 0.7) * math.pi * 6)
    value = 0.72 + 0.2 * swirl + 0.1 * _fbm(rng)
    # Des bulles claires.
    yy, xx = np.ogrid[:S, :S]
    for _ in range(30):
        cx, cy, r = rng.integers(0, S), rng.integers(0, S), rng.integers(3, 9)
        d = np.sqrt(((xx - cx + S // 2) % S - S // 2) ** 2 + ((yy - cy + S // 2) % S - S // 2) ** 2) / r
        value = np.where(d < 1, np.maximum(value, 0.95 - 0.3 * d), value)
    return np.clip(value, 0, 1)


GENERATORS = {
    "stone": stone, "flagstone": flagstone, "planks": planks, "grain": grain, "metal": metal,
    "gold": gold, "cloth": cloth, "straw": straw, "leather": leather, "rough": rough, "slime": slime,
}
## La taille (en mètres) d'une répétition de chaque texture sur les objets.
TILE = {
    "stone": 0.8, "flagstone": 1.0, "planks": 0.8, "grain": 0.5, "metal": 0.5, "gold": 0.5,
    "cloth": 0.5, "straw": 0.6, "leather": 0.4, "rough": 0.8, "slime": 0.6,
}

_cache = {}


def values(name):
    if name not in _cache:
        _cache[name] = GENERATORS[name]()
    return _cache[name]


def linear_mean(name):
    """La moyenne de la texture en lumière linéaire (pour compenser l'assombrissement)."""
    v = values(name)
    return float(np.mean(np.where(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)))


def blender_image(name, tint=None):
    """L'image Blender (raccordable) de la texture, créée une seule fois et rangée
    dans le fichier .blend (pour qu'elle soit intégrée au .glb). Grise, ou teintée
    par « tint » (« rrggbb », pour les lueurs)."""
    import bpy
    image_name = "tex_" + name + ("_" + tint if tint else "")
    image = bpy.data.images.get(image_name)
    if image is not None:
        return image
    value = values(name)
    image = bpy.data.images.new(image_name, S, S, alpha=False)
    rgba = np.ones((S, S, 4), dtype=np.float32)
    # La couleur de l'image est en sRGB : on garde les valeurs telles quelles.
    color = [int(tint[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] if tint else (1.0, 1.0, 1.0)
    for c in range(3):
        rgba[:, :, c] = value[::-1] * color[c]
    image.pixels.foreach_set(rgba.ravel())
    image.file_format = "PNG"
    image.pack()
    return image


def save_png(name, path, tint=(1.0, 1.0, 1.0)):
    """Enregistre la texture teintée en PNG (pour les murs et les sols du jeu)."""
    import bpy
    value = values(name)
    image = bpy.data.images.new("png_" + name, S, S, alpha=False)
    rgba = np.ones((S, S, 4), dtype=np.float32)
    for c in range(3):
        rgba[:, :, c] = np.clip(value[::-1] * tint[c], 0, 1)
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)
    print("Texture :", path)
