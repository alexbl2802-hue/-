# Звери, которых Meshy по API не анимирует (четвероногие и восьминогие): волк и паук.
# Модель из простых форм (сглаженные капсулы и сферы), скелет, привязка (каждая часть — к своей
# кости), свои анимации. Сохраняет godot/models/wolf.glb и godot/models/spider.glb.
#
# blender -b --factory-startup -P tools/blender/beasts.py -- godot/models
#
# Координаты в описании — как в Godot: x — вбок (влево +), y — вверх, z — вперёд (морда к +Z).
import math
import sys

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

OUT = sys.argv[sys.argv.index("--") + 1]
FPS = 30


def V(x, y, z):
    """Godot (x, вверх, вперёд) → Blender (x, −вперёд, вверх): экспорт glTF развернёт обратно."""
    return Vector((x, -z, y))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def material(name, color, emit=0.0, rough=0.7, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0.0:
        b.inputs["Emission Color"].default_value = (*color, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    return m


def hexc(h):
    """Цвет #rrggbb (sRGB) → линейный, как ждёт Blender"""
    return tuple(((h >> sh & 255) / 255.0) ** 2.2 for sh in (16, 8, 0))


PARTS = []   # (объект, кость)


def part(kind, center, size, bone, mat, rot=(0, 0, 0), seg=12, along=None):
    """Часть тела: 'ball' — сглаженная сфера, 'box' — скруглённый брусок, 'cone' — конус (шип, коготь)."""
    if kind == "ball":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(6, seg // 2), radius=1.0)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=1.0, depth=2.0)
    else:
        bpy.ops.mesh.primitive_cube_add(size=2.0)
    o = bpy.context.active_object
    o.scale = (size[0] / 2.0, size[2] / 2.0, size[1] / 2.0) if kind != "ball" else (size[0], size[2], size[1])
    if along is not None:   # длинная ось части (высота) — вдоль направления along (Godot)
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(V(*along).normalized())
    else:
        o.rotation_euler = Euler((rot[0], -rot[2], rot[1]), "XYZ")   # повороты вокруг осей Godot
    o.location = V(*center)
    if kind == "box":
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        mod = o.modifiers.new("bevel", "BEVEL")
        mod.width = min(size) * 0.35
        mod.segments = 3
        bpy.ops.object.modifier_apply(modifier="bevel")
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = kind != "cone"
    PARTS.append((o, bone))
    return o


def armature(name, bones):
    """bones: [(имя, начало, конец, родитель)] в координатах Godot."""
    bpy.ops.object.armature_add(enter_editmode=True)
    arm = bpy.context.active_object
    arm.name = name
    eb = arm.data.edit_bones
    eb.remove(eb[0])
    for nm, h, t, par in bones:
        b = eb.new(nm)
        b.head = V(*h)
        b.tail = V(*t)
        b.roll = 0.0
        if par:
            b.parent = eb[par]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def bind(arm, mesh_name):
    """Склеить части в одну сетку, каждая часть целиком на своей кости, привязать к скелету."""
    for o, bone in PARTS:
        vg = o.vertex_groups.new(name=bone)
        vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    for o, _ in PARTS:
        o.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0][0]
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = mesh_name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    body.parent = arm
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    PARTS.clear()
    return body


# ---------- Анимации: повороты костей вокруг осей Godot (в позе покоя), ключи по кадрам
AX = {"x": V(1, 0, 0), "y": V(0, 1, 0), "z": V(0, 0, 1)}


def rot_q(arm, bone, turns):
    """turns: [(ось 'x'|'y'|'z', угол)] — мировые оси Godot. Возвращает локальный кватернион кости."""
    R = Matrix.Identity(3)
    for ax, a in turns:
        R = Matrix.Rotation(a, 3, AX[ax]) @ R
    M = arm.data.bones[bone].matrix_local.to_3x3()
    return (M.inverted() @ R @ M).to_quaternion()


def action(arm, name, length, keys, root=None, loop=True):
    """keys: {кость: [(доля 0..1, [(ось, угол), …]), …]}; root: [(доля, (dx, dy, dz) Godot)] — смещение таза."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    frames = max(2, round(length * FPS))
    for bone, ks in keys.items():
        pb = arm.pose.bones[bone]
        pb.rotation_mode = "QUATERNION"
        for t, turns in ks:
            pb.rotation_quaternion = rot_q(arm, bone, turns)
            pb.keyframe_insert("rotation_quaternion", frame=1 + t * frames)
    if root:
        rb = arm.pose.bones[ROOT[arm.name]]
        M = arm.data.bones[ROOT[arm.name]].matrix_local.to_3x3()
        for t, d in root:
            rb.location = M.inverted() @ V(*d)
            rb.keyframe_insert("location", frame=1 + t * frames)
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
        if loop:
            fc.modifiers.new("CYCLES")
    # дорожка NLA — чтобы экспорт взял все клипы
    tr = arm.animation_data.nla_tracks.new()
    tr.name = name
    st = tr.strips.new(name, 1, act)
    st.action_frame_end = 1 + frames
    arm.animation_data.action = None
    return act


def cyc(phase, amp, n=8, off=0.0):
    """Ключи синусоиды по кругу: [(доля, угол)] — для шага и покачивания."""
    return [(i / n, amp * math.sin(2 * math.pi * (i / n + phase)) + off) for i in range(n + 1)]


def swing(axis, phase, amp, n=8, off=0.0, extra=None):
    return [(t, [(axis, a)] + (extra or [])) for t, a in cyc(phase, amp, n, off)]


def export(path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                              export_def_bones=False, export_apply=True)
    print("→", path)


ROOT = {}

# ================= Волк: шипастый волк-убийца
reset()
fur = material("Fur", hexc(0x7a828c), rough=0.85)
fur_dark = material("FurDark", hexc(0x4a5058), rough=0.9)
belly = material("Belly", hexc(0xb8bcc4), rough=0.9)
spike_m = material("Spike", hexc(0x2a2d34), rough=0.4)
claw = material("Claw", hexc(0x1e1e22), rough=0.35)
eye = material("Eye", hexc(0xff3020), emit=3.0)
fang = material("Fang", hexc(0xf4f0e6), rough=0.3)
arm = armature("WolfRig", [
    ("hips", (0, 0.95, -0.5), (0, 0.97, 0.05), None),
    ("spine", (0, 0.97, 0.05), (0, 1.02, 0.45), "hips"),
    ("neck", (0, 1.05, 0.45), (0, 1.22, 0.7), "spine"),
    ("head", (0, 1.25, 0.7), (0, 1.22, 1.05), "neck"),
    ("jaw", (0, 1.15, 0.78), (0, 1.1, 1.08), "head"),
    ("ear.L", (0.12, 1.4, 0.72), (0.14, 1.62, 0.7), "head"),
    ("ear.R", (-0.12, 1.4, 0.72), (-0.14, 1.62, 0.7), "head"),
    ("fl_up.L", (0.2, 0.92, 0.42), (0.2, 0.5, 0.44), "spine"),
    ("fl_lo.L", (0.2, 0.5, 0.44), (0.2, 0.1, 0.42), "fl_up.L"),
    ("fl_paw.L", (0.2, 0.1, 0.42), (0.2, 0.03, 0.56), "fl_lo.L"),
    ("fl_up.R", (-0.2, 0.92, 0.42), (-0.2, 0.5, 0.44), "spine"),
    ("fl_lo.R", (-0.2, 0.5, 0.44), (-0.2, 0.1, 0.42), "fl_up.R"),
    ("fl_paw.R", (-0.2, 0.1, 0.42), (-0.2, 0.03, 0.56), "fl_lo.R"),
    ("bl_up.L", (0.2, 0.92, -0.5), (0.2, 0.52, -0.36), "hips"),
    ("bl_lo.L", (0.2, 0.52, -0.36), (0.2, 0.18, -0.56), "bl_up.L"),
    ("bl_paw.L", (0.2, 0.18, -0.56), (0.2, 0.03, -0.46), "bl_lo.L"),
    ("bl_up.R", (-0.2, 0.92, -0.5), (-0.2, 0.52, -0.36), "hips"),
    ("bl_lo.R", (-0.2, 0.52, -0.36), (-0.2, 0.18, -0.56), "bl_up.R"),
    ("bl_paw.R", (-0.2, 0.18, -0.56), (-0.2, 0.03, -0.46), "bl_lo.R"),
    ("tail1", (0, 1.05, -0.68), (0, 1.12, -0.88), "hips"),
    ("tail2", (0, 1.12, -0.88), (0, 1.17, -1.08), "tail1"),
    ("tail3", (0, 1.17, -1.08), (0, 1.2, -1.27), "tail2"),
    ("tail4", (0, 1.2, -1.27), (0, 1.21, -1.45), "tail3"),
    ("tail_tip", (0, 1.21, -1.45), (0, 1.21, -1.75), "tail4"),
])
ROOT[arm.name] = "hips"
# Туловище: мощная грудь, поджарый зад, светлое брюхо
part("ball", (0, 0.97, -0.25), (0.3, 0.27, 0.48), "hips", fur)
part("ball", (0, 1.02, 0.28), (0.34, 0.34, 0.4), "spine", fur)
part("ball", (0, 0.8, 0.0), (0.22, 0.13, 0.5), "spine", belly)
part("ball", (0, 1.12, 0.55), (0.24, 0.24, 0.26), "neck", fur)
# Голова: череп, вытянутая морда, нос, уши, глаза, клыки
part("ball", (0, 1.28, 0.8), (0.21, 0.19, 0.22), "head", fur)
part("ball", (0, 1.21, 1.0), (0.12, 0.1, 0.17), "head", fur)
part("ball", (0, 1.24, 1.15), (0.05, 0.04, 0.04), "head", claw)
part("ball", (0, 1.12, 0.98), (0.1, 0.05, 0.15), "jaw", fur_dark)
for sx, s in [(1, "L"), (-1, "R")]:
    part("cone", (sx * 0.13, 1.5, 0.71), (0.06, 0.15, 0.05), "ear." + s, fur_dark, rot=(0, 0, -sx * 0.2))
    part("ball", (sx * 0.1, 1.33, 0.97), (0.035, 0.025, 0.02), "head", eye)
    part("cone", (sx * 0.06, 1.08, 1.06), (0.022, 0.06, 0.022), "jaw", fang, rot=(math.pi, 0, 0))
# Шипы вдоль спины
for k in range(7):
    z = 0.45 - k * 0.17
    bone = "spine" if z > 0.05 else "hips"
    part("cone", (0, 1.25 - abs(k - 3) * 0.02, z), (0.05, 0.16 - abs(k - 3) * 0.015, 0.05), bone, spike_m, rot=(-0.35, 0, 0))
# Лапы
for sx, s in [(1, "L"), (-1, "R")]:
    part("ball", (sx * 0.2, 0.72, 0.43), (0.09, 0.25, 0.1), "fl_up." + s, fur)
    part("ball", (sx * 0.2, 0.3, 0.43), (0.065, 0.22, 0.07), "fl_lo." + s, fur_dark)
    part("ball", (sx * 0.2, 0.05, 0.5), (0.08, 0.045, 0.11), "fl_paw." + s, fur_dark)
    part("ball", (sx * 0.2, 0.74, -0.44), (0.1, 0.24, 0.13), "bl_up." + s, fur)
    part("ball", (sx * 0.2, 0.35, -0.46), (0.065, 0.2, 0.07), "bl_lo." + s, fur_dark)
    part("ball", (sx * 0.2, 0.06, -0.5), (0.08, 0.045, 0.12), "bl_paw." + s, fur_dark)
    for c in (-1, 0, 1):
        part("cone", (sx * 0.2 + c * 0.04, 0.04, 0.6), (0.018, 0.05, 0.018), "fl_paw." + s, claw, rot=(math.pi / 2, 0, 0))
        part("cone", (sx * 0.2 + c * 0.04, 0.04, -0.37), (0.018, 0.05, 0.018), "bl_paw." + s, claw, rot=(math.pi / 2, 0, 0))
# Хвост с шипами
for k, b in enumerate(["tail1", "tail2", "tail3", "tail4"]):
    z = -0.78 - k * 0.19
    y = 1.09 + k * 0.035
    r = 0.09 - k * 0.012
    part("ball", (0, y, z), (r, r, 0.12), b, fur)
    for sx in (1, -1):
        part("cone", (sx * r * 0.9, y + 0.03, z), (0.025, 0.08, 0.025), b, spike_m, rot=(-0.4, 0, -sx * 0.9))
part("cone", (0, 1.21, -1.6), (0.05, 0.18, 0.05), "tail_tip", spike_m, rot=(-math.pi / 2, 0, 0))
bind(arm, "Wolf")
arm.animation_data_create()
X = "x"
legs_trot = {   # фаза: диагональные пары вместе
    "fl_up.L": 0.0, "bl_up.R": 0.0, "fl_up.R": 0.5, "bl_up.L": 0.5}
k = {}
for b, ph in legs_trot.items():
    lo = b.replace("_up", "_lo")
    # вперёд — минус вокруг X; нижнее звено сгибается, когда лапа идёт вперёд (поднята)
    k[b] = swing(X, ph, 0.42)
    k[lo] = [(t, [(X, (0.55 if b.startswith("f") else -0.55) * max(0.0, math.sin(2 * math.pi * (t + ph + 0.25))))]) for t, _ in cyc(0, 1)]
k["tail1"] = swing("y", 0.0, 0.18)
k["tail2"] = swing("y", 0.1, 0.18)
k["head"] = swing(X, 0.0, 0.05, off=0.0)
action(arm, "Walk", 1.0, k, root=[(t, (0, abs(math.sin(2 * math.pi * t)) * 0.03, 0)) for t, _ in cyc(0, 1)])
k = {}
gallop = {"fl_up.L": 0.0, "fl_up.R": 0.08, "bl_up.L": 0.5, "bl_up.R": 0.58}
for b, ph in gallop.items():
    lo = b.replace("_up", "_lo")
    k[b] = swing(X, ph, 0.75)
    k[lo] = [(t, [(X, (0.9 if b.startswith("f") else -0.8) * max(0.0, math.sin(2 * math.pi * (t + ph + 0.25))))]) for t, _ in cyc(0, 1)]
k["spine"] = swing(X, 0.25, 0.12)
k["hips"] = swing(X, 0.75, 0.1)
k["neck"] = swing(X, 0.0, 0.1)
k["tail1"] = [(t, [(X, -0.3)]) for t in (0, 1)]
action(arm, "Run", 0.6, k, root=[(t, (0, math.sin(2 * math.pi * t) * 0.07 + 0.04, 0)) for t, _ in cyc(0, 1)])
k = {
    "spine": swing(X, 0.0, 0.03, n=4),
    "neck": swing(X, 0.25, 0.04, n=4),
    "tail1": swing("y", 0.0, 0.25, n=4),
    "tail2": swing("y", 0.15, 0.2, n=4),
    "ear.L": swing(X, 0.0, 0.05, n=4),
}
action(arm, "Idle", 2.0, k, root=[(t, (0, math.sin(2 * math.pi * t) * 0.01, 0)) for t, _ in cyc(0, 1, 4)])
# Атака: присел, выпад, удар правой лапой сверху и укус (удар на 0,45 с из 0,8)
A = lambda *p: p
k = {
    "hips": [(0, [(X, 0)]), (0.3, [(X, 0.15)]), (0.55, [(X, -0.12)]), (1, [(X, 0)])],
    "spine": [(0, [(X, 0)]), (0.3, [(X, 0.1)]), (0.55, [(X, 0.15)]), (1, [(X, 0)])],
    "neck": [(0, [(X, 0)]), (0.3, [(X, -0.3)]), (0.55, [(X, 0.35)]), (1, [(X, 0)])],
    "jaw": [(0, [(X, 0)]), (0.4, [(X, 0.55)]), (0.6, [(X, 0)]), (1, [(X, 0)])],
    "fl_up.R": [(0, [(X, 0)]), (0.35, [(X, -1.6)]), (0.56, [(X, 0.5)]), (0.8, [(X, 0.1)]), (1, [(X, 0)])],
    "fl_lo.R": [(0, [(X, 0)]), (0.35, [(X, 0.8)]), (0.56, [(X, -0.1)]), (1, [(X, 0)])],
    "bl_up.L": [(0, [(X, 0)]), (0.3, [(X, -0.35)]), (0.55, [(X, 0.3)]), (1, [(X, 0)])],
    "bl_up.R": [(0, [(X, 0)]), (0.3, [(X, -0.35)]), (0.55, [(X, 0.3)]), (1, [(X, 0)])],
    "tail1": [(0, [(X, 0)]), (0.3, [(X, -0.4)]), (1, [(X, 0)])],
}
action(arm, "Attack", 0.8, k, root=[(0, (0, 0, 0)), (0.3, (0, -0.12, -0.15)), (0.55, (0, 0.05, 0.35)), (1, (0, 0, 0))], loop=False)
# Прицел хвостом: хвост выгибается над спиной, кончик смотрит вперёд
k = {}
for i, b in enumerate(["tail1", "tail2", "tail3", "tail4", "tail_tip"]):
    k[b] = [(0, [(X, 0)]), (0.6, [(X, 0.55 + 0.05 * i)]), (1, [(X, 0.55 + 0.05 * i)])]
k["hips"] = [(0, [(X, 0)]), (0.6, [(X, 0.12)]), (1, [(X, 0.12)])]
k["neck"] = [(0, [(X, 0)]), (0.6, [(X, -0.2)]), (1, [(X, -0.2)])]
action(arm, "Aim", 0.6, k, loop=False)
k = {
    "spine": [(0, [(X, 0)]), (0.3, [(X, -0.2)]), (1, [(X, 0)])],
    "neck": [(0, [(X, 0)]), (0.3, [(X, -0.5)]), (1, [(X, 0)])],
    "head": [(0, [(X, 0)]), (0.3, [("y", 0.3)]), (1, [(X, 0)])],
}
action(arm, "Hit", 0.45, k, root=[(0, (0, 0, 0)), (0.3, (0, 0, -0.15)), (1, (0, 0, 0))], loop=False)
export(OUT + "/wolf.glb")

# ================= Паук
reset()
shell = material("Shell", hexc(0x4a3560), rough=0.6)
shell_dark = material("ShellDark", hexc(0x2a1f36), rough=0.7)
mark = material("Mark", hexc(0xd04a60), rough=0.6)
eye = material("Eye", hexc(0xff3020), emit=3.0)
fang = material("Fang", hexc(0x1a1420), rough=0.3)
LEGS = []
bones = [
    ("body", (0, 0.62, -0.1), (0, 0.62, 0.15), None),
    ("head", (0, 0.62, 0.15), (0, 0.62, 0.42), "body"),
    ("abdomen", (0, 0.66, -0.1), (0, 0.72, -0.85), "body"),
    ("fang.L", (0.07, 0.55, 0.42), (0.07, 0.42, 0.5), "head"),
    ("fang.R", (-0.07, 0.55, 0.42), (-0.07, 0.42, 0.5), "head"),
]
for sx, s in [(1, "L"), (-1, "R")]:
    for i in range(4):
        z = 0.25 - i * 0.17
        a = sx * (i - 1.5) * 0.42          # ноги веером: передние вперёд, задние назад
        d = Vector((sx * math.cos(abs(a)), 0, (1 if i < 2 else -1) * math.sin(abs(a))))
        p0 = (sx * 0.2, 0.62, z)
        knee = (p0[0] + d.x * 0.55, 0.95, p0[2] + d.z * 0.55)
        tip = (p0[0] + d.x * 1.0, 0.02, p0[2] + d.z * 1.0)
        n = "leg%d.%s" % (i + 1, s)
        bones.append((n + "_up", p0, knee, "body"))
        bones.append((n + "_lo", knee, tip, n + "_up"))
        LEGS.append((n, sx, i, p0, knee, tip))
arm = armature("SpiderRig", bones)
ROOT[arm.name] = "body"
part("ball", (0, 0.72, -0.5), (0.48, 0.38, 0.6), "abdomen", shell, seg=16)
part("ball", (0, 0.86, -0.5), (0.18, 0.06, 0.3), "abdomen", mark)
part("ball", (0, 0.62, 0.12), (0.3, 0.22, 0.3), "body", shell_dark, seg=14)
part("ball", (0, 0.64, 0.36), (0.18, 0.15, 0.13), "head", shell_dark)
for x, y in [(-0.06, 0.72), (0.06, 0.72), (-0.12, 0.67), (0.12, 0.67)]:
    part("ball", (x, y, 0.47), (0.035, 0.035, 0.025), "head", eye)
for sx, s in [(1, "L"), (-1, "R")]:
    part("cone", (sx * 0.07, 0.48, 0.47), (0.03, 0.08, 0.03), "fang." + s, fang, rot=(math.pi, 0, 0))
for n, sx, i, p0, knee, tip in LEGS:
    for (a0, a1, b, r) in [(p0, knee, n + "_up", 0.05), (knee, tip, n + "_lo", 0.04)]:
        c = [(a0[j] + a1[j]) / 2 for j in range(3)]
        dv = Vector(a1) - Vector(a0)
        part("ball", c, (r, dv.length / 2, r), b, shell_dark, seg=8, along=tuple(dv))
bind(arm, "Spider")
arm.animation_data_create()
# Ходьба: две четвёрки ног по очереди (L1, R2, L3, R4 и наоборот); нога идёт вперёд поднятой
k = {}
for n, sx, i, *_ in LEGS:
    grp = (i % 2) ^ (0 if sx > 0 else 1)
    ph = 0.5 * grp
    k[n + "_up"] = [(t, [("y", -sx * 0.32 * math.sin(2 * math.pi * (t + ph))), ("z", sx * 0.28 * max(0.0, math.cos(2 * math.pi * (t + ph))))]) for t, _ in cyc(0, 1)]
k["abdomen"] = swing("x", 0.0, 0.04)
action(arm, "Walk", 0.6, k, root=[(t, (0, abs(math.sin(4 * math.pi * t)) * 0.03, 0)) for t, _ in cyc(0, 1)])
k = {"abdomen": swing("x", 0.0, 0.05, n=4)}
for n, sx, i, *_ in LEGS:
    k[n + "_up"] = [(t, [("z", sx * 0.04 * math.sin(2 * math.pi * (t + i * 0.2)))]) for t, _ in cyc(0, 1, 4)]
action(arm, "Idle", 2.0, k, root=[(t, (0, math.sin(2 * math.pi * t) * 0.01, 0)) for t, _ in cyc(0, 1, 4)])
# Бросок-укус: откинулся назад, бросок вперёд, клыки сжимаются (удар на 0,35 с из 0,7)
k = {
    "body": [(0, [("x", 0)]), (0.3, [("x", -0.35)]), (0.5, [("x", 0.25)]), (1, [("x", 0)])],
    "fang.L": [(0, [("y", 0)]), (0.3, [("y", 0.5)]), (0.5, [("y", -0.3)]), (1, [("y", 0)])],
    "fang.R": [(0, [("y", 0)]), (0.3, [("y", -0.5)]), (0.5, [("y", 0.3)]), (1, [("y", 0)])],
}
for n, sx, i, *_ in LEGS:
    if i < 2:
        k[n + "_up"] = [(0, [("z", 0)]), (0.3, [("z", sx * 0.6)]), (0.5, [("z", -sx * 0.1)]), (1, [("z", 0)])]
action(arm, "Attack", 0.7, k, root=[(0, (0, 0, 0)), (0.3, (0, 0.05, -0.2)), (0.5, (0, -0.05, 0.4)), (1, (0, 0, 0))], loop=False)
# На дыбы (плевок королевы): тело запрокидывается, передние ноги вверх
k = {"body": [(0, [("x", 0)]), (0.7, [("x", -0.6)]), (1, [("x", -0.6)])]}
for n, sx, i, *_ in LEGS:
    if i < 2:
        k[n + "_up"] = [(0, [("z", 0)]), (0.7, [("z", sx * 0.9)]), (1, [("z", sx * 0.9)])]
action(arm, "Rear", 0.8, k, root=[(0, (0, 0, 0)), (0.7, (0, 0.25, -0.15)), (1, (0, 0.25, -0.15))], loop=False)
k = {"body": [(0, [("x", 0)]), (0.3, [("x", -0.25), ("z", 0.15)]), (1, [("x", 0)])]}
action(arm, "Hit", 0.45, k, root=[(0, (0, 0, 0)), (0.3, (0, 0.05, -0.15)), (1, (0, 0, 0))], loop=False)
export(OUT + "/spider.glb")
