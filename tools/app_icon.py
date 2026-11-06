#!/usr/bin/env python3
"""Иконка приложения из присланной картинки (meshy/ui/app_icon_src.jpg):
  godot/icon.png            — 512×512, картинка целиком, как прислана;
  godot/icon_fg.png         — 432×432 передний слой адаптивной иконки: картинка целиком на всю видимую
                              зону лаунчера (288×288 в центре);
  godot/icon_bg.png         — 432×432 фон адаптивной иконки: чёрный (как углы картинки).
python3 tools/app_icon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "meshy" / "ui" / "app_icon_src.jpg"
OUT = ROOT / "godot"
BOX = (23, 18, 1223, 1218)   # рамка на картинке
RADIUS = 0.27                # скругление углов рамки (доля стороны)


def rounded(img, r):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), radius=int(img.size[0] * r), fill=255)
    out = img.convert("RGBA")
    out.putalpha(m)
    return out


def main():
    # Картинка целиком, как прислана (с рамкой и чёрными углами), без обрезки и скругления
    src = Image.open(SRC).convert("RGB")
    src.resize((512, 512), Image.LANCZOS).save(OUT / "icon.png")
    # Адаптивная: картинка целиком на всю видимую зону лаунчера (288×288 из 432), под ней — чёрный
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.paste(src.resize((288, 288), Image.LANCZOS), (72, 72))
    fg.save(OUT / "icon_fg.png")
    Image.new("RGB", (432, 432), (0, 0, 0)).save(OUT / "icon_bg.png")
    print("иконки готовы")


if __name__ == "__main__":
    main()
