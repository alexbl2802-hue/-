extends Node
class_name AnimatePoseGenerator
## Rule-based Russian/English prompt -> whole-body bone rotation animation.
## Skeleton3D bone names are resolved by aliases; missing bones are reported.
signal generated(name: String, duration: float)
signal warning(message: String)
@export var skeleton: Skeleton3D
@export var animation_player: AnimationPlayer
@export var library_name := "ANIMATE"
@export_range(8, 60) var sample_fps := 24
const ALIASES := {
 "hips": ["hips", "pelvis", "mixamorig:hips"],
 "spine": ["spine", "spine1", "mixamorig:spine"],
 "chest": ["chest", "spine2", "upperchest", "mixamorig:spine2"],
 "left_thigh": ["leftupleg", "leftthigh", "thigh_l", "mixamorig:leftupleg"],
 "right_thigh": ["rightupleg", "rightthigh", "thigh_r", "mixamorig:rightupleg"],
 "left_shin": ["leftleg", "leftcalf", "calf_l", "mixamorig:leftleg"],
 "right_shin": ["rightleg", "rightcalf", "calf_r", "mixamorig:rightleg"],
 "left_arm": ["leftarm", "leftupperarm", "upperarm_l", "mixamorig:leftarm"],
 "right_arm": ["rightarm", "rightupperarm", "upperarm_r", "mixamorig:rightarm"],
 "left_forearm": ["leftforearm", "lowerarm_l", "mixamorig:leftforearm"],
 "right_forearm": ["rightforearm", "lowerarm_r", "mixamorig:rightforearm"]
}

func generate_from_text(description: String, animation_name: String = "") -> Animation:
 if skeleton == null or animation_player == null:
  warning.emit("Assign Skeleton3D and AnimationPlayer")
  return null
 var words := description.to_lower()
 var motion := "thrust"
 if "бег" in words or "run" in words: motion = "run"
 elif "ход" in words or "walk" in words: motion = "walk"
 elif "рыв" in words or "dash" in words or "уклон" in words: motion = "dash"
 elif "блок" in words or "block" in words: motion = "block"
 elif "руб" in words or "slash" in words or "кругов" in words: motion = "slash"
 elif "прыг" in words or "jump" in words: motion = "jump"
 elif "кол" in words or "thrust" in words or "выпад" in words: motion = "thrust"
 var length := {"walk": 0.85, "run": 0.58, "dash": 0.32, "block": 0.6, "slash": 0.7, "jump": 0.75, "thrust": 0.62}[motion] as float
 var name := animation_name if not animation_name.is_empty() else "Generated_%s" % motion
 var animation := Animation.new()
 animation.length = length
 animation.loop_mode = Animation.LOOP_LINEAR if motion in ["walk", "run"] else Animation.LOOP_NONE
 var resolved := _resolve_bones()
 for role in resolved:
  var bone_idx: int = resolved[role]
  var path := NodePath("%s:%s" % [str(animation_player.get_path_to(skeleton)), skeleton.get_bone_name(bone_idx)])
  var track := animation.add_track(Animation.TYPE_ROTATION_3D)
  animation.track_set_path(track, path)
  animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
  var samples := maxi(3, int(ceil(length * sample_fps)))
  for step in range(samples + 1):
   var t := float(step) / float(samples)
   var euler := _pose(motion, role, t)
   animation.rotation_track_insert_key(track, t * length, Quaternion.from_euler(euler))
 var lib := animation_player.get_animation_library(library_name)
 if lib == null:
  lib = AnimationLibrary.new()
  animation_player.add_animation_library(library_name, lib)
 if lib.has_animation(name): lib.remove_animation(name)
 lib.add_animation(name, animation)
 generated.emit("%s/%s" % [library_name, name], length)
 return animation

func _resolve_bones() -> Dictionary:
 var result := {}
 for role in ALIASES:
  for idx in range(skeleton.get_bone_count()):
   var candidate := skeleton.get_bone_name(idx).to_lower().replace("_", "").replace(" ", "")
   if candidate in ALIASES[role]:
    result[role] = idx
    break
  if not result.has(role): warning.emit("Missing bone role: " + role)
 return result

func _pose(motion: String, role: String, t: float) -> Vector3:
 var swing := sin(t * TAU)
 var opposite := -swing
 var power := 1.0
 if motion == "run": power = 1.6
 if motion in ["walk", "run"]:
  match role:
   "left_thigh": return Vector3(swing * 0.48 * power, 0, 0)
   "right_thigh": return Vector3(opposite * 0.48 * power, 0, 0)
   "left_shin": return Vector3(maxf(0.0, -swing) * 0.65 * power, 0, 0)
   "right_shin": return Vector3(maxf(0.0, swing) * 0.65 * power, 0, 0)
   "left_arm": return Vector3(opposite * 0.35 * power, 0, 0)
   "right_arm": return Vector3(swing * 0.35 * power, 0, 0)
   "hips": return Vector3(0, swing * 0.05, 0)
 if motion == "thrust":
  var strike := sin(t * PI)
  match role:
   "right_arm": return Vector3(-1.05 * strike, 0, -0.2 * strike)
   "right_forearm": return Vector3(-0.45 * strike, 0, 0)
   "left_arm": return Vector3(0.4 * strike, 0, 0.3 * strike)
   "spine", "chest": return Vector3(-0.25 * strike, 0.22 * strike, 0)
   "left_thigh": return Vector3(-0.35 * strike, 0, 0)
   "right_thigh": return Vector3(0.38 * strike, 0, 0)
 if motion == "slash":
  var strike := sin(t * PI)
  match role:
   "right_arm": return Vector3(-0.9 * strike, 0, -0.75 * strike)
   "right_forearm": return Vector3(-0.5 * strike, 0, 0)
   "chest", "spine": return Vector3(0, 0.5 * sin(t * TAU), 0)
   "hips": return Vector3(0, -0.2 * sin(t * TAU), 0)
   "left_thigh": return Vector3(0.25 * strike, 0, 0)
   "right_thigh": return Vector3(-0.25 * strike, 0, 0)
 if motion == "block":
  var rise := minf(1.0, t * 5.0)
  if role == "right_arm": return Vector3(-1.1 * rise, 0, 0.35 * rise)
  if role == "right_forearm": return Vector3(-0.8 * rise, 0, 0)
  if role == "left_arm": return Vector3(-0.45 * rise, 0, -0.25 * rise)
 if motion == "dash":
  var lean := sin(t * PI)
  if role in ["spine", "chest", "hips"]: return Vector3(-0.3 * lean, 0, 0)
  if role == "left_thigh": return Vector3(-0.6 * lean, 0, 0)
  if role == "right_thigh": return Vector3(0.6 * lean, 0, 0)
 if motion == "jump":
  var fold := sin(t * PI)
  if role in ["left_thigh", "right_thigh"]: return Vector3(-0.55 * fold, 0, 0)
  if role in ["left_shin", "right_shin"]: return Vector3(0.65 * fold, 0, 0)
  if role in ["left_arm", "right_arm"]: return Vector3(-0.5 * fold, 0, 0)
 return Vector3.ZERO
