#!/usr/bin/env python3
"""Деревья для телефона из присланных полных моделей (полные оригиналы — в истории git, meshy/big/tree_<имя>.glb.partNN до этого изменения):
  tree_<имя>.glb       — половина треугольников (Blender Decimate), текстуры как есть: ближе 25 м;
  tree_<имя>_near.glb  — ~60 тыс. треугольников, текстуры 2048/1024: 25–60 м;
  (tree_<имя>_mid / _far — прежние: 60–130 м и дальше).
python3 tools/tree_lods.py ИМЯ ПОЛНАЯ_МОДЕЛЬ.glb [ПОЛОВИНА.glb]
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_models as pm  # noqa: E402

DEC = Path(__file__).parent / "blender" / "decimate.py"


def tris(path):
    j, _ = pm.read_glb(path)
    return sum(j["accessors"][p["indices"]]["count"] // 3 for m in j["meshes"] for p in m["primitives"] if "indices" in p)


def decimate(src, dst, ratio):
    subprocess.run(["blender", "-b", "--factory-startup", "-P", str(DEC), "--", str(src), str(dst), str(ratio)],
                   check=True, stdout=subprocess.DEVNULL)


def main():
    name, full = sys.argv[1], Path(sys.argv[2])
    half = Path(sys.argv[3]) if len(sys.argv) > 3 else pm.OUT / ("tree_%s.glb" % name)
    if len(sys.argv) <= 3:
        decimate(full, half, 0.5)
    near = pm.OUT / ("tree_%s_near.glb" % name)
    decimate(half, near, 60000 / tris(half))
    j, b = pm.read_glb(near)
    imgs = pm.shrink_textures(j, b, {"color": 2048, "attrib": 1024, "normal": 1024})
    bld = pm.rebuild(j, b, replace_image=imgs)
    j["bufferViews"] = bld.views
    pm.write_glb(near, j, bld.blob)
    print(name, "половина:", tris(half), "ближняя копия:", tris(near))


if __name__ == "__main__":
    main()
