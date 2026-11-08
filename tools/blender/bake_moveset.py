# Blender headless: Moveset Free -> анимации на скелете героя -> GLB (только скелет и действия)
import bpy, sys, os, json, traceback
argv = sys.argv[sys.argv.index("--") + 1:]
pkgs, src_glb, out_glb = argv[0], argv[1], argv[2]
keys = argv[3].split(",") if len(argv) > 3 else None
sys.path.insert(0, pkgs)
bpy.ops.wm.read_factory_settings(use_empty=True)
import moveset_free as M
from moveset_free import core, retarget
try:
    M.register()
except Exception as e:
    print("MS register:", e)
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
arm.select_set(True)
rt = retarget.Retarget(arm)
print("MS rig recognized, scale", rt.scale, "root", rt.root)
ch = M.new_char(arm)
lib = M.library()
want = keys or [k for k in lib["actions"] if "@" not in k]
for k in want:
    a = lib["actions"][k]
    M.take_lib(ch, a["action"], a["params"])
ch = core.fill_char(ch)
bpy.ops.object.mode_set(mode='POSE')
fps = 30
done = []
for k in want:
    mode = lib["actions"][k]["action"]
    try:
        clip = core.sample_clip(ch, "normal", mode, M.lookup_for(ch), fps)
        act = rt.bake("MS_" + k, clip, fps, 0.0, None)
        act.use_fake_user = True
        done.append(k)
    except Exception as e:
        print("MS FAIL", k, e); traceback.print_exc()
rt.rest()
bpy.ops.object.mode_set(mode='OBJECT')
# NLA: каждое действие отдельным клипом
ad = arm.animation_data or arm.animation_data_create()
ad.action = None
for a in bpy.data.actions:
    tr = ad.nla_tracks.new(); tr.name = a.name
    tr.strips.new(a.name, int(a.frame_range[0]), a)
bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB', use_selection=True, export_animations=True,
                          export_animation_mode='NLA_TRACKS', export_force_sampling=True)
print("MS DONE", len(done), done)
