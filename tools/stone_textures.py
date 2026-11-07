#!/usr/bin/env python3
"""Текстуры каменной кладки в стиле присланного фото (светло-серые округлые блоки, тёмные швы,
мох по низу блоков и в швах) и синей черепицы для крыш башен. Все текстуры бесшовные.

python3 tools/stone_textures.py   →   godot/textures/stone_wall_*.png, stone_path_*.png, roof_tiles_*.png
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "godot" / "textures"
S = 1024
rng = np.random.default_rng(11)


def fbm(size, octaves=5, base=4, seed=0):
    """Бесшовный шум: сумма периодических гармоник (через БПФ)."""
    r = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp = 1.0
    for o in range(octaves):
        f = base * 2 ** o
        spec = np.zeros((size, size), complex)
        k = min(f, size // 2 - 1)
        spec[:k, :k] = (r.normal(size=(k, k)) + 1j * r.normal(size=(k, k)))
        layer = np.real(np.fft.ifft2(spec))
        layer /= np.abs(layer).max() + 1e-9
        out += layer * amp
        amp *= 0.5
    out -= out.min()
    return out / out.max()


def blur(a, r):
    """Бесшовное размытие (окно 2r+1) — несколько проходов прямоугольного фильтра."""
    for _ in range(3):
        acc = np.zeros_like(a)
        for d in range(-r, r + 1):
            acc += np.roll(a, d, 0)
        a = acc / (2 * r + 1)
        acc = np.zeros_like(a)
        for d in range(-r, r + 1):
            acc += np.roll(a, d, 1)
        a = acc / (2 * r + 1)
    return a


def blocks(rows, cols, jitter, seed):
    """Раскладка «вперевязку»: для каждого пикселя — номер камня и расстояние до его края (px)."""
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    bh = S / rows
    row = np.floor(yy / bh).astype(int)
    # Свои ширины камней в каждом ряду (сумма = S, ряд замкнут по кругу)
    ids = np.zeros((S, S), int)
    dist = np.zeros((S, S))
    base_w = S / cols
    nid = 0
    for ry in range(rows):
        widths = base_w * (1 + r.uniform(-jitter, jitter, cols))
        widths *= S / widths.sum()
        edges = np.concatenate([[0], np.cumsum(widths)]) + (base_w * 0.5 if ry % 2 else 0) + r.uniform(-8, 8)
        y0, y1 = int(ry * bh), int((ry + 1) * bh)
        ys = yy[y0:y1, :]
        xs = xx[y0:y1, :]
        dy = np.minimum(ys - ry * bh, (ry + 1) * bh - ys)
        for c in range(cols):
            a, b = edges[c], edges[c + 1]
            # с учётом замыкания по X
            xa = (xs - a) % S
            inside = xa < (b - a)
            dx = np.minimum(xa, (b - a) - xa)
            d = np.minimum(dx, dy)
            sel = inside
            ids[y0:y1, :][sel] = nid
            dist[y0:y1, :][sel] = d[sel]
            nid += 1
    return ids, dist, nid


def stone(name, rows, cols, jitter, grout, round_px, seed, moss_amount):
    ids, dist, n = blocks(rows, cols, jitter, seed)
    r = np.random.default_rng(seed + 1)
    noise = fbm(S, 6, 6, seed + 2)
    fine = fbm(S, 4, 48, seed + 3)
    # Высота: подушка — круто у края, плоско к середине; неровные края — шумом
    d = dist + (noise - 0.5) * 6.0 + (fine - 0.5) * 2.0
    t = np.clip((d - grout) / round_px, 0, 1)
    h = np.sqrt(1 - (1 - t) ** 2) * 0.85 + noise * 0.1 + fine * 0.05
    h[d <= grout] = 0.05 + fine[d <= grout] * 0.05
    # Цвет каждого камня: светло-серый с лёгким синим или тёплым оттенком
    tone = r.uniform(0.74, 0.92, n)
    tint = r.uniform(-0.015, 0.015, n)
    base = np.stack([tone[ids] * (0.96 + tint[ids]), tone[ids] * 0.97, tone[ids] * (1.0 - tint[ids] * 0.5 + 0.02)], -1)
    # Пятна и выветривание
    base *= (0.86 + 0.2 * noise)[..., None] * (0.94 + 0.08 * fine)[..., None]
    # Затенение по краю (мягкая «подушка») и тёмный шов
    ao = 0.45 + 0.55 * np.clip(t * 1.2, 0, 1) ** 0.7
    col = base * ao[..., None]
    grout_c = np.array([0.20, 0.21, 0.19])
    gmask = (d <= grout)[..., None]
    col = np.where(gmask, grout_c * (0.8 + 0.4 * fine[..., None]), col)
    # Мох: по низу камней и в швах, жёлто-зелёный, пятнами
    yy = np.mgrid[0:S, 0:S][0].astype(np.float64)
    bh = S / rows
    lower = ((yy % bh) / bh) ** 3                      # низ каждого ряда
    mn = fbm(S, 5, 5, seed + 4)
    moss = np.clip((mn - (1.0 - moss_amount)) * 4.0, 0, 1) * np.clip(lower * 1.3 + (1 - t) * 0.8, 0, 1)
    moss *= np.clip((fine - 0.35) * 3.0, 0, 1)   # мох клочками, а не пятном
    moss = blur(moss, 1)
    moss_c = np.stack([0.50 + 0.15 * fine, 0.62 + 0.12 * fine, 0.20 + 0.06 * fine], -1)
    col = col * (1 - moss[..., None] * 0.8) + moss_c * moss[..., None] * 0.8
    col = np.clip(col, 0, 1)
    save(name, col, h, 7.0)


def roof(name):
    """Черепица: ряды скруглённых снизу плиток, синяя, как на крышах домов."""
    rows, cols = 16, 16
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    bh, bw = S / rows, S / cols
    row = np.floor(yy / bh)
    off = np.where(row % 2 == 1, bw / 2, 0)
    cx = ((xx + off) % bw) - bw / 2
    fy = (yy % bh) / bh                                   # 0 — верх ряда, 1 — низ
    r = np.random.default_rng(5)
    tile_id = (row * cols + np.floor((xx + off) / bw) % cols).astype(int)
    tone = r.uniform(0.82, 1.12, rows * cols)[tile_id]
    # Скругление низа плитки: край — полуокружность
    edge = 1.0 - 0.18 * np.clip(np.abs(cx) / (bw * 0.5), 0, 1) ** 4
    inside = fy < edge
    noise = fbm(S, 5, 8, 21)
    shade = 0.62 + 0.38 * np.clip(fy / edge, 0, 1)          # к низу плитки светлее (выпуклая)
    shade *= 1.0 - 0.25 * (np.abs(cx) / (bw * 0.5)) ** 2
    blue = np.array([0.22, 0.36, 0.86])
    col = blue[None, None, :] * (tone * shade * (0.9 + 0.2 * noise))[..., None]
    gap = np.array([0.06, 0.08, 0.18])
    col = np.where(inside[..., None], col, gap)
    h = np.where(inside, 0.3 + 0.7 * np.clip(fy / edge, 0, 1), 0.0) + noise * 0.05
    save(name, np.clip(col, 0, 1), h, 5.0)


def save(name, col, h, strength):
    Image.fromarray((col * 255).astype(np.uint8)).save(OUT / f"{name}_albedo.png")
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    nrm = np.stack([-gx, gy, nz], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8)).save(OUT / f"{name}_normal.png")
    print("→", name)


if __name__ == "__main__":
    stone("stone_wall", rows=8, cols=4, jitter=0.25, grout=4.0, round_px=40.0, seed=3, moss_amount=0.45)
    stone("stone_path", rows=6, cols=5, jitter=0.3, grout=4.5, round_px=34.0, seed=8, moss_amount=0.3)
    roof("roof_tiles")
