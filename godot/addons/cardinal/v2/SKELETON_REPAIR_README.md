# CARDINAL 2.1: Auto Skeleton Repair — experimental

New script: `addons/cardinal/auto_skeleton_repair.gd`.

Provides `CardinalAutoSkeletonRepair.audit(skeleton, expected_bone_names)` for diagnostics and `add_bone_in_editor(skeleton, bone_name, parent_name, rest_transform)` for editor-only bone creation. It does **not** assign vertex skin weights, repair GLB source assets, or retarget animation tracks. Bone naming conventions vary across imported rigs; supply a matching expected-bones list. Use Blender for rigging and weights, export GLB, then reimport into Godot. Back up the original first.

Example in an editor tool script:
```gdscript
@tool
extends EditorScript
func _run() -> void:
    var rig := EditorInterface.get_edited_scene_root().get_node_or_null("Character/Skeleton3D") as Skeleton3D
    if rig != null:
        print(CardinalAutoSkeletonRepair.audit(rig))
        # Uncomment only after checking rig hierarchy and rest transform:
        # print(CardinalAutoSkeletonRepair.add_bone_in_editor(rig, "WeaponSocket", "RightHand", Transform3D.IDENTITY))
```

Imported scenes can be overwritten on reimport. Prefer a source asset or inherited scene for edits.
