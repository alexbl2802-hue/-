#!/usr/bin/env python3
"""Картинки меню и экрана загрузки (присланные, meshy/ui/*_src.jpg) → godot/ui/.
Меню — как есть (кнопки нарисованы, игра кладёт поверх них настоящие кнопки).
Загрузка — с нарисованной полоски убирается заливка и надпись: их рисует игра (scripts/boot.gd).

python3 tools/ui_art.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

R = Path(__file__).resolve().parent.parent
SRC = R / "meshy" / "ui"
OUT = R / "godot" / "ui"
OUT.mkdir(parents=True, exist_ok=True)

Image.open(SRC / "menu_src.jpg").convert("RGB").save(OUT / "menu_bg.jpg", quality=90)

a = np.asarray(Image.open(SRC / "loading_src.jpg").convert("RGB")).astype(np.float64)
# 1) Полоска: внутренность (x 358–832, y 627–648) — как пустая часть полоски (столбец x=880)
col = a[627:649, 880:881, :]
a[627:649, 356:834, :] = col
# 2) Надпись «Загрузка...»: светлые буквы и их ореол заливаются окружающим фоном (диффузия)
y0, y1, x0, x1 = 572, 622, 548, 742
reg = a[y0:y1, x0:x1].copy()
bright = reg.min(axis=2) > 120
mask = Image.fromarray((bright * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))
m = np.asarray(mask) > 0
known = (~m).astype(np.float64)
fill = reg.copy()
def box(x, r=2):
    """Среднее по квадрату (2r+1)² — края повторяются"""
    p = np.pad(x, [(r, r), (r, r)] + [(0, 0)] * (x.ndim - 2), mode="edge")
    out = np.zeros_like(x)
    for dy in range(2 * r + 1):
        for dx in range(2 * r + 1):
            out += p[dy:dy + x.shape[0], dx:dx + x.shape[1]]
    return out / (2 * r + 1) ** 2


for _ in range(300):
    num = box(fill * known[..., None])
    den = box(known)
    est = num / np.maximum(den, 1e-6)[..., None]
    fill = np.where(m[..., None], est, reg)
    known = np.where(m, np.minimum(1.0, den * 1.5 + known), known)
a[y0:y1, x0:x1] = fill
Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(OUT / "loading_bg.jpg", quality=90)
print("готово:", OUT)
