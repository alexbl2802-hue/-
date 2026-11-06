@tool
## ANIMATE: процедурные анимации человекоподобного скелета по описанию (начальная версия).
## Работает и в редакторе (addons/animate/dock.gd), и в игре (scripts/ui/animate_panel.gd).
class_name AnimateGenerator
extends RefCounted

const ALIASES := {
    "left_arm": ["leftarm", "leftupperarm", "upperarm_l", "arm_l", "l_upperarm"],
    "right_arm": ["rightarm", "rightupperarm", "upperarm_r", "arm_r", "r_upperarm"],
    "left_forearm": ["leftforearm", "lowerarm_l", "forearm_l"],
    "right_forearm": ["rightforearm", "lowerarm_r", "forearm_r"],
    "left_leg": ["leftupleg", "leftthigh", "thigh_l", "upperleg_l"],
    "right_leg": ["rightupleg", "rightthigh", "thigh_r", "upperleg_r"],
    "left_knee": ["leftleg", "leftshin", "calf_l", "lowerleg_l"],
    "right_knee": ["rightleg", "rightshin", "calf_r", "lowerleg_r"],
    "spine": ["spine", "chest"],
    "head": ["head"]
}

static func find_bones(skeleton: Skeleton3D) -> Dictionary:
    var found := {}
    for part in ALIASES:
        found[part] = -1
        for i in range(skeleton.get_bone_count()):
            var name := skeleton.get_bone_name(i).to_lower().replace("mixamorig:", "").replace("mixamorig_", "").replace(" ", "")
            for alias in ALIASES[part]:
                if name == alias or name.contains(alias):
                    found[part] = i
                    break
            if found[part] >= 0:
                break
    return found

static func parse_prompt(prompt: String) -> Dictionary:
    var s := prompt.to_lower()
    var motion := "idle"
    if "бег" in s or "беж" in s or "run" in s:
        motion = "run"
    elif "ход" in s or "идет" in s or "идёт" in s or "walk" in s:
        motion = "walk"
    elif "рывок" in s or "dash" in s:
        motion = "dash"
    elif "удар" in s or "меч" in s or "slash" in s:
        motion = "slash"
    elif "присед" in s or "crouch" in s:
        motion = "crouch"
    elif "прыж" in s or "jump" in s:
        motion = "jump"
    elif "маш" in s or "взмах" in s or "мах" in s or "привет" in s or "wave" in s:
        motion = "wave"
    var intensity := 1.0
    if "быстр" in s or "сильн" in s or "резк" in s:
        intensity = 1.4
    if "медлен" in s or "плавн" in s:
        intensity = 0.65
    return {"motion": motion, "intensity": intensity}

## prefix — путь от корня AnimationPlayer до скелета ("" — проигрыватель смотрит прямо на скелет)
static func generate(skeleton: Skeleton3D, motion: String, duration: float, intensity: float, fps: int = 30, prefix: String = "") -> Animation:
    var anim := Animation.new()
    duration = maxf(0.2, duration)
    intensity = clampf(intensity, 0.1, 2.0)
    anim.length = duration
    anim.loop_mode = Animation.LOOP_LINEAR if motion in ["idle", "walk", "run"] else Animation.LOOP_NONE
    var bones := find_bones(skeleton)
    for part in bones:
        var index: int = bones[part]
        if index < 0:
            continue
        var track := anim.add_track(Animation.TYPE_ROTATION_3D)
        anim.track_set_path(track, NodePath("%s:%s" % [prefix, skeleton.get_bone_name(index)]))
        var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
        anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
        for frame in range(int(ceil(duration * fps)) + 1):
            var t := minf(duration, float(frame) / float(fps))
            var u := t / duration
            var phase := TAU * u
            var angle := 0.0
            var side := -1.0 if part.begins_with("left") else 1.0
            match motion:
                "walk", "run":
                    var amp := (0.35 if motion == "walk" else 0.65) * intensity
                    if part.ends_with("leg"):
                        angle = sin(phase) * amp * side
                    elif part.ends_with("arm"):
                        angle = -sin(phase) * amp * side * 0.7
                    elif part.ends_with("knee"):
                        angle = maxf(0.0, sin(phase) * side) * amp * 0.7
                    elif part == "spine":
                        angle = sin(phase * 2.0) * 0.035 * intensity
                "slash":
                    if part == "right_arm":
                        angle = (-0.8 + 1.8 * smoothstep(0.25, 0.6, u)) * sin(PI * u) * intensity
                    elif part == "spine":
                        angle = sin(PI * u) * 0.35 * intensity
                "dash":
                    if part == "spine":
                        angle = sin(PI * u) * 0.5 * intensity
                    elif part.ends_with("leg"):
                        angle = sin(PI * u) * side * 0.35 * intensity
                "crouch":
                    if part.ends_with("leg") or part.ends_with("knee"):
                        angle = sin(PI * u) * 0.55 * intensity
                    elif part == "spine":
                        angle = sin(PI * u) * 0.2 * intensity
                "jump":
                    if part.ends_with("leg"):
                        angle = sin(PI * u) * 0.35 * intensity
                    elif part.ends_with("arm"):
                        angle = -sin(PI * u) * 0.55 * intensity
                "wave":
                    if part == "right_arm":
                        angle = 0.6 * intensity + sin(phase * 3.0) * 0.25 * intensity
                    elif part == "right_forearm":
                        angle = -0.7 * intensity
                "idle":
                    if part == "spine":
                        angle = sin(phase) * 0.025 * intensity
            # Поворот кости в Godot — не добавка, а полный поворот: добавку кладём поверх позы покоя
            var rotation := rest * Quaternion(Vector3.RIGHT, angle)
            anim.rotation_track_insert_key(track, t, rotation)
    return anim
