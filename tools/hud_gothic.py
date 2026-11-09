#!/usr/bin/env python3
"""Les cadres du HUD « pierre et braise » (remplace le rendu Blender de tools/blender/hud.py).

Style : pierre sombre fissurée, arêtes léchées par la lueur orange des braises,
liseré rouge à l'intérieur, cornes d'os aux coins et sur le médaillon.
Tout est calculé avec numpy (bruit, relief, éclairage) : pas besoin de Blender.

    python3 tools/hud_gothic.py            # écrit dans assets/ui_hd/
    python3 tools/hud_gothic.py --out DIR  # ailleurs (pour comparer)

Les cadres sont découpés en 9 zones par le jeu (voir scripts/ui.gd, HD_MARGINS) :
les bords se RÉPÈTENT. Le bruit de la pierre est donc périodique, de période
« taille - 2 x marge », et calé sur la marge : les répétitions se raccordent.
Les images sont rendues au double de leur taille d'affichage (Ui.hd_texture).
"""

import argparse
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZES = {"panel": 256, "slot": 128, "button": 128, "bubble": 128, "medallion": 512}
MARGINS = {"panel": 64, "slot": 32, "button": 32, "bubble": 32}  # = HD_MARGINS de ui.gd

LIGHT = np.array([-0.45, -0.6, 0.66])      # La lumière principale, en haut à gauche.
EMBER_DIR = np.array([0.15, 0.75, 0.35])   # La lueur des braises, par en dessous.
STONE_DARK = np.array([34, 27, 25], float)
STONE_LIGHT = np.array([128, 104, 88], float)
EMBER = np.array([255, 96, 28], float)
RED_LINE = np.array([170, 28, 20], float)
BONE = np.array([226, 206, 170], float)
BONE_DARK = np.array([70, 52, 40], float)


# ---------------------------------------------------------------------------
# Bruit périodique
# ---------------------------------------------------------------------------

def _value_noise(period, cells, rng):
    """Bruit lisse sur un tore period x period (cells x cells points de contrôle)."""
    grid = rng.random((cells, cells))
    t = (np.arange(period) / period) * cells
    i0 = np.floor(t).astype(int) % cells
    i1 = (i0 + 1) % cells
    f = t - np.floor(t)
    f = f * f * (3 - 2 * f)
    rows = grid[i0][:, i0] * (1 - f)[None, :] + grid[i0][:, i1] * f[None, :]
    rows1 = grid[i1][:, i0] * (1 - f)[None, :] + grid[i1][:, i1] * f[None, :]
    return rows * (1 - f)[:, None] + rows1 * f[:, None]


def _fbm(period, rng, base_cells=4, octaves=4):
    total = np.zeros((period, period))
    amp, norm = 1.0, 0.0
    cells = base_cells
    for _ in range(octaves):
        if cells > period:
            break
        total += _value_noise(period, cells, rng) * amp
        norm += amp
        amp *= 0.5
        cells *= 2
    return total / norm


def _cracks(period, rng, points=10, width=1.1):
    """Les fissures : les frontières d'un pavage de Voronoï (périodique)."""
    pts = rng.random((points, 2)) * period
    y, x = np.mgrid[0:period, 0:period].astype(float)
    dists = []
    for py, px in pts:
        dy = np.abs(y - py)
        dx = np.abs(x - px)
        dy = np.minimum(dy, period - dy)
        dx = np.minimum(dx, period - dx)
        dists.append(np.sqrt(dx * dx + dy * dy))
    d = np.sort(np.stack(dists), axis=0)
    edge = d[1] - d[0]
    return np.clip(1.0 - edge / width, 0.0, 1.0)


def _tile(texture, h, w, offset):
    period = texture.shape[0]
    ys = (np.arange(h) - offset) % period
    xs = (np.arange(w) - offset) % period
    return texture[ys][:, xs]


# ---------------------------------------------------------------------------
# Rendu : relief -> normales -> lumière
# ---------------------------------------------------------------------------

def _normals(height, strength):
    gy, gx = np.gradient(height * strength)
    n = np.stack([-gx, -gy, np.ones_like(height)], axis=-1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def _shade(height, albedo, strength=2.5, ember=0.3):
    n = _normals(height, strength)
    light = LIGHT / np.linalg.norm(LIGHT)
    ember_dir = EMBER_DIR / np.linalg.norm(EMBER_DIR)
    diffuse = np.clip(n @ light, 0, 1)
    glow = np.clip(n @ ember_dir, 0, 1) ** 2.2
    color = albedo * (0.25 + 0.95 * diffuse[..., None]) + EMBER * glow[..., None] * ember
    # Un petit reflet sur les arêtes bien tournées vers la lumière.
    color += 60.0 * (diffuse[..., None] ** 12)
    return color


def _stone(h, w, margin, seed, crack_points=10):
    """Albédo et relief d'une pierre sombre fissurée, qui se répète tous les period pixels."""
    rng = np.random.default_rng(seed)
    period = max(16, (w - 2 * margin)) if margin else w
    noise = _tile(_fbm(period, rng, 4, 5), h, w, margin)
    grain = _tile(_fbm(period, rng, 16, 3), h, w, margin)
    cracks = _tile(_cracks(period, rng, crack_points), h, w, margin)
    tone = np.clip(0.35 + 0.7 * (noise - 0.5) + 0.25 * (grain - 0.5), 0, 1)
    albedo = STONE_DARK + (STONE_LIGHT - STONE_DARK) * tone[..., None]
    albedo *= (1.0 - 0.6 * cracks)[..., None]
    relief = 0.6 * noise + 0.25 * grain - 0.9 * cracks
    return albedo, relief, cracks


def _rect_distance(h, w, radius):
    """Distance au bord d'un rectangle aux coins arrondis (positive dedans)."""
    y, x = np.mgrid[0:h, 0:w].astype(float) + 0.5
    d = np.minimum(np.minimum(x, w - x), np.minimum(y, h - y))
    if radius > 0:
        cx = np.clip(x, radius, w - radius)
        cy = np.clip(y, radius, h - radius)
        corner = (x < radius) | (x > w - radius)
        corner &= (y < radius) | (y > h - radius)
        d = np.where(corner, radius - np.hypot(x - cx, y - cy), d)
    return d


def _smooth(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def _frame(size, margin, band, seed, inside, line, line_glow=0.0, glow_color=None, radius=10,
           inset=2.0, crack_points=10, desaturate=0.0):
    """Un cadre carré : bandeau de pierre (largeur band), liseré coloré, fond « inside »."""
    h = w = size
    d = _rect_distance(h, w, radius) - inset
    albedo, relief, cracks = _stone(h, w, margin, seed, crack_points)
    # Le profil du bandeau : il monte depuis le bord, puis plonge vers le creux du centre.
    rise = _smooth(0.0, band * 0.28, d)
    fall = 1.0 - _smooth(band * 0.7, band, d)
    profile = rise * fall
    height = profile * (1.0 + 0.35 * relief) + 0.08 * relief * (d > band)
    color = _shade(height * 9.0, albedo)
    # Le fond (le creux) : sombre, légèrement translucide.
    inside_rgb = np.array(inside[:3], float)
    in_mask = _smooth(band * 0.85, band + 1.0, d)
    color = color * (1 - in_mask[..., None]) + inside_rgb * in_mask[..., None]
    # Le liseré coloré, juste à l'intérieur du bandeau, et sa lueur.
    line_rgb = np.array(line, float)
    stripe = np.exp(-((d - (band + 1.5)) / 1.4) ** 2)
    color = color * (1 - stripe[..., None]) + line_rgb * stripe[..., None]
    if line_glow > 0:
        glow_rgb = np.array(glow_color if glow_color is not None else line, float)
        halo = np.exp(-np.clip(d - band - 1.5, 0, None) / (band * 0.35)) * (d > band) * line_glow
        color += glow_rgb * halo[..., None] * 0.6
    if desaturate > 0:
        gray = color.mean(axis=-1, keepdims=True)
        color = color * (1 - desaturate) + gray * desaturate
    alpha = np.clip(d + 0.5, 0, 1) * 255.0
    alpha = np.where(d > band, np.minimum(alpha, inside[3] + (255 - inside[3]) * stripe), alpha)
    img = np.dstack([np.clip(color, 0, 255), alpha]).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


# ---------------------------------------------------------------------------
# Cornes et bossages
# ---------------------------------------------------------------------------

def _horn(canvas, base, tip, width, bend, steps=48):
    """Une corne d'os : un fuseau courbé, ombré de l'os clair à la pointe sombre."""
    arr = np.array(canvas).astype(float)
    h, w = arr.shape[:2]
    base = np.array(base, float)
    tip = np.array(tip, float)
    axis = tip - base
    length = np.linalg.norm(axis)
    normal = np.array([-axis[1], axis[0]]) / length
    y, x = np.mgrid[0:h, 0:w].astype(float)
    for i in range(steps, -1, -1):
        t = i / steps
        center = base + axis * t + normal * bend * math.sin(t * math.pi) * length
        radius = width * (1 - t) ** 0.9 * 0.5 + 0.6
        dist = np.hypot(x - center[0], y - center[1])
        mask = np.clip(radius + 0.5 - dist, 0, 1)
        if not mask.any():
            continue
        # Ombrage cylindrique : clair du côté de la lumière (en haut à gauche).
        side = ((x - center[0]) * -0.6 + (y - center[1]) * -0.8) / max(radius, 0.5)
        light = np.clip(0.55 + 0.45 * side, 0.15, 1.0)
        rings = 0.9 + 0.1 * math.sin(t * 40.0)
        col = (BONE * (1 - t ** 1.6) + BONE_DARK * t ** 1.6) * rings
        rgb = col[None, None, :] * light[..., None]
        rgb += EMBER * np.clip(-side, 0, 1)[..., None] * 0.25  # La braise par en dessous.
        a = mask[..., None]
        arr[..., :3] = arr[..., :3] * (1 - a) + rgb * a
        arr[..., 3] = np.maximum(arr[..., 3], mask * 255)
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def _boss(canvas, center, radius, seed):
    """Un bossage de pierre rond (aux coins des panneaux, sous les cornes)."""
    arr = np.array(canvas).astype(float)
    h, w = arr.shape[:2]
    y, x = np.mgrid[0:h, 0:w].astype(float)
    dist = np.hypot(x - center[0], y - center[1])
    dome = np.sqrt(np.clip(1 - (dist / radius) ** 2, 0, 1))
    albedo, relief, _ = _stone(h, w, 0, seed, 6)
    color = _shade(dome * 6.0 + 0.2 * relief, albedo * 0.9)
    mask = np.clip(radius + 0.5 - dist, 0, 1)[..., None]
    arr[..., :3] = arr[..., :3] * (1 - mask) + color * mask
    arr[..., 3] = np.maximum(arr[..., 3], mask[..., 0] * 255)
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------------------
# Les images
# ---------------------------------------------------------------------------

def render_panel(out):
    size, m = SIZES["panel"], MARGINS["panel"]
    img = _frame(size, m, band=40, seed=11, inside=(16, 10, 10, 235), line=RED_LINE, line_glow=0.25,
                 radius=14, inset=6.0, crack_points=12)
    # Aux quatre coins : un bossage et une petite corne qui pointe vers l'extérieur.
    for sx, sy in [(0, 0), (1, 0), (0, 1), (1, 1)]:
        cx = 24 if sx == 0 else size - 24
        cy = 24 if sy == 0 else size - 24
        tip = (2 if sx == 0 else size - 2, 2 if sy == 0 else size - 2)
        img = _boss(img, (cx, cy), 15, 30 + sx + 2 * sy)
        bend = 0.18 if (sx + sy) % 2 == 0 else -0.18
        img = _horn(img, (cx, cy), tip, 13, bend)
    img.save(os.path.join(out, "panel.png"))


def render_slot(out):
    size, m = SIZES["slot"], MARGINS["slot"]
    _frame(size, m, band=16, seed=21, inside=(8, 5, 5, 240), line=(120, 30, 22), radius=8,
           inset=2.0, crack_points=6).save(os.path.join(out, "slot.png"))


def render_buttons(out):
    size, m = SIZES["button"], MARGINS["button"]
    specs = {
        "normal": dict(inside=(30, 20, 18, 245), line=RED_LINE, line_glow=0.15),
        "hover": dict(inside=(48, 28, 20, 245), line=(255, 110, 40), line_glow=0.6),
        "pressed": dict(inside=(56, 36, 14, 245), line=(255, 214, 74), line_glow=1.0,
                        glow_color=(255, 170, 40)),
        "disabled": dict(inside=(16, 13, 12, 235), line=(60, 40, 36), desaturate=0.6),
    }
    for name, spec in specs.items():
        _frame(size, m, band=20, seed=41, radius=9, inset=2.0, crack_points=6, **spec).save(
            os.path.join(out, "button_%s.png" % name))


def render_bubble(out):
    size, m = SIZES["bubble"], MARGINS["bubble"]
    _frame(size, m, band=18, seed=51, inside=(18, 11, 11, 235), line=RED_LINE, line_glow=0.2, radius=10,
           inset=2.0, crack_points=6).save(os.path.join(out, "bubble.png"))


def render_medallion(out):
    """L'anneau du portrait : pierre hérissée de pointes, deux grandes cornes, un crâne."""
    size = SIZES["medallion"]
    c = size / 2.0
    outer, inner = 196.0, 145.0  # Comme FRAME_OUTER / FRAME_INNER (lord_portrait.gd).
    y, x = np.mgrid[0:size, 0:size].astype(float) + 0.5
    r = np.hypot(x - c, y - c)
    angle = np.arctan2(y - c, x - c)
    # Des pointes tout autour de l'anneau (un peu irrégulières).
    rng = np.random.default_rng(7)
    spikes = 18
    jitter = rng.random(spikes) * 0.4 + 0.8
    phase = (angle / (2 * math.pi) * spikes) % 1.0
    index = np.floor((angle + math.pi) / (2 * math.pi) * spikes).astype(int) % spikes
    spike = np.clip(1.0 - np.abs(phase - 0.5) * 2.0, 0, 1) ** 1.5 * 16.0 * jitter[index]
    outer_r = outer + spike
    band = outer_r - inner
    d = np.minimum(outer_r - r, r - inner)
    albedo, relief, _ = _stone(size, size, 0, 61, 22)
    t = np.clip((r - inner) / band, 0, 1)
    profile = np.sin(t * math.pi) ** 0.6 * (d > -1)
    groove = np.exp(-((r - (inner + 18)) / 3.0) ** 2) * 0.5  # Une rainure près du bord intérieur.
    height = profile * (1 + 0.3 * relief) - groove
    color = _shade(height * 14.0, albedo, strength=2.0, ember=0.7)
    # Le liseré rouge brûlant contre le visage.
    stripe = np.exp(-((r - (inner + 3.0)) / 2.2) ** 2)
    color = color * (1 - stripe[..., None]) + np.array([230, 60, 20]) * stripe[..., None]
    alpha = np.clip(d + 0.5, 0, 1) * 255
    img = Image.fromarray(np.dstack([np.clip(color, 0, 255), alpha]).astype(np.uint8), "RGBA")
    # Les deux grandes cornes, qui partent du haut de l'anneau.
    img = _horn(img, (c - 120, c - 140), (c - 236, c - 246), 46, -0.28, steps=80)
    img = _horn(img, (c + 120, c - 140), (c + 236, c - 246), 46, 0.28, steps=80)
    img = _boss(img, (c - 120, c - 140), 26, 71)
    img = _boss(img, (c + 120, c - 140), 26, 72)
    # Le crâne, en bas : l'icône du crâne, teintée d'os vieilli.
    skull_path = os.path.join(ROOT, "assets", "icons_hd", "skull.png")
    if os.path.exists(skull_path):
        skull = Image.open(skull_path).convert("RGBA").resize((92, 92), Image.LANCZOS)
        s = np.array(skull).astype(float)
        s[..., :3] = s[..., :3] * np.array([0.92, 0.82, 0.7])
        skull = Image.fromarray(np.clip(s, 0, 255).astype(np.uint8), "RGBA")
        img.alpha_composite(skull, (int(c - 46), int(c + outer - 58)))
    img.save(os.path.join(out, "medallion.png"))


def render_ornament(out):
    """Le crâne d'ornement posé sur les panneaux (voir hud.gd, _add_ornament)."""
    skull_path = os.path.join(ROOT, "assets", "icons_hd", "skull.png")
    skull = Image.open(skull_path).convert("RGBA").resize((96, 96), Image.LANCZOS)
    s = np.array(skull).astype(float)
    s[..., :3] = s[..., :3] * np.array([0.8, 0.7, 0.6])
    img = Image.new("RGBA", (128, 128))
    img = _horn(img, (52, 70), (4, 30), 18, 0.25)
    img = _horn(img, (76, 70), (124, 30), 18, -0.25)
    img.alpha_composite(Image.fromarray(np.clip(s, 0, 255).astype(np.uint8), "RGBA"), (16, 22))
    img.save(os.path.join(out, "ornament_skull.png"))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=os.path.join(ROOT, "assets", "ui_hd"))
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    render_panel(args.out)
    render_slot(args.out)
    render_buttons(args.out)
    render_bubble(args.out)
    render_medallion(args.out)
    render_ornament(args.out)
    print("Cadres écrits dans", args.out)


if __name__ == "__main__":
    main()
