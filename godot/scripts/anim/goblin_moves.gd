## Новые движения гоблина (свои анимации, см. PoseLib): удар дубиной сверху обеими руками,
## широкий боковой взмах и отскок назад после удара. Дубина в правой руке.
## "sword" в ключе — куда смотрит дубина (кисть поворачивается сама).
class_name GoblinMoves
extends RefCounted

## Момент удара в каждой анимации (с) — под него подгоняется скорость замаха
const HIT := {"overhead": 0.55, "side": 0.5}

const BASE := {
	"LeftArm": Vector3(0, 10, -40), "RightArm": Vector3(0, -10, 40),
	"LeftForeArm": Vector3(-20, 0, 0), "RightForeArm": Vector3(-20, 0, 0),
}

static func _k(t: float, p: Dictionary, hips := Vector3.ZERO, club = null) -> Dictionary:
	var k := {"t": t, "p": p, "hips": hips}
	if club != null:
		k["sword"] = club
	return k

## Боевая поза: присел, руки перед собой, дубина вверх-вперёд
static func ready_pose() -> Dictionary:
	return {
		"Spine": Vector3(14, 0, 0), "Spine1": Vector3(6, 0, 0), "Neck": Vector3(-14, 0, 0),
		"LeftUpLeg": Vector3(-20, 15, 8), "LeftLeg": Vector3(35, 0, 0), "LeftFoot": Vector3(-15, 0, 0),
		"RightUpLeg": Vector3(-5, -15, -8), "RightLeg": Vector3(30, 0, 0), "RightFoot": Vector3(-25, 0, 0),
		"RightArm": Vector3(-35, -10, 35), "RightForeArm": Vector3(-50, 0, 0),
		"LeftArm": Vector3(-35, 10, -35), "LeftForeArm": Vector3(-50, 0, 0),
	}
const READY_HIPS := Vector3(0, -0.1, 0)
const READY_CLUB := Vector3(0.1, 0.8, 0.6)

## Удар сверху: дубина заносится за голову двумя руками и обрушивается вниз
static func overhead() -> Array:
	var up := ready_pose()
	up["Spine"] = Vector3(-12, 0, 0)
	up["Spine1"] = Vector3(-6, 0, 0)
	up["Neck"] = Vector3(10, 0, 0)
	up["RightArm"] = Vector3(-150, -10, 10)
	up["RightForeArm"] = Vector3(-40, 0, 0)
	up["LeftArm"] = Vector3(-150, 10, -10)
	up["LeftForeArm"] = Vector3(-40, 0, 0)
	up["LeftUpLeg"] = Vector3(-10, 15, 8)
	up["LeftLeg"] = Vector3(20, 0, 0)
	var down := ready_pose()
	down["Spine"] = Vector3(38, 0, 0)
	down["Spine1"] = Vector3(12, 0, 0)
	down["Neck"] = Vector3(-30, 0, 0)
	down["RightArm"] = Vector3(-70, -10, 20)
	down["RightForeArm"] = Vector3(-10, 0, 0)
	down["LeftArm"] = Vector3(-70, 10, -20)
	down["LeftForeArm"] = Vector3(-10, 0, 0)
	down["LeftUpLeg"] = Vector3(-38, 15, 8)
	down["LeftLeg"] = Vector3(55, 0, 0)
	return [
		_k(0.0, ready_pose(), READY_HIPS, READY_CLUB),
		_k(0.4, up, Vector3(0, -0.04, -0.05), Vector3(0, 0.3, -1)),
		_k(HIT["overhead"], down, Vector3(0, -0.2, 0.08), Vector3(0, -0.7, 0.8)),
		_k(0.8, down, Vector3(0, -0.2, 0.08), Vector3(0, -0.8, 0.6)),
		_k(1.1, ready_pose(), READY_HIPS, READY_CLUB),
	]

## Боковой взмах: корпус закручен вправо, дубина отведена назад — широкий взмах налево
static func side() -> Array:
	var wind := ready_pose()
	wind["Hips"] = Vector3(0, -30, 0)
	wind["Spine"] = Vector3(10, -20, 0)
	wind["Spine1"] = Vector3(4, -14, 0)
	wind["Neck"] = Vector3(-10, 40, 0)
	wind["RightArm"] = Vector3(0, -50, -5)
	wind["RightForeArm"] = Vector3(0, -20, 0)
	wind["LeftArm"] = Vector3(-60, 30, -30)
	var hit := ready_pose()
	hit["Hips"] = Vector3(0, 25, 0)
	hit["Spine"] = Vector3(14, 20, 0)
	hit["Spine1"] = Vector3(6, 12, 0)
	hit["Neck"] = Vector3(-14, -30, 0)
	hit["RightArm"] = Vector3(0, 80, -10)
	hit["RightForeArm"] = Vector3(0, 10, 0)
	hit["LeftArm"] = Vector3(0, 20, -50)
	return [
		_k(0.0, ready_pose(), READY_HIPS, READY_CLUB),
		_k(0.36, wind, Vector3(0, -0.12, 0), Vector3(-0.8, 0.2, -0.5)),
		_k(HIT["side"], hit, Vector3(0, -0.14, 0.06), Vector3(1, 0, 0.3)),
		_k(0.7, hit, Vector3(0, -0.12, 0.04), Vector3(0.8, -0.2, -0.3)),
		_k(1.0, ready_pose(), READY_HIPS, READY_CLUB),
	]

## Отскок назад после удара
static func hop_back() -> Array:
	var crouch := ready_pose()
	crouch["LeftUpLeg"] = Vector3(-40, 15, 8)
	crouch["LeftLeg"] = Vector3(75, 0, 0)
	crouch["LeftFoot"] = Vector3(-35, 0, 0)
	crouch["RightUpLeg"] = Vector3(-40, -15, -8)
	crouch["RightLeg"] = Vector3(75, 0, 0)
	crouch["RightFoot"] = Vector3(-35, 0, 0)
	var air := ready_pose()
	air["LeftUpLeg"] = Vector3(-30, 15, 8)
	air["RightUpLeg"] = Vector3(-25, -15, -8)
	air["LeftLeg"] = Vector3(30, 0, 0)
	air["RightLeg"] = Vector3(35, 0, 0)
	air["Spine"] = Vector3(24, 0, 0)
	return [
		_k(0.0, ready_pose(), READY_HIPS, READY_CLUB),
		_k(0.07, crouch, Vector3(0, -0.22, 0), READY_CLUB),
		_k(0.2, air, Vector3(0, 0.03, 0), READY_CLUB),
		_k(0.32, crouch, Vector3(0, -0.2, 0), READY_CLUB),
		_k(0.5, ready_pose(), READY_HIPS, READY_CLUB),
	]

static func all() -> Dictionary:
	return {
		"overhead": [overhead(), 1.1, false],
		"side": [side(), 1.0, false],
		"hop_back": [hop_back(), 0.5, false],
	}

## Одна библиотека на всех гоблинов (скелет у всех один)
static var _lib: AnimationLibrary

static func library(sk: Skeleton3D, ref: Animation, prefix: String, club_axis: Vector3) -> AnimationLibrary:
	if _lib:
		return _lib
	_lib = AnimationLibrary.new()
	var moves := all()
	for name in moves:
		var m: Array = moves[name]
		_lib.add_animation(name, PoseLib.build(sk, m[0], BASE, m[1], m[2], ref, 0.0, prefix, club_axis))
	return _lib
