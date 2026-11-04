#!/usr/bin/env python3
"""Новый герой (meshy/hero_new/Shadow_Vanguard_Kirito_Sword_Run.glb): его модель и его бег
(Kirito_Sword_Run, Running) + все движения прежнего героя (godot/models/hero.glb), перенесённые
на новый скелет (те же имена костей Mixamo; пальцев у новой модели нет — их дорожки пропускаются).
Таз — без перемещения вперёд и вбок (героя двигает игра). Результат — godot/models/hero.glb.

python3 tools/new_hero.py
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_models as pm  # noqa: E402

NEW = pm.ROOT / "meshy" / "hero_new" / "Shadow_Vanguard_Kirito_Sword_Run.glb"
OLD = pm.OUT / "hero.glb"

j, b = pm.read_glb(NEW)
names, _ = pm.bone_tree(j)
hips = names["Hips"]
own = {a["name"] for a in j["animations"]}
rest_h = np.array(j["nodes"][hips].get("translation", [0, 1, 0]), np.float64)
clips = []
for name, times, tracks in pm.retarget(j, str(OLD)):
    if name in own:
        continue   # бег — свой, из новой модели
    out = []
    for n, kind, v in tracks:
        if n == hips and kind == "translation":
            v = v.copy()
            v[:, 0] = rest_h[0]
            v[:, 2] = rest_h[2]
        out.append((n, kind, v))
    clips.append((name, times - times[0], out))
bld = pm.rebuild(j, b)
for name, times, tracks in clips:
    pm.add_animation(j, bld, name, times, tracks)
j["bufferViews"] = bld.views
print("клипы:", [a["name"] for a in j["animations"]])
pm.write_glb(OLD, j, bld.blob)
