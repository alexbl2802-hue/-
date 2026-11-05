#!/usr/bin/env python3
"""Движения из присланного файла (meshy/rig/mannequin_all_animation.glb: манекен Mixamo, 68 костей
с пальцами, 20 клипов) — герою и монстрам-людям (гоблин/кобольд/голем, скелеты, кролик).

Герой:
  1) пальцы: tools/hero_fingers.py (кости и веса пальцев из скелета манекена);
  2) клипы манекена переносятся на скелет героя (prepare_models.retarget_dir — у манекена Т-поза,
     у героя А-поза); клипы с теми же именами заменяются; таз без перемещения вперёд/вбок;
  3) шаг вперёд таза в ударах сохраняется отдельно (godot/models/hero_rootmotion.json):
     игра двигает героя по нему (настоящий шаг в ударе, ноги не скользят);
  4) в старых клипах без пальцев — хват из новой стойки (пальцы сжаты на рукояти).
Монстры: те же клипы на их скелеты (у кого есть такие кости), удары и стойка.

python3 tools/rig_from_mannequin.py [hero|mobs|all]
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_models as pm  # noqa: E402

SRC = pm.ROOT / "meshy" / "rig" / "mannequin_all_animation.glb"
SKIP = {"Archery_Shot_1"}                       # лук герою не нужен
ROOT_MOTION = ["Double_Combo_Attack", "Attack", "Charged_Slash", "Axe_Spin_Attack", "_360_Power_Spin_Jump",
               "Double_Blade_Spin"]
MOB_CLIPS = {
    "goblin.glb": ["Running", "Walking", "Combat_Stance", "Double_Combo_Attack", "Attack", "Axe_Spin_Attack", "Charged_Slash"],
    "skeleton.glb": ["Running", "Combat_Stance", "Double_Combo_Attack", "Attack", "Axe_Spin_Attack"],
    "bunny.glb": ["Combat_Stance", "Walking", "Running"],
}


def finger_bones(j):
    names, _ = pm.bone_tree(j)
    return {n: i for n, i in names.items() if "Hand" in n and n[-1] in "1234" and "Hand" != n[-5:]
            and any(f in n for f in ("Thumb", "Index", "Middle", "Ring", "Pinky"))}


def apply(target, clips, strip_xz=True, rootmotion=None):
    """Перенести клипы манекена на модель target (godot/models/…); одноимённые заменяются."""
    tpath = pm.OUT / target
    j, b = pm.read_glb(tpath)
    names, _ = pm.bone_tree(j)
    hips = names["Hips"]
    rest_h = np.array(j["nodes"][hips].get("translation", [0, 1, 0]), np.float64)
    new = []
    curves = {}
    for name, times, tracks in pm.retarget_dir(j, str(SRC), only=set(clips)):
        out = []
        for n, kind, v in tracks:
            if n == hips and kind == "translation":
                v = v.copy()
                if rootmotion is not None and name in ROOT_MOTION:
                    # шаг таза вперёд (+Z модели) — отдельно, для игры; 60 кадров/с
                    t60 = np.arange(0.0, times[-1] - times[0] + 1e-6, 1.0 / 60.0)
                    z = np.interp(t60 + times[0], times, v[:, 2] - v[0, 2])
                    curves[name] = [round(float(x), 4) for x in z]
                if strip_xz:
                    v[:, 0] = rest_h[0]
                    v[:, 2] = rest_h[2]
            out.append((n, kind, v))
        new.append((name, times - times[0], out))
    keep = {c[0] for c in new}
    bld = pm.rebuild(j, b)
    j["animations"] = [a for a in j.get("animations", []) if a["name"] not in keep]
    for name, times, tracks in new:
        pm.add_animation(j, bld, name, times, tracks)
    j["bufferViews"] = bld.views
    print(target, "клипы:", sorted(keep))
    pm.write_glb(tpath, j, bld.blob)
    if rootmotion is not None:
        Path(rootmotion).write_text(json.dumps({"fps": 60, "clips": curves}))
        print("шаг в ударах:", {k: round(max(v) - min(v), 2) for k, v in curves.items()})


def fill_fingers(target, pose_clip="Combat_Stance"):
    """Клипам без дорожек пальцев — постоянный хват из стойки (первый кадр pose_clip)."""
    tpath = pm.OUT / target
    j, b = pm.read_glb(tpath)
    fb = finger_bones(j)
    if not fb:
        return
    pose = {}
    for a in j["animations"]:
        if a["name"] != pose_clip:
            continue
        for ch in a["channels"]:
            n = ch["target"]["node"]
            if n in fb.values() and ch["target"]["path"] == "rotation":
                pose[n] = pm.accessor(j, b, a["samplers"][ch["sampler"]]["output"])[0].astype(np.float64)
    if not pose:
        print("нет позы пальцев в", pose_clip)
        return
    bld = pm.rebuild(j, b)
    filled = []
    for a in j["animations"]:
        have = {ch["target"]["node"] for ch in a["channels"] if ch["target"]["path"] == "rotation"}
        missing = [n for n in pose if n not in have]
        if not missing:
            continue
        t_idx = a["samplers"][a["channels"][0]["sampler"]]["input"]
        cnt = j["accessors"][t_idx]["count"]
        for n in missing:
            vals = np.repeat(pose[n][None], cnt, 0).astype(np.float32)
            j["accessors"].append({"bufferView": bld.add(vals.tobytes()), "componentType": 5126, "count": cnt, "type": "VEC4"})
            a["samplers"].append({"input": t_idx, "output": len(j["accessors"]) - 1, "interpolation": "LINEAR"})
            a["channels"].append({"sampler": len(a["samplers"]) - 1, "target": {"node": n, "path": "rotation"}})
        filled.append(a["name"])
    j["bufferViews"] = bld.views
    print(target, "хват вклеен в", len(filled), "клипов")
    pm.write_glb(tpath, j, bld.blob)


def hero():
    subprocess.run([sys.executable, str(Path(__file__).parent / "hero_fingers.py")], check=True)
    sj, _ = pm.read_glb(SRC)
    clips = [a["name"] for a in sj["animations"] if a["name"] not in SKIP]
    apply("hero.glb", clips, rootmotion=pm.OUT / "hero_rootmotion.json")
    fill_fingers("hero.glb")


def mobs():
    for target, clips in MOB_CLIPS.items():
        apply(target, clips)
        fill_fingers(target)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("hero", "all"):
        hero()
    if what in ("mobs", "all"):
        mobs()
