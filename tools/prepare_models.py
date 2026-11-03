"""Готовит модели Meshy для телефона и кладёт результат в godot/models/.

Исходники большие (по 37–43 МБ), в репозиторий не идут — пути передаются аргументами:

  python3 tools/prepare_models.py ranger SLASH.glb RUNNING.glb RUNFAST.glb
  python3 tools/prepare_models.py sword  LONGSWORD.glb

ranger — следопыт (Shadow Ranger):
  * из модели вырезаются её собственные клинки (в правой руке и сабля у левого бедра);
  * по вырезанному клинку из руки вычисляется хват — где рукоять лежит в кулаке и куда смотрит клинок
    (в системе кости RightHand), это пишется в godot/models/hero_grip.json, чтобы наш меч держался так же;
  * анимации бега и быстрого бега переносятся в один файл к анимации удара;
  * текстуры 4096 уменьшаются: цвет 2048, нормали и металл/шероховатость 1024.

warden — герой Shadowwarden без меча (его единственная анимация — дыхание и осмотр):
  python3 tools/prepare_models.py warden WARDEN.glb SLASH.glb RUNNING.glb RUNFAST.glb
  анимации удара и бега следопыта переносятся на скелет Shadowwarden (ретаргетинг: позы покоя
  у моделей разные, поэтому вращения пересчитываются через мировые повороты костей).

bunny — боевой кролик: python3 tools/prepare_models.py bunny GUARD_PUNCH.glb KICK.glb DODGE.glb
  (одна модель, анимации стойки с ударом, удара ногой в прыжке и кувырка собираются в один файл).

trees — деревья: python3 tools/prepare_models.py trees ember=EMBER.glb pine=EVERGREEN.glb ancient=ANCIENT.glb
  → godot/models/tree_<имя>.glb (~60 тыс. треугольников, текстуры 2048), tree_<имя>_mid.glb (~8 тыс.), tree_<имя>_far.glb (~1,5 тыс.).
env — камни и горы: python3 tools/prepare_models.py env PEAK.glb MONOLITH.glb STEPS.glb OUTCROP.glb
  Mossy_Stone_Peak → godot/textures/mountain_rock.jpg — бесшовная текстура склонов всех гор (2048)
  (из цветовой текстуры модели, края сведены со сдвинутой копией), большие камни
  Mossclad_Monolith → rock_big1.glb и Mossbound_Stone_Steps → rock_big2.glb, маленький
  Mossy_Stone_Outcrop → rock_small.glb; у каждого камня три версии: вблизи ~40 тыс. треугольников
  (текстуры 2048), _mid ~6 тыс., _far ~1 тыс.

hero_skills — анимации умений героя: python3 tools/prepare_models.py hero_skills SKILL_03.glb JUMP_OVER_OBSTACLE.glb
  Skill_03 → «Whirl» (Вихрь: удар с разворотом, обрезается на полном обороте),
  Jump_Over_Obstacle → «DashJump» (Рывок: длинный прыжок). Обе переносятся на скелет героя
  (ретаргетинг), перемещение таза вперёд/вбок убирается — героя двигает сама игра.

shadowclaw — кролик-оборотень Shadowclaw Rabbit без скелета (только сетка с текстурами):
  python3 tools/prepare_models.py shadowclaw RIGGED_BUNNY.glb SHADOWCLAW.glb
  сетка упрощается до ~40 тыс. треугольников, текстуры 1024/512; скелет и анимации берутся у
  прежнего боевого кролика (RIGGED_BUNNY — его godot/models/bunny.glb) и подгоняются под новое тело:
  суставы переносятся по опорным высотам (низ ступней, плечи, макушка), веса кожи — с ближайших
  вершин старой модели. Результат заменяет godot/models/bunny.glb.

sword — длинный меч: сетка упрощается (gltfpack, ~2,5 тыс. треугольников), текстуры 1024,
рядом пишется ржавая версия цветовой текстуры (longsword_rust.jpg).
  python3 tools/prepare_models.py blade NAME BLADE.glb — другие клинки (bone_blade, crystal_blade).
"""
import io
import json
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "godot/models"


# ---------- Чтение и запись GLB
def read_glb(path):
    d = Path(path).read_bytes()
    jlen = struct.unpack_from("<I", d, 12)[0]
    j = json.loads(d[20:20 + jlen])
    blen = struct.unpack_from("<I", d, 20 + jlen)[0]
    return j, d[20 + jlen + 8:20 + jlen + 8 + blen]


def view_bytes(j, b, vi):
    v = j["bufferViews"][vi]
    o = v.get("byteOffset", 0)
    return b[o:o + v["byteLength"]]


def accessor(j, b, ai):
    a = j["accessors"][ai]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a["componentType"]]
    raw = view_bytes(j, b, a["bufferView"])
    arr = np.frombuffer(raw, dt, a["count"] * n, a.get("byteOffset", 0))
    return arr.reshape(-1, n) if n > 1 else arr


class Builder:
    """Собирает новый бинарный буфер: каждый bufferView переписывается заново."""

    def __init__(self):
        self.blob = bytearray()
        self.views = []

    def add(self, data, target=None):
        while len(self.blob) % 4:
            self.blob.append(0)
        v = {"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(data)}
        if target:
            v["target"] = target
        self.blob += data
        self.views.append(v)
        return len(self.views) - 1


def write_glb(path, j, blob):
    j["buffers"] = [{"byteLength": len(blob)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    blob = bytes(blob) + b"\0" * ((4 - len(blob) % 4) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob))
    out += struct.pack("<I4s", len(js), b"JSON") + js + struct.pack("<I4s", len(blob), b"BIN\0") + blob
    Path(path).write_bytes(out)
    print("→", Path(path).relative_to(ROOT), f"{len(out) / 1e6:.1f} МБ")


def rebuild(j, b, replace_view=None, replace_image=None):
    """Переписывает все bufferView в новый буфер; можно подменить данные отдельных view/картинок."""
    bld = Builder()
    remap = {}
    img_views = {img["bufferView"]: k for k, img in enumerate(j.get("images", []))}
    for vi, v in enumerate(j["bufferViews"]):
        data = view_bytes(j, b, vi)
        if replace_view and vi in replace_view:
            data = replace_view[vi]
        if vi in img_views and replace_image and img_views[vi] in replace_image:
            data = replace_image[img_views[vi]]
        remap[vi] = bld.add(data, v.get("target"))
        if "byteStride" in v:
            bld.views[-1]["byteStride"] = v["byteStride"]
    j["bufferViews"] = bld.views
    return bld


def resize_image(data, size, fmt):
    im = Image.open(io.BytesIO(data))
    im = im.convert("RGB")
    if max(im.size) > size:
        im = im.resize((size, size), Image.LANCZOS)
    out = io.BytesIO()
    if fmt == "JPEG":
        im.save(out, "JPEG", quality=88)
    else:
        im.save(out, "PNG", optimize=True)
    return out.getvalue()


def image_roles(j):
    m = j["materials"][0]
    pbr = m.get("pbrMetallicRoughness", {})
    roles = {}
    if "baseColorTexture" in pbr:
        roles[j["textures"][pbr["baseColorTexture"]["index"]]["source"]] = "color"
    if "metallicRoughnessTexture" in pbr:
        roles[j["textures"][pbr["metallicRoughnessTexture"]["index"]]["source"]] = "attrib"
    if "normalTexture" in m:
        roles[j["textures"][m["normalTexture"]["index"]]["source"]] = "normal"
    return roles


def shrink_textures(j, b, sizes):
    out = {}
    for k, role in image_roles(j).items():
        img = j["images"][k]
        fmt = "PNG" if role == "normal" else "JPEG"
        out[k] = resize_image(view_bytes(j, b, img["bufferView"]), sizes[role], fmt)
        img["mimeType"] = "image/png" if fmt == "PNG" else "image/jpeg"
    return out


# ---------- Следопыт
def ranger(slash_path, run_path, runfast_path):
    j, b = read_glb(slash_path)
    sk = j["skins"][0]
    names = [j["nodes"][k]["name"].split(":")[-1] for k in sk["joints"]]
    ibm = accessor(j, b, sk["inverseBindMatrices"]).reshape(-1, 4, 4)
    bind = {n: np.linalg.inv(ibm[k].T) for k, n in enumerate(names)}
    prim = j["meshes"][0]["primitives"][0]
    P = accessor(j, b, prim["attributes"]["POSITION"])
    J = accessor(j, b, prim["attributes"]["JOINTS_0"])
    W = accessor(j, b, prim["attributes"]["WEIGHTS_0"])
    dom = np.array([names[J[i, W[i].argmax()]] for i in range(len(P))])
    rh = bind["RightHand"]

    # Клинок в правой руке: вершины кисти дальше 0,2 м от сустава
    blade = (dom == "RightHand") & (np.linalg.norm(P - rh[:3, 3], axis=1) > 0.2)
    # Сабля у левого бедра — изогнутая полоса вдоль ноги (координаты в позе привязки)
    A, B = np.array([0.08, 1.11, 0.26]), np.array([0.42, 0.25, -0.17])
    t = np.clip(((P - A) @ (B - A)) / ((B - A) @ (B - A)), 0, 1)
    sabre = np.linalg.norm(P - (A + t[:, None] * (B - A)), axis=1) < 0.045

    # Хват по вырезанному клинку, в системе кости RightHand
    inv = np.linalg.inv(rh)
    to_hand = lambda pts: (inv[:3, :3] @ pts.T).T + inv[:3, 3]
    bl = to_hand(P[blade])
    c = bl.mean(0)
    u, s, vt = np.linalg.svd(bl - c)
    axis = vt[0]
    if axis @ c < 0:
        axis = -axis                         # клинок смотрит от кисти
    width = vt[1] - axis * (vt[1] @ axis)
    width /= np.linalg.norm(width)
    fist = to_hand(P[(dom == "RightHand") & ~blade]).mean(0)
    grip = c + axis * ((fist - c) @ axis)    # точка на оси клинка напротив центра кулака
    (OUT / "hero_grip.json").write_text(json.dumps({
        "grip": [round(float(x), 4) for x in grip],
        "blade": [round(float(x), 4) for x in axis],
        "width": [round(float(x), 4) for x in width],
    }, indent=1))
    print("хват:", grip.round(3), "клинок:", axis.round(3), "ширина:", width.round(3))

    # Индексы без вырезанных треугольников
    I = accessor(j, b, prim["indices"]).reshape(-1, 3)
    keep = ~(blade | sabre)[I].any(1)
    I2 = I[keep].astype(np.uint16 if len(P) < 65536 else np.uint32)
    print(f"вырезано треугольников: {(~keep).sum()} из {len(I)}")
    idx_acc = j["accessors"][prim["indices"]]
    idx_view = idx_acc["bufferView"]
    idx_acc["count"] = int(I2.size)
    idx_acc["byteOffset"] = 0
    idx_acc["componentType"] = 5123 if I2.dtype == np.uint16 else 5125

    imgs = shrink_textures(j, b, {"color": 2048, "normal": 1024, "attrib": 1024})
    bld = rebuild(j, b, replace_view={idx_view: I2.tobytes()}, replace_image=imgs)

    # Анимации из других файлов: те же узлы, переносим каналы и данные
    for path in (run_path, runfast_path):
        oj, ob = read_glb(path)
        for anim in oj["animations"]:
            new_samplers = []
            for smp in anim["samplers"]:
                ns = dict(smp)
                for key in ("input", "output"):
                    a = dict(oj["accessors"][smp[key]])
                    a.pop("bufferView")
                    a["byteOffset"] = 0
                    raw = accessor(oj, ob, smp[key]).tobytes()
                    vi = bld.add(raw)
                    a["bufferView"] = vi
                    j["accessors"].append(a)
                    ns[key] = len(j["accessors"]) - 1
                new_samplers.append(ns)
            j["animations"].append({"name": anim["name"], "channels": anim["channels"], "samplers": new_samplers})
    j["bufferViews"] = bld.views
    print("анимации:", [a["name"] for a in j["animations"]])
    write_glb(OUT / "hero.glb", j, bld.blob)


# ---------- Длинный меч
def simplify_blade(path, name, ratio=0.015):
    tmp = OUT / f"_{name}_tmp.glb"
    cmd = ["npx", "--yes", "gltfpack@0.22.0", "-i", str(path), "-o", str(tmp), "-si", str(ratio), "-noq", "-kn"]
    subprocess.run(cmd, check=True)
    j, b = read_glb(tmp)
    imgs = shrink_textures(j, b, {"color": 1024, "normal": 1024, "attrib": 512})
    bld = rebuild(j, b, replace_image=imgs)
    write_glb(OUT / f"{name}.glb", j, bld.blob)
    tmp.unlink()


def sword(path):
    tmp = OUT / "_longsword_tmp.glb"
    cmd = ["npx", "--yes", "gltfpack@0.22.0", "-i", str(path), "-o", str(tmp), "-si", "0.015", "-noq", "-kn"]
    subprocess.run(cmd, check=True)
    j, b = read_glb(tmp)
    imgs = shrink_textures(j, b, {"color": 1024, "normal": 1024, "attrib": 512})
    color_k = [k for k, r in image_roles(j).items() if r == "color"][0]
    bld = rebuild(j, b, replace_image=imgs)
    write_glb(OUT / "longsword.glb", j, bld.blob)
    tmp.unlink()
    # Ржавчина: тусклее, рыже-бурые пятна по шуму, ржавые края
    im = np.asarray(Image.open(io.BytesIO(imgs[color_k])).convert("RGB")).astype(np.float32) / 255
    h, w = im.shape[:2]
    rng = np.random.default_rng(7)
    noise = np.zeros((h, w), np.float32)
    for scale, amp in ((8, 0.5), (32, 0.3), (128, 0.2)):
        small = rng.random((scale, scale)).astype(np.float32)
        noise += amp * np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)) / 255
    rust_a = np.array([0.42, 0.2, 0.08])
    rust_b = np.array([0.6, 0.33, 0.14])
    rust = rust_a + (rust_b - rust_a) * noise[..., None]
    gray = im.mean(2, keepdims=True)
    amount = np.clip((noise - 0.35) * 2.2, 0.15, 0.85)[..., None]
    out = (gray * 0.7) * (1 - amount) + rust * amount * (0.6 + 0.6 * gray)
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(OUT / "longsword_rust.jpg", quality=88)
    print("→ godot/models/longsword_rust.jpg")


# ---------- Кватернионы (x, y, z, w)
def qmul(a, b):
    ax, ay, az, aw = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    bx, by, bz, bw = b[..., 0], b[..., 1], b[..., 2], b[..., 3]
    return np.stack([aw * bx + ax * bw + ay * bz - az * by,
                     aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw,
                     aw * bw - ax * bx - ay * by - az * bz], -1)


def qinv(a):
    return a * np.array([-1, -1, -1, 1], np.float64)


def bone_tree(j):
    names, parent = {}, {}
    for i, n in enumerate(j["nodes"]):
        if "name" in n:
            names[n["name"].split(":")[-1]] = i
        for c in n.get("children", []):
            parent[c] = i
    return names, parent


def rest_rot(n):
    return np.array(n.get("rotation", [0, 0, 0, 1]), np.float64)


def global_rest(j, i, parent):
    q = rest_rot(j["nodes"][i])
    while i in parent:
        i = parent[i]
        q = qmul(rest_rot(j["nodes"][i]), q)
    return q


def add_animation(j, bld, name, times, tracks):
    """tracks: [(node, path, values float32 array)]"""
    ta = {"bufferView": bld.add(times.astype(np.float32).tobytes()), "componentType": 5126, "count": len(times),
          "type": "SCALAR", "min": [float(times.min())], "max": [float(times.max())]}
    j["accessors"].append(ta)
    t_idx = len(j["accessors"]) - 1
    samplers, channels = [], []
    for node, path, vals in tracks:
        j["accessors"].append({"bufferView": bld.add(vals.astype(np.float32).tobytes()), "componentType": 5126,
                               "count": len(vals), "type": "VEC4" if path == "rotation" else "VEC3"})
        samplers.append({"input": t_idx, "output": len(j["accessors"]) - 1, "interpolation": "LINEAR"})
        channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": path}})
    j.setdefault("animations", []).append({"name": name, "samplers": samplers, "channels": channels})


def retarget(tj, src_path, name_map=None):
    """Анимации из src переносятся на скелет tj (одинаковые имена костей Mixamo; иначе — name_map
    «имя в источнике → имя в цели»).
    Мировой поворот кости цели = мировой поворот источника · (мировой покой источника)⁻¹ · мировой покой цели."""
    sj, sb = read_glb(src_path)
    if name_map:
        for n in sj["nodes"]:
            if n.get("name") in name_map:
                n["name"] = name_map[n["name"]]
    s_names, s_parent = bone_tree(sj)
    t_names, t_parent = bone_tree(tj)
    common = [n for n in t_names if n in s_names]
    out = []
    for anim in sj["animations"]:
        rot, tr = {}, {}
        raw = []
        for ch in anim["channels"]:
            smp = anim["samplers"][ch["sampler"]]
            node = ch["target"]["node"]
            nm = sj["nodes"][node].get("name", "").split(":")[-1]
            t_ = accessor(sj, sb, smp["input"]).astype(np.float64)
            vals = accessor(sj, sb, smp["output"]).astype(np.float64)
            if ch["target"]["path"] in ("rotation", "translation"):
                raw.append((nm, ch["target"]["path"], t_, vals))
        # Дорожки с разным числом ключей приводим к общей сетке кадров (самой подробной)
        times = max((r[2] for r in raw), key=len)
        for nm, path, t_, vals in raw:
            if len(t_) != len(times) or not np.allclose(t_, times):
                vals = np.stack([np.interp(times, t_, vals[:, c]) for c in range(vals.shape[1])], 1)
                if path == "rotation":
                    vals /= np.linalg.norm(vals, axis=1, keepdims=True)
            (rot if path == "rotation" else tr)[nm] = vals
        F = len(times)
        # Мировые повороты источника по кадрам
        s_order = sorted(s_names, key=lambda n: _depth(s_names[n], s_parent))
        s_glob = {}
        for nm in s_order:
            i = s_names[nm]
            local = rot.get(nm, np.repeat(rest_rot(sj["nodes"][i])[None], F, 0))
            p = s_parent.get(i)
            pn = sj["nodes"][p].get("name", "").split(":")[-1] if p is not None else None
            s_glob[nm] = qmul(s_glob[pn], local) if pn in s_glob else qmul(np.repeat(global_rest(sj, p, s_parent)[None], F, 0) if p is not None else np.repeat(np.array([[0, 0, 0, 1.0]]), F, 0), local)
        t_order = sorted(common, key=lambda n: _depth(t_names[n], t_parent))
        t_glob, tracks = {}, []
        for nm in t_order:
            i = t_names[nm]
            g = qmul(qmul(s_glob[nm], qinv(global_rest(sj, s_names[nm], s_parent))[None]), global_rest(tj, i, t_parent)[None])
            p = t_parent.get(i)
            pn = tj["nodes"][p].get("name", "").split(":")[-1] if p is not None else None
            if pn in t_glob:
                pg = t_glob[pn]
            elif p is not None:
                pg = np.repeat(global_rest(tj, p, t_parent)[None], F, 0)
            else:   # корневая кость без родителя
                pg = np.repeat(np.array([[0, 0, 0, 1.0]]), F, 0)
            local = qmul(qinv(pg), g)
            local /= np.linalg.norm(local, axis=1, keepdims=True)
            t_glob[nm] = g
            tracks.append((i, "rotation", local))
        # Перемещение бёдер — с поправкой на рост
        if "Hips" in tr:
            sh = np.array(sj["nodes"][s_names["Hips"]].get("translation", [0, 1, 0]))
            th = np.array(tj["nodes"][t_names["Hips"]].get("translation", [0, 1, 0]))
            k = th[1] / sh[1]
            tracks.append((t_names["Hips"], "translation", tr["Hips"] * k + (th - sh * k)))
        out.append((anim["name"], times, tracks))
    return out


def _depth(i, parent):
    d = 0
    while i in parent:
        i = parent[i]
        d += 1
    return d


def warden(path, slash, run, runfast):
    j, b = read_glb(path)
    anims = []
    for src in (slash, run, runfast):
        anims += retarget(j, src)
    imgs = shrink_textures(j, b, {"color": 2048, "normal": 1024, "attrib": 1024})
    bld = rebuild(j, b, replace_image=imgs)
    j["animations"][0]["name"] = "Idle"
    for name, times, tracks in anims:
        add_animation(j, bld, name, times, tracks)
    j["bufferViews"] = bld.views
    print("анимации:", [a["name"] for a in j["animations"]])
    write_glb(OUT / "hero.glb", j, bld.blob)
    grip = OUT / "hero_grip.json"
    if grip.exists():
        grip.unlink()   # у Shadowwarden есть кости пальцев — хват считается по ним


def warden_full(stance_path):
    """Герой из модели Shadowwarden с анимацией Combat_Stance — текстуры не сжимаются (как в исходнике).
    Все прежние анимации героя (Idle, удар, бег, быстрый бег, вихрь, прыжок рывка) переносятся с hero.glb."""
    j, b = read_glb(stance_path)
    old = OUT / "hero.glb"
    anims = retarget(j, old) if old.exists() else []
    bld = rebuild(j, b)
    for name, times, tracks in anims:
        add_animation(j, bld, name, times, tracks)
    j["bufferViews"] = bld.views
    print("анимации:", [a["name"] for a in j["animations"]])
    write_glb(OUT / "hero.glb", j, bld.blob)


# Скелет Meshy (риггинг по API) → имена костей Mixamo нашего героя
MESHY_TO_MIXAMO = {"Spine02": "Spine", "Spine01": "Spine1", "Spine": "Spine2", "neck": "Neck", "head_end": "HeadTop_End"}


def meshy_clips(*paths):
    """Клипы из файлов Meshy (meshy/<имя>/anim_*.glb) переносятся на скелет героя (godot/models/hero.glb):
    кости — по MESHY_TO_MIXAMO, пальцы (у скелета Meshy их нет) — хват меча из удара героя,
    таз — без перемещения вперёд и вбок (героя двигает игра). Клип с таким же именем заменяется."""
    j, b = read_glb(OUT / "hero.glb")
    names, _ = bone_tree(j)
    hips = names["Hips"]
    # Пальцы: поворот в первом кадре удара героя
    fingers = []
    slash = [a for a in j["animations"] if a["name"] == "Right_Hand_Sword_Slash"][0]
    for ch in slash["channels"]:
        nm = j["nodes"][ch["target"]["node"]].get("name", "")
        if ch["target"]["path"] == "rotation" and any(f in nm for f in ("Thumb", "Index", "Middle", "Ring", "Pinky")):
            v = accessor(j, b, slash["samplers"][ch["sampler"]]["output"])[0]
            fingers.append((ch["target"]["node"], v))
    clips = []
    for pth in paths:
        for name, times, tracks in retarget(j, pth, MESHY_TO_MIXAMO):
            if name == "Combat_Stance":
                continue   # стойка уже есть (из файла героя)
            out = []
            rest_h = np.array(j["nodes"][hips].get("translation", [0, 1, 0]), np.float64)
            for n, kind, v in tracks:
                if n == hips and kind == "translation":
                    v = v.copy()
                    v[:, 0] = rest_h[0]   # таз над местом героя: без сдвига вперёд и вбок
                    v[:, 2] = rest_h[2]
                out.append((n, kind, v))
            for n, v in fingers:
                out.append((n, "rotation", np.repeat(np.asarray(v, np.float64)[None], len(times), 0)))
            clips.append((name, times - times[0], out))
    keep = {c[0] for c in clips}
    bld = rebuild(j, b)
    j["animations"] = [a for a in j["animations"] if a["name"] not in keep]
    for name, times, tracks in clips:
        add_animation(j, bld, name, times, tracks)
    j["bufferViews"] = bld.views
    print("анимации:", [a["name"] for a in j["animations"]])
    write_glb(OUT / "hero.glb", j, bld.blob)


def meshy_to(target, names, *paths):
    """Клипы Meshy (meshy/hero/*.glb) переносятся на скелет Mixamo другой модели (гоблин, кролик):
    names — какие клипы взять (через запятую, «источник=новое_имя» переименовывает).
    Таз — без перемещения вперёд и вбок; уже имеющиеся у модели клипы с тем же именем заменяются."""
    tpath = OUT / target
    j, b = read_glb(tpath)
    names_t, _ = bone_tree(j)
    hips = names_t["Hips"]
    want = {}
    for part in names.split(","):
        a, _, bnm = part.partition("=")
        want[a.strip()] = (bnm or a).strip()
    clips = []
    for pth in paths:
        for name, times, tracks in retarget(j, pth, MESHY_TO_MIXAMO):
            if name not in want:
                continue
            rest_h = np.array(j["nodes"][hips].get("translation", [0, 1, 0]), np.float64)
            out = []
            for n, kind, v in tracks:
                if n == hips and kind == "translation":
                    v = v.copy()
                    v[:, 0] = rest_h[0]
                    v[:, 2] = rest_h[2]
                out.append((n, kind, v))
            clips.append((want[name], times - times[0], out))
    keep = {c[0] for c in clips}
    bld = rebuild(j, b)
    j["animations"] = [a for a in j["animations"] if a["name"] not in keep]
    for name, times, tracks in clips:
        add_animation(j, bld, name, times, tracks)
    j["bufferViews"] = bld.views
    print(target, "анимации:", [a["name"] for a in j["animations"]])
    write_glb(tpath, j, bld.blob)


def bunny(guard, kick, dodge):
    j, b = read_glb(guard)
    imgs = shrink_textures(j, b, {"color": 1024, "normal": 1024, "attrib": 512})
    bld = rebuild(j, b, replace_image=imgs)
    for path in (kick, dodge):
        oj, ob = read_glb(path)
        for anim in oj["animations"]:
            new_samplers = []
            for smp in anim["samplers"]:
                ns = dict(smp)
                for key in ("input", "output"):
                    a = dict(oj["accessors"][smp[key]])
                    a.pop("bufferView")
                    a["byteOffset"] = 0
                    a["bufferView"] = bld.add(accessor(oj, ob, smp[key]).tobytes())
                    j["accessors"].append(a)
                    ns[key] = len(j["accessors"]) - 1
                new_samplers.append(ns)
            j["animations"].append({"name": anim["name"], "channels": anim["channels"], "samplers": new_samplers})
    j["bufferViews"] = bld.views
    print("анимации:", [a["name"] for a in j["animations"]])
    write_glb(OUT / "bunny.glb", j, bld.blob)


# ---------- Камни и горы (Meshy, статичные модели)
def env_model(src, out_name, ratio, color, other, aggressive):
    tmp = ROOT / ("tools/_" + out_name)
    cmd = ["npx", "--yes", "gltfpack@0.22.0", "-i", str(src), "-o", str(tmp), "-si", str(ratio), "-noq", "-kn"]
    if aggressive:
        cmd.insert(-2, "-sa")   # швы текстуры не мешают упрощать — камню хватит ~2 тыс. треугольников
    subprocess.run(cmd, check=True)
    j, b = read_glb(tmp)
    tmp.unlink()
    imgs = shrink_textures(j, b, {"color": color, "attrib": other, "normal": other})
    bld = rebuild(j, b, replace_image=imgs)
    j["bufferViews"] = bld.views
    write_glb(OUT / out_name, j, bld.blob)


def lod_models(src, name, tris, sizes):
    """Несколько версий модели: name.glb, name_mid.glb, name_far.glb — по числу треугольников tris
    и размерам текстур sizes [(цвет, остальные), ...]."""
    j, _ = read_glb(src)
    total = 0
    for m in j["meshes"]:
        for p in m["primitives"]:
            total += j["accessors"][p["indices"]]["count"] // 3
    for suffix, n, sz in zip(["", "_mid", "_far"], tris, sizes):
        env_model(src, name + suffix + ".glb", min(1.0, n / total), sz[0], sz[1], True)


def mountain_texture(peak):
    """Склоны гор как у модели горы: её цветовая текстура → бесшовная плитка 2048."""
    j, b = read_glb(peak)
    k = [i for i, r in image_roles(j).items() if r == "color"][0]
    im = Image.open(io.BytesIO(view_bytes(j, b, j["images"][k]["bufferView"]))).convert("RGB")
    a = np.asarray(im.resize((2048, 2048), Image.LANCZOS)).astype(np.float32)
    n = a.shape[0]
    y, x = np.mgrid[0:n, 0:n] / (n - 1)
    w = np.clip(np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y)) / 0.18, 0, 1)[..., None]
    w = w * w * (3 - 2 * w)
    shifted = np.roll(np.roll(a, n // 2, 0), n // 2, 1)
    out = ROOT / "godot/textures/mountain_rock.jpg"
    out.parent.mkdir(exist_ok=True)
    Image.fromarray((a * w + shifted * (1 - w)).clip(0, 255).astype(np.uint8)).save(out, quality=90)
    print("→", out.relative_to(ROOT))


def env(peak, monolith, steps, outcrop):
    mountain_texture(peak)
    # Камни подробно (телефон мощный): вблизи ~40 тыс. треугольников, текстуры 2048/1024;
    # на среднем расстоянии ~6 тыс.; вдали ~1 тыс.
    tris = [40000, 6000, 1000]
    sizes = [(2048, 1024), (1024, 512), (512, 256)]
    lod_models(monolith, "rock_big1", tris, sizes)
    lod_models(steps, "rock_big2", tris, sizes)
    lod_models(outcrop, "rock_small", [25000, 4000, 800], sizes)


# ---------- Деревья: модели Meshy (миллионы треугольников) → ближняя и дальняя версии
def tree_models(src, name):
    """Три версии дерева: tree_<name>.glb — вблизи (~60 тыс. треугольников, текстуры 2048/1024),
    tree_<name>_mid.glb — на среднем расстоянии (~8 тыс., 1024/512), tree_<name>_far.glb — вдали (~1,5 тыс., 512)."""
    j, _ = read_glb(src)
    total = 0
    for m in j["meshes"]:
        for p in m["primitives"]:
            total += j["accessors"][p["indices"]]["count"] // 3
    env_model(src, "tree_%s.glb" % name, 60000 / total, 2048, 1024, True)
    env_model(src, "tree_%s_mid.glb" % name, 8000 / total, 1024, 512, True)
    env_model(src, "tree_%s_far.glb" % name, 1500 / total, 512, 256, True)


def trees(*pairs):
    """trees NAME=SRC.glb ...: например ember=Autumn_Ember_Tree.glb"""
    for pr in pairs:
        name, src = pr.split("=", 1)
        tree_models(src, name)


# ---------- Анимации умений героя (Вихрь, Рывок)
def _hips_yaw(q):
    x, y, z, w = q[:, 0], q[:, 1], q[:, 2], q[:, 3]
    return np.unwrap(np.arctan2(2 * (x * z + w * y), 1 - 2 * (x * x + y * y)))


def hero_skills(skill_path, jump_path):
    j, b = read_glb(OUT / "hero.glb")
    bld = rebuild(j, b)
    j["animations"] = [a for a in j["animations"] if a["name"] not in ("Whirl", "DashJump")]
    names, _ = bone_tree(j)
    hips = names["Hips"]
    for path, name in ((skill_path, "Whirl"), (jump_path, "DashJump")):
        _, times, tracks = retarget(j, path)[0]
        end = len(times)
        if name == "Whirl":
            # Обрезаем на полном обороте, чтобы в конце герой смотрел туда же, откуда начал
            rot = [v for n, pth, v in tracks if n == hips and pth == "rotation"][0]
            yaw = _hips_yaw(rot)
            turned = np.abs(yaw - yaw[0])
            idx = np.nonzero(turned >= 2 * np.pi)[0]
            if len(idx):
                end = int(idx[0]) + 1
            print("Вихрь: оборот %.0f° за %.2f с" % (np.degrees(turned[end - 1]), times[end - 1]))
        out_tracks = []
        for n, pth, v in tracks:
            v = v[:end].copy()
            if n == hips and pth == "translation":
                v[:, 0] = v[0, 0]   # без перемещения таза вперёд и вбок
                v[:, 2] = v[0, 2]
                if name == "DashJump":   # прыжок рывка низкий: подъём тела — треть исходного
                    v[:, 1] = v[0, 1] + (v[:, 1] - v[0, 1]) * 0.33
            out_tracks.append((n, pth, v))
        add_animation(j, bld, name, times[:end] - times[0], out_tracks)
    j["bufferViews"] = bld.views
    print("анимации:", [a["name"] for a in j["animations"]])
    write_glb(OUT / "hero.glb", j, bld.blob)


# ---------- Кролик-оборотень Shadowclaw: перенос скелета, весов и анимаций со старого кролика
def _landmarks(P):
    """Низ ступней, высота рук в T-позе, макушка; размах рук; середина по глубине."""
    arm = P[np.abs(P[:, 0]) > 0.45, 1].mean()
    return P[:, 1].min(), arm, P[:, 1].max(), np.abs(P[:, 0]).max(), (P[:, 2].min() + P[:, 2].max()) / 2


class BodyMap:
    """Старое тело → новое: по высоте кусочно-линейно (ступни, плечи, макушка), по ширине — размах рук."""

    def __init__(self, old_p, new_p):
        o, n = _landmarks(old_p), _landmarks(new_p)
        self.yo, self.yn = np.array(o[:3]), np.array(n[:3])
        self.sx = n[3] / o[3]
        self.dz = n[4] - o[4]

    def fwd(self, p):
        p = np.array(p, dtype=np.float64).reshape(-1, 3).copy()
        p[:, 0] *= self.sx
        p[:, 1] = np.interp(p[:, 1], self.yo, self.yn)
        p[:, 2] += self.dz
        return p

    def inv(self, p):
        p = np.array(p, dtype=np.float64).reshape(-1, 3).copy()
        p[:, 0] /= self.sx
        p[:, 1] = np.interp(p[:, 1], self.yn, self.yo)
        p[:, 2] -= self.dz
        return p


def _skin_transfer(old_p, old_j, old_w, new_p_old_space, k=6):
    """Веса кожи для новых вершин: средние по k ближайшим вершинам старой модели (по 1/расстояние)."""
    n_joints = int(old_j.max()) + 1
    dense = np.zeros((len(old_p), n_joints), np.float32)
    for c in range(4):
        np.add.at(dense, (np.arange(len(old_p)), old_j[:, c].astype(int)), old_w[:, c])
    J = np.zeros((len(new_p_old_space), 4), np.uint16)
    W = np.zeros((len(new_p_old_space), 4), np.float32)
    o2 = (old_p ** 2).sum(1)
    for s in range(0, len(new_p_old_space), 2048):
        q = new_p_old_space[s:s + 2048]
        d2 = (q ** 2).sum(1)[:, None] + o2[None, :] - 2 * q @ old_p.T
        idx = np.argpartition(d2, k, axis=1)[:, :k]
        dd = np.sqrt(np.maximum(np.take_along_axis(d2, idx, 1), 1e-12))
        wk = 1.0 / (dd + 1e-4)
        acc = (dense[idx] * wk[:, :, None]).sum(1)
        top = np.argsort(-acc, axis=1)[:, :4]
        tw = np.take_along_axis(acc, top, 1)
        tw /= tw.sum(1, keepdims=True)
        J[s:s + 2048] = top
        W[s:s + 2048] = tw
    return J, W


def _acc(j, bld, arr, ctype, typ, target=None, minmax=False):
    a = {"bufferView": bld.add(np.ascontiguousarray(arr).tobytes(), target), "componentType": ctype,
         "count": int(arr.shape[0]), "type": typ}
    if minmax:
        a["min"] = arr.min(0).tolist()
        a["max"] = arr.max(0).tolist()
    j["accessors"].append(a)
    return len(j["accessors"]) - 1


def shadowclaw(rig_path, mesh_path):
    # 1. Новая сетка: упрощение и текстуры поменьше
    tmp = ROOT / "tools/_shadowclaw_lo.glb"
    subprocess.run(["npx", "--yes", "gltfpack@0.22.0", "-i", str(mesh_path), "-o", str(tmp), "-si", "0.025", "-noq", "-kn"], check=True)
    nj, nb = read_glb(tmp)
    tmp.unlink()
    imgs = shrink_textures(nj, nb, {"color": 1024, "attrib": 512, "normal": 1024})
    nprim = nj["meshes"][0]["primitives"][0]
    NP = accessor(nj, nb, nprim["attributes"]["POSITION"]).astype(np.float64)
    NP[:, 1] -= NP[:, 1].min()   # модель стоит центром в нуле — ставим ступни на землю
    NN = accessor(nj, nb, nprim["attributes"]["NORMAL"])
    NT = accessor(nj, nb, nprim["attributes"]["TEXCOORD_0"])
    NI = accessor(nj, nb, nprim["indices"]).astype(np.uint32)
    # 2. Старый кролик: сетка с весами, скелет, анимации
    oj, ob = read_glb(rig_path)
    oprim = oj["meshes"][0]["primitives"][0]
    OP = accessor(oj, ob, oprim["attributes"]["POSITION"]).astype(np.float64)
    OJ = accessor(oj, ob, oprim["attributes"]["JOINTS_0"])
    OW = accessor(oj, ob, oprim["attributes"]["WEIGHTS_0"]).astype(np.float32)
    bm = BodyMap(OP, NP)
    print("опорные высоты: старые", bm.yo.round(3), "новые", bm.yn.round(3), "ширина ×", round(bm.sx, 3), "глубина +", round(bm.dz, 3))
    J, W = _skin_transfer(OP, OJ, OW, bm.inv(NP))
    # Плащ за спиной двигается с корпусом: без ног, иначе он тянется за ними узкой лентой
    jnames = [oj["nodes"][n]["name"].split(":")[-1] for n in oj["skins"][0]["joints"]]
    leg = np.array([any(t in nm for t in ("UpLeg", "Leg", "Foot", "Toe")) for nm in jnames])
    hips = jnames.index("Hips")
    cape = (NP[:, 2] - bm.dz < -0.14) & (NP[:, 1] > 0.25)
    W[cape] *= ~leg[J[cape]]
    s_ = W[cape].sum(1)
    Wc, Jc = W[cape], J[cape]
    Jc[s_ == 0, 0] = hips
    Wc[s_ == 0, 0] = 1.0
    Wc /= Wc.sum(1, keepdims=True)
    W[cape], J[cape] = Wc, Jc
    print("плащ:", int(cape.sum()), "вершин привязаны к корпусу")
    # 3. Скелет под новое тело: мировые положения суставов переносим, повороты оставляем
    sk = oj["skins"][0]
    joints = sk["joints"]
    parent = {c: i for i, n in enumerate(oj["nodes"]) for c in n.get("children", [])}
    ibm = accessor(oj, ob, sk["inverseBindMatrices"]).reshape(-1, 4, 4)
    bind = {node: np.linalg.inv(ibm[k].T) for k, node in enumerate(joints)}
    new_pos = {node: bm.fwd(bind[node][:3, 3])[0] for node in joints}
    new_bind = {}
    for node in joints:
        m = bind[node].copy()
        m[:3, 3] = new_pos[node]
        new_bind[node] = m
    new_local = {}
    for node in joints:
        pnode = parent.get(node)
        if pnode in new_bind:
            loc = np.linalg.inv(new_bind[pnode]) @ new_bind[node]
            new_local[node] = loc[:3, 3]
            oj["nodes"][node]["translation"] = loc[:3, 3].tolist()
        else:   # корень скелета (Hips): его положение задано в системе модели
            oj["nodes"][node]["translation"] = (np.array(oj["nodes"][node].get("translation", [0, 0, 0])) + new_pos[node] - bind[node][:3, 3]).tolist()
    # 4. Собираем файл заново: новая сетка и материал, старые узлы и анимации
    bld = Builder()
    out = {"asset": oj["asset"], "scene": 0, "scenes": oj["scenes"], "nodes": oj["nodes"], "accessors": [],
           "materials": nj["materials"], "textures": nj["textures"], "samplers": nj.get("samplers", [{}]), "images": []}
    for k, img in enumerate(nj["images"]):
        out["images"].append({"mimeType": img["mimeType"], "bufferView": bld.add(imgs[k])})
    attrs = {
        "POSITION": _acc(out, bld, NP.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": _acc(out, bld, NN.astype(np.float32), 5126, "VEC3", 34962),
        "TEXCOORD_0": _acc(out, bld, NT.astype(np.float32), 5126, "VEC2", 34962),
        "JOINTS_0": _acc(out, bld, J, 5123, "VEC4", 34962),
        "WEIGHTS_0": _acc(out, bld, W, 5126, "VEC4", 34962),
    }
    out["meshes"] = [{"name": "shadowclaw", "primitives": [{"attributes": attrs, "indices": _acc(out, bld, NI, 5125, "SCALAR", 34963), "material": 0}]}]
    nibm = np.stack([np.linalg.inv(new_bind[node]).T for node in joints]).astype(np.float32)
    out["skins"] = [{"joints": joints, "inverseBindMatrices": _acc(out, bld, nibm.reshape(-1, 16), 5126, "MAT4")}]
    hips = [n for n in joints if parent.get(n) not in new_bind]
    out["animations"] = []
    for anim in oj["animations"]:
        samplers = []
        for ch in anim["channels"]:
            smp = anim["samplers"][ch["sampler"]]
            t = accessor(oj, ob, smp["input"]).astype(np.float32)
            v = accessor(oj, ob, smp["output"]).astype(np.float64)
            node = ch["target"]["node"]
            if ch["target"]["path"] == "translation":
                if node in hips:   # таз двигается в системе модели — переносим как точку тела
                    v = bm.fwd(v)
                elif node in new_local:   # длины костей не анимируются — новые постоянные
                    v = np.tile(new_local[node], (len(v), 1))
            ti = _acc(out, bld, t.reshape(-1), 5126, "SCALAR", None, False)
            out["accessors"][ti]["min"] = [float(t.min())]
            out["accessors"][ti]["max"] = [float(t.max())]
            vi = _acc(out, bld, v.astype(np.float32), 5126, {3: "VEC3", 4: "VEC4"}[v.shape[1]])
            samplers.append({"input": ti, "output": vi, "interpolation": smp.get("interpolation", "LINEAR")})
        chans = [{"sampler": k, "target": c["target"]} for k, c in enumerate(anim["channels"])]
        out["animations"].append({"name": anim["name"], "channels": chans, "samplers": samplers})
    out["bufferViews"] = bld.views
    # Узел сетки — новая сетка со скином
    for n in out["nodes"]:
        if "mesh" in n:
            n["mesh"] = 0
            n["skin"] = 0
    write_glb(OUT / "bunny.glb", out, bld.blob)
    print("суставы: таз", new_pos[hips[0]].round(3), "| высоты:", bm.yn.round(3))


if __name__ == "__main__":
    if sys.argv[1] == "ranger":
        ranger(*sys.argv[2:5])
    elif sys.argv[1] == "sword":
        sword(sys.argv[2])
    elif sys.argv[1] == "blade":
        simplify_blade(sys.argv[3], sys.argv[2])
    elif sys.argv[1] == "warden":
        warden(*sys.argv[2:6])
    elif sys.argv[1] == "warden_full":
        warden_full(sys.argv[2])
    elif sys.argv[1] == "meshy_clips":
        meshy_clips(*sys.argv[2:])
    elif sys.argv[1] == "meshy_to":
        meshy_to(sys.argv[2], sys.argv[3], *sys.argv[4:])
    elif sys.argv[1] == "bunny":
        bunny(*sys.argv[2:5])
    elif sys.argv[1] == "env":
        env(*sys.argv[2:6])
    elif sys.argv[1] == "hero_skills":
        hero_skills(*sys.argv[2:4])
    elif sys.argv[1] == "trees":
        trees(*sys.argv[2:])
    elif sys.argv[1] == "shadowclaw":
        shadowclaw(*sys.argv[2:4])
