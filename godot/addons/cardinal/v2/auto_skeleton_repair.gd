@tool
extends RefCounted
class_name CardinalAutoSkeletonRepair

# Diagnostic and editor-only helper. Does not modify mesh weights or source GLB.
const HUMANOID: Array[String] = ["Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]

static func audit(skeleton: Skeleton3D, expected: Array[String] = HUMANOID) -> Dictionary:
    if skeleton == null:
        return {"ok": false, "error": "Skeleton3D not found"}
    var missing: Array[String] = []
    for name in expected:
        if skeleton.find_bone(name) == -1:
            missing.append(name)
    return {"ok": missing.is_empty(), "missing": missing, "bone_count": skeleton.get_bone_count(), "note": "Use a profile matching the model's bone names"}

static func add_bone_in_editor(skeleton: Skeleton3D, bone_name: String, parent_name: String, rest: Transform3D) -> Dictionary:
    if not Engine.is_editor_hint():
        return {"ok": false, "error": "Editor only"}
    if skeleton == null or bone_name.is_empty() or skeleton.find_bone(bone_name) >= 0:
        return {"ok": false, "error": "Invalid skeleton or duplicate bone"}
    var parent_idx: int = skeleton.find_bone(parent_name)
    if parent_idx < 0:
        return {"ok": false, "error": "Parent bone missing"}
    var idx: int = skeleton.get_bone_count()
    skeleton.add_bone(bone_name)
    skeleton.set_bone_parent(idx, parent_idx)
    skeleton.set_bone_rest(idx, rest)
    return {"ok": true, "bone_index": idx, "warning": "Skin weights and animation tracks not modified; rig in Blender before production"}
