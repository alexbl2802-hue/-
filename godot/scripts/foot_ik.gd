## Ноги на склонах: каждая стопа опускается или поднимается до земли под ней (луч вниз),
## таз опускается к нижней стопе, колени сгибаются через IK двух костей (TwoBoneIK3D).
## Работает стоя, на ходу и на бегу (поднятая нога сохраняет высоту шага над землёй под собой);
## в прыжке и действиях — выключено.
class_name FootIK
extends Node

const REACH_UP := 0.7        # насколько выше стопы ищем землю
const REACH_DOWN := 0.9      # и насколько ниже
const MAX_DROP := 0.45       # таз опускается не больше чем на столько
const FADE := 6.0            # скорость включения/выключения (1/с)

var body: CharacterBody3D
var sk: Skeleton3D
var offset := 0.0            # насколько опущена модель (≤ 0), прибавить к высоте модели
var weight := 0.0
var _legs := []              # [{foot, ik, target, pole}]

func setup(b: CharacterBody3D, skel: Skeleton3D) -> bool:
	body = b
	sk = skel
	var find := func(suffix: String) -> int:
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).ends_with(suffix):
				return i
		return -1
	for side in ["Left", "Right"]:
		var up: int = find.call(side + "UpLeg")
		var knee: int = find.call(side + "Leg")
		var foot: int = find.call(side + "Foot")
		if up < 0 or knee < 0 or foot < 0:
			return false
		var t := Node3D.new()
		var p := Node3D.new()
		sk.add_child(t)
		sk.add_child(p)
		var ik := TwoBoneIK3D.new()
		sk.add_child(ik)
		ik.setting_count = 1
		ik.set_root_bone_name(0, sk.get_bone_name(up))
		ik.set_middle_bone_name(0, sk.get_bone_name(knee))
		ik.set_end_bone_name(0, sk.get_bone_name(foot))
		ik.set_target_node(0, ik.get_path_to(t))
		ik.set_pole_node(0, ik.get_path_to(p))
		ik.influence = 0.0
		ik.active = false
		_legs.append({"foot": foot, "ik": ik, "target": t, "pole": p})
	return true

## Вызывать каждый кадр физики после анимации. on — стоит ли персонаж спокойно на земле.
## facing — куда смотрит (рад). Возвращает смещение модели по высоте.
func update(dt: float, on: bool, facing: float) -> float:
	weight = move_toward(weight, 1.0 if on else 0.0, dt * FADE)
	if weight <= 0.0:
		offset = move_toward(offset, 0.0, dt * 2.0)
		for l in _legs:
			(l["ik"] as TwoBoneIK3D).active = false
		return offset
	var space := body.get_world_3d().direct_space_state
	var base := body.global_position.y
	var fwd := Vector3(sin(facing), 0, cos(facing))
	var deltas := []
	var feet := []
	for l in _legs:
		# Стопа по анимации (без сдвига модели и без IK)
		var fp: Vector3 = sk.global_transform * sk.get_bone_global_pose(l["foot"]).origin
		fp.y -= offset
		feet.append(fp)
		var q := PhysicsRayQueryParameters3D.create(fp + Vector3.UP * REACH_UP, fp + Vector3.DOWN * REACH_DOWN, 1)
		q.exclude = [body.get_rid()]
		var hit := space.intersect_ray(q)
		deltas.append(clampf((hit["position"].y - base) if hit else 0.0, -MAX_DROP, REACH_UP))
	# Таз — к нижней стопе
	var want := clampf(minf(deltas[0], deltas[1]), -MAX_DROP, 0.0)
	offset = lerpf(offset, want * weight, minf(1.0, dt * 10.0))
	for i in _legs.size():
		var l: Dictionary = _legs[i]
		var fp: Vector3 = feet[i]
		var target := Vector3(fp.x, fp.y + deltas[i], fp.z)
		(l["target"] as Node3D).global_position = target
		(l["pole"] as Node3D).global_position = target + fwd * 1.2 + Vector3.UP * 0.6
		var ik: TwoBoneIK3D = l["ik"]
		ik.active = true
		ik.influence = weight
	return offset
