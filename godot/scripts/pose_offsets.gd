## Добавочные повороты костей поверх анимации — в осях скелета, вокруг сустава кости.
## Нужен там, где готовой анимации не хватает: руки героя на бегу отводятся от тела,
## у кролика в прыжке работают ноги (присел → оттолкнулся → поджал → приземлился).
## Владелец каждый кадр задаёт углы через set_angle(); ось — в системе скелета.
## Если в одной цепочке крутятся несколько костей, у них должна быть одна общая ось
## (так у ног кролика: всё сгибается вокруг поперечной оси).
class_name PoseOffsets
extends SkeletonModifier3D

var _rot := {}   # индекс кости → [ось в системе скелета, угол]

func set_angle(bone: int, axis: Vector3, angle: float) -> void:
	if bone >= 0:
		_rot[bone] = [axis.normalized(), angle]

func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk or _rot.is_empty():
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
