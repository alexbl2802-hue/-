#!/usr/bin/env python3
"""Файл данных, который игра скачивает после установки (scripts/boot.gd).

1) id данных — хэш содержимого godot/models и godot/textures (не изменились — заново не качается);
2) id записывается в project.godot (application/config/data_id);
3) в пресет экспорта «Data» вписывается список файлов (модели и текстуры).
Печатает id. Дальше: godot --export-pack "Data" ../build/data-<id>.pck
"""
import hashlib
import re
from pathlib import Path

G = Path(__file__).resolve().parent.parent / "godot"
files = []
for d in ["models", "textures"]:
    for p in sorted((G / d).rglob("*")):
        if p.is_file() and not p.name.endswith((".import", ".uid")):
            files.append(p)
h = hashlib.sha256()
for p in files:
    h.update(str(p.relative_to(G)).encode())
    h.update(p.read_bytes())
data_id = h.hexdigest()[:12]
proj = (G / "project.godot").read_text()
if "config/data_id=" in proj:
    proj = re.sub(r'config/data_id=".*"', f'config/data_id="{data_id}"', proj)
else:
    proj = proj.replace("[application]\n", f'[application]\n\nconfig/data_id="{data_id}"\n', 1)
(G / "project.godot").write_text(proj)
lst = ", ".join(f'"res://{p.relative_to(G).as_posix()}"' for p in files)
pre = (G / "export_presets.cfg").read_text()
a = pre.index("[preset.1]")
pre = pre[:a] + re.sub(r"export_files=PackedStringArray\(.*?\)", f"export_files=PackedStringArray({lst})", pre[a:], count=1)
(G / "export_presets.cfg").write_text(pre)
print(data_id)
