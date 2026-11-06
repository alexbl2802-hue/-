# Упрощение сетки в Blender (Decimate, Collapse) с сохранением UV и текстур как есть.
# blender -b --factory-startup -P tools/blender/decimate.py -- вход.glb выход.glb доля
# Половина треугольников (Decimate, Collapse), текстуры и UV — как были
import bpy, sys
src, out, ratio = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in [o for o in bpy.data.objects if o.type == "MESH"]:
    before = sum(len(p.vertices) - 2 for p in o.data.polygons)
    m = o.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = float(ratio)
    m.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="dec")
    after = sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("DECIMATE", o.name, before, "->", after)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="AUTO", export_apply=True)
print("->", out)
