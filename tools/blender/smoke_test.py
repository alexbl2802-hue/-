# Проверка Blender: открыть модель (.glb), сделать на её скелете клип «кивок» и сохранить в .glb.
# blender -b --factory-startup -P tools/blender/smoke_test.py -- вход.glb выход.glb
import bpy, sys, math
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
print("armature:", arm.name, "bones:", len(arm.data.bones), "actions:", [a.name for a in bpy.data.actions][:6])
# Простая анимация: кивок головой (проверка, что можно создавать свои клипы)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
head = [b for b in arm.pose.bones if b.name.endswith("Head")][0]
act = bpy.data.actions.new("Test_Nod")
arm.animation_data_create()
arm.animation_data.action = act
head.rotation_mode = "XYZ"
for f, a in [(1, 0), (12, 0.4), (24, 0)]:
    head.rotation_euler = (a, 0, 0)
    head.keyframe_insert("rotation_euler", frame=f)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", export_animations=True)
print("exported", argv[1])
