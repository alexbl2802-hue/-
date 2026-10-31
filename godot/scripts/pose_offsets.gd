## Добавочные повороты костей поверх анимации — в осях скелета, вокруг сустава кости.
## Нужен там, где готовой анимации не хватает: руки героя на бегу отводятся от тела,
## у кролика в прыжке работают ноги (присел → оттолкнулся → поджал → приземлился).
## Владелец каждый кадр задаёт углы через set_angle(); ось — в системе скелета.
## Если в одной цепочке крутятся несколько костей, у них должна быть одна общая ось
## (так у ног кролика: всё сгибается вокруг поперечной оси).
class_name PoseOffsets
extends SkeletonModifier3D

var _rot := {}   # индекс кости → [ось в системе скелета, угол]
var _local := {} # индекс кости → [ось в системе самой кости, угол] — сгиб как у шарнира
var _scale := {} # индекс кости → растяжение (например, длиннее вдоль кости)
var _quat := {}  # индекс кости → добавочный поворот в системе кости (несколько осей сразу)
var _rest := {}  # индекс кости → доля перехода от позы анимации к позе покоя (0…1)

## Добавочный поворот кости в её собственной системе (заменяет set_local для этой кости)
func set_local_quat(bone: int, q: Quaternion) -> void:
	if bone >= 0:
		_quat[bone] = q
		_local.erase(bone)

## Плавно увести кость из позы анимации в позу покоя (например, ровные параллельные ноги)
func set_rest_blend(bone: int, w: float) -> void:
	if bone >= 0:
		_rest[bone] = clampf(w, 0.0, 1.0)

func set_bone_stretch(bone: int, s: Vector3) -> void:
	if bone >= 0:
		_scale[bone] = s

## Поворот вокруг оси самой кости: ось поворачивается вместе с костью в анимации,
## поэтому колено сгибается по своему шарниру, как бы ни была развёрнута нога
func set_local(bone: int, axis: Vector3, angle: float) -> void:
	if bone >= 0:
		_local[bone] = [axis.normalized(), angle]

func set_angle(bone: int, axis: Vector3, angle: float) -> void:
	if bone >= 0:
		_rot[bone] = [axis.normalized(), angle]

func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk:
		return
	for b in _rest:
		if _rest[b] > 0.0001:
			var r := sk.get_bone_rest(b).basis.get_rotation_quaternion()
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(r, _rest[b]))
	for b in _scale:
		sk.set_bone_pose_scale(b, sk.get_bone_pose_scale(b) * _scale[b])
	for b in _quat:
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * _quat[b])
	for b in _local:
		if absf(_local[b][1]) > 0.0001:
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion(_local[b][0], _local[b][1]))
	if _rot.is_empty():
		return
	# Глобальные позы читаем до изменений: общая ось у цепочки делает их достаточными
	var g := {}
	for b in _rot:
		g[b] = sk.get_bone_global_pose(b).basis.orthonormalized()
	for b in _rot:
		var a: float = _rot[b][1]
		if absf(a) < 0.0001:
			continue
		var local_axis: Vector3 = (g[b].inverse() * _rot[b][0]).normalized()
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion(local_axis, a))
