@tool
extends RefCounted
## Creates only a helper bone. Does NOT modify skin weights or imported GLB files.
static func add_helper_bone(skeleton: Skeleton3D, name: String, parent_name: String) -> String:
    if skeleton == null or not is_instance_valid(skeleton):
        return "ERROR: Skeleton3D не выбран"
    name = name.strip_edges()
    if name.is_empty() or name.contains(":") or name.contains("/"):
        return "ERROR: некорректное имя кости"
    if skeleton.find_bone(name) >= 0:
        return "ERROR: кость уже существует"
    var parent := skeleton.find_bone(parent_name)
    if parent < 0:
        return "ERROR: родительская кость не найдена"
    skeleton.add_bone(name)
    var index := skeleton.find_bone(name)
    skeleton.set_bone_parent(index, parent)
    skeleton.set_bone_rest(index, Transform3D.IDENTITY)
    return "OK: создана вспомогательная кость %s. Для деформации нужны веса вершин; сохраните сцену как отдельный ресурс." % name
