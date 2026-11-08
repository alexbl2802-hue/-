@tool
extends Node
class_name AdventureAnimationBuilder
## Run build() in editor via an EditorScript or call from @tool script.
## Produces editable Animation resources. Bone names must match actual Skeleton3D.
##
## Подогнано под модели «Земель приключений» (скелет Mixamo с приставкой mixamorig_):
## • имена костей ищутся по окончанию — с приставкой mixamorig_/mixamorig: и без неё;
## • base_clip — стойка модели: её дорожки копируются в каждый клип, а руки и позвоночник
##   поворачиваются ПОВЕРХ её позы (раньше поворот заменял позу кости, остальные кости
##   уходили в T-позу);
## • повороты — вокруг осей модели (вверх — поворот корпуса, вбок — подъём руки вперёд);
## • source_clips — имя клипа модуля → [клип модели, с какой секунды, по какую]: если у модели
##   есть настоящая анимация (вихрь, горизонтальный удар, блок), берётся отрезок из неё.
@export var skeleton: Skeleton3D
@export var animation_player: AnimationPlayer
@export var right_upper_arm := "RightArm"
@export var right_forearm := "RightForeArm"
@export var left_upper_arm := "LeftArm"
@export var left_forearm := "LeftForeArm"
@export var spine := "Spine"
@export var base_clip := ""
@export var source_clips := {}

const NAMES := ["horizontal", "whirlwind", "shield_block_start", "shield_block_loop", "shield_block_hit", "shield_block_end",
	"sword_block_start", "sword_block_loop", "sword_block_hit", "sword_block_end"]

func build() -> void:
	if skeleton == null or animation_player == null:
		push_error("Assign skeleton and animation_player")
		return
	var library := animation_player.get_animation_library("")
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)
	var sp := _bone(spine)
	var ra := _bone(right_upper_arm)
	var rf := _bone(right_forearm)
	var la := _bone(left_upper_arm)
	var lf := _bone(left_forearm)
	_make(library, "horizontal", 0.55, {sp: [0, -0.3, 0.6, 0.15, 0], ra: [0, -0.6, 1.0, 0.4, 0], rf: [0, -0.2, 0.6, 0.2, 0]})
	_make(library, "whirlwind", 0.9, {sp: [0, -0.4, 1.0, 2.8, 0], ra: [0, -0.8, 0.4, 0.5, 0], rf: [0, -0.3, 0.1, 0.3, 0]})
	for prefix in ["shield", "sword"]:
		var arm := la if prefix == "shield" else ra
		var forearm := lf if prefix == "shield" else rf
		_make(library, prefix + "_block_start", 0.18, {arm: [0, -0.5, -0.7, -0.7, -0.7], forearm: [0, 0.5, 0.7, 0.7, 0.7]})
		_make(library, prefix + "_block_loop", 0.6, {arm: [-0.7, -0.7, -0.7, -0.7, -0.7], forearm: [0.7, 0.7, 0.7, 0.7, 0.7]}, true)
		_make(library, prefix + "_block_hit", 0.24, {arm: [-0.7, -0.9, -0.5, -0.7, -0.7], forearm: [0.7, 0.9, 0.6, 0.7, 0.7]})
		_make(library, prefix + "_block_end", 0.2, {arm: [-0.7, -0.5, -0.25, -0.1, 0], forearm: [0.7, 0.5, 0.25, 0.1, 0]})

## Кость по окончанию имени (любая приставка: mixamorig_, mixamorig:, Armature_…)
func _bone(name: String) -> String:
	if skeleton.find_bone(name) >= 0:
		return name
	for i in skeleton.get_bone_count():
		var b := skeleton.get_bone_name(i)
		if b.ends_with("_" + name) or b.ends_with(":" + name):
			return b
	return name

func _make(library: AnimationLibrary, name: String, duration: float, rotations: Dictionary, loop: bool = false) -> void:
	var anim: Animation
	var src: Array = source_clips.get(name, [])
	if src.size() >= 3 and animation_player.has_animation(src[0]):
		anim = _segment(animation_player.get_animation(src[0]), float(src[1]), float(src[2]))
	else:
		anim = _from_base(duration)
		var path := str(animation_player.get_node(animation_player.root_node).get_path_to(skeleton))
		var pose := _base_globals()
		var keys := rotations.keys()
		# Плечо раньше предплечья: предплечье считается от уже повёрнутого плеча
		keys.sort_custom(func(a, b): return skeleton.find_bone(a) < skeleton.find_bone(b))
		var frames := []
		for i in range(5):
			frames.append({})
		for bone_name in keys:
			var bone_idx := skeleton.find_bone(bone_name)
			if bone_idx < 0:
				push_warning("Missing bone: " + bone_name + " (" + name + ")")
				continue
			var tp := NodePath(path + ":" + bone_name)
			var old := anim.find_track(tp, Animation.TYPE_ROTATION_3D)
			if old >= 0:
				anim.remove_track(old)
			var track := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(track, tp)
			var parent := skeleton.get_bone_parent(bone_idx)
			var angles: Array = rotations[bone_name]
			for i in range(5):
				var t := duration * float(i) / 4.0
				var fr: Dictionary = frames[i]
				var p_new: Basis = fr.get(parent, pose[parent].basis if parent >= 0 else Basis())
				var l_base: Basis = (pose[parent].basis.inverse() if parent >= 0 else Basis()) * pose[bone_idx].basis
				var g_cur := p_new * l_base
				var q_model := _pose_turn(bone_name, bone_idx, float(angles[i]), g_cur, pose)
				var g_new := Basis(q_model) * g_cur
				fr[bone_idx] = g_new
				anim.rotation_track_insert_key(track, t, (p_new.inverse() * g_new).get_rotation_quaternion().normalized())
	anim.length = duration if src.size() < 3 else anim.length
	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR
	if library.has_animation(name):
		library.remove_animation(name)
	library.add_animation(name, anim)

## Поза кости в стойке (первый ключ стойки) или в покое
func _base_rotation(bone_idx: int) -> Quaternion:
	if base_clip != "" and animation_player.has_animation(base_clip):
		var a := animation_player.get_animation(base_clip)
		var path := str(animation_player.get_node(animation_player.root_node).get_path_to(skeleton))
		var tr := a.find_track(NodePath(path + ":" + skeleton.get_bone_name(bone_idx)), Animation.TYPE_ROTATION_3D)
		if tr >= 0 and a.track_get_key_count(tr) > 0:
			return a.track_get_key_value(tr, 0)
	return skeleton.get_bone_rest(bone_idx).basis.get_rotation_quaternion()

## Клип из стойки: все дорожки стойки (первая поза) — тело стоит, поверх вращаются руки
func _from_base(duration: float) -> Animation:
	var anim := Animation.new()
	anim.length = duration
	if base_clip == "" or not animation_player.has_animation(base_clip):
		return anim
	var b := animation_player.get_animation(base_clip)
	for tr in b.get_track_count():
		if b.track_get_key_count(tr) == 0:
			continue
		var t := anim.add_track(b.track_get_type(tr))
		anim.track_set_path(t, b.track_get_path(tr))
		anim.track_insert_key(t, 0.0, b.track_get_key_value(tr, 0))
	return anim

## Отрезок настоящего клипа модели [from, to] — со сдвигом к нулю
func _segment(src: Animation, from: float, to: float) -> Animation:
	to = minf(to, src.length)
	var anim := Animation.new()
	anim.length = maxf(0.05, to - from)
	for tr in src.get_track_count():
		var t := anim.add_track(src.track_get_type(tr))
		anim.track_set_path(t, src.track_get_path(tr))
		anim.track_set_interpolation_type(t, src.track_get_interpolation_type(tr))
		for k in src.track_get_key_count(tr):
			var kt := src.track_get_key_time(tr, k)
			if kt >= from - 0.0001 and kt <= to + 0.0001:
				anim.track_insert_key(t, kt - from, src.track_get_key_value(tr, k))
	return anim

## Глобальные позы костей в стойке (или в покое)
func _base_globals() -> Array:
	var out := []
	if base_clip != "" and animation_player.has_animation(base_clip):
		var was := animation_player.current_animation
		animation_player.play(base_clip)
		animation_player.seek(0.0, true)
		skeleton.force_update_all_bone_transforms()
		for i in skeleton.get_bone_count():
			out.append(skeleton.get_bone_global_pose(i).orthonormalized())
		if was != "":
			animation_player.play(was)
		return out
	for i in skeleton.get_bone_count():
		out.append(skeleton.get_bone_global_rest(i).orthonormalized())
	return out

## Поворот кости в системе модели (лицом +Z, левая сторона +X): позвоночник — вокруг вертикали
## на угол модуля; плечо и предплечье — к позе защиты: |угол| / 0,7 — насколько дойти до неё
func _pose_turn(bone_name: String, bone_idx: int, angle: float, g_cur: Basis, pose: Array) -> Quaternion:
	if bone_name == _bone(spine):
		return Quaternion(Vector3.UP, angle)
	var child := -1
	for c in skeleton.get_bone_children(bone_idx):
		child = c
		break
	if child < 0:
		return Quaternion()
	var dir: Vector3 = g_cur * (pose[bone_idx].basis.inverse() * (pose[child].origin - pose[bone_idx].origin))
	if dir.length() < 0.0001:
		return Quaternion()
	var right_side := bone_name == _bone(right_upper_arm) or bone_name == _bone(right_forearm)
	var upper := bone_name == _bone(right_upper_arm) or bone_name == _bone(left_upper_arm)
	var target: Vector3
	if upper:
		target = Vector3(-0.35 if right_side else 0.35, 0.15, 1.0)        # плечо — вперёд, чуть в сторону
	elif right_side:
		target = Vector3(0.25, 0.9, 0.35)                                 # предплечье с мечом — вверх: клинок перед собой
	else:
		target = Vector3(-0.85, 0.25, 0.45)                               # предплечье со щитом — поперёк груди
	var f := clampf(absf(angle) / 0.7, 0.0, 1.3)
	var full := Quaternion(dir.normalized(), target.normalized())
	return Quaternion().slerp(full, minf(f, 1.0))
