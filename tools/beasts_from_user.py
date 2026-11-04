#!/usr/bin/env python3
"""Волк и паук из присланных моделей (meshy/beasts/*_src.glb) → godot/models/wolf.glb, spider.glb.

1) Переворот волка: в шаге и беге повороты костей записаны добавкой к позе покоя, и волк вставал
   вертикально — они пересчитываются (покой · ключ). Кости, анимированные в шаге, но не в клипе,
   получают постоянную дорожку из первого кадра шага.
2) Добавляются клипы: Idle — поза первого кадра шага (с лёгким дыханием корпуса), Hit — отдёргивание
   корпуса назад и возврат.

python3 tools/beasts_from_user.py
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_models as pm  # noqa: E402

SRC = pm.ROOT / "meshy" / "beasts"


def qmul(a, b):
    return pm.qmul(a, b)


def axis_q(axis, deg):
    a = np.radians(deg) / 2
    v = np.asarray(axis, float) / np.linalg.norm(axis)
    return np.array([*(v * np.sin(a)), np.cos(a)])


def clip_tracks(j, b, anim):
    """Дорожки клипа на общей сетке кадров: {(узел, вид): значения}, времена."""
    raw = []
    for ch in anim["channels"]:
        s = anim["samplers"][ch["sampler"]]
        raw.append((ch["target"]["node"], ch["target"]["path"], pm.accessor(j, b, s["input"]).astype(float),
                    pm.accessor(j, b, s["output"]).astype(float)))
    times = max((r[2] for r in raw), key=len)
    out = {}
    for n, kind, t, v in raw:
        if len(t) != len(times) or not np.allclose(t, times):
            v = np.stack([np.interp(times, t, v[:, c]) for c in range(v.shape[1])], 1)
            if kind == "rotation":
                v /= np.linalg.norm(v, axis=1, keepdims=True)
        out[(n, kind)] = v
    return times - times[0], out


def build(src, dst, walk, root_bone, hit_axis, offset_clips=()):
    j, b = pm.read_glb(src)
    names, _ = pm.bone_tree(j)
    clips = {}
    for a in j["animations"]:
        clips[a["name"]] = clip_tracks(j, b, a)
    # Клипы, где повороты записаны добавкой к позе покоя (ключ 0 — «без поворота»): поворот = покой · ключ.
    # У присланного волка так шаг и бег — без пересчёта он встаёт вертикально.
    for name in offset_clips:
        t, tr = clips[name]
        for (n, kind), v in list(tr.items()):
            if kind == "rotation":
                rest = np.array(j["nodes"][n].get("rotation", [0, 0, 0, 1]), float)
                tr[(n, kind)] = np.stack([qmul(rest, q) for q in v])
    wt, wtr = clips[walk]
    first = {k: v[0] for k, v in wtr.items()}
    fixed = {}
    for name, (t, tr) in clips.items():
        tr = dict(tr)
        for k, v0 in first.items():
            if k not in tr:
                tr[k] = np.repeat(v0[None], len(t), 0)
        fixed[name] = (t, tr)
        print(name, "дорожек:", len(clips[name][1]), "→", len(tr))
    # Стойка: поза первого кадра шага, корпус чуть «дышит»
    root = names[root_bone]
    t = np.linspace(0, 2.0, 21)
    tr = {k: np.repeat(v0[None], len(t), 0) for k, v0 in first.items()}
    if (root, "rotation") in tr:
        q0 = first[(root, "rotation")]
        tr[(root, "rotation")] = np.stack([qmul(q0, axis_q(hit_axis, 2.0 * np.sin(2 * np.pi * x / 2.0))) for x in t])
    fixed["Idle"] = (t, tr)
    # Реакция на удар: корпус отдёргивается назад (≈14°) и возвращается
    t = np.linspace(0, 0.45, 10)
    tr = {k: np.repeat(v0[None], len(t), 0) for k, v0 in first.items()}
    if (root, "rotation") in tr:
        q0 = first[(root, "rotation")]
        k = np.sin(np.clip(t / 0.45, 0, 1) * np.pi)
        tr[(root, "rotation")] = np.stack([qmul(q0, axis_q(hit_axis, -14.0 * x)) for x in k])
    fixed["Hit"] = (t, tr)
    bld = pm.rebuild(j, b)
    j["animations"] = []
    for name, (t, tr) in fixed.items():
        pm.add_animation(j, bld, name, t, [(n, kind, v) for (n, kind), v in tr.items()])
    j["bufferViews"] = bld.views
    print("клипы:", [a["name"] for a in j["animations"]])
    pm.write_glb(dst, j, bld.blob)


build(SRC / "wolf_src.glb", pm.OUT / "wolf.glb", "Wolf_Walk", "Bone_000", (1, 0, 0), offset_clips=("Wolf_Walk", "Wolf_Run"))
build(SRC / "spider_src.glb", pm.OUT / "spider.glb", "Spider_Walk", "Bone_000", (1, 0, 0))
