# Шаг 2 «видео → анимация героя»: Blender headless.
# Точки тела с видео (tools/mocap/track_video.py) переносятся на скелет героя, как в Open MoCap Blender
# (точка-цель на каждую кость, кость смотрит на свою цель, движение запекается в ключи), только без окон:
#   кость смотрит от своего сустава на следующий (плечо → локоть, локоть → запястье, бедро → колено ...),
#   таз и грудь поворачиваются по линии бёдер/плеч, голова — по ушам и носу, ноги стоят на земле.
# blender -b -P tools/blender/mocap_bake.py -- точки.json godot/models/hero.glb выход.glb ИмяКлипа
import bpy, sys, json
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
src_json, src_glb, out_glb, clip = argv[0], argv[1], argv[2], argv[3]
data = json.load(open(src_json))
fps = int(round(data["fps"]))
frames = data["frames"]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src_glb)
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
for o in list(bpy.data.objects):
    if o.type == 'MESH':
        bpy.data.objects.remove(o)
if arm.animation_data:
    arm.animation_data.action = None
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
P = "mixamorig:"
pb = {b.name[len(P):]: b for b in arm.pose.bones if b.name.startswith(P)}
for b in arm.pose.bones:
    b.rotation_mode = 'QUATERNION'
    b.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
W = arm.matrix_world
rest = {k: (W @ b.matrix) for k, b in pb.items()}   # мировые матрицы костей в позе покоя
head = lambda k: rest[k].translation


def frame_of(left, up):
    """Базис: X — влево от героя, Z — вверх, Y = Z × X."""
    x = left.normalized()
    y = up.cross(x).normalized()
    z = x.cross(y)
    return Matrix((x, y, z)).transposed()


# Покой героя: линия бёдер, линия плеч, «верх» корпуса
hip_mid0 = (head("LeftUpLeg") + head("RightUpLeg")) / 2
sh_mid0 = (head("LeftArm") + head("RightArm")) / 2
F_hips0 = frame_of(head("LeftUpLeg") - head("RightUpLeg"), sh_mid0 - hip_mid0)
F_chest0 = frame_of(head("LeftArm") - head("RightArm"), sh_mid0 - hip_mid0)
print("MC hero left is +X:", head("LeftUpLeg").x > head("RightUpLeg").x)


def pts(f):
    # MediaPipe (x вправо по кадру, y вниз, z к камере меньше) → Blender (x, z, −y)
    return [Vector((p[0], p[2], -p[1])) for p in f["w"]]


# Сглаживание по времени (среднее по 5 кадрам) — убирает дрожь нейросети
raw = [pts(f) for f in frames]
n = len(raw)
L = []
for t in range(n):
    win = raw[max(0, t - 2):t + 3]
    L.append([sum((w[i] for w in win), Vector()) / len(win) for i in range(33)])

mid = lambda p, a, b: (p[a] + p[b]) / 2
DIRS = [  # кость: (откуда, куда) — номера точек MediaPipe
    ("LeftArm", 11, 13), ("LeftForeArm", 13, 15), ("LeftHand", 15, (17, 19)),
    ("RightArm", 12, 14), ("RightForeArm", 14, 16), ("RightHand", 16, (18, 20)),
    ("LeftUpLeg", 23, 25), ("LeftLeg", 25, 27), ("LeftFoot", 27, 31),
    ("RightUpLeg", 24, 26), ("RightLeg", 26, 28), ("RightFoot", 28, 32),
]


def P_(p, i):
    return mid(p, *i) if isinstance(i, tuple) else p[i]


def set_world(bone, M):
    bone.matrix = W.inverted() @ M
    bpy.context.view_layer.update()


def world(bone):
    return W @ bone.matrix


def aim(bone, d):
    """Повернуть кость так, чтобы она смотрела по направлению d (наименьший поворот)."""
    M = world(bone)
    y = (M.to_3x3() @ Vector((0, 1, 0))).normalized()
    q = y.rotation_difference(d.normalized())
    R = q.to_matrix() @ M.to_3x3()
    N = R.to_4x4()
    N.translation = M.translation
    set_world(bone, N)


def orient(bone, F_now, F_rest):
    """Повернуть кость вместе с базисом корпуса (из покоя в текущий)."""
    R = F_now @ F_rest.inverted() @ rest_rot[bone.name]
    M = R.to_4x4()
    M.translation = world(bone).translation
    set_world(bone, M)


rest_rot = {b.name: rest[k].to_3x3() for k, b in pb.items()}
keyed = ["Hips", "Spine2", "Neck", "Head"] + [d[0] for d in DIRS]
scn = bpy.context.scene
scn.render.fps = fps
act = bpy.data.actions.new("MC_" + clip)
arm.animation_data_create().action = act
feet = ["LeftToe_End", "RightToe_End", "LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]
for t, p in enumerate(L):
    f = t + 1
    scn.frame_set(f)
    for b in arm.pose.bones:
        b.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    hm, sm = mid(p, 23, 24), mid(p, 11, 12)
    orient(pb["Hips"], frame_of(p[23] - p[24], sm - hm), F_hips0)
    orient(pb["Spine2"], frame_of(p[11] - p[12], sm - hm), F_chest0)
    ears, nose = mid(p, 7, 8), p[0]
    aim(pb["Neck"], ears - sm)
    hx = p[7] - p[8]
    back = ears - nose
    orient(pb["Head"], frame_of(hx, hx.cross(back)), Matrix.Identity(3))
    for k, a, b in DIRS:
        aim(pb[k], P_(p, b) - P_(p, a))
    # Ноги на земле: самая низкая точка стопы — на высоте покоя
    low = min((W @ pb[k].matrix).translation.z for k in feet if k in pb)
    low0 = min(rest[k].translation.z for k in feet if k in rest)
    M = world(pb["Hips"])
    M.translation.z += low0 - low
    set_world(pb["Hips"], M)
    for k in keyed:
        pb[k].keyframe_insert("rotation_quaternion", frame=f)
    pb["Hips"].keyframe_insert("location", frame=f)
scn.frame_start, scn.frame_end = 1, n
bpy.ops.object.mode_set(mode='OBJECT')
ad = arm.animation_data
ad.action = None
tr = ad.nla_tracks.new(); tr.name = act.name
tr.strips.new(act.name, 1, act)
act.use_fake_user = True
bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='NLA_TRACKS', export_force_sampling=True)
print("MC DONE", act.name, n, "кадров", fps, "fps")
