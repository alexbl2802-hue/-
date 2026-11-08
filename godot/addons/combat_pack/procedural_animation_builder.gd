@tool
extends Node
class_name AdventureAnimationBuilder
## Run build() in editor via an EditorScript or call from @tool script.
## Produces editable Animation resources. Bone names must match actual Skeleton3D.
@export var skeleton: Skeleton3D
@export var animation_player: AnimationPlayer
@export var right_upper_arm := "RightArm"
@export var right_forearm := "RightForeArm"
@export var left_upper_arm := "LeftArm"
@export var left_forearm := "LeftForeArm"
@export var spine := "Spine"

func build() -> void:
    if skeleton == null or animation_player == null:
        push_error("Assign skeleton and animation_player")
        return
    var library := animation_player.get_animation_library("")
    if library == null:
        library = AnimationLibrary.new()
        animation_player.add_animation_library("", library)
    _make(library, "horizontal", 0.55, {spine: [0, -0.3, 0.6, 0.15, 0], right_upper_arm: [0, -0.6, 1.0, 0.4, 0], right_forearm: [0, -0.2, 0.6, 0.2, 0]})
    _make(library, "whirlwind", 0.9, {spine: [0, -0.4, 1.0, 2.8, 0], right_upper_arm: [0, -0.8, 0.4, 0.5, 0], right_forearm: [0, -0.3, 0.1, 0.3, 0]})
    for prefix in ["shield", "sword"]:
        var arm := left_upper_arm if prefix == "shield" else right_upper_arm
        var forearm := left_forearm if prefix == "shield" else right_forearm
        _make(library, prefix + "_block_start", 0.18, {arm: [0, -0.5, -0.7, -0.7, -0.7], forearm: [0, 0.5, 0.7, 0.7, 0.7]})
        _make(library, prefix + "_block_loop", 0.6, {arm: [-0.7] * 5, forearm: [0.7] * 5}, true)
        _make(library, prefix + "_block_hit", 0.24, {arm: [-0.7, -0.9, -0.5, -0.7, -0.7], forearm: [0.7, 0.9, 0.6, 0.7, 0.7]})
        _make(library, prefix + "_block_end", 0.2, {arm: [-0.7, -0.5, -0.25, -0.1, 0], forearm: [0.7, 0.5, 0.25, 0.1, 0]})

func _make(library: AnimationLibrary, name: String, duration: float, rotations: Dictionary, loop: bool = false) -> void:
    var anim := Animation.new()
    anim.length = duration
    if loop:
        anim.loop_mode = Animation.LOOP_LINEAR
    for bone_name in rotations.keys():
        var bone_idx := skeleton.find_bone(bone_name)
        if bone_idx < 0:
            push_warning("Missing bone: " + bone_name + " (" + name + ")")
            continue
        var track := anim.add_track(Animation.TYPE_ROTATION_3D)
        var path := animation_player.get_path_to(skeleton)
        anim.track_set_path(track, NodePath(str(path) + ":" + bone_name))
        var angles: Array = rotations[bone_name]
        for i in range(5):
            var t := duration * float(i) / 4.0
            var axis := Vector3.UP if bone_name == spine else Vector3.FORWARD
            anim.rotation_track_insert_key(track, t, Quaternion(axis, float(angles[i])))
    if library.has_animation(name):
        library.remove_animation(name)
    library.add_animation(name, anim)
