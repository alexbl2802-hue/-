## Монстр: модель, поведение (бродит → гонится → замах → удар → отдых → домой),
## вспышка при попадании, падение при смерти и возвращение в долину через время.
extends CharacterBody3D

const TYPES := {
	"slime": {"hp": 45, "dmg": 7, "speed": 3.4, "r": 0.6, "aggro": 11.0, "reach": 1.5, "cd": 1.3, "windup": 0.45, "bar": 1.5, "lunge": true},
	"goblin": {"hp": 70, "dmg": 10, "speed": 4.6, "walk": 0.8, "r": 0.45, "aggro": 15.0, "reach": 1.7, "cd": 1.1, "windup": 0.4, "bar": 2.0},
	"skeleton": {"hp": 80, "dmg": 12, "speed": 3.9, "r": 0.45, "aggro": 13.0, "reach": 1.8, "cd": 1.2, "windup": 0.45, "bar": 2.4},
	"spider": {"hp": 55, "dmg": 9, "speed": 5.2, "r": 0.7, "aggro": 12.0, "reach": 1.7, "cd": 0.9, "windup": 0.35, "bar": 1.4, "lunge": true},
	# Кролик с длинными когтями: сильнее гоблина, бродит по всему миру
	"rabbit": {"hp": 85, "dmg": 16, "speed": 7.8, "r": 0.45, "aggro": 14.0, "reach": 1.7, "cd": 0.75, "windup": 0.06, "bar": 1.6, "lunge": true, "roam": true},
	# Кобольд в броне с мечом: живёт в подземельях, крепкий и бьёт больно
	"kobold": {"hp": 130, "dmg": 23, "speed": 4.2, "r": 0.45, "aggro": 13.0, "reach": 2.0, "cd": 0.85, "windup": 0.06, "bar": 2.1},
}
const GRAVITY := 25.0

var type := "slime"
var in_dungeon := false
var T: Dictionary
var hero: Node3D
var home := Vector3.ZERO
var hp := 1.0
var st := "idle"
var dead := false
var facing := 0.0

var _t := 0.0
var _kb := Vector3.ZERO
var _flash := 0.0
var _walk := 0.0
var _hop := randf() * 6.0
var _speed_now := 0.0
var _moving := false
var _wander = null
var _wander_t := randf() * 3.0
var _dead_t := 0.0
var _model: Node3D
var _body: Node3D
var _legs: Array = []
var _arms: Array = []
var _mats: Array = []
var _shape: CollisionShape3D
var _char: Node3D            # модель с анимациями (сейчас — гоблин из models/goblin.glb)
var _ap: AnimationPlayer
var _flash_mat: StandardMaterial3D
var _anim_on := true
var _swing := false

const GOBLIN_MODEL := "res://models/goblin.glb"
const BUNNY_MODEL := "res://models/bunny.glb"
# Боевой кролик (Meshy): стойка, удар рукой и удар ногой в прыжке, кувырок-уклонение.
# Времена — секунды внутри анимаций: петля стойки и момент удара.
const B_PUNCH := "Boxing_Guard_Prep_Straight_Punch"
const B_KICK := "Flying_Fist_Kick"
const B_DODGE := "Roll_Dodge_2"
const B_GUARD := [0.1, 1.5]       # петля стойки в начале анимации удара рукой
const B_HITS := {B_PUNCH: 2.0, B_KICK: 2.9}

var _bunny := false
var _b_attack := ""
var _dodge_t := -1.0

func setup(kind: String, pos: Vector3, h: Node3D) -> void:
	type = kind
	T = TYPES[kind]
	hero = h
	home = pos
	hp = T["hp"]
	facing = randf() * TAU

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.5
	var shape := CapsuleShape3D.new()
	shape.radius = T["r"]
	shape.height = maxf(1.2, T["r"] * 2.0 + 0.2)
	_shape = CollisionShape3D.new()
	_shape.shape = shape
	_shape.position.y = shape.height / 2.0
	add_child(_shape)
	_model = Node3D.new()
	add_child(_model)
	match type:
		"slime": _build_slime()
		"goblin": _build_humanoid(0.82, 0x6aa84f, 0x6b4a2b, 0x3d2a18, 0xffd400, 0.6, 0.56, 0.2, true, false, "club")
		"skeleton": _build_humanoid(1.0, 0xe6dfc8, 0xd8d0b8, 0x3a3228, 0x6fd0ff, 1.5, 0.46, 0.13, false, true, "sword")
		"spider": _build_spider()
		"rabbit": _build_rabbit()
		"kobold": _build_kobold()
	if type == "goblin" and ResourceLoader.exists(GOBLIN_MODEL):
		_attach_goblin()
	elif type == "rabbit" and ResourceLoader.exists(BUNNY_MODEL):
		_attach_bunny()
	global_position = home

# ---------- Боевой кролик: в лапах свои когти, оружие не нужно
func _attach_bunny() -> void:
	for c in _model.get_children():
		c.visible = false
	_char = (load(BUNNY_MODEL) as PackedScene).instantiate()
	_char.scale = Vector3.ONE * 0.95
	_model.add_child(_char)
	_ap = _char.find_children("*", "AnimationPlayer", true, false)[0]
	_ap.playback_default_blend_time = 0.12
	for n in _ap.get_animation_list():
		_ap.get_animation(n).loop_mode = Animation.LOOP_NONE
	_ap.play(B_PUNCH)
	_ap.seek(randf_range(B_GUARD[0], B_GUARD[1]), true)
	_bunny = true
	_setup_flash()
	_setup_hop_legs()

func _animate_bunny(dt: float) -> void:
	var hopping := false
	# Кувырок после пропущенного удара
	if _dodge_t >= 0.0:
		_dodge_t += dt
		if _dodge_t > 0.9:
			_dodge_t = -1.0
	elif st == "windup" and not _swing:
		# Удары по очереди: рукой и ногой в прыжке, с момента незадолго до удара
		_swing = true
		_b_attack = B_KICK if _b_attack == B_PUNCH else B_PUNCH
		_ap.play(_b_attack, 0.08)
		_ap.seek(B_HITS[_b_attack] - 0.35, true)
		_ap.speed_scale = 1.8
	elif not (st == "windup" or (st == "recover" and _t < 0.4)):
		_swing = false
		# Стойка: петля начала анимации удара рукой; на ходу — прыжками
		if _ap.current_animation != B_PUNCH or _ap.current_animation_position > B_GUARD[1] or _ap.current_animation_position < B_GUARD[0] - 0.05:
			_ap.play(B_PUNCH, 0.15)
			_ap.seek(B_GUARD[0], true)
		_ap.speed_scale = 1.0
		hopping = _moving
	_hop_legs(dt, hopping)

## Прыжки кролика: невысокие и частые — присел → оттолкнулся ногами → короткий прыжок
## (ноги лишь слегка согнуты) → приземлился, спружинив. Обе ноги работают вместе.
## Ключи цикла: [доля цикла, бедро вперёд, сгиб колена, носок вниз] — в градусах,
## добавляются к стойке из анимации (в ней колени уже немного согнуты).
const HOP_KEYS := [
	[0.00, 8.0, 14.0, 0.0],      # касание земли
	[0.20, 26.0, 46.0, -10.0],   # присел, пружиня
	[0.45, -12.0, 2.0, 28.0],    # толчок: ноги выпрямлены, на носках
	[0.72, 12.0, 20.0, 10.0],    # в воздухе ноги чуть согнуты
	[1.00, 8.0, 14.0, 0.0],
]
const HOP_GROUND := 0.45         # доля цикла на земле, дальше — короткий прыжок
const HOP_HEIGHT := [0.09, 0.16] # высота прыжка: бродит / гонится
const HOP_RATE := [2.4, 3.2]     # прыжков в секунду
## В боксёрской стойке корпус развёрнут примерно на 50° (голова — на 37°) от направления
## модели; в прыжках доворачиваем кролика, чтобы он скакал грудью вперёд, а не боком
const HOP_TURN := 0.9

var _legs_mod: PoseOffsets
var _leg_bones := []             # [бедро, колено, стопа] для левой и правой ноги
var _leg_len := 0.8
var _flex_axis := Vector3.RIGHT  # поперечная ось скелета: вокруг неё сгибаются ноги
var _hop_p := 0.0
var _hop_w := 0.0

func _setup_hop_legs() -> void:
	var sk: Skeleton3D = _char.find_children("*", "Skeleton3D", true, false)[0]
	var find := func(suffix: String) -> int:
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).ends_with(suffix):
				return i
		return -1
	for side in ["Left", "Right"]:
		var bones: Array = [find.call(side + "UpLeg"), find.call(side + "Leg"), find.call(side + "Foot")]
		if bones.has(-1):
			return
		_leg_bones.append(bones)
	var gr := func(i: int) -> Vector3: return sk.get_bone_global_rest(i).origin
	var lb: Array = _leg_bones[0]
	_leg_len = (gr.call(lb[1]).distance_to(gr.call(lb[0])) + gr.call(lb[2]).distance_to(gr.call(lb[1]))) * _char.scale.x
	var toe: int = find.call("LeftToeBase")
	var fwd := Vector3(0, 0, 1)
	if toe >= 0:
		fwd = gr.call(toe) - gr.call(lb[2])
		fwd.y = 0.0
		fwd = fwd.normalized()
	# Поворот вокруг этой оси уводит направленную вниз кость вперёд
	_flex_axis = Vector3.DOWN.cross(fwd).normalized()
	# Ось сгиба каждого сустава — в системе самой кости (по позе покоя): в стойке нога
	# развёрнута, и сгиб вокруг общей оси тела выворачивал бы колено вбок
	for leg in _leg_bones:
		var axes := []
		for b in leg:
			axes.append((sk.get_bone_global_rest(b).basis.orthonormalized().inverse() * _flex_axis).normalized())
		leg.append(axes)
	_legs_mod = PoseOffsets.new()
	sk.add_child(_legs_mod)

## Кролик продвигается в основном в полёте: пока ноги на земле, он почти стоит на месте
## (иначе лапы скользили бы по траве); средняя скорость за прыжок не меняется
func _hop_speed() -> float:
	if _legs_mod == null or _hop_w < 0.5 or not _moving:
		return 1.0
	const ON_GROUND := 0.45
	return ON_GROUND if _hop_p <= HOP_GROUND else (1.0 - HOP_GROUND * ON_GROUND) / (1.0 - HOP_GROUND)

func _hop_pose(p: float) -> Vector3:
	for i in range(1, HOP_KEYS.size()):
		var k1: Array = HOP_KEYS[i]
		if p <= k1[0]:
			var k0: Array = HOP_KEYS[i - 1]
			var f := smoothstep(0.0, 1.0, (p - k0[0]) / (k1[0] - k0[0]))
			return Vector3(lerpf(k0[1], k1[1], f), lerpf(k0[2], k1[2], f), lerpf(k0[3], k1[3], f))
	return Vector3(HOP_KEYS[0][1], HOP_KEYS[0][2], HOP_KEYS[0][3])

func _hop_legs(dt: float, hopping: bool) -> void:
	_char.position.y = 0.0
	_char.rotation.y = HOP_TURN * _hop_w
	if _legs_mod == null:
		if hopping:   # запасной вариант: просто подскоки
			_hop += dt * (9.0 if st == "chase" else 6.0)
			_char.position.y = absf(sin(_hop)) * (0.35 if st == "chase" else 0.18)
		return
	var chase := st == "chase"
	# Прыжок доводим до приземления, даже если кролик остановился
	if hopping or _hop_p > HOP_GROUND:
		_hop_p += dt * HOP_RATE[1 if chase else 0]
		if _hop_p >= 1.0:
			_hop_p = fmod(_hop_p, 1.0) if hopping else 0.0
	_hop_w = move_toward(_hop_w, 1.0 if hopping or _hop_p > 0.0 else 0.0, dt * 6.0)
	if not hopping and _hop_p <= HOP_GROUND:
		_hop_p = move_toward(_hop_p, 0.0, dt)
	var a := _hop_pose(_hop_p) * deg_to_rad(1.0) * _hop_w
	for lb in _leg_bones:
		_legs_mod.set_local(lb[0], lb[3][0], a.x)
		_legs_mod.set_local(lb[1], lb[3][1], -a.y)
		_legs_mod.set_local(lb[2], lb[3][2], -a.z)
	# Высота тела: на земле — насколько присел, в полёте — дуга прыжка
	var drop := _leg_len * (1.0 - (cos(a.x) + cos(a.x - a.y)) / 2.0)
	var y := 0.0
	var on_ground := 1.0
	if _hop_p > HOP_GROUND:
		var f := (_hop_p - HOP_GROUND) / (1.0 - HOP_GROUND)
		y = sin(PI * f) * HOP_HEIGHT[1 if chase else 0] * _hop_w
		on_ground = 1.0 - smoothstep(0.0, 0.15, f) + smoothstep(0.75, 1.0, f)
	_char.position.y = y - drop * clampf(on_ground, 0.0, 1.0)

func _dodge() -> void:
	_dodge_t = 0.0
	_ap.play(B_DODGE, 0.05)
	_ap.seek(0.35, true)
	_ap.speed_scale = 1.6

# ---------- Модель гоблина (Meshy): блочное тело прячем, в правую руку — дубина
func _attach_goblin() -> void:
	for c in _model.get_children():
		c.visible = false
	_char = (load(GOBLIN_MODEL) as PackedScene).instantiate()
	_char.scale = Vector3.ONE * 0.92
	_model.add_child(_char)
	_ap = _char.find_children("*", "AnimationPlayer", true, false)[0]
	_ap.playback_default_blend_time = 0.15
	for n in ["Combat_Stance", "Slow_Orc_Walk", "Running"]:
		_ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_ap.get_animation("Charged_Slash").loop_mode = Animation.LOOP_NONE
	_ap.play("Combat_Stance")
	_ap.seek(randf() * 1.5, true)
	_setup_flash()
	_attach_club()

## Белая вспышка при попадании — полупрозрачный слой поверх модели
func _setup_flash() -> void:
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1, 1, 1, 0)
	for m in _char.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = _flash_mat
		m.visibility_range_end = 130.0

## Дубина гоблина: рукоять поперёк ладони, толстый конец выходит над большим пальцем
func _attach_club() -> void:
	var sk: Skeleton3D = _char.find_children("*", "Skeleton3D", true, false)[0]
	var hand := -1
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with("RightHand"):
			hand = i
	if hand < 0:
		return
	var att := BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_name = sk.get_bone_name(hand)
	att.bone_idx = hand
	var idx := _finger(sk, hand, "RightHandIndex1")
	var pinky := _finger(sk, hand, "RightHandPinky1")
	var fingers := ((idx + pinky) / 2.0).normalized()
	var dir := idx - pinky
	dir = (dir - fingers * dir.dot(fingers)).normalized()
	var flat := fingers.cross(dir).normalized()
	var grip := fingers * ((idx + pinky) / 2.0).length() * 0.7 - flat * 0.02
	var club := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.045
	cm.height = 0.85
	cm.radial_segments = 7
	club.mesh = cm
	club.material_override = Mats.lp(0x5a3a1c, 0.95, 0.0, -1, 0.0, 0.45, 3.0)
	att.add_child(club)
	club.transform = Transform3D(Basis(fingers, dir, flat), grip + dir * 0.32)
	for k in 3:   # сучки-шипы на толстом конце
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.03
		sm.height = 0.1
		sm.radial_segments = 4
		spike.mesh = sm
		spike.material_override = Mats.lp(0x3a2412)
		club.add_child(spike)
		var a := k * TAU / 3.0
		spike.position = Vector3(cos(a) * 0.11, 0.3, sin(a) * 0.11)
		spike.rotation = Vector3(sin(a) * 1.2, 0, -cos(a) * 1.2)

func _finger(sk: Skeleton3D, parent: int, suffix: String) -> Vector3:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with(suffix):
			return sk.get_bone_global_rest(parent).affine_inverse() * sk.get_bone_global_rest(i).origin
	return Vector3.UP * 0.1

## Монстры вдали «спят» — вместе с ними замирает и анимация
func set_active(on: bool) -> void:
	set_physics_process(on)
	if _ap and on != _anim_on:
		_anim_on = on
		_ap.active = on

const G_WALK_STRIDE := 0.27   # м/с: столько проходит гоблин за секунду анимации Slow_Orc_Walk
const G_RUN_STRIDE := 3.45    # то же для Running

func _animate_char() -> void:
	var want := "Combat_Stance"
	var speed := 1.0
	if st == "windup" or (st == "recover" and _t < 0.45):
		want = "Charged_Slash"
		# Удар в анимации приходится примерно на середину (1,1 с) — совмещаем с концом замаха
		speed = 0.8 / maxf(0.15, T["windup"])
	elif _moving:
		# Скорость анимации — по длине шага (замер: tests/gait.tscn), иначе ноги скользят:
		# быстро — бегом, медленно — шагом вразвалку
		if _speed_now > 1.4:
			want = "Running"
			speed = _speed_now / G_RUN_STRIDE
		else:
			want = "Slow_Orc_Walk"
			speed = maxf(0.3, _speed_now / G_WALK_STRIDE)
	if st == "windup" and not _swing:
		# Каждый новый удар — анимация с начала замаха
		_swing = true
		_ap.play(want, 0.1)
		_ap.seek(0.3, true)
	elif _ap.current_animation != want:
		_ap.play(want)
	if st != "windup" and st != "recover":
		_swing = false
	_ap.speed_scale = speed

# ---------- Модели
func _mat(color: int, rough := 0.8, emit := -1, energy := 0.0) -> ShaderMaterial:
	var m: ShaderMaterial = Mats.lp(color, rough, 0.0, emit, energy).duplicate()
	m.set_meta("emit", m.get_shader_parameter("emission"))
	m.set_meta("energy", m.get_shader_parameter("emission_energy"))
	_mats.append(m)
	return m

func _box(parent: Node3D, size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _blob(parent: Node3D, r: float, m: Material, pos: Vector3, segs := 8, rings := 4) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = rings
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build_slime() -> void:
	_body = Node3D.new()
	_model.add_child(_body)
	var c := Color.from_hsv(randf_range(0.26, 0.38), 0.6, 0.75)
	var blob := _blob(_body, 0.62, _mat(c.to_rgba32() >> 8, 0.3), Vector3(0, 0.5, 0))
	blob.scale = Vector3(1, 0.8, 1)
	var eye := _mat(0x111111)
	_box(_body, Vector3(0.1, 0.16, 0.05), eye, Vector3(-0.18, 0.62, 0.52))
	_box(_body, Vector3(0.1, 0.16, 0.05), eye, Vector3(0.18, 0.62, 0.52))

func _build_humanoid(sc: float, skin_c: int, cloth_c: int, dark_c: int, eye_c: int, glow: float, bw: float, limb: float, ears: bool, ribs: bool, weapon: String) -> void:
	var inner := Node3D.new()
	inner.scale = Vector3.ONE * sc
	_model.add_child(inner)
	var skin := _mat(skin_c)
	var cloth := _mat(cloth_c)
	var dark := _mat(dark_c)
	_box(inner, Vector3(bw, 0.7, 0.3), cloth, Vector3(0, 1.22, 0))
	if ribs:
		for k in 3:
			_box(inner, Vector3(bw + 0.02, 0.05, 0.31), dark, Vector3(0, 1.08 + k * 0.17, 0))
	var head := Node3D.new()
	head.position.y = 1.82
	inner.add_child(head)
	_box(head, Vector3(0.42, 0.4, 0.4), skin, Vector3.ZERO)
	var eye := _mat(eye_c, 0.5, eye_c, glow)
	_box(head, Vector3(0.09, 0.07, 0.02), eye, Vector3(-0.1, 0.03, 0.205))
	_box(head, Vector3(0.09, 0.07, 0.02), eye, Vector3(0.1, 0.03, 0.205))
	if ears:
		for sx in [-1.0, 1.0]:
			var ear := _box(head, Vector3(0.2, 0.1, 0.06), skin, Vector3(sx * 0.28, 0.08, 0))
			ear.rotation.z = sx * 0.5
	if ribs:
		_box(head, Vector3(0.3, 0.06, 0.02), dark, Vector3(0, -0.12, 0.205))
	for sx in [-1.0, 1.0]:
		var lp := Node3D.new()
		lp.position = Vector3(0.15 * sx, 0.88, 0)
		inner.add_child(lp)
		_box(lp, Vector3(limb, 0.62, limb), dark, Vector3(0, -0.32, 0))
		_legs.append(lp)
		var ap := Node3D.new()
		ap.position = Vector3((bw / 2.0 + 0.1) * sx, 1.52, 0)
		inner.add_child(ap)
		_box(ap, Vector3(limb * 0.9, 0.62, limb * 0.9), skin if ribs else cloth, Vector3(0, -0.28, 0))
		_box(ap, Vector3(limb * 0.9, 0.16, limb * 0.9), skin, Vector3(0, -0.65, 0))
		_arms.append(ap)
	var w := Node3D.new()
	w.position = Vector3(0, -0.66, 0.04)
	w.rotation.x = PI / 2
	_arms[0].add_child(w)
	if weapon == "club":
		var club := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.11; cm.bottom_radius = 0.05; cm.height = 0.9; cm.radial_segments = 6
		club.mesh = cm
		club.material_override = _mat(0x5a3a1c)
		club.position.y = 0.4
		w.add_child(club)
	else:
		_box(w, Vector3(0.07, 0.85, 0.03), _mat(0x8a7a68, 0.5), Vector3(0, 0.5, 0))
		_box(w, Vector3(0.26, 0.06, 0.07), dark, Vector3(0, 0.08, 0))

func _build_spider() -> void:
	_body = Node3D.new()
	_model.add_child(_body)
	var shell := _mat(0x3a2a4a)
	var leg_m := _mat(0x2a1f36)
	var abd := _blob(_body, 0.5, shell, Vector3(0, 0.7, -0.45), 6, 3)
	abd.scale = Vector3(1, 0.75, 1.2)
	_blob(_body, 0.32, shell, Vector3(0, 0.6, 0.15), 6, 3)
	var eye := _mat(0xff3020, 0.5, 0xff2010, 1.5)
	for p in [[-0.1, 0.7], [0.1, 0.7], [-0.17, 0.63], [0.17, 0.63]]:
		_box(_body, Vector3(0.06, 0.06, 0.04), eye, Vector3(p[0], p[1], 0.44))
	for sx in [-1.0, 1.0]:
		for k in 4:
			var pv := Node3D.new()
			pv.position = Vector3(sx * 0.2, 0.62, 0.25 - k * 0.17)
			_body.add_child(pv)
			var holder := Node3D.new()
			holder.rotation.y = sx * (k - 1.5) * 0.4
			pv.add_child(holder)
			var up := _box(holder, Vector3(0.6, 0.07, 0.07), leg_m, Vector3(sx * 0.28, 0.14, 0))
			up.rotation.z = sx * 0.5
			var low := _box(holder, Vector3(0.07, 0.75, 0.07), leg_m, Vector3(sx * 0.62, -0.12, 0))
			low.rotation.z = sx * -0.3
			_legs.append([pv, k * 1.6 + (PI if sx > 0 else 0.0)])

## Кролик переезжает: новый «дом» в 20–60 м, на суше и вне города
func _roam() -> void:
	for i in 8:
		var a := randf() * TAU
		var d := randf_range(20.0, 60.0)
		var p := home + Vector3(cos(a) * d, 0, sin(a) * d)
		var lim := WorldGen.HALF - 40.0
		if absf(p.x) > lim or absf(p.z) > lim or WorldGen.town_dist(p.x, p.z) < 50.0:
			continue
		var g := WorldGen.ground_at(p.x, p.z)
		if g < 1.5 or g > 30.0 or WorldGen.normal_y_at(p.x, p.z) < 0.8:
			continue
		home = Vector3(p.x, g, p.z)
		return

func _build_rabbit() -> void:
	_body = Node3D.new()
	_model.add_child(_body)
	var fur_c: int = [0xd8d0c4, 0x9a7a5a, 0x8a8a8a][randi() % 3]
	var fur := _mat(fur_c)
	var belly := _mat(0xf2ece0)
	var claw := _mat(0xf4f4f0, 0.3)
	var torso := _blob(_body, 0.45, fur, Vector3(0, 0.75, -0.05), 7, 4)
	torso.scale = Vector3(0.9, 1.0, 1.15)
	var bl := _blob(_body, 0.3, belly, Vector3(0, 0.72, 0.33), 6, 3)
	bl.scale = Vector3(0.9, 1.1, 0.6)
	var head := Node3D.new()
	head.position = Vector3(0, 1.28, 0.22)
	_body.add_child(head)
	_blob(head, 0.28, fur, Vector3.ZERO, 7, 4)
	# Длинные уши
	for sx in [-1.0, 1.0]:
		var ear := _box(head, Vector3(0.1, 0.62, 0.05), fur, Vector3(sx * 0.12, 0.48, -0.04))
		ear.rotation = Vector3(-0.15, 0, -sx * 0.18)
		var inner_ear := _box(head, Vector3(0.05, 0.45, 0.02), _mat(0xe8a0a8), Vector3(sx * 0.12, 0.46, 0.006))
		inner_ear.rotation = Vector3(-0.15, 0, -sx * 0.18)
	var eye := _mat(0xd02020, 0.4, 0xff2020, 0.8)
	for sx in [-1.0, 1.0]:
		_box(head, Vector3(0.06, 0.07, 0.04), eye, Vector3(sx * 0.12, 0.05, 0.285))
	_box(head, Vector3(0.08, 0.06, 0.05), _mat(0xe88aa0), Vector3(0, -0.04, 0.305))
	# Мощные задние лапы
	for sx in [-1.0, 1.0]:
		var hl := Node3D.new()
		hl.position = Vector3(sx * 0.28, 0.55, -0.2)
		_body.add_child(hl)
		var thigh := _blob(hl, 0.24, fur, Vector3(0, -0.12, 0), 6, 3)
		thigh.scale = Vector3(0.8, 1.0, 1.3)
		_box(hl, Vector3(0.16, 0.08, 0.42), fur, Vector3(0, -0.5, 0.12))
		_legs.append(hl)
	# Передние лапы с длинными острыми когтями
	for sx in [-1.0, 1.0]:
		var ap := Node3D.new()
		ap.position = Vector3(sx * 0.3, 0.98, 0.25)
		_body.add_child(ap)
		_box(ap, Vector3(0.12, 0.42, 0.12), fur, Vector3(0, -0.2, 0))
		for k in 3:
			var c := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0; cm.bottom_radius = 0.035; cm.height = 0.42; cm.radial_segments = 4
			c.mesh = cm
			c.material_override = claw
			c.position = Vector3((k - 1) * 0.045, -0.48, 0.12)
			c.rotation.x = 0.9
			ap.add_child(c)
		_arms.append(ap)

## Кобольд-оборотень: собачья голова, шерсть, ноги коленями назад, чешуйчатый нагрудник, меч и щит
func _build_kobold() -> void:
	var inner := Node3D.new()
	inner.scale = Vector3.ONE * 0.95
	_model.add_child(inner)
	var fur_c: int = [0x6a5038, 0x5a5a5e, 0x7a5a3a][randi() % 3]
	var fur := _mat(fur_c)
	var fur_dark := _mat(Color(WorldGen.hex(fur_c)).darkened(0.35).to_rgba32() >> 8)
	var fur_light := _mat(Color(WorldGen.hex(fur_c)).lightened(0.25).to_rgba32() >> 8)
	var steel := _mat(0x9aa2ac, 0.35)
	steel.set_shader_parameter("metallic", 0.6)
	var steel_dark := _mat(0x6e767e, 0.4)
	steel_dark.set_shader_parameter("metallic", 0.6)
	var leather := _mat(0x4a3220)
	# Сутулый торс: широкая грудь, наклон вперёд
	var torso := Node3D.new()
	torso.position.y = 0.95
	torso.rotation.x = 0.22
	inner.add_child(torso)
	_box(torso, Vector3(0.66, 0.8, 0.42), fur, Vector3(0, 0.38, 0))
	_box(torso, Vector3(0.5, 0.3, 0.36), fur_dark, Vector3(0, -0.05, 0))
	# Чешуйчатый нагрудник: ряды накладывающихся пластинок
	for row in 5:
		for col in 5:
			var off := 0.055 if row % 2 == 1 else 0.0
			var x := -0.24 + col * 0.12 + off
			if absf(x) > 0.3:
				continue
			var sc := _box(torso, Vector3(0.12, 0.11, 0.03), steel if (row + col) % 2 == 0 else steel_dark, Vector3(x, 0.66 - row * 0.1, 0.225))
			sc.rotation.x = -0.35
	_box(torso, Vector3(0.62, 0.5, 0.04), steel_dark, Vector3(0, 0.45, -0.22))  # спина
	_box(torso, Vector3(0.68, 0.08, 0.46), leather, Vector3(0, 0.1, 0))       # пояс
	# Грива шерсти на загривке и плечах
	for k in 7:
		var a := -0.9 + k * 0.3
		var tuft := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0; tm.bottom_radius = 0.09; tm.height = 0.3; tm.radial_segments = 4
		tuft.mesh = tm
		tuft.material_override = fur_light if k % 2 == 0 else fur
		tuft.position = Vector3(sin(a) * 0.3, 0.82, -0.06 - cos(a) * 0.12)
		tuft.rotation = Vector3(-0.6, 0, -sin(a) * 0.7)
		torso.add_child(tuft)
	# Собачья голова: череп, вытянутая морда, нос, острые уши, светящиеся глаза
	var head := Node3D.new()
	head.position = Vector3(0, 0.98, 0.12)
	torso.add_child(head)
	_box(head, Vector3(0.36, 0.34, 0.36), fur, Vector3.ZERO)
	_box(head, Vector3(0.22, 0.18, 0.3), fur_light, Vector3(0, -0.06, 0.3))   # морда
	_box(head, Vector3(0.18, 0.06, 0.26), fur_dark, Vector3(0, -0.17, 0.27))  # нижняя челюсть
	_box(head, Vector3(0.09, 0.07, 0.06), _mat(0x141414, 0.3), Vector3(0, -0.01, 0.46))  # нос
	for sx in [-1.0, 1.0]:
		_box(head, Vector3(0.025, 0.06, 0.025), _mat(0xf2ead8), Vector3(sx * 0.06, -0.15, 0.4))  # клыки
		var ear := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.0; em.bottom_radius = 0.09; em.height = 0.3; em.radial_segments = 4
		ear.mesh = em
		ear.material_override = fur_dark
		ear.position = Vector3(sx * 0.12, 0.28, -0.06)
		ear.rotation = Vector3(-0.2, 0, -sx * 0.25)
		head.add_child(ear)
	var eye := _mat(0xffc020, 0.4, 0xffa000, 1.4)
	for sx in [-1.0, 1.0]:
		_box(head, Vector3(0.07, 0.04, 0.02), eye, Vector3(sx * 0.1, 0.05, 0.185))
	# Хвост
	var tail := _box(inner, Vector3(0.12, 0.12, 0.55), fur_dark, Vector3(0, 0.85, -0.42))
	tail.rotation.x = 0.7
	# Ноги оборотня: бедро вперёд, голень назад, лапа на пальцах
	for sx in [-1.0, 1.0]:
		var lp := Node3D.new()
		lp.position = Vector3(0.17 * sx, 0.95, 0)
		inner.add_child(lp)
		var thigh := _box(lp, Vector3(0.2, 0.42, 0.24), fur, Vector3(0, -0.17, 0.08))
		thigh.rotation.x = -0.45
		var shin := _box(lp, Vector3(0.14, 0.42, 0.14), fur_dark, Vector3(0, -0.55, 0.1))
		shin.rotation.x = 0.55
		_box(lp, Vector3(0.16, 0.09, 0.26), fur_dark, Vector3(0, -0.88, 0.12))  # лапа
		_legs.append(lp)
		# Руки с когтистыми ладонями, на предплечьях — поручи
		var ap := Node3D.new()
		ap.position = Vector3(0.42 * sx, 1.62, 0.18)
		inner.add_child(ap)
		_box(ap, Vector3(0.17, 0.62, 0.17), fur, Vector3(0, -0.28, 0))
		_box(ap, Vector3(0.2, 0.22, 0.2), steel, Vector3(0, -0.45, 0))
		_box(ap, Vector3(0.16, 0.14, 0.18), fur_dark, Vector3(0, -0.64, 0))
		_arms.append(ap)
	# Меч
	var w := Node3D.new()
	w.position = Vector3(0, -0.66, 0.04)
	w.rotation.x = PI / 2
	_arms[0].add_child(w)
	_box(w, Vector3(0.08, 1.0, 0.03), steel, Vector3(0, 0.58, 0))
	_box(w, Vector3(0.3, 0.07, 0.08), leather, Vector3(0, 0.08, 0))
	# Небольшой щит на левой руке
	var shield := _box(_arms[1], Vector3(0.06, 0.5, 0.42), _mat(0x6a4a2a), Vector3(-0.1, -0.45, 0.1))
	_box(shield, Vector3(0.08, 0.2, 0.2), steel, Vector3(0, 0, 0))

# ---------- Бой
func hit(dmg: int, dir: Vector3, crit := false) -> void:
	if dead:
		return
	hp -= dmg
	_flash = 1.0
	_kb = dir * 9.0
	Fx.text(str(dmg) + ("!" if crit else ""), global_position + Vector3(0, T["bar"] - 2.0, 0), Color("#ff9a3a") if crit else Color("#fff2b0"), crit)
	if hp <= 0.0:
		_die()
		return
	if st == "windup":
		st = "recover"
		_t = T["cd"] - 0.45
	elif st == "idle" or st == "return":
		st = "chase"
	if _bunny and _dodge_t < 0.0 and randf() < 0.3:
		_dodge()

func knock(mult: float) -> void:
	_kb *= mult

func _die() -> void:
	dead = true
	_dead_t = 0.0
	collision_layer = 0
	collision_mask = 1
	Game.kills += 1
	Game.give_xp(Game.ENEMY_XP[type], global_position)
	get_parent().on_enemy_killed(self)

func revive() -> void:
	dead = false
	hp = T["hp"]
	st = "idle"
	_kb = Vector3.ZERO
	global_position = home + Vector3(0, 0.5, 0)
	velocity = Vector3.ZERO
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	visible = true
	_model.scale = Vector3.ONE
	_model.rotation = Vector3(0, facing, 0)

func reset_home() -> void:
	if dead:
		return
	hp = T["hp"]
	st = "idle"
	_kb = Vector3.ZERO
	global_position = home + Vector3(0, 0.5, 0)
	velocity = Vector3.ZERO

# ---------- Поведение
func _physics_process(dt: float) -> void:
	if dead:
		_dead_t += dt
		var k := minf(1.0, _dead_t / 0.4)
		_model.rotation.z = k * 1.4
		_model.scale = Vector3.ONE * maxf(0.001, 1.0 - maxf(0.0, _dead_t - 0.6) / 0.5)
		if _dead_t > 1.1:
			visible = false
		if not in_dungeon and _dead_t > 30.0 and hero.global_position.distance_to(home) > 40.0:
			revive()
		return
	var to_hero: Vector3 = hero.global_position - global_position
	to_hero.y = 0
	var dist := maxf(0.01, to_hero.length())
	var can_see: bool = not hero.dead and not hero.busy and absf(hero.global_position.y - global_position.y) < 4.0
	var to_home := home - global_position
	to_home.y = 0
	var home_d := to_home.length()
	var mv := Vector3.ZERO
	var sp := 0.0
	_t += dt
	match st:
		"idle":
			_wander_t -= dt
			if _wander_t <= 0.0:
				_wander_t = randf_range(2.0, 6.0)
				if T.get("roam", false) and randf() < 0.35:
					_roam()
				_wander = home + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)) if randf() < 0.6 else null
			if _wander != null:
				var w: Vector3 = _wander - global_position
				w.y = 0
				if w.length() > 0.6:
					mv = w.normalized()
					sp = T.get("walk", T["speed"] * 0.35)
				else:
					_wander = null
			if can_see and dist < T["aggro"]:
				st = "chase"
		"chase":
			# Монстр гонится долго: сдаётся, только если герой очень далеко или он сам ушёл далеко от дома
			if not can_see or dist > T["aggro"] * 3.5 or home_d > 90.0:
				st = "return"
			elif dist < T["reach"]:
				st = "windup"
				_t = 0.0
			else:
				mv = to_hero / dist
				sp = T["speed"]
		"windup":
			facing += angle_difference(facing, atan2(to_hero.x, to_hero.z)) * minf(1.0, dt * 10.0)
			if _t >= T["windup"]:
				st = "recover"
				_t = 0.0
				if T.get("lunge", false):
					_kb += Vector3(sin(facing), 0, cos(facing)) * 7.0
				if can_see and dist < T["reach"] + 0.6 and absf(angle_difference(facing, atan2(to_hero.x, to_hero.z))) < 1.2:
					hero.take_damage(T["dmg"], global_position)
		"recover":
			if _t >= T["cd"]:
				st = "chase" if can_see and dist < T["aggro"] * 3.5 else "return"
		"return":
			if home_d < 1.5:
				st = "idle"
			else:
				mv = to_home / home_d
				sp = T["speed"] * 0.7
				hp = minf(T["hp"], hp + 10.0 * dt)
				if can_see and dist < T["aggro"] * 0.9:
					st = "chase"
	if sp > 0.0:
		facing += angle_difference(facing, atan2(mv.x, mv.z)) * minf(1.0, dt * 8.0)
	_moving = sp > 0.1
	_speed_now = lerpf(_speed_now, sp, minf(1.0, dt * 8.0))
	var hv := mv * sp * _hop_speed()
	# Не заходим в воду
	var ahead := global_position + hv.normalized() * 1.0 if sp > 0.0 else global_position
	if sp > 0.0 and not in_dungeon and WorldGen.ground_at(ahead.x, ahead.z) < 0.4:
		hv = Vector3.ZERO
	hv += _kb
	_kb *= exp(-dt * 6.0)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * dt
	move_and_slide()
	_model.rotation.y = facing
	_animate(dt)
	# Вспышка при попадании
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 5.0)
		if _flash_mat:
			_flash_mat.albedo_color.a = _flash * 0.6
		for m in _mats:
			m.set_shader_parameter("emission", (m.get_meta("emit") as Color).lerp(Color.WHITE, _flash))
			m.set_shader_parameter("emission_energy", lerpf(m.get_meta("energy"), 0.8, _flash))

func _animate(dt: float) -> void:
	if _bunny:
		_animate_bunny(dt)
		return
	if _char:
		_animate_char()
		return
	match type:
		"slime":
			_hop += dt * (7.0 if _moving else 2.5)
			var k := absf(sin(_hop))
			if st == "windup":
				var w := minf(1.0, _t / T["windup"])
				_body.scale = Vector3(1 + 0.3 * w, 1 - 0.35 * w, 1 + 0.3 * w)
				_body.position.y = 0.0
			else:
				_body.position.y = k * 0.45 if _moving else 0.0
				_body.scale = Vector3(1 + (1 - k) * 0.1, 0.9 + k * 0.18, 1 + (1 - k) * 0.1)
		"rabbit":
			_hop += dt * (9.0 if _moving else 2.0)
			var k := absf(sin(_hop))
			_body.position.y = k * 0.35 if _moving else 0.0
			_body.rotation.x = -0.25 * k if _moving else 0.0
			for l in _legs:
				l.rotation.x = -0.6 * k if _moving else 0.0
			var ax := 0.3 * sin(_hop) if _moving else 0.0
			if st == "windup":
				ax = -2.0 * minf(1.0, _t / T["windup"])
			elif st == "recover" and _t < 0.2:
				ax = lerpf(-2.0, 0.8, smoothstep(0.0, 1.0, _t / 0.12))
			for a in _arms:
				a.rotation.x = ax
		"spider":
			_walk += dt * (14.0 if _moving else 2.0)
			var amp := 0.35 if _moving else 0.05
			for l in _legs:
				l[0].rotation.x = sin(_walk + l[1]) * amp
			_body.rotation.x = -0.45 * minf(1.0, _t / T["windup"]) if st == "windup" else 0.0
		_:
			_walk += dt * _speed_now * 1.8
			var amp := minf(1.0, _speed_now / 4.0) * 0.8 if _moving else 0.0
			var sw := sin(_walk)
			_legs[0].rotation.x = sw * amp
			_legs[1].rotation.x = -sw * amp
			_arms[1].rotation.x = sw * amp * 0.7
			var ax := -sw * amp * 0.7
			if st == "windup":
				ax = -2.6 * minf(1.0, _t / (T["windup"] * 0.8))
			elif st == "recover" and _t < 0.25:
				ax = lerpf(-2.6, 0.4, smoothstep(0.0, 1.0, _t / 0.15))
			_arms[0].rotation.x = ax
