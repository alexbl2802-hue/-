#!/usr/bin/env python3
"""Текстуры для Terrain3D (godot/textures/t3d/): у каждой — albedo+высота (RGBA) и нормаль+шероховатость (RGBA),
все 1024×1024, как требует массив текстур Terrain3D. Источники — textures/grass_*, dirt_*, mountain_rock.jpg.

python3 tools/make_terrain3d_textures.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

T = Path(__file__).resolve().parent.parent / "godot" / "textures"
OUT = T / "t3d"
N = 1024


def load(p, size=N):
    return np.asarray(Image.open(p).convert("RGB").resize((size, size), Image.LANCZOS)).astype(np.float64) / 255.0


def normal_from(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.dstack([-dx, -dy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def save(name, alb, height, nrm, rough):
    a = np.dstack([alb, height])
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA").save(OUT / f"{name}_albedo_height.png")
    b = np.dstack([nrm, np.full(height.shape, rough) if np.isscalar(rough) else rough])
    Image.fromarray((np.clip(b, 0, 1) * 255).astype(np.uint8), "RGBA").save(OUT / f"{name}_normal_rough.png")


def lum(c):
    return c @ np.array([0.2126, 0.7152, 0.0722])


OUT.mkdir(parents=True, exist_ok=True)
g = load(T / "grass_albedo.png")
gn = load(T / "grass_normal.png")
save("grass", g, lum(g) / max(lum(g).max(), 1e-6), gn, 0.85)
d = load(T / "dirt_albedo.png")
dn = load(T / "dirt_normal.png")
save("dirt", d, lum(d) / max(lum(d).max(), 1e-6), dn, 0.9)
# Песок: та же земля, светлее и желтее, мельче рисунок
s = np.clip(d * np.array([1.9, 1.75, 1.45]) + 0.06, 0, 1)
save("sand", s, lum(s) / lum(s).max(), dn * 0.5 + np.array([0.25, 0.25, 0.5]), 0.95)
# Камень гор (Mossy Stone Peak)
r = load(T / "mountain_rock.jpg")
rh = lum(r)
save("rock", r, rh / rh.max(), normal_from(rh, 6.0), 0.8)
print("готово:", OUT)
