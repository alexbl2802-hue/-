# Ходьба и бег волка в Blender: лапы — через IK (цели-точки идут по траектории шага: на земле назад,
# в воздухе дугой вперёд), суставы сгибает решатель, тело покачивается, хвост и голова живут.
# Результат — повороты костей относительно позы покоя (в осях скелета) по кадрам →
# meshy/beasts/wolf_gait.json; в модель их вписывает tools/beasts_from_user.py.
#
# blender -b --factory-startup -P tools/blender/wolf_gait.py -- meshy/beasts/wolf_src.glb meshy/beasts/wolf_gait.json
import json
import math
import sys

import bpy
from mathutils import Vector

src, out = sys.argv[sys.argv.index("--") + 1:][:2]
FPS = 30
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
if arm.animation_data:
    arm.animation_data.action = None
scene = bpy.context.scene
scene.render.fps = FPS
B = arm.data.bones
P = arm.pose.bones
# Вперёд у волка — −Y (морда), вверх — +Z, поперёк — X
FWD = Vector((0, -1, 0))

# Лапы: [кость с IK, длина цепочки, кость-подошва (её голова — точка на земле), сторона, перед/зад]
LEGS = {
    "FL": ["Bone_024", 3, "Bone_023", -1, "front"],   # x < 0
    "FR": ["Bone_030", 3, "Bone_029", 1, "front"],
    "BL": ["Bone_007", 3, "Bone_006", -1, "back"],
    "BR": ["Bone_012", 3, "Bone_011", -1, "back"],
}
# у задних лап по x: Bone_009 — x>0, Bone_014 — x<0
LEGS["BR"] = ["Bone_007", 3, "Bone_006", 1, "back"]
LEGS["BL"] = ["Bone_012", 3, "Bone_011", -1, "back"]

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
targets = {}
for k, (ik_bone, chain, foot, side, part) in LEGS.items():
    tgt = bpy.data.objects.new("T_" + k, None)
    scene.collection.objects.link(tgt)
    tgt.location = B[foot].head_local.copy()
    pole = bpy.data.objects.new("P_" + k, None)
    scene.collection.objects.link(pole)
    mid = B[ik_bone].parent.parent.head_local if part == "front" else B[ik_bone].parent.head_local
    # локоть передней лапы смотрит назад (+Y), колено задней — вперёд (−Y)
    pole.location = mid + Vector((0, 0.8 if part == "front" else -0.8, 0))
    c = P[ik_bone].constraints.new("IK")
    c.target = tgt
    c.pole_target = pole
    c.chain_count = chain
    c.use_tail = True    # цель — голова подошвы = конец кости с IK
    # угол полюса подбираем так, чтобы в покое цепочка не крутилась
    c.pole_angle = math.radians(-90)
    targets[k] = (tgt, B[foot].head_local.copy())
bpy.ops.object.mode_set(mode="OBJECT")


def pole_fix():
    """Подобрать угол полюса для каждой лапы: в позе покоя кости цепочки не должны поворачиваться."""
    for k, (ik_bone, chain, foot, side, part) in LEGS.items():
        c = P[ik_bone].constraints[0]
        best, err_best = 0.0, 1e9
        for deg in range(-180, 180, 2):
            c.pole_angle = math.radians(deg)
            bpy.context.view_layer.update()
            err = 0.0
            b = P[ik_bone]
            for _ in range(chain):
                q = b.matrix.to_quaternion().rotation_difference(b.bone.matrix_local.to_quaternion())
                err += abs(q.angle)
                b = b.parent
            if err < err_best:
                best, err_best = deg, err
        c.pole_angle = math.radians(best)
        print("полюс", k, best, "°, ошибка", round(err_best, 3))


pole_fix()


def smooth(s):
    return s * s * (3 - 2 * s)


def foot_offset(phase, L, h, duty):
    """Смещение подошвы от точки покоя: (вперёд, вверх). На земле — назад, в воздухе — дугой вперёд."""
    phase %= 1.0
    if phase < duty:
        return L / 2 - L * (phase / duty), 0.0
    s = (phase - duty) / (1 - duty)
    return -L / 2 + L * smooth(s), h * math.sin(math.pi * s)


def bake(name, T, L, h, duty, phases, body):
    frames = round(T * FPS)
    clip = {"times": [], "rot": {b.name: [] for b in B}, "root": []}
    for f in range(frames + 1):
        t = f / frames
        for k, (tgt, rest) in targets.items():
            d, up = foot_offset(t + phases[k], L, h, duty)
            tgt.location = rest + FWD * d + Vector((0, 0, up))
        body(t)
        bpy.context.view_layer.update()
        clip["times"].append(f / FPS)
        for b in B:
            pb = P[b.name]
            q = pb.matrix.to_quaternion() @ b.matrix_local.to_quaternion().inverted()
            clip["rot"][b.name].append([q.w, q.x, q.y, q.z])
        root = P["Bone_000"]
        clip["root"].append(list(root.matrix.translation - B["Bone_000"].head_local))
    print(name, frames + 1, "кадров")
    return clip


def set_rot(name, axis, ang):
    pb = P[name]
    pb.rotation_mode = "AXIS_ANGLE"
    # ось — в осях скелета; переводим в оси кости
    ax = (B[name].matrix_local.to_3x3().inverted() @ Vector(axis)).normalized()
    pb.rotation_axis_angle = (ang, ax.x, ax.y, ax.z)


def body_walk(t):
    P["Bone_000"].location = B["Bone_000"].matrix_local.to_3x3().inverted() @ Vector((0, 0, 0.025 * math.cos(4 * math.pi * t)))
    set_rot("Bone_021", (1, 0, 0), 0.04 * math.sin(4 * math.pi * t))           # шея кивает в такт
    set_rot("Bone_018", (0, 0, 1), 0.18 * math.sin(2 * math.pi * t))           # хвост качается
    set_rot("Bone_017", (0, 0, 1), 0.15 * math.sin(2 * math.pi * t - 0.6))
    set_rot("Bone_004", (0, 0, 1), 0.04 * math.sin(2 * math.pi * t))           # спина изгибается


def body_run(t):
    P["Bone_000"].location = B["Bone_000"].matrix_local.to_3x3().inverted() @ Vector((0, 0, 0.07 * math.sin(2 * math.pi * t) + 0.03))
    set_rot("Bone_004", (1, 0, 0), 0.14 * math.sin(2 * math.pi * t))           # спина сжимается и распрямляется
    set_rot("Bone_003", (1, 0, 0), 0.10 * math.sin(2 * math.pi * t))
    set_rot("Bone_021", (1, 0, 0), -0.10 * math.sin(2 * math.pi * t))          # голова держится ровнее
    set_rot("Bone_018", (1, 0, 0), -0.25 + 0.12 * math.sin(2 * math.pi * t))   # хвост вытянут назад
    set_rot("Bone_017", (1, 0, 0), 0.08 * math.sin(2 * math.pi * t - 0.8))


clips = {
    # Шаг: поочерёдно задняя левая, передняя левая, задняя правая, передняя правая
    "Wolf_Walk": bake("Wolf_Walk", 1.0, 0.55, 0.12, 0.62, {"BL": 0.0, "FL": 0.25, "BR": 0.5, "FR": 0.75}, body_walk),
    # Галоп: задние почти вместе, через полцикла — передние
    "Wolf_Run": bake("Wolf_Run", 0.6, 1.25, 0.24, 0.36, {"BR": 0.0, "BL": 0.08, "FL": 0.5, "FR": 0.58}, body_run),
}
json.dump(clips, open(out, "w"))
print("→", out)
