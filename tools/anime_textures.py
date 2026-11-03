#!/usr/bin/env python3
"""Текстуры земли в аниме-стиле: из «фотографичных» (make_ground_textures.py) делаются рисованные —
крупные мазки одного цвета (фильтр моды), меньше оттенков (постеризация), чуть ярче и чище.
Карты нормалей сглаживаются — рельеф мягче, как на рисованном фоне.

python3 tools/anime_textures.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

T = Path(__file__).resolve().parent.parent / "godot" / "textures"


def paint(img, levels=7, mode=7, sat=1.15):
    im = img.convert("RGB").filter(ImageFilter.ModeFilter(mode)).filter(ImageFilter.SMOOTH_MORE)
    a = np.asarray(im).astype(np.float64) / 255.0
    # постеризация по яркости с сохранением оттенка
    lum = a @ np.array([0.299, 0.587, 0.114])
    q = np.round(lum * levels) / levels
    a = a * ((q + 0.04) / (lum + 0.04))[..., None]
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return ImageEnhance.Color(im).enhance(sat)


def soft_normal(img, r=3):
    return img.convert("RGB").filter(ImageFilter.GaussianBlur(r))


def fbm(n, octaves, base, seed):
    r = np.random.default_rng(seed)
    out = np.zeros((n, n))
    amp = tot = 0.0
    amp = 1.0
    for o in range(octaves):
        c = base * 2 ** o
        g = np.tile(r.random((c, c)), (3, 3)).astype(np.float32)
        a = np.asarray(Image.fromarray(g, "F").resize((n * 3, n * 3), Image.BICUBIC))[n:2 * n, n:2 * n]
        out += a * amp
        tot += amp
        amp *= 0.5
    out /= tot
    return (out - out.min()) / (out.max() - out.min())


def anime_grass(n=1024):
    """Рисованный газон: пятна трёх оттенков зелёного с мягкими краями и редкие светлые штрихи травинок."""
    rng = np.random.default_rng(3)
    f = fbm(n, 4, 4, 21)
    tones = np.array([[70, 140, 52], [96, 168, 62], [128, 192, 78]]) / 255.0
    idx = np.digitize(f, [0.4, 0.66])
    col = tones[idx]
    im = Image.fromarray((col * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.5))
    a = np.asarray(im).astype(np.float64) / 255.0
    light = np.array([170, 214, 104]) / 255.0
    dark = np.array([52, 112, 44]) / 255.0
    for _ in range(9000):
        x, y = rng.integers(0, n, 2)
        ln = rng.integers(5, 12)
        c = light if rng.random() < 0.6 else dark
        lean = rng.normal(0, 0.35)
        for t in range(ln):
            xi = int(x + lean * t) % n
            yi = (y - t) % n
            a[yi, xi] = a[yi, xi] * 0.35 + c * 0.65
            a[yi, (xi + 1) % n] = a[yi, (xi + 1) % n] * 0.6 + c * 0.4
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


anime_grass().save(T / "grass_albedo.png")
soft_normal(Image.open(T / "grass_normal.png"), 4).save(T / "grass_normal.png")
paint(Image.open(T / "dirt_albedo.png")).save(T / "dirt_albedo.png")
soft_normal(Image.open(T / "dirt_normal.png")).save(T / "dirt_normal.png")
rock = Image.open(T / "mountain_rock.jpg").convert("RGB").filter(ImageFilter.GaussianBlur(4))
paint(rock, levels=5, mode=9, sat=1.15).filter(ImageFilter.SMOOTH_MORE).save(T / "mountain_rock.jpg", quality=92)
soft_normal(Image.open(T / "water_normal.png"), 2).save(T / "water_normal.png")
print("готово")
