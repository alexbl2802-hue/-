#!/usr/bin/env python3
"""Иконка приложения из присланной картинки (meshy/ui/app_icon_src.jpg):
  godot/icon.png            — 512×512, рамка со скруглёнными углами, вокруг прозрачно (обычная иконка);
  godot/icon_fg.png         — 432×432 передний слой адаптивной иконки: картинка в видимой зоне лаунчера
                              (288×288 в центре), чтобы надпись не обрезалась маской;
  godot/icon_bg.png         — 432×432 фон адаптивной иконки: та же картинка, размытая и затемнённая.
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
    art = Image.open(SRC).convert("RGB").crop(BOX)
    rounded(art.resize((512, 512), Image.LANCZOS), RADIUS).save(OUT / "icon.png")
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(rounded(art.resize((288, 288), Image.LANCZOS), RADIUS), (72, 72))
    fg.save(OUT / "icon_fg.png")
    bg = art.resize((432, 432), Image.LANCZOS).filter(ImageFilter.GaussianBlur(14))
    ImageEnhance.Brightness(bg).enhance(0.55).save(OUT / "icon_bg.png")
    print("иконки готовы")


if __name__ == "__main__":
    main()
