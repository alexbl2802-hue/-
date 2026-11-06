@tool
extends RefCounted
## Read-only rig/animation diagnostics. No scene mutations.

static func inspect(skeleton: Skeleton3D, animation: Animation = null) -> Array[String]:
    var issues: Array[String] = []
    if skeleton == null or not is_instance_valid(skeleton):
        issues.append("ERROR: Skeleton3D не выбран")
        return issues
    var count := skeleton.get_bone_count()
    if count == 0:
        issues.append("ERROR: скелет не содержит костей")
        return issues
    var names := {}
    for i in range(count):
        var name := skeleton.get_bone_name(i)
        if name.strip_edges().is_empty():
            issues.append("ERROR: пустое имя кости #%d" % i)
        if names.has(name.to_lower()):
            issues.append("WARNING: повторяющееся имя кости: %s" % name)
        names[name.to_lower()] = true
        var parent := skeleton.get_bone_parent(i)
        if parent >= count or parent == i:
            issues.append("ERROR: неправильный родитель у %s" % name)
        var rest := skeleton.get_bone_rest(i)
        if not rest.origin.is_finite() or not rest.basis.is_finite():
            issues.append("ERROR: нечисловая rest-трансформация: %s" % name)
        elif absf(rest.basis.determinant()) < 0.00001:
            issues.append("ERROR: вырожденная rest-трансформация: %s" % name)
    var found: Dictionary = preload("res://addons/animate/generator.gd").find_bones(skeleton)
    for required in ["left_arm", "right_arm", "left_leg", "right_leg", "spine", "head"]:
        if found.get(required, -1) < 0:
            issues.append("INFO: не найдена типовая кость: %s (возможно, нестандартный риг)" % required)
    if animation != null:
        if animation.length <= 0.0:
            issues.append("ERROR: нулевая длина анимации")
        for track in range(animation.get_track_count()):
            var path := animation.track_get_path(track)
            if animation.track_get_key_count(track) == 0:
                issues.append("WARNING: пустая дорожка %s" % str(path))
            var prev := -1.0
            for key in range(animation.track_get_key_count(track)):
                var time := animation.track_get_key_time(track, key)
                if time < prev or time > animation.length + 0.001:
                    issues.append("WARNING: ключ вне времени/порядка: %s" % str(path))
                prev = time
            if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
                var bone_name := str(path).get_slice(":", 1)
                if bone_name != "" and skeleton.find_bone(bone_name) < 0:
                    issues.append("WARNING: дорожка ссылается на отсутствующую кость: %s" % bone_name)
    if issues.is_empty():
        issues.append("OK: базовые проверки пройдены")
    return issues
