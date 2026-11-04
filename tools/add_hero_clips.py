#!/usr/bin/env python3
"""Добавить герою клипы из присланного файла (тот же скелет Mixamo): переносятся на скелет
godot/models/hero.glb, таз — без перемещения вперёд и вбок. Клипы с такими же именами заменяются.

python3 tools/add_hero_clips.py meshy/hero_new/Shadow_Vanguard_4_Animations_Godot.glb [имя1,имя2]
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_models as pm  # noqa: E402

src = sys.argv[1]
only = set(sys.argv[2].split(",")) if len(sys.argv) > 2 else None
j, b = pm.read_glb(pm.OUT / "hero.glb")
names, _ = pm.bone_tree(j)
hips = names["Hips"]
rest_h = np.array(j["nodes"][hips].get("translation", [0, 1, 0]), np.float64)
clips = []
for name, times, tracks in pm.retarget(j, src):
    if only and name not in only:
        continue
    out = []
    for n, kind, v in tracks:
        if n == hips and kind == "translation":
            v = v.copy()
            v[:, 0] = rest_h[0]
            v[:, 2] = rest_h[2]
        out.append((n, kind, v))
    clips.append((name, times - times[0], out))
keep = {c[0] for c in clips}
bld = pm.rebuild(j, b)
j["animations"] = [a for a in j["animations"] if a["name"] not in keep]
for name, times, tracks in clips:
    pm.add_animation(j, bld, name, times, tracks)
j["bufferViews"] = bld.views
print("клипы:", [a["name"] for a in j["animations"]])
pm.write_glb(pm.OUT / "hero.glb", j, bld.blob)
