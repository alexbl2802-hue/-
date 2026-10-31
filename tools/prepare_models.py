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

sword — длинный меч: сетка упрощается (gltfpack, ~2,5 тыс. треугольников), текстуры 1024,
рядом пишется ржавая версия цветовой текстуры (longsword_rust.jpg).
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


if __name__ == "__main__":
    if sys.argv[1] == "ranger":
        ranger(*sys.argv[2:5])
    elif sys.argv[1] == "sword":
        sword(sys.argv[2])
