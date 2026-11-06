#!/usr/bin/env python3
"""Пальцы герою: кости пальцев из присланного скелета Mixamo (meshy/rig/mannequin_all_animation.glb,
68 костей) вставляются в скелет героя (godot/models/hero.glb, 28 костей, без пальцев) — чтобы рука
сжималась на рукояти меча, а клипы с пальцами (хват) переносились полностью.

1) Кости. Положение каждой кости пальца берётся в системе кисти манекена (от запястья к кончику
   среднего пальца, большой палец — вперёд) и переносится в такую же систему кисти героя с поправкой
   на длину кисти. Повороты покоя — так же. Кончик среднего пальца у героя уже есть (Middle4) — он
   становится концом цепочки среднего пальца.
2) Веса. Вершины кисти героя (её доля веса) делятся между кистью и ближайшими фалангами: по расстоянию
   до отрезков костей в системе кисти (две ближайшие кости, вес ~ 1/расстояние⁴), ладонь остаётся
   на кисти.

python3 tools/hero_fingers.py [hero.glb] [mannequin.glb]
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_models as pm  # noqa: E402

HERO = Path(sys.argv[1]) if len(sys.argv) > 1 else pm.OUT / "hero.glb"
MANN = Path(sys.argv[2]) if len(sys.argv) > 2 else pm.ROOT / "meshy" / "rig" / "mannequin_all_animation.glb"
FINGERS = ["Thumb", "Index", "Middle", "Ring", "Pinky"]


def q2m(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def m2q(m):
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1.0) * 2
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = np.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = [0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s]
    elif m[1, 1] > m[2, 2]:
        s = np.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = [(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s]
    else:
        s = np.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = [(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s]
    q = np.array(q)
    return q / np.linalg.norm(q)


def local_m(n):
    m = np.eye(4)
    s = np.array(n.get("scale", [1, 1, 1]), float)
    m[:3, :3] = q2m(n.get("rotation", [0, 0, 0, 1])) * s
    m[:3, 3] = n.get("translation", [0, 0, 0])
    return m


def globals_(j):
    par = {}
    for i, n in enumerate(j["nodes"]):
        for c in n.get("children", []):
            par[c] = i
    g = {}

    def get(i):
        if i not in g:
            g[i] = (get(par[i]) if i in par else np.eye(4)) @ local_m(j["nodes"][i])
        return g[i]
    for i in range(len(j["nodes"])):
        get(i)
    return g, par


def by_name(j):
    return {n.get("name", ""): i for i, n in enumerate(j["nodes"])}


def frame(o, tip):
    """Система кисти: x — к кончику среднего пальца, z — вперёд (+Z в glTF), y = z × x."""
    x = tip - o
    L = np.linalg.norm(x)
    x /= L
    z = np.array([0.0, 0.0, 1.0])
    z = z - x * np.dot(z, x)
    z /= np.linalg.norm(z)
    y = np.cross(z, x)
    return np.stack([x, y, z], 1), L


def hand_cloud(j, b, hand_node, O, R, L):
    """Вершины, где главная кость — кисть, в системе кисти (в долях длины)."""
    joints = j["skins"][0]["joints"]
    if hand_node not in joints:
        return None
    hk = joints.index(hand_node)
    out = []
    for mesh in j["meshes"]:
        for prim in mesh["primitives"]:
            at = prim["attributes"]
            if "JOINTS_0" not in at:
                continue
            P = pm.accessor(j, b, at["POSITION"]).astype(np.float64)
            J = pm.accessor(j, b, at["JOINTS_0"]).astype(np.int64)
            W = pm.accessor(j, b, at["WEIGHTS_0"]).astype(np.float64)
            dom = J[np.arange(len(J)), W.argmax(1)]
            out.append(((P[dom == hk] - O) @ R) / L)
    c = np.concatenate(out) if out else np.zeros((0, 3))
    return c if len(c) > 50 else None


def axis_map(cm, ch):
    """Покоординатное соответствие облаков кисти манекена и героя (по 2-му и 98-му процентилю):
    длина пальцев, ширина ладони и отведение большого пальца берутся из геометрии героя."""
    lo_m, hi_m = np.percentile(cm, 2, 0), np.percentile(cm, 98, 0)
    lo_h, hi_h = np.percentile(ch, 2, 0), np.percentile(ch, 98, 0)
    k = (hi_h - lo_h) / np.maximum(hi_m - lo_m, 1e-6)
    return lambda c: (c - lo_m) * k + lo_h


def _chain(pts, base_x):
    """Цепочка пальца по облаку его вершин: ось (главная компонента), от основания (base_x вдоль
    кисти) к кончику; суставы 1…4 на 0, 0.4, 0.7 и 1.0 длины — по середине сечения."""
    cen = pts.mean(0)
    _, _, vt = np.linalg.svd(pts - cen, full_matrices=False)
    ax = vt[0] if vt[0][0] >= 0 else -vt[0]
    t = (pts - cen) @ ax
    t0 = (base_x - cen[0]) / max(ax[0], 0.2)
    t1 = np.percentile(t, 99.5)
    out = []
    for q in (0.0, 0.4, 0.7, 1.0):
        tq = t0 + (t1 - t0) * q
        near = pts[np.abs(t - tq) < (t1 - t0) * 0.08]
        out.append(near.mean(0) if len(near) > 4 and q > 0 else cen + ax * (tq - 0))
    return out


def fit_fingers(c, knuckle_x):
    """Пальцы по геометрии кисти (в системе кисти): четыре пальца — по ширине кисти дальше костяшек,
    большой — то, что выходит из плоскости ладони у её начала. None — если не получилось."""
    if c is None:
        return None
    palm = c[(c[:, 0] > 0.15) & (c[:, 0] < knuckle_x)]
    if len(palm) < 30:
        return None
    y0 = np.median(palm[:, 1])
    # большой палец: больше всего выходит из плоскости ладони (в одну сторону), между запястьем
    # и костяшками
    reg = (c[:, 0] > 0.25) & (c[:, 0] < knuckle_x + 0.05)
    dev = c[:, 1] - y0
    if not np.any(reg):
        return None
    sgn = np.sign(dev[reg][np.argmax(np.abs(dev[reg]))])
    lim = 0.55 * np.max(np.abs(dev[reg]))
    off = reg & (dev * sgn > lim)
    th = c[off]
    if len(th) < 30:
        return None
    # четыре пальца: дальше костяшек, 1-мерная кластеризация по ширине (z)
    fz = c[(c[:, 0] > knuckle_x + 0.06) & ~off]
    if len(fz) < 80:
        return None
    zs = np.percentile(fz[:, 2], [87, 62, 38, 13])
    for _ in range(20):
        lab = np.argmin(np.abs(fz[:, 2][:, None] - zs[None]), 1)
        zs = np.array([fz[lab == k, 2].mean() if np.any(lab == k) else zs[k] for k in range(4)])
    # указательный — ближе к большому пальцу по ширине
    order = np.argsort(-zs) if np.median(th[:, 2]) > np.median(fz[:, 2]) else np.argsort(zs)
    out = {}
    for name, k in zip(["Index", "Middle", "Ring", "Pinky"], order):
        pts = fz[lab == k]
        if len(pts) < 15:
            return None
        ch_ = _chain(pts, knuckle_x)
        d = ch_[3] - ch_[0]
        if d[0] < 0.5 * np.linalg.norm(d):   # палец должен идти вдоль кисти
            return None
        out[name] = ch_
    tc = _chain(th, th[:, 0].min())
    out["Thumb"] = tc
    return out


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(np.dot(ab, ab), 1e-12), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


def main():
    j, b = pm.read_glb(HERO)
    mj, mb = pm.read_glb(MANN)
    G, par = globals_(j)
    MG, _ = globals_(mj)
    hn, mn = by_name(j), by_name(mj)
    if "mixamorig:RightHandIndex1" in hn:
        print("у героя уже есть пальцы — ничего не делаю")
        return
    skin = j["skins"][0]
    joints = list(skin["joints"])
    ibm = pm.accessor(j, b, skin["inverseBindMatrices"]).reshape(-1, 4, 4).copy()
    new_bones = {}   # имя → индекс узла
    chains = {}      # сторона → {палец: [позиции суставов 1..4 (мир)]}, плюс кисть
    for side in ["Left", "Right"]:
        hand = hn["mixamorig:%sHand" % side]
        tip = hn["mixamorig:%sHandMiddle4" % side]
        R_h, L_h = frame(G[hand][:3, 3], G[tip][:3, 3])
        O_h = G[hand][:3, 3]
        mhand = mn["mixamorig:%sHand" % side]
        R_m, L_m = frame(MG[mhand][:3, 3], MG[mn["mixamorig:%sHandMiddle4" % side]][:3, 3])
        O_m = MG[mhand][:3, 3]
        rot_map = R_h @ R_m.T
        # Подгонка по геометрии кисти (если у обеих моделей есть вершины кисти)
        ch = hand_cloud(j, b, hand, O_h, R_h, L_h)
        cm = hand_cloud(mj, mb, mhand, O_m, R_m, L_m)
        fit = axis_map(cm, ch) if ch is not None and cm is not None else (lambda c: c)
        # костяшки — на ~0,61 длины от запястья до кончиков (так у манекена и у героев Meshy)
        knuckle = 0.61 * np.percentile(ch[:, 0], 99) if ch is not None else 0.6
        geo = fit_fingers(ch, knuckle)
        print(side, "пальцы по геометрии модели" if geo else "пальцы по манекену (геометрия не распознана)")
        # старый кончик среднего пальца больше не ребёнок кисти
        j["nodes"][hand]["children"] = [c for c in j["nodes"][hand].get("children", []) if c != tip]
        chains[side] = {"hand": O_h, "R": R_h, "L": L_h, "fingers": {}}
        for f in FINGERS:
            parent = hand
            pts = []
            for k in range(1, 5):
                name = "mixamorig:%sHand%s%d" % (side, f, k)
                mg = MG[mn[name]]
                cpos = fit((R_m.T @ (mg[:3, 3] - O_m)) / L_m)
                if geo and not (f == "Thumb" and k == 1):
                    cpos = geo[f][k - 1 if f != "Thumb" else k - 1]
                    if f == "Thumb":   # 1 — в ладони (как у манекена), 2…4 — по самому пальцу
                        cpos = geo[f][[0, 0, 1, 3][k - 1]] if k > 1 else cpos
                pos = O_h + R_h @ (cpos * L_h)
                rot = rot_map @ (mg[:3, :3] / np.linalg.norm(mg[:3, :3], axis=0))
                gm = np.eye(4)
                gm[:3, :3] = rot
                gm[:3, 3] = pos
                if f == "Middle" and k == 4:
                    idx = tip          # уже есть — переподвешиваем (и ставим на настоящий кончик)
                else:
                    idx = len(j["nodes"])
                    j["nodes"].append({"name": name})
                    joints.append(idx)
                    new_bones[name] = idx
                    ibm = np.concatenate([ibm, np.linalg.inv(gm).T[None]], 0)
                lm = np.linalg.inv(G[parent]) @ gm
                node = j["nodes"][idx]
                node["translation"] = lm[:3, 3].tolist()
                node["rotation"] = m2q(lm[:3, :3] / np.linalg.norm(lm[:3, :3], axis=0)).tolist()
                node.pop("scale", None)
                j["nodes"][parent].setdefault("children", []).append(idx)
                G[idx] = gm
                if idx == tip:
                    ibm[joints.index(tip)] = np.linalg.inv(gm).T
                pts.append(pos)
                parent = idx
            chains[side]["fingers"][f] = pts
    # Дорожки старых клипов на кончик среднего пальца теперь неверны (у него новый родитель) — убираем
    tips = {hn["mixamorig:LeftHandMiddle4"], hn["mixamorig:RightHandMiddle4"]}
    for a in j.get("animations", []):
        keep = [c for c in a["channels"] if c["target"]["node"] not in tips]
        if len(keep) != len(a["channels"]):
            used = sorted({c["sampler"] for c in keep})
            remap = {s: k for k, s in enumerate(used)}
            a["samplers"] = [a["samplers"][s] for s in used]
            for c in keep:
                c["sampler"] = remap[c["sampler"]]
            a["channels"] = keep
    # Веса пальцев
    jidx = {n: k for k, n in enumerate(joints)}
    bld = pm.rebuild(j, b)
    stats = {}
    for mesh in j["meshes"]:
        for prim in mesh["primitives"]:
            at = prim["attributes"]
            P = pm.accessor(j, b, at["POSITION"]).astype(np.float64)
            J = pm.accessor(j, b, at["JOINTS_0"]).astype(np.int64).copy()
            W = pm.accessor(j, b, at["WEIGHTS_0"]).astype(np.float64)
            wa = j["accessors"][at["WEIGHTS_0"]]
            if wa["componentType"] != 5126:
                W = W / (255.0 if wa["componentType"] == 5121 else 65535.0)
            W = W.copy()
            for side, ch in chains.items():
                hk = jidx[hn["mixamorig:%sHand" % side]]
                has = (J == hk) & (W > 0)
                rows = np.where(has.any(1))[0]
                if len(rows) == 0:
                    continue
                pts = P[rows]
                # отрезки: кисть (запястье → середина оснований пальцев) и фаланги 1..3 каждого пальца
                bases = np.mean([ch["fingers"][f][0] for f in ["Index", "Middle", "Ring", "Pinky"]], 0)
                segs = [(hk, ch["hand"], bases)]
                for f in FINGERS:
                    p = ch["fingers"][f]
                    for k in range(3):
                        segs.append((jidx[new_bones["mixamorig:%sHand%s%d" % (side, f, k + 1)]], p[k], p[k + 1]))
                    # кончик: продолжение последней фаланги на треть (у кончика вершины тоже за фалангой 3)
                    ext = p[3] + (p[3] - p[2]) * 0.35
                    segs.append((segs[-1][0], p[3], ext))
                D = np.stack([seg_dist(pts, a, c) for _, a, c in segs], 1)
                # ладонь: вершины ближе к основаниям, чем фаланги, — на кисти
                order = np.argsort(D, 1)[:, :3]
                d1 = np.take_along_axis(D, order, 1)
                w = 1.0 / np.maximum(d1, 1e-4) ** 3
                w /= w.sum(1, keepdims=True)
                for r_i, r in enumerate(rows):
                    slot = int(np.where(J[r] == hk)[0][0])
                    wh = W[r, slot]
                    entries = {}
                    for s in range(4):
                        if s != slot and W[r, s] > 0:
                            entries[int(J[r, s])] = entries.get(int(J[r, s]), 0.0) + W[r, s]
                    for c in range(3):
                        bj = segs[order[r_i, c]][0]
                        entries[bj] = entries.get(bj, 0.0) + wh * w[r_i, c]
                    top = sorted(entries.items(), key=lambda e: -e[1])[:4]
                    tot = sum(v for _, v in top)
                    J[r] = 0
                    W[r] = 0
                    for s, (bj, v) in enumerate(top):
                        J[r, s] = bj
                        W[r, s] = v / tot
                    if bj != hk:
                        stats[side] = stats.get(side, 0) + 1
            jt = 5121 if len(joints) < 256 else 5123
            at["JOINTS_0"] = pm._acc(j, bld, J.astype(np.uint8 if jt == 5121 else np.uint16), jt, "VEC4", 34962)
            at["WEIGHTS_0"] = pm._acc(j, bld, W.astype(np.float32), 5126, "VEC4", 34962)
    skin["joints"] = joints
    skin["inverseBindMatrices"] = pm._acc(j, bld, ibm.astype(np.float32).reshape(-1, 16), 5126, "MAT4")
    j["bufferViews"] = bld.views
    print("костей:", len(joints), "новых:", len(new_bones), "вершин на пальцах:", stats)
    pm.write_glb(HERO, j, bld.blob)


if __name__ == "__main__":
    main()
