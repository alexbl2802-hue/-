#!/usr/bin/env python3
"""Данные игры, которые скачиваются после установки (scripts/boot.gd), — частями.

Каждая модель (со своими текстурами и версиями для дальних расстояний) и каждая группа текстур —
отдельный файл pack-<группа>-<отпечаток>.pck. Отпечаток — хэш содержимого: если модель не менялась,
имя файла то же, и телефон его заново не качает — докачиваются только новые и изменённые части.
Список частей с размерами — godot/data/packs.json (лежит в APK).

python3 tools/data_pack.py <godot> <папка для .pck>
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

G = Path(__file__).resolve().parent.parent / "godot"
LOD = ("_mid", "_far")


def groups():
    files = [p for d in ["models", "textures"] for p in sorted((G / d).rglob("*"))
             if p.is_file() and not p.name.endswith((".import", ".uid"))]
    bases = sorted({p.stem for p in files if p.suffix == ".glb" and p.parent == G / "models" and not p.stem.endswith(LOD)},
                   key=len, reverse=True)
    out = {}
    for p in files:
        rel = p.relative_to(G)
        if p.parent == G / "models":
            key = next((b for b in bases if p.stem == b or p.stem.startswith(b + "_")), p.stem)
        else:
            key = "_".join(rel.parent.parts)          # textures, textures_t3d, models_skins
        out.setdefault(key, []).append(p)
    return out


def digest(paths):
    h = hashlib.sha256()
    for p in sorted(paths):
        h.update(str(p.relative_to(G)).encode())
        h.update(p.read_bytes())
    return h.hexdigest()[:12]


def fetch_prev(name, dst):
    """Часть с тем же именем (те же исходники) из прошлого релиза — байт в байт, чтобы телефон её не
    перекачивал (сборка .pck каждый раз даёт немного другие байты). Адрес — PREV_PACKS_URL.
    Не скачалась (нет в релизе, 504 и т. п.) — False, часть соберётся заново."""
    base = os.environ.get("PREV_PACKS_URL", "")
    if not base:
        return False
    for attempt in range(3):
        try:
            with urllib.request.urlopen(base + name, timeout=120) as r, open(dst, "wb") as f:
                while True:
                    chunk = r.read(1 << 20)
                    if not chunk:
                        break
                    f.write(chunk)
            if dst.stat().st_size > 0:
                return True
        except Exception as e:
            print("  прошлый релиз: %s — %s (попытка %d)" % (name, e, attempt + 1))
            time.sleep(3 * (attempt + 1))
    if dst.exists():
        dst.unlink()
    return False


def main():
    godot, outdir = sys.argv[1], Path(sys.argv[2]).resolve()
    outdir.mkdir(parents=True, exist_ok=True)
    presets = (G / "export_presets.cfg").read_text()
    a = presets.index("[preset.1]")
    packs = []
    for key, paths in sorted(groups().items()):
        name = "pack-%s-%s.pck" % (re.sub(r"[^a-z0-9_]", "_", key.lower()), digest(paths))
        lst = ", ".join('"res://%s"' % p.relative_to(G).as_posix() for p in paths)
        cfg = presets[:a] + re.sub(r"export_files=PackedStringArray\(.*?\)", "export_files=PackedStringArray(%s)" % lst,
                                   presets[a:], count=1)
        (G / "export_presets.cfg").write_text(cfg)
        dst = outdir / name
        reused = fetch_prev(name, dst)
        if not reused:
            subprocess.run([godot, "--headless", "--path", str(G), "--export-pack", "Data", str(dst)], check=True,
                           stdout=subprocess.DEVNULL)
        packs.append({"name": name, "size": dst.stat().st_size,
                      "sha256": hashlib.sha256(dst.read_bytes()).hexdigest()})
        print("%-50s %7.1f МБ  (%d файлов)%s" % (name, dst.stat().st_size / 1e6, len(paths), "  — из прошлого релиза" if reused else ""))
    (G / "export_presets.cfg").write_text(presets)
    (G / "data").mkdir(exist_ok=True)
    # Формат данных 1 (scripts/boot.gd DATA_FORMAT): версия приложения и контрольные суммы частей
    ver = re.search(r'^config/version="([^"]*)"', (G / "project.godot").read_text(), re.M)
    (G / "data" / "packs.json").write_text(json.dumps({"format": 1, "app": ver.group(1) if ver else "",
                                                       "packs": packs}, indent=1))
    print("всего %.1f МБ в %d частях" % (sum(p["size"] for p in packs) / 1e6, len(packs)))


if __name__ == "__main__":
    main()
