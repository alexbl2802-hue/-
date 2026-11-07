extends Node
class_name AnimateValidator
signal issue_found(code: String, details: Dictionary)
@export var skeleton: Skeleton3D
@export var animation_player: AnimationPlayer
@export var max_angular_speed := 22.0

func validate_animation(animation_name: String) -> Array[Dictionary]:
 var issues: Array[Dictionary] = []
 if animation_player == null or not animation_player.has_animation(animation_name):
  issues.append({"code": "missing_animation", "animation": animation_name})
 else:
  var animation := animation_player.get_animation(animation_name)
  for track in range(animation.get_track_count()):
   if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
   for k in range(1, animation.track_get_key_count(track)):
    var dt := animation.track_get_key_time(track, k) - animation.track_get_key_time(track, k - 1)
    if dt <= 0.0:
     issues.append({"code": "duplicate_key_time", "track": track, "key": k})
     continue
    var a: Quaternion = animation.track_get_key_value(track, k - 1)
    var b: Quaternion = animation.track_get_key_value(track, k)
    if a.angle_to(b) / dt > max_angular_speed:
     issues.append({"code": "angular_spike", "track": track, "key": k})
 for issue in issues: issue_found.emit(issue["code"], issue)
 return issues

func validate_rig() -> Array[Dictionary]:
 var issues: Array[Dictionary] = []
 if skeleton == null:
  issues.append({"code": "missing_skeleton"})
 elif skeleton.get_bone_count() == 0:
  issues.append({"code": "empty_skeleton"})
 for issue in issues: issue_found.emit(issue["code"], issue)
 return issues
