# Мантия (присланная модель Meshy без скелета) → плащ на скелете героя.
# Подгоняется по росту и положению героя, веса костей переносятся с тела героя (ближайшие точки),
# сохраняется вместе со скелетом героя в godot/models/cloak_mantle.glb.
#
# blender -b --factory-startup -P tools/blender/fit_cloak.py -- godot/models/hero.glb meshy/beasts/shadowmantle_src.glb godot/models/cloak_mantle.glb
import sys

import bpy
from mathutils import Vector

hero_path, cloak_path, out_path = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=hero_path)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
arm.data.pose_position = "REST"   # мерить и переносить веса в позе покоя (T-поза)
if arm.animation_data:
    arm.animation_data.action = None
body = max([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: len(o.vertex_groups))
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=cloak_path)
cloak = max([o for o in set(bpy.data.objects) - before if o.type == "MESH"], key=lambda o: len(o.data.vertices))
# Мировые габариты


def bounds(o):
    pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


# Отвязать мантию от родителя, применить преобразования
bpy.ops.object.select_all(action="DESELECT")
cloak.select_set(True)
bpy.context.view_layer.objects.active = cloak
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
blo, bhi = bounds(body)
clo, chi = bounds(cloak)
# Рост: верх капюшона — на уровне макушки героя (+2 см), низ — у щиколоток
hero_h = bhi.z - blo.z
cloak_h = chi.z - clo.z
k = (hero_h + 0.02) / cloak_h
cloak.scale = (k * 1.04, k * 1.04, k)        # чуть шире — поверх одежды героя
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
clo, chi = bounds(cloak)
c_mid = (clo + chi) / 2
# Середина туловища героя по X/Y — по костям таза и шеи
hips = arm.matrix_world @ arm.data.bones[[b.name for b in arm.data.bones if b.name.endswith("Hips")][0]].head_local
cloak.location += Vector((hips.x - c_mid.x, hips.y - c_mid.y, (blo.z + hero_h + 0.02) - chi.z))
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
print("мантия: масштаб %.3f, габариты" % k, bounds(cloak))
# Группы вершин = кости; веса — с тела героя (ближайшая точка поверхности)
for g in body.vertex_groups:
    cloak.vertex_groups.new(name=g.name)
dt = cloak.modifiers.new("dt", "DATA_TRANSFER")
dt.object = body
dt.use_vert_data = True
dt.data_types_verts = {"VGROUP_WEIGHTS"}
dt.vert_mapping = "POLYINTERP_NEAREST"
dt.layers_vgroup_select_src = "ALL"
dt.layers_vgroup_select_dst = "NAME"
bpy.context.view_layer.objects.active = cloak
bpy.ops.object.datalayout_transfer(modifier="dt")
bpy.ops.object.modifier_apply(modifier="dt")
# Не больше 4 костей на вершину, сумма 1
bpy.ops.object.select_all(action="DESELECT")
cloak.select_set(True)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
cloak.parent = arm
mod = cloak.modifiers.new("Armature", "ARMATURE")
mod.object = arm
cloak.name = "CloakMantle"
# Убрать тело героя и всё лишнее: в файле — скелет и мантия
for o in list(bpy.data.objects):
    if o not in (arm, cloak):
        bpy.data.objects.remove(o, do_unlink=True)
arm.data.pose_position = "POSE"
if arm.animation_data:
    arm.animation_data.action = None
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_animations=False, export_apply=False)
print("→", out_path)
