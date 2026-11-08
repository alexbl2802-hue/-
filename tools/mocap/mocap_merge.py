#!/usr/bin/env python3
"""Шаг 3 «видео → анимация героя»: клип MC_<имя> из GLB Blender (tools/blender/mocap_bake.py) — в модель.
Перенос как у Moveset (prepare_models.retarget_dir, поза покоя учитывается); клип с тем же именем заменяется.

python3 tools/mocap/mocap_merge.py <glb_из_blender> hero.glb
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import prepare_models as pm  # noqa: E402


def main():
    src, name = sys.argv[1], sys.argv[2]
    path = pm.OUT / name
    j, b = pm.read_glb(path)
    clips = [(nm, times - times[0], tracks) for nm, times, tracks in pm.retarget_dir(j, src) if nm.startswith("MC_")]
    new = {c[0] for c in clips}
    j["animations"] = [a for a in j.get("animations", []) if a["name"] not in new]
    bld = pm.rebuild(j, b)
    for nm, times, tracks in clips:
        pm.add_animation(j, bld, nm, times, tracks)
    j["bufferViews"] = bld.views
    pm.write_glb(path, j, bld.blob)
    print(name, "клипы с видео:", sorted(new))


if __name__ == "__main__":
    main()
