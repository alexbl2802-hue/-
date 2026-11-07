#!/usr/bin/env python3
"""NPC из присланной модели Meshy (скелет Mixamo, 28 костей, только «Running»):
модель копируется как есть и получает клип «Idle» — стойка героя (godot/models/hero.glb),
перенесённая на скелет NPC (prepare_models.retarget_dir, поза покоя учитывается).

python3 tools/npc_idle.py <модель.glb> <имя_в_godot/models.glb>
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_models as pm  # noqa: E402


def main():
    src, out = Path(sys.argv[1]), pm.OUT / sys.argv[2]
    j, b = pm.read_glb(src)
    names, _ = pm.bone_tree(j)
    hips = names["Hips"]
    rest_h = np.array(j["nodes"][hips].get("translation", [0, 1, 0]), np.float64)
    clips = []
    for name, times, tracks in pm.retarget_dir(j, str(pm.OUT / "hero.glb"), only={"Idle"}):
        res = []
        for n, kind, v in tracks:
            if n == hips and kind == "translation":
                v = v.copy()
                v[:, 0] = rest_h[0]
                v[:, 2] = rest_h[2]
            res.append((n, kind, v))
        clips.append((name, times - times[0], res))
    bld = pm.rebuild(j, b)
    for name, times, tracks in clips:
        pm.add_animation(j, bld, name, times, tracks)
    j["bufferViews"] = bld.views
    pm.write_glb(out, j, bld.blob)
    print(out, "клипы:", [a["name"] for a in j["animations"]])


if __name__ == "__main__":
    main()
