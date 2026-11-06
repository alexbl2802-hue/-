@tool
extends RefCounted
## Safe resource-only fixes. Always returns a duplicate; never changes the source.
static func fix_animation(source: Animation, skeleton: Skeleton3D) -> Dictionary:
    if source == null or skeleton == null:
        return {"animation": null, "changes": ["Нет анимации или скелета"]}
    var result: Animation = source.duplicate(true)
    var changes: Array[String] = []
    if result.length < 0.2:
        result.length = 0.2
        changes.append("Длительность увеличена до 0.2 сек")
    for track in range(result.get_track_count() - 1, -1, -1):
        if result.track_get_key_count(track) == 0:
            changes.append("Удалена пустая дорожка: %s" % str(result.track_get_path(track)))
            result.remove_track(track)
            continue
        if result.track_get_type(track) == Animation.TYPE_ROTATION_3D:
            var path := str(result.track_get_path(track))
            var bone_name := path.get_slice(":", 1)
            if bone_name != "" and skeleton.find_bone(bone_name) < 0:
                changes.append("Удалена дорожка отсутствующей кости: %s" % bone_name)
                result.remove_track(track)
    if changes.is_empty():
        changes.append("Безопасных автоматических исправлений не требуется")
    return {"animation": result, "changes": changes}
