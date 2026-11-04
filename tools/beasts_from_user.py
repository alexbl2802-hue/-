#!/usr/bin/env python3
"""Волк, паук и скелет из присланных моделей (meshy/beasts/*_src.glb, meshy/hero_new/Skeleton_Animations_Godot.glb)
→ godot/models/wolf.glb, spider.glb, skeleton.glb.

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
PRE = True   # добавка к позе покоя — в системе родителя (ключ · покой)


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


def qinv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]])


def sagittal(j, n, v):
    """Ноги шагают только вперёд-назад: из поворота кости (относительно покоя, в осях модели)
    оставляется только поворот вокруг оси X модели (поперёк тела) — без махов вбок и скручивания."""
    names, parent = pm.bone_tree(j)
    rest = np.array(j["nodes"][n].get("rotation", [0, 0, 0, 1]), float)
    g = pm.global_rest(j, n, parent)
    out = []
    for q in v:
        d = qmul(qinv(rest), q)                       # поворот в осях кости
        D = qmul(qmul(g, d), qinv(g))                 # тот же поворот в осях модели
        ang = 2 * np.arctan2(D[0], D[3])              # вокруг X модели
        D2 = np.array([np.sin(ang / 2), 0, 0, np.cos(ang / 2)])
        d2 = qmul(qmul(qinv(g), D2), g)
        out.append(qmul(rest, d2))
    return np.stack(out)


def gait_clips(j, path):
    """Клипы из Blender (tools/blender/wolf_gait.py): повороты костей относительно покоя в осях скелета
    Blender (Z вверх) → локальные повороты узлов glTF (Y вверх) по иерархии."""
    import json
    data = json.loads(Path(path).read_text())
    names, parent = pm.bone_tree(j)
    out = {}
    for name, c in data.items():
        t = np.array(c["times"], float)
        F = len(t)
        glob = {}
        order = sorted(c["rot"], key=lambda n: pm._depth(names[n], parent))
        tr = {}
        for n in order:
            i = names[n]
            g = pm.global_rest(j, i, parent)
            D = np.array([[q[1], q[3], -q[2], q[0]] for q in c["rot"][n]])   # (w,x,y,z) Blender → (x,y,z,w) glTF
            G = np.stack([qmul(d, g) for d in D])
            p = parent.get(i)
            pn = j["nodes"][p].get("name", "").split(":")[-1] if p is not None else None
            if pn in glob:
                PG = glob[pn]
            else:
                PG = np.repeat(pm.global_rest(j, p, parent)[None], F, 0) if p is not None else np.repeat(np.array([[0, 0, 0, 1.0]]), F, 0)
            loc = np.stack([qmul(qinv(PG[k]), G[k]) for k in range(F)])
            loc /= np.linalg.norm(loc, axis=1, keepdims=True)
            glob[n] = G
            tr[(i, "rotation")] = loc
        # Перемещение корня (покачивание тела)
        r = names["Bone_000"]
        rest_t = np.array(j["nodes"][r].get("translation", [0, 0, 0]), float)
        pr = parent.get(r)
        pq = pm.global_rest(j, pr, parent) if pr is not None else np.array([0, 0, 0, 1.0])
        M = np.array(pm.quat_to_mat(pq)) if hasattr(pm, "quat_to_mat") else None
        dl = []
        for d in c["root"]:
            dg = np.array([d[0], d[2], -d[1]])
            # в оси родителя: R⁻¹·d (поворот кватернионом)
            qv = qmul(qmul(qinv(pq), np.array([*dg, 0.0])), pq)
            dl.append(rest_t + qv[:3])
        tr[(r, "translation")] = np.array(dl)
        out[name] = (t - t[0], tr)
    return out


def build(src, dst, walk, root_bone, hit_axis, offset_clips=(), legs=(), leg_clips=(), gait=None):
    j, b = pm.read_glb(src)
    names, _ = pm.bone_tree(j)
    clips = {}
    for a in j["animations"]:
        clips[a["name"]] = clip_tracks(j, b, a)
    if gait:
        clips.update(gait_clips(j, gait))
    # Клипы, где повороты записаны добавкой к позе покоя (ключ 0 — «без поворота»): поворот = покой · ключ.
    # У присланного волка так шаг и бег — без пересчёта он встаёт вертикально.
    for name in offset_clips:
        t, tr = clips[name]
        for (n, kind), v in list(tr.items()):
            if kind == "rotation":
                rest = np.array(j["nodes"][n].get("rotation", [0, 0, 0, 1]), float)
                tr[(n, kind)] = np.stack([qmul(q, rest) if PRE else qmul(rest, q) for q in v])
    # Махи ногами вбок убираются (шаг и бег): у присланных клипов ноги вращались не только вперёд-назад
    for name in leg_clips:
        t, tr = clips[name]
        for (n, kind), v in list(tr.items()):
            if kind == "rotation" and j["nodes"][n].get("name", "").split(":")[-1] in legs:
                tr[(n, kind)] = sagittal(j, n, v)
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


WOLF_LEGS = ["Bone_%03d" % i for i in list(range(22, 28)) + list(range(28, 34)) + list(range(5, 10)) + list(range(10, 15))]
# Ходьба и бег волка — свои, из Blender (tools/blender/wolf_gait.py → meshy/beasts/wolf_gait.json)
build(SRC / "wolf_src.glb", pm.OUT / "wolf.glb", "Wolf_Walk", "Bone_000", (1, 0, 0), gait=SRC / "wolf_gait.json")
build(SRC / "spider_src.glb", pm.OUT / "spider.glb", "Spider_Walk", "Bone_000", (1, 0, 0))
SK_LEGS = [s + b for s in ("Left", "Right") for b in ("UpLeg", "Leg", "Foot")]
build(pm.ROOT / "meshy" / "hero_new" / "Skeleton_Animations_Godot.glb", pm.OUT / "skeleton.glb", "Skeleton_Walk", "Hips", (1, 0, 0),
      legs=SK_LEGS, leg_clips=("Skeleton_Walk", "Skeleton_Run_Anime"))

# Скелету — движения из Meshy (стойка, боевой шаг, спринт, удары), реакция на удар — своя (Hit)
pm.meshy_to("skeleton.glb", "Combat_Stance,Walk_Fight_Forward,Lean_Forward_Sprint,Left_Slash,Double_Combo_Attack,Charged_Upward_Slash",
            str(pm.ROOT / "meshy/hero/anim_92_105_97_240_221_102_86_91_147_89.glb"),
            str(pm.ROOT / "meshy/hero/anim_158_156_384_509_21_10_178_187_100_148.glb"))
