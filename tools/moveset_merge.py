#!/usr/bin/env python3
"""Анимации Moveset Free (Blender-дополнение NoMicro Studio, https://moveset3d.com/) — в модель.

1) tools/blender/bake_moveset.py в Blender: дополнение строит свои 55 анимаций и переносит их на
   скелет модели (свой ретаргетинг дополнения), результат — GLB со скелетом и действиями;
2) здесь: эти действия переносятся в саму модель (prepare_models.retarget_dir — поза покоя учитывается),
   имена — с приставкой MS_ («@» → «_»). Прежние клипы MS_ заменяются.

python3 tools/moveset_merge.py <glb_из_blender> <модель в godot/models>
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_models as pm  # noqa: E402


def main():
    src, name = sys.argv[1], sys.argv[2]
    path = pm.OUT / name
    j, b = pm.read_glb(path)
    old = j.get("animations", [])
    keep = [a for a in old if not a["name"].startswith("MS_")]
    clips = []
    for nm, times, tracks in pm.retarget_dir(j, src):
        if not nm.startswith("MS_"):
            continue
        clips.append((nm.replace("@", "_"), times - times[0], tracks))
    j["animations"] = keep
    bld = pm.rebuild(j, b)
    for nm, times, tracks in clips:
        pm.add_animation(j, bld, nm, times, tracks)
    j["bufferViews"] = bld.views
    pm.write_glb(path, j, bld.blob)
    print(name, "клипов Moveset:", len(clips))


if __name__ == "__main__":
    main()
