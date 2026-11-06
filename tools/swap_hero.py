#!/usr/bin/env python3
"""Новый главный герой из присланной модели (по умолчанию meshy/hero_new/Shadow_Swordsman_Running.glb):
1) недостающие кости — пальцы (tools/hero_fingers.py, из скелета манекена meshy/rig/…);
2) все движения прежнего героя (godot/models/hero.glb) переносятся на новый скелет
   (prepare_models.retarget_dir — поза покоя учитывается); свои клипы новой модели остаются;
3) клипам без пальцев — хват из стойки (tools/rig_from_mannequin.fill_fingers).
Результат — godot/models/hero.glb (прежний сохраняется в meshy/hero_new/hero_prev.glb).

python3 tools/swap_hero.py [новая_модель.glb]
"""
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_models as pm  # noqa: E402
import rig_from_mannequin as rm  # noqa: E402

NEW = Path(sys.argv[1]) if len(sys.argv) > 1 else pm.ROOT / "meshy" / "hero_new" / "Shadow_Swordsman_Running.glb"
OLD = pm.OUT / "hero.glb"
PREV = pm.ROOT / "meshy" / "hero_new" / "hero_prev.glb"


def main():
    shutil.copy(OLD, PREV)
    work = pm.OUT / "hero_new_tmp.glb"
    shutil.copy(NEW, work)
    subprocess.run([sys.executable, str(Path(__file__).parent / "hero_fingers.py"), str(work)], check=True)
    j, b = pm.read_glb(work)
    names, _ = pm.bone_tree(j)
    hips = names["Hips"]
    rest_h = np.array(j["nodes"][hips].get("translation", [0, 1, 0]), np.float64)
    own = {a["name"] for a in j.get("animations", [])}
    clips = []
    for name, times, tracks in pm.retarget_dir(j, str(PREV)):
        if name in own:
            continue   # свои движения новой модели (бег) — как есть
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
    print("клипов перенесено:", len(clips), "своих:", sorted(own))
    pm.write_glb(OLD, j, bld.blob)
    work.unlink()
    rm.fill_fingers("hero.glb")


if __name__ == "__main__":
    main()
