#!/usr/bin/env python3
"""Бесшовные текстуры земли и воды (генерируются один раз, кладутся в godot/textures/).

grass_albedo.png / grass_normal.png — густой газон: тысячи травинок разных оттенков поверх
    тёмной подложки, мелкие пятна клевера и сухой травы.
dirt_albedo.png / dirt_normal.png — утоптанная земля с камешками и трещинками.
water_normal.png — мелкая рябь (две такие карты бегут навстречу друг другу в шейдере воды).

python3 tools/make_ground_textures.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "godot" / "textures"
N = 1024
rng = np.random.default_rng(11)


def fbm(size, octaves, base, seed, persist=0.55):
    """Бесшовный шум: сумма октав из периодической интерполяции случайной сетки."""
    r = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        cells = base * (2 ** o)
        g = r.random((cells, cells))
        # бикубическое (через PIL) растяжение периодической сетки: дополняем край копией
        tile = np.tile(g, (3, 3))
        im = Image.fromarray(tile.astype(np.float32), mode="F")
        im = im.resize((size * 3, size * 3), Image.BICUBIC)
        a = np.asarray(im, dtype=np.float64)[size:2 * size, size:2 * size]
        out += a * amp
        tot += amp
        amp *= persist
    out /= tot
    out -= out.min()
    return out / max(out.max(), 1e-6)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.dstack([-dx, -dy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def stamp_blades(col, hgt, count, palette, length, width):
    """Травинки: короткие штрихи с наклоном, светлеют к кончику; поверх друг друга (z-буфер по высоте)."""
    H, W = hgt.shape
    for _ in range(count):
        x0, y0 = rng.random() * W, rng.random() * H
        ang = -np.pi / 2 + rng.normal(0, 0.55)
        ln = length * (0.5 + rng.random())
        c = np.array(palette[rng.integers(len(palette))], dtype=np.float64)
        c *= 0.85 + rng.random() * 0.3
        steps = int(ln * 1.5) + 2
        bend = rng.normal(0, 0.02)
        for s in range(steps):
            t = s / (steps - 1)
            a = ang + bend * s
            x = x0 + np.cos(a) * ln * t
            y = y0 + np.sin(a) * ln * t
            wdt = max(1, int(round(width * (1.0 - t * 0.7))))
            for k in range(-(wdt // 2), wdt - wdt // 2):
                xi = int(x + k) % W
                yi = int(y) % H
                z = t * 0.7 + 0.3
                if z >= hgt[yi, xi] - 0.15:
                    hgt[yi, xi] = max(hgt[yi, xi], z)
                    col[yi, xi] = c * (0.55 + 0.6 * t)


def grass():
    base = fbm(N, 5, 4, 1)
    patches = fbm(N, 3, 3, 2)
    col = np.zeros((N, N, 3))
    soil = np.array([52, 60, 26]) / 255.0
    col[:] = soil * (0.6 + 0.5 * base[..., None])
    hgt = base * 0.2
    greens = [(96, 150, 44), (118, 168, 52), (80, 132, 38), (138, 176, 64), (104, 156, 60), (70, 120, 34)]
    stamp_blades(col, hgt, 60000, [np.array(c) / 255.0 for c in greens], 11, 3)
    dry = [(170, 160, 84), (150, 150, 70), (128, 146, 56)]
    stamp_blades(col, hgt, 7000, [np.array(c) / 255.0 for c in dry], 9, 2)
    # Пятна более тёмной сочной травы и выгоревшей — крупный узор внутри одной плитки
    col *= (0.85 + 0.3 * patches)[..., None]
    yellow = np.clip((patches - 0.6) * 2.5, 0, 1)[..., None]
    col = col * (1 - yellow * 0.25) + yellow * 0.25 * col * np.array([1.25, 1.1, 0.7])
    col = np.clip(col, 0, 1)
    Image.fromarray((col * 255).astype(np.uint8)).save(OUT / "grass_albedo.png", optimize=True)
    Image.fromarray(normal_from_height(hgt, 2.5)).save(OUT / "grass_normal.png", optimize=True)


def dirt():
    base = fbm(N, 6, 5, 3)
    fine = fbm(N, 3, 64, 4)
    col = np.array([112, 86, 58]) / 255.0 * (0.62 + 0.55 * base[..., None])
    col *= (0.88 + 0.24 * fine)[..., None]
    grit = rng.random((N, N))
    col *= (0.9 + 0.2 * grit)[..., None]
    hgt = base * 0.4 + fine * 0.2 + grit * 0.08
    # Камешки: эллипсы светлее и выше земли, с тенью снизу
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(1400):
        cx, cy = rng.random() * N, rng.random() * N
        r = 1.5 + rng.random() ** 3 * 7
        x0, x1 = int(cx - r - 2), int(cx + r + 3)
        y0, y1 = int(cy - r - 2), int(cy + r + 3)
        xs = np.arange(x0, x1) % N
        ys = np.arange(y0, y1) % N
        dx = (np.arange(x0, x1)[None, :] - cx) / r
        dy = (np.arange(y0, y1)[:, None] - cy) / (r * (0.6 + rng.random() * 0.4))
        ang = np.arctan2(dy, dx)
        ph = rng.random(3) * 6.28
        wob = 1.0 + 0.18 * np.sin(ang * 3 + ph[0]) + 0.1 * np.sin(ang * 5 + ph[1])
        d = (dx * dx + dy * dy) / (wob * wob)
        m = d < 1.0
        shade = 0.75 + rng.random() * 0.5
        stone = np.array([128, 112, 92]) / 255.0 * shade
        sub = col[np.ix_(ys, xs)]
        lit = np.broadcast_to((1.0 - 0.45 * (dy + 0.3).clip(0, 1)), d.shape)[..., None]
        sub[m] = (stone * lit)[m]
        col[np.ix_(ys, xs)] = sub
        hs = hgt[np.ix_(ys, xs)]
        hs[m] = np.maximum(hs[m], 0.6 + 0.4 * np.sqrt(1 - d[m]))
        hgt[np.ix_(ys, xs)] = hs
    # Трещинки — тёмные тонкие линии там, где шум пересекает середину
    cr = fbm(N, 4, 6, 5)
    crack = np.clip(1.0 - np.abs(cr - 0.5) * 140.0, 0, 1) * fbm(N, 3, 8, 9)
    col *= (1 - 0.3 * crack)[..., None]
    hgt -= crack * 0.25
    col = np.clip(col, 0, 1)
    Image.fromarray((col * 255).astype(np.uint8)).save(OUT / "dirt_albedo.png", optimize=True)
    Image.fromarray(normal_from_height(hgt, 3.0)).save(OUT / "dirt_normal.png", optimize=True)


def water():
    h = fbm(512, 5, 8, 6, 0.5) * 0.7 + fbm(512, 3, 24, 7) * 0.3
    Image.fromarray(normal_from_height(h, 9.0)).save(OUT / "water_normal.png", optimize=True)


if __name__ == "__main__":
    import sys
    OUT.mkdir(parents=True, exist_ok=True)
    for what in (sys.argv[1:] or ["water", "dirt", "grass"]):
        globals()[what]()
    print("готово:", OUT)
