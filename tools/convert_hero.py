"""Готовит модель героя для игры: assets/models/hero.glb → godot/data/hero_model.json.

В исходном файле все детали лежат вместе (часть из них вообще не привязана к сцене),
скелета нет, руки разведены (A-поза). Скрипт:
  * собирает все детали и раскладывает их по частям тела по положению:
    туловище с головой, правая/левая рука, правая/левая нога;
  * переводит оси в систему Godot (вверх — Y, лицом — +Z);
  * опускает руки вдоль тела, чтобы работали анимации ходьбы и удара;
  * записывает вершины каждой части относительно её точки вращения (плечо, бедро).
Запуск: python3 tools/convert_hero.py
"""
import json, math, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/models/hero.glb"
OUT = ROOT / "godot/data/hero_model.json"

SHOULDER = (0.20, 1.60)   # |x|, высота плеча
HIP = (0.18, 0.98)        # |x|, высота бедра
ARM_HANG_DEG = 16.0       # на сколько градусов рука отведена от тела после выпрямления

d = SRC.read_bytes()
jlen = struct.unpack_from("<I", d, 12)[0]
gl = json.loads(d[20:20 + jlen])
bin_off = 20 + jlen + 8
acc, views = gl["accessors"], gl["bufferViews"]


def read(ai):
    a = acc[ai]
    v = views[a["bufferView"]]
    off = bin_off + v.get("byteOffset", 0) + a.get("byteOffset", 0)
    comps = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
    fmt = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[a["componentType"]]
    vals = struct.unpack_from("<%d%s" % (a["count"] * comps, fmt), d, off)
    return [vals[i:i + comps] for i in range(0, len(vals), comps)] if comps > 1 else list(vals)


def to_godot(p):
    # В файле вверх — Z, лицом — −Y. В Godot вверх — Y, герой смотрит в +Z.
    x, y, z = p
    return (x, z, -y)


def part_of(c):
    x, y, z = c          # координаты Godot
    if abs(x) > 0.3 and y > 1.1:
        return "arm_r" if x < 0 else "arm_l"
    if y < 0.92 and abs(x) > 0.03:
        return "leg_r" if x < 0 else "leg_l"
    return "body"


def lin_to_srgb(c):
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


# Оболочки для доспеха и шлема — копии торса и причёски, их растягивают поверх модели
SHELLS = {"armor": 0, "helmet": 5}
shells = {}
for name, mi in SHELLS.items():
    prim = gl["meshes"][mi]["primitives"][0]
    pos = [to_godot(p) for p in read(prim["attributes"]["POSITION"])]
    idx = read(prim["indices"])
    cx = [(min(p[k] for p in pos) + max(p[k] for p in pos)) / 2 for k in range(3)]
    shells[name] = {
        "center": [round(v, 3) for v in cx],
        "v": [round(p[k] - cx[k], 4) for p in pos for k in range(3)],
        "i": [i for t in range(0, len(idx), 3) for i in (idx[t], idx[t + 2], idx[t + 1])],
    }

parts = {k: {"v": [], "c": [], "i": []} for k in ["body", "arm_r", "arm_l", "leg_r", "leg_l"]}
for mesh in gl["meshes"]:
    for prim in mesh["primitives"]:
        pos = [to_godot(p) for p in read(prim["attributes"]["POSITION"])]
        col = read(prim["attributes"]["COLOR_0"])
        idx = read(prim["indices"])
        mn = [min(p[k] for p in pos) for k in range(3)]
        mx = [max(p[k] for p in pos) for k in range(3)]
        center = [(a + b) / 2 for a, b in zip(mn, mx)]
        pt = parts[part_of(center)]
        base = len(pt["v"])
        pt["v"] += pos
        # Цвета в файле — линейные (так их показывает Godot при обычном импорте);
        # наш шейдер ждёт sRGB, поэтому переводим
        pt["c"] += [[round(lin_to_srgb(c[k] / 255), 3) for k in range(3)] for c in col]
        # Godot считает лицевой стороной треугольники по часовой стрелке — меняем порядок
        for t in range(0, len(idx), 3):
            pt["i"] += [base + idx[t], base + idx[t + 2], base + idx[t + 1]]

out = {"parts": {}, "shells": shells}
for name, pt in parts.items():
    side = -1 if name.endswith("_r") else 1
    if name.startswith("arm"):
        pivot = (side * SHOULDER[0], SHOULDER[1], 0.0)
        # Направление руки сейчас — от плеча к самой дальней точке (кисти)
        far = max(pt["v"], key=lambda p: (p[0] - pivot[0]) ** 2 + (p[1] - pivot[1]) ** 2)
        cur = math.atan2(abs(far[0] - pivot[0]), pivot[1] - far[1])   # угол от вертикали вниз
        rot = -(cur - math.radians(ARM_HANG_DEG)) * side           # поворот в плоскости XY к телу
        cs, sn = math.cos(rot), math.sin(rot)
        verts = []
        for x, y, z in pt["v"]:
            dx, dy = x - pivot[0], y - pivot[1]
            verts.append((dx * cs - dy * sn, dx * sn + dy * cs, z))
        hand = max(verts, key=lambda p: -p[1])
        out[name.replace("arm", "hand")] = [round(hand[0], 3), round(hand[1] + 0.05, 3), round(hand[2], 3)]
    elif name.startswith("leg"):
        pivot = (side * HIP[0], HIP[1], 0.0)
        verts = [(x - pivot[0], y - pivot[1], z) for x, y, z in pt["v"]]
    else:
        pivot = (0.0, 0.0, 0.0)
        verts = pt["v"]
    out["parts"][name] = {
        "pivot": [round(v, 3) for v in pivot],
        "v": [round(c, 4) for p in verts for c in p],
        "c": [c for col in pt["c"] for c in col],
        "i": pt["i"],
    }
    print(f"{name:6} вершин {len(verts):5} треугольников {len(pt['i']) // 3:5}")

ys = [p[1] for p in parts["body"]["v"]]
out["head_top"] = round(max(ys), 3)
out["height"] = round(max(ys), 3)
OUT.write_text(json.dumps(out, separators=(",", ":")))
print("→", OUT.relative_to(ROOT), f"{OUT.stat().st_size // 1024} КБ", "кисти", out["hand_r"], out["hand_l"])
