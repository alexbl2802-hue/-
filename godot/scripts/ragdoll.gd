## Падение по физике (рэгдолл): при смерти кости скелета становятся телами с суставами
## и падают под действием силы тяжести и удара. Тела создаются только в момент смерти
## и удаляются при возрождении, чтобы живые персонажи не тратили силы телефона.
## Подходит скелетам с костями Mixamo (герой, гоблин, кролик).
class_name Ragdoll
extends RefCounted

const LAYER := 16            # свой слой столкновений: тела падают на землю, но не толкают живых
## [кость, кость-продолжение (до неё — длина тела), толщина, сустав]
const PARTS := [
	["Hips", "Spine", 0.16, "none"],
	["Spine", "Neck", 0.17, "cone"],
	["Head", "HeadTop_End", 0.12, "cone"],
	["LeftArm", "LeftForeArm", 0.06, "cone"],
	["LeftForeArm", "LeftHand", 0.05, "hinge"],
	["RightArm", "RightForeArm", 0.06, "cone"],
	["RightForeArm", "RightHand", 0.05, "hinge"],
	["LeftUpLeg", "LeftLeg", 0.08, "cone"],
	["LeftLeg", "LeftFoot", 0.06, "hinge"],
	["RightUpLeg", "RightLeg", 0.08, "cone"],
	["RightLeg", "RightFoot", 0.06, "hinge"],
]

var sim: PhysicalBoneSimulator3D
var _bones := {}

static func _find(sk: Skeleton3D, suffix: String) -> int:
	for i in sk.get_bone_count():
		# Имена вида "mixamorig_Hips": конец совпадает, а перед ним не буква
		var n := sk.get_bone_name(i)
		if n.ends_with(suffix) and (n.length() == suffix.length() or not n[n.length() - suffix.length() - 1].to_lower() in "abcdefghijklmnopqrstuvwxyz"):
			return i
	return -1

## Уронить скелет. push — толчок (направление и сила удара), м/с
func start(sk: Skeleton3D, push: Vector3) -> bool:
	stop()
	sim = PhysicalBoneSimulator3D.new()
	sk.add_child(sim)   # последним — поверх анимации и остальных правок поз
	var scale := sk.global_basis.get_scale().x
	for p in PARTS:
		var b := _find(sk, p[0])
		var c := _find(sk, p[1])
		if b < 0 or c < 0:
			continue
		# Положение кости-продолжения в системе кости (по позе в момент смерти)
		var rel: Vector3 = sk.get_bone_global_pose(b).affine_inverse() * sk.get_bone_global_pose(c).origin
		var half := rel.length() * 0.5
		if half < 0.01:
			continue
		var pb := PhysicalBone3D.new()
		pb.name = "RB_" + p[0]
		pb.bone_name = sk.get_bone_name(b)
		# Как в редакторе Godot: тело — посередине кости, вдоль −Z к продолжению; сустав — в начале кости
		var body := Transform3D()
		var up := Vector3.BACK if absf(rel.normalized().y) > 0.9 else Vector3.UP
		body.basis = Basis.looking_at(rel, up)
		body.origin = body.basis * Vector3(0, 0, -half)
		pb.body_offset = body
		pb.joint_offset = Transform3D(Basis(), Vector3(0, 0, half))
		match p[3]:
			"none": pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
			"hinge": pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			_: pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		pb.collision_layer = LAYER
		pb.collision_mask = 1
		pb.mass = 1.0 + half * 4.0
		pb.linear_damp = 1.8    # тело быстро успокаивается и не катится по склону
		pb.angular_damp = 4.0
		pb.friction = 1.0
		var cap := CapsuleShape3D.new()
		var r: float = p[2] / maxf(scale, 0.01)
		cap.radius = r
		cap.height = maxf(half * 2.0, r * 2.0 + 0.01)
		var cs := CollisionShape3D.new()
		cs.shape = cap
		cs.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
		pb.add_child(cs)
		sim.add_child(pb)
		_bones[p[0]] = pb
	if _bones.is_empty():
		stop()
		return false
	sim.physical_bones_start_simulation()
	# Толчок: корпус летит по направлению удара, чуть вверх
	for k in _bones:
		var w := 1.0 if k in ["Hips", "Spine", "Head"] else 0.5
		(_bones[k] as PhysicalBone3D).linear_velocity = push * w
	return true

## Вернуть кости анимации (при возрождении)
func stop() -> void:
	if sim and is_instance_valid(sim):
		sim.physical_bones_stop_simulation()
		sim.queue_free()
	sim = null
	_bones = {}

func active() -> bool:
	return sim != null
