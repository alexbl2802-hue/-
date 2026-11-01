## Герой: модель из блоков, движение относительно камеры, прыжок, плавание,
## бой мечом, умения Вихрь и Рывок, урон, лечение, смерть.
extends CharacterBody3D

signal hurt(dmg: int)
signal died

const WALK := 5.5
const RUN := 11.0
const JUMP := 9.0
const GRAVITY := 25.0

var touch: Node          # TouchUI: move, run, jump
var rig: Node3D          # CameraRig: yaw
var enemies: Node        # менеджер монстров
var campfire_pos := Vector3.ZERO
var facing := PI
var attack_t := -1.0
var dead := false
var busy := false
var underground := false   # в подземелье: никакой воды и плавания
var cd := {"whirl": 0.0, "dash": 0.0}

var _model: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _slash: MeshInstance3D
var _sword: Node3D
var _blade: MeshInstance3D
var _blade_mat: ShaderMaterial
var _tunic_mat: ShaderMaterial
var _helmet: MeshInstance3D
var _helmet_mat: ShaderMaterial
var _walk := 0.0
var _speed_now := 0.0
var _time := 0.0
var _attack_hit := false
var _invuln := 0.0
var _hurt_ago := 99.0
var _push := Vector3.ZERO
var _spin_t := -1.0
var _spin_hit := false
var _dash_t := -1.0
var _dash_dir := Vector3.FORWARD
var _dash_hit: Array = []
var _dash_speed := 1.0       # во сколько раз быстрее базовой (растёт с уровнем и эволюцией)
const ATTACK_SPEED := 0.8    # скорость удара мечом (−20%)
# Рывок — быстрый низкий прыжок вперёд, расстояние прежнее (28 м/с × 0,26 с)
const DASH_TIME := 0.3
const DASH_SPEED := 28.0 * 0.26 / DASH_TIME   # базовая скорость рывка, м/с
const DASH_JUMP := 0.15                       # низкий быстрый прыжок: высота дуги (плюс небольшой подъём в анимации), м
const DASH_POSE := 0.2                        # кадр быстрого бега с самым широким шагом
var _dead_t := 0.0
var _char: Node3D           # модель персонажа из models/hero.glb
var _anim: AnimationPlayer
var _new_swing := false
var _idle_pose := false
var _gear := {}
var _longsword: Node3D
var _blades := {}           # модели клинков: ключ → {node, mesh, base, glow, rust}
var _has_idle := false            # детали брони и шлема на костях модели: имя → MeshInstance3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(51)
	floor_snap_length = 0.6
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.9
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.95
	add_child(cs)
	_build_model()
	_attach_character()
	Game.changed.connect(update_look)
	update_look()

# ---------- Модель
func _box(parent: Node3D, size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var M := func(c: int) -> Material: return Mats.lp(c, 0.8)
	var skin: Material = M.call(0xf1c27d)
	_tunic_mat = Mats.lp(0x2e6b8a, 0.8).duplicate()
	var pants: Material = M.call(0x5b4632)
	var boots: Material = M.call(0x3a2a1a)
	var hair: Material = M.call(0x5a3a1e)
	_box(_model, Vector3(0.62, 0.75, 0.36), _tunic_mat, Vector3(0, 1.25, 0))
	_box(_model, Vector3(0.64, 0.1, 0.38), M.call(0x2a1a0a), Vector3(0, 0.92, 0))
	_box(_model, Vector3(0.66, 0.22, 0.4), _tunic_mat, Vector3(0, 0.78, 0))
	var head := Node3D.new()
	head.position.y = 1.85
	_model.add_child(head)
	_box(head, Vector3(0.42, 0.42, 0.42), skin, Vector3.ZERO)
	_box(head, Vector3(0.46, 0.14, 0.46), hair, Vector3(0, 0.21, 0))
	_box(head, Vector3(0.46, 0.32, 0.1), hair, Vector3(0, 0.06, -0.2))
	_box(head, Vector3(0.07, 0.07, 0.02), M.call(0x1a1a1a), Vector3(-0.1, 0.03, 0.215))
	_box(head, Vector3(0.07, 0.07, 0.02), M.call(0x1a1a1a), Vector3(0.1, 0.03, 0.215))
	_helmet_mat = Mats.lp(0xa0a8b0, 0.8).duplicate()
	_helmet = _box(head, Vector3(0.5, 0.24, 0.5), _helmet_mat, Vector3(0, 0.2, 0))
	for s in [-1.0, 1.0]:
		var lp := Node3D.new()
		lp.position = Vector3(0.16 * s, 0.88, 0)
		_model.add_child(lp)
		_box(lp, Vector3(0.24, 0.6, 0.26), pants, Vector3(0, -0.3, 0))
		_box(lp, Vector3(0.26, 0.2, 0.34), boots, Vector3(0, -0.75, 0.04))
		_legs.append(lp)
		var ap := Node3D.new()
		ap.position = Vector3(0.42 * s, 1.55, 0)
		_model.add_child(ap)
		_box(ap, Vector3(0.2, 0.62, 0.22), _tunic_mat, Vector3(0, -0.28, 0))
		_box(ap, Vector3(0.19, 0.17, 0.19), skin, Vector3(0, -0.66, 0))
		_arms.append(ap)
	# Меч в правой руке: клинок смотрит вперёд, когда рука опущена
	_sword = Node3D.new()
	_sword.position = Vector3(0, -0.68, 0.04)
	_sword.rotation.x = PI / 2
	_arms[0].add_child(_sword)
	_blade_mat = Mats.lp(0xc0c8d0, 0.4, 0.3).duplicate()
	_blade = _box(_sword, Vector3(0.08, 1.0, 0.03), _blade_mat, Vector3(0, 0.62, 0))
	_box(_sword, Vector3(0.32, 0.07, 0.09), M.call(0x8a6a2a), Vector3(0, 0.1, 0))
	_box(_sword, Vector3(0.06, 0.2, 0.06), M.call(0x3a2410), Vector3(0, -0.02, 0))
	# След от взмаха меча — полукольцо
	_slash = MeshInstance3D.new()
	_slash.mesh = _half_ring(1.0, 2.1, 20)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1, 0.96, 0.85, 0)
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slash.material_override = sm
	_slash.position = Vector3(-0.3, 1.2, 0.3)
	_slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(_slash)

## Модель персонажа — следопыт (Meshy, скелет Mixamo; tools/prepare_models.py вырезал его
## собственные клинки и собрал анимации удара, бега и быстрого бега в один файл).
## Блочная модель остаётся запасной: её прячем, а меч переносим в правую кисть.
const CHAR_PATH := "res://models/hero.glb"
const GRIP_PATH := "res://models/hero_grip.json"
const SWORD_PATH := "res://models/longsword.glb"
const RUST_TEX := "res://models/longsword_rust.jpg"
const CHAR_SCALE := 1.05
const SHOW_GEAR := true   # надетое снаряжение видно на герое (накладки на костях модели)
const A_IDLE := "Idle"         # дыхание и осмотр (есть у Shadowwarden)
const A_WALK := "Running"      # отдельной ходьбы нет — медленный бег
const A_RUN := "RunFast"
const A_SLASH := "Right_Hand_Sword_Slash"
const A_WHIRL := "Whirl"        # удар с разворотом (Skill_03), ровно один оборот
const A_DASH := "DashJump"      # прыжок через препятствие (Jump_Over_Obstacle)
# Вихрь: длительность и момент удара — середина оборота в анимации
const WHIRL_TIME := 0.75
const WHIRL_HIT := 0.5
const STRIDE_WALK := 4.8       # м/с, на которые уходит стопа за секунду анимации Running
const STRIDE_RUN := 8.25       # то же для RunFast (замер: tests/gait.tscn)
const ARMS_OUT_WALK := 0.3     # насколько отводить руки от тела на бегу, рад
const ARMS_OUT_RUN := 0.38
var _arms_mod: PoseOffsets
var _arm_axes := []
var _arms_w := 0.0

func _attach_character() -> void:
	if not ResourceLoader.exists(CHAR_PATH):
		return
	_char = (load(CHAR_PATH) as PackedScene).instantiate()
	_char.scale = Vector3.ONE * CHAR_SCALE
	_model.add_child(_char)
	for c in _model.get_children():
		if c != _char and c != _slash:
			c.visible = false
	_anim = _char.find_children("*", "AnimationPlayer", true, false)[0]
	_anim.playback_default_blend_time = 0.15
	for n in [A_WALK, A_RUN]:
		_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_anim.get_animation(A_SLASH).loop_mode = Animation.LOOP_NONE
	for n in [A_WHIRL, A_DASH]:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_NONE
	_has_idle = _anim.has_animation(A_IDLE)
	if _has_idle:
		_anim.get_animation(A_IDLE).loop_mode = Animation.LOOP_LINEAR
	var sk: Skeleton3D = _char.find_children("*", "Skeleton3D", true, false)[0]
	for m in _char.find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var hand := -1
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with("RightHand"):
			hand = i
	var att := BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_name = sk.get_bone_name(hand)
	att.bone_idx = hand
	_sword.get_parent().remove_child(_sword)
	att.add_child(_sword)
	if FileAccess.file_exists(GRIP_PATH):
		# Хват взят у собственного клинка модели (см. tools/prepare_models.py)
		var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GRIP_PATH))
		var blade := Vector3(g["blade"][0], g["blade"][1], g["blade"][2]).normalized()
		var width := Vector3(g["width"][0], g["width"][1], g["width"][2]).normalized()
		_sword.transform = Transform3D(Basis(width, blade, width.cross(blade).normalized()), Vector3(g["grip"][0], g["grip"][1], g["grip"][2]))
	else:
		# Хват по костям пальцев: пальцы сжимаются в кулак, рукоять проходит через его середину,
		# клинок выходит над большим и указательным пальцами
		var hg := HandGrip.new()
		sk.add_child(hg)
		if hg.setup(sk, "Right"):
			var blade := hg.grip_axis
			var width := (hg.fingers_dir - blade * hg.fingers_dir.dot(blade)).normalized()
			_sword.transform = Transform3D(Basis(width, blade, width.cross(blade).normalized()), hg.grip_point)
	_sword.scale = Vector3.ONE / CHAR_SCALE
	_attach_blades()
	_build_gear(sk)
	_setup_arms(sk)
	_anim.play(A_IDLE if _has_idle else A_SLASH)
	_anim.seek(0.0, true)
	update_look()

## Модели клинков: у всех клинок по −Y, середина рукояти на y ≈ 0,65, ширина по X.
## Переворачиваем клинком вверх и ставим серединой рукояти в начало хвата.
## Длинный меч — ржавый (ржавая текстура), железный и стальной; костяной и кристальный — свои модели.
const BLADES := {
	"longsword": "res://models/longsword.glb",
	"bone_blade": "res://models/bone_blade.glb",
	"crystal_blade": "res://models/crystal_blade.glb",
}
const BLADE_OF := {"sword_bone": "bone_blade", "sword_crystal": "crystal_blade"}

func _attach_blades() -> void:
	for key in BLADES:
		if not ResourceLoader.exists(BLADES[key]):
			continue
		var node: Node3D = (load(BLADES[key]) as PackedScene).instantiate()
		node.visible = false
		_sword.add_child(node)
		var mi: MeshInstance3D = node.find_children("*", "MeshInstance3D", true, false)[0]
		var base: StandardMaterial3D = mi.mesh.surface_get_material(0)
		_blades[key] = {"node": node, "mesh": mi, "base": base, "glow": base.duplicate()}
	if _blades.is_empty():
		return
	for c in _sword.get_children():
		if not c in _blades.values().map(func(x): return x["node"]):
			c.visible = false
	if _blades.has("longsword"):
		var ls: Dictionary = _blades["longsword"]
		ls["rust"] = (ls["base"] as StandardMaterial3D).duplicate()
		ls["rust"].albedo_texture = load(RUST_TEX)
		ls["rust"].metallic = 0.15
		ls["rust"].roughness = 0.9
	_longsword = _blades.get("longsword", {}).get("node")

## Броня и шлем — детали на костях модели, двигаются вместе с телом.
## Размеры подобраны по модели: торс ~0,4 м в ширину, голова ~0,2 м.
func _build_gear(sk: Skeleton3D) -> void:
	# Положение каждой накладки задаётся в системе скелета в позе покоя (T-поза, лицом к +Z,
	# левая рука — к +X) и переводится в систему своей кости — так накладки не зависят от того,
	# как повёрнуты оси костей у модели
	var bone := func(suffix: String) -> int:
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).ends_with(suffix):
				return i
		return -1
	var rest := func(suffix: String) -> Transform3D: return sk.get_bone_global_rest(bone.call(suffix))
	var put := func(suffix: String, mesh: Mesh, center: Vector3, size: Vector3, basis := Basis()) -> MeshInstance3D:
		var att := BoneAttachment3D.new()
		sk.add_child(att)
		var b: int = bone.call(suffix)
		att.bone_name = sk.get_bone_name(b)
		att.bone_idx = b
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = StandardMaterial3D.new()
		att.add_child(mi)
		var g: Transform3D = sk.get_bone_global_rest(b)
		mi.transform = g.affine_inverse() * Transform3D(basis.scaled(size), center)
		return mi
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 16
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.0
	dome.is_hemisphere = true
	dome.radial_segments = 16
	dome.rings = 6
	var box := BoxMesh.new()
	var spine1: Vector3 = rest.call("Spine1").origin
	var spine2: Vector3 = rest.call("Spine2").origin
	var neck: Vector3 = rest.call("Neck").origin
	var head: Vector3 = rest.call("Head").origin
	# Нагрудник и пояс
	_gear["cuirass"] = put.call("Spine1", tube, spine1 + Vector3(0, 0.1, 0.02), Vector3(0.17, 0.3, 0.13))
	_gear["chest_top"] = put.call("Spine2", dome, Vector3(spine1.x, spine1.y + 0.25, spine1.z + 0.02), Vector3(0.17, 0.06, 0.13))
	_gear["belt"] = put.call("Spine", tube, rest.call("Spine").origin + Vector3(0, -0.02, 0.01), Vector3(0.18, 0.05, 0.14))
	# Наплечники
	for side in ["Left", "Right"]:
		var sh: Vector3 = rest.call(side + "Arm").origin
		var sx := 1.0 if side == "Left" else -1.0
		_gear["pauldron_" + side] = put.call(side + "Arm", dome, sh + Vector3(sx * 0.03, 0.03, 0), Vector3(0.1, 0.08, 0.1), Basis(Vector3(0, 0, 1), -sx * 0.5))
	# Шлем поверх капюшона
	_gear["helm"] = put.call("Head", dome, head + Vector3(0, 0.1, -0.01), Vector3(0.13, 0.14, 0.145))
	_gear["helm_rim"] = put.call("Head", tube, head + Vector3(0, 0.1, -0.01), Vector3(0.137, 0.02, 0.152))
	_gear["helm_nose"] = put.call("Head", box, head + Vector3(0, 0.04, 0.14), Vector3(0.025, 0.1, 0.02))
	# Сапоги: голенище на нижней части голени и носок
	for side in ["Left", "Right"]:
		var knee: Vector3 = rest.call(side + "Leg").origin
		var ankle: Vector3 = rest.call(side + "Foot").origin
		var toe: Vector3 = rest.call(side + "ToeBase").origin
		var up := (knee - ankle).normalized()
		var axis := Basis(up.cross(Vector3(0, 0, 1)).normalized(), up, up.cross(up.cross(Vector3(0, 0, 1))).normalized() * -1.0)
		_gear["boot_" + side] = put.call(side + "Leg", tube, ankle + up * 0.13, Vector3(0.075, 0.26, 0.08), axis)
		_gear["toe_" + side] = put.call(side + "Foot", box, (ankle + toe) / 2.0 + Vector3(0, -0.03, 0.02), Vector3(0.11, 0.09, 0.2))
	# Плащ: полотно за спиной от плеч до колен, ворот
	_gear["cloak"] = put.call("Spine2", box, Vector3(spine2.x, spine2.y - 0.32, spine2.z - 0.17), Vector3(0.42, 0.9, 0.025), Basis(Vector3(1, 0, 0), 0.1))
	_gear["cloak_collar"] = put.call("Neck", tube, neck + Vector3(0, -0.03, -0.01), Vector3(0.14, 0.06, 0.12))
	# Щит на тыльной стороне левого предплечья (в T-позе — сверху, когда рука опущена — снаружи)
	var elbow: Vector3 = rest.call("LeftForeArm").origin
	var wrist: Vector3 = rest.call("LeftHand").origin
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 1.0
	disc.radial_segments = 20
	_gear["shield"] = put.call("LeftForeArm", disc, (elbow + wrist) / 2.0 + Vector3(0, 0.08, 0), Vector3(0.27, 0.035, 0.27))
	_gear["shield_boss"] = put.call("LeftForeArm", dome, (elbow + wrist) / 2.0 + Vector3(0, 0.1, 0), Vector3(0.07, 0.05, 0.07))

func _set_gear(names: Array, show: bool, color: Color, metal: bool) -> void:
	for n in names:
		var mi: MeshInstance3D = _gear[n]
		mi.visible = show
		var m := mi.material_override as StandardMaterial3D
		m.albedo_color = color
		m.albedo_color = color.darkened(0.25) if metal else color
		m.metallic = 0.5 if metal else 0.0
		m.roughness = 0.5 if metal else 0.85

func _bone_local(sk: Skeleton3D, parent: int, suffix: String) -> Vector3:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with(suffix):
			return sk.get_bone_global_rest(parent).affine_inverse() * sk.get_bone_global_rest(i).origin
	return Vector3.UP * 0.1

## Анимации модели: стойка, ходьба, бег, удар, вихрь, рывок, прыжок
func _animate_char(on_floor: bool, moving: bool) -> void:
	var want := A_WALK
	var speed := 1.0
	var idle := false
	if blocking:
		want = A_SLASH
		speed = 0.0
		# Скорость 1 и возврат к кадру: при скорости 0 плавный переход в позу никогда не завершается
		if _anim.current_animation != A_SLASH:
			_anim.play(A_SLASH, 0.12)
			_anim.seek(BLOCK_POSE, true)
		elif absf(_anim.current_animation_position - BLOCK_POSE) > 0.005:
			_anim.seek(BLOCK_POSE, false)
		_anim.speed_scale = 1.0
		_spread_arms(false)
		return
	if _spin_t >= 0.0 and _anim.has_animation(A_WHIRL):
		want = A_WHIRL
		speed = _anim.get_animation(A_WHIRL).length / WHIRL_TIME
	elif _dash_t >= 0.0 and _anim.has_animation(A_DASH):
		want = A_DASH
		speed = _anim.get_animation(A_DASH).length / DASH_TIME
	elif attack_t >= 0.0 or _spin_t >= 0.0:
		want = A_SLASH
		# Вся анимация удара длится 1,5 с — сжимаем её в один удар героя
		speed = 2.6 * (1.0 + 0.1 * Game.rank("agility")) * ATTACK_SPEED
	elif _dash_t >= 0.0:
		# Прыжок рывка: ноги в широком шаге, как в полёте
		want = A_RUN
		speed = 0.0
		if _anim.current_animation != want or absf(_anim.current_animation_position - DASH_POSE) > 0.01:
			_anim.play(want, 0.08)
			_anim.seek(DASH_POSE, true)
	elif not on_floor:
		want = A_RUN
		speed = 0.0
	elif moving:
		want = A_RUN if _speed_now > 7.0 else A_WALK
		# Скорость анимации — по длине шага модели, чтобы стопы не скользили по земле
		speed = _speed_now / (STRIDE_RUN if want == A_RUN else STRIDE_WALK)
	elif _has_idle:
		want = A_IDLE   # дыхание и осмотр
	else:
		# Стойка: первый кадр удара — боевая поза с мечом
		want = A_SLASH
		speed = 0.0
		idle = true
	var swing := (want == A_SLASH and not idle) or want == A_WHIRL or want == A_DASH
	if _anim.current_animation != want or (swing and _new_swing) or (idle and not _idle_pose):
		_anim.play(want, 0.1 if swing else -1.0)
		_anim.seek(0.08 if want == A_SLASH and not idle else 0.0, true)
		_new_swing = false
	_idle_pose = idle
	_anim.speed_scale = speed
	_spread_arms(want != A_SLASH and on_floor and moving)

## На бегу руки модели почти прижаты к телу — отводим плечи наружу
func _spread_arms(running: bool) -> void:
	if _arms_mod == null:
		return
	var target := clampf(_speed_now / WALK, 0.0, 1.0) if running else 0.0
	_arms_w = move_toward(_arms_w, target, get_physics_process_delta_time() * 5.0)
	var a := lerpf(ARMS_OUT_WALK, ARMS_OUT_RUN, clampf((_speed_now - WALK) / (RUN - WALK), 0.0, 1.0)) * _arms_w
	for arm in _arm_axes:
		_arms_mod.set_angle(arm[0], arm[1], a)

func _setup_arms(sk: Skeleton3D) -> void:
	var hips := -1
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with("Hips"):
			hips = i
	for side in ["Left", "Right"]:
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).ends_with(side + "Arm"):
				var out := sk.get_bone_global_rest(i).origin - (sk.get_bone_global_rest(hips).origin if hips >= 0 else Vector3.ZERO)
				out.y = 0.0
				out.z = 0.0
				# Поворот вокруг этой оси уводит опущенную руку в сторону от тела
				_arm_axes.append([i, Vector3.DOWN.cross(out.normalized())])
	if _arm_axes.size() == 2:
		_arms_mod = PoseOffsets.new()
		sk.add_child(_arms_mod)

## Полукольцо в вертикальной плоскости: от спины через верх вперёд
func _half_ring(r0: float, r1: float, segs: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i in segs + 1:
		var a := PI * i / segs
		verts.append(Vector3(0, sin(a) * r0, -cos(a) * r0))
		verts.append(Vector3(0, sin(a) * r1, -cos(a) * r1))
	var idx := PackedInt32Array()
	for i in segs:
		var k := i * 2
		idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## Надетое снаряжение видно на герое: цвет и длина меча, доспех, шлем
func update_look() -> void:
	var w := Items.get_item(Game.equip["weapon"]["id"]) if Game.equip["weapon"] != null else {}
	var a := Items.get_item(Game.equip["armor"]["id"]) if Game.equip["armor"] != null else {}
	var h := Items.get_item(Game.equip["helm"]["id"]) if Game.equip["helm"] != null else {}
	_sword.visible = not w.is_empty()
	if not w.is_empty():
		_blade_mat.set_shader_parameter("albedo", WorldGen.hex(w["color"]))
		# Клинок высокого ранга светится цветом ранга
		var r: int = Game.equip["weapon"]["r"]
		if r >= 3:
			_blade_mat.set_shader_parameter("emission", Items.RANKS[r]["color"])
			_blade_mat.set_shader_parameter("emission_energy", 0.9)
		else:
			_blade_mat.set_shader_parameter("emission", WorldGen.hex(w.get("glow", 0)))
			_blade_mat.set_shader_parameter("emission_energy", 1.0 if w.has("glow") else 0.0)
		_blade.scale.y = w["len"]
		_blade.position.y = 0.12 + 0.5 * w["len"]
		if not _blades.is_empty():
			var id: String = Game.equip["weapon"]["id"]
			var key: String = BLADE_OF.get(id, "longsword")
			if not _blades.has(key):
				key = "longsword"
			var s := 0.55 * float(w["len"])
			for k in _blades:
				_blades[k]["node"].visible = k == key
			var bl: Dictionary = _blades[key]
			(bl["node"] as Node3D).transform = Transform3D(Basis(Vector3(0, 0, 1), PI).scaled(Vector3.ONE * s), Vector3(0, 0.65 * s, 0))
			var mat: StandardMaterial3D = bl["base"]
			if id == "sword_rusty" and bl.has("rust"):
				mat = bl["rust"]
			elif id == "sword_steel":
				mat = bl["glow"]
				mat.albedo_color = WorldGen.hex(w["color"])
			if r >= 3:
				# Великий и легендарный ранг — клинок светится цветом ранга
				var g: StandardMaterial3D = bl["glow"]
				if mat != g:
					g.albedo_color = Color.WHITE
				g.emission_enabled = true
				g.emission = Items.RANKS[r]["color"]
				g.emission_energy_multiplier = 0.8
				mat = g
			else:
				(bl["glow"] as StandardMaterial3D).emission_enabled = false
			(bl["mesh"] as MeshInstance3D).material_override = mat
	_tunic_mat.set_shader_parameter("albedo", WorldGen.hex(a.get("color", 0x2e6b8a)))
	_tunic_mat.set_shader_parameter("metallic", 0.55 if a.get("metal", false) else 0.0)
	_tunic_mat.set_shader_parameter("roughness", 0.45 if a.get("metal", false) else 0.8)
	_helmet.visible = not h.is_empty()
	if not h.is_empty():
		_helmet_mat.set_shader_parameter("albedo", WorldGen.hex(h["color"]))
	# У следопыта своя броня и капюшон — накладки брони и шлема на нём не показываем
	if not _gear.is_empty() and SHOW_GEAR:
		var am: bool = a.get("metal", false)
		_set_gear(["cuirass", "chest_top", "belt"], not a.is_empty(), WorldGen.hex(a.get("color", 0)), am)
		_set_gear(["belt"], not a.is_empty(), WorldGen.hex(0x4a3220), false)
		# Наплечники — только у металлических доспехов
		_set_gear(["pauldron_Left", "pauldron_Right"], am, WorldGen.hex(a.get("color", 0)), true)
		var hm: bool = h.get("id", "") == "helm_iron" or (not h.is_empty() and h["color"] != 0x6a4626)
		_set_gear(["helm"], not h.is_empty(), WorldGen.hex(h.get("color", 0)), hm)
		_set_gear(["helm_rim", "helm_nose"], hm, WorldGen.hex(h.get("color", 0)).darkened(0.15), true)
		for slot in ["boots", "cloak", "shield"]:
			var e = Game.equip.get(slot)
			var it: Dictionary = Items.get_item(e["id"]) if e != null else {}
			var c: Color = WorldGen.hex(it.get("color", 0x444444))
			var metal: bool = it.get("metal", false)
			match slot:
				"boots": _set_gear(["boot_Left", "boot_Right", "toe_Left", "toe_Right"], e != null, c, metal)
				"cloak": _set_gear(["cloak", "cloak_collar"], e != null, c, false)
				"shield":
					_set_gear(["shield"], e != null, c, metal)
					_set_gear(["shield_boss"], e != null, Color("#b8b0a0"), true)

# ---------- Бой
func attack() -> void:
	if _spin_t >= 0.0 or _dash_t >= 0.0 or dead or busy or blocking:
		return
	# Комбо: нажатие во время удара — следующий удар сразу после этого
	if attack_t >= 0.0:
		if attack_t > 0.12 and combo < 2:
			_combo_queued = true
		return
	combo = combo + 1 if _since_swing < COMBO_WINDOW and combo < 2 else 0
	_start_swing()

## Блок: пока кнопка удерживается, удары спереди наносят меньше урона (щит — ещё меньше),
## герой идёт медленно и не бьёт
const BLOCK_REDUCE := 0.6     # без щита блок снимает 60% урона
const BLOCK_ARC := 1.75       # спереди — в пределах ±100°
const BLOCK_POSE := 0.7      # кадр удара, где меч поднят перед собой — стойка блока
var blocking := false

func block_reduce() -> float:
	return minf(0.9, BLOCK_REDUCE + Game.block_bonus())

## Комбо из трёх ударов: третий — выпад вперёд, сильнее и отбрасывает
const COMBO_WINDOW := 0.5     # сколько ждать следующего нажатия после удара, с
const COMBO_MULT := [1.0, 1.1, 1.6]
var combo := 0                # номер удара в комбо: 0, 1, 2
var _combo_queued := false
var _since_swing := 99.0

func _start_swing() -> void:
	attack_t = 0.0
	_attack_hit = false
	_combo_queued = false
	# Автонаведение на ближайшего врага рядом — удобно на телефоне
	var best: Node3D = null
	var bd := 4.5
	for e in enemies.alive_near(global_position, 4.5):
		var d := _flat(e.global_position - global_position).length()
		if d < bd:
			bd = d
			best = e
	if best:
		var v := _flat(best.global_position - global_position)
		facing = atan2(v.x, v.z)
	if combo == 2:
		# Выпад: рывок на пару метров вперёд
		_push += Vector3(sin(facing), 0, cos(facing)) * 9.0
	_new_swing = true

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

func _sword_hit() -> void:
	var finisher := combo == 2
	var reach := 2.9 if finisher else 2.3
	for e in enemies.alive_near(global_position, 4.5):
		var v := _flat(e.global_position - global_position)
		var d := maxf(0.01, v.length())
		if d > reach + e.T["r"] or absf(e.global_position.y - global_position.y) > 2.5:
			continue
		if absf(angle_difference(facing, atan2(v.x, v.z))) > (1.6 if finisher else 1.25) and d > e.T["r"] + 0.7:
			continue
		_deal(e, COMBO_MULT[combo], v / d)
		if finisher:
			e.knock(2.2)   # третий удар отбрасывает далеко
	if finisher:
		Fx.ring(global_position + Vector3(sin(facing), 0.1, cos(facing)) * 1.4, Color("#ffd479"), 2.0, 0.35)

## Урон с учётом навыков «Критический удар» и «Вампиризм»
func _deal(e: Node3D, mult: float, dir: Vector3) -> void:
	var dmg := roundi((Game.dmg + randf() * 8.0) * mult)
	var crit := randf() < Game.rank("crit") * 0.08 + Game.crit_bonus
	if crit:
		dmg *= 2
	e.hit(dmg, dir, crit)
	var vamp := Game.rank("vamp") * 0.04
	if vamp > 0.0 and not dead:
		Game.hp = minf(Game.max_hp, Game.hp + dmg * vamp)

func use_skill(id: String) -> void:
	var r := Game.rank(id)
	if r == 0 or cd[id] > 0.0 or dead or busy or _spin_t >= 0.0 or _dash_t >= 0.0:
		return
	attack_t = -1.0
	_new_swing = true
	if id == "whirl":
		_spin_t = 0.0
		_spin_hit = false
		cd["whirl"] = SkillDefs.whirl_cd(r)
	elif id == "dash":
		# Направление — куда наклонён джойстик, иначе — куда смотрит герой
		var dir := Vector3(sin(facing), 0, cos(facing))
		var mv: Vector2 = touch.move if touch else Vector2.ZERO
		if mv.length() > 0.2:
			var yaw: float = rig.yaw
			dir = (Vector3(-sin(yaw), 0, -cos(yaw)) * mv.y + Vector3(cos(yaw), 0, -sin(yaw)) * mv.x).normalized()
		_dash_dir = dir
		facing = atan2(dir.x, dir.z)
		_dash_t = 0.0
		_dash_hit = []
		_dash_speed = SkillDefs.dash_stats(Game.skills)["speed"]
		cd["dash"] = SkillDefs.dash_stats(Game.skills)["cd"]
		if SkillDefs.dash_form(Game.skills) == "blink":
			# Мерцание: вспышка там, где герой исчез
			Fx.ring(global_position + Vector3(0, 0.1, 0), Color("#b9a8ff"), 2.0, 0.4, true)

func cooldown_total(id: String) -> float:
	var r := maxi(1, Game.rank(id))
	return SkillDefs.whirl_cd(r) if id == "whirl" else SkillDefs.dash_stats(Game.skills)["cd"]

func _whirl_hit() -> void:
	var mult := 1.2 + 0.3 * (Game.rank("whirl") - 1)
	Fx.ring(global_position + Vector3(0, 0.6, 0), Color("#bfefff"), 7.0, 0.4)
	for e in enemies.alive_near(global_position, 5.0):
		var v := _flat(e.global_position - global_position)
		var d := maxf(0.01, v.length())
		if d > 3.3 + e.T["r"] or absf(e.global_position.y - global_position.y) > 2.5:
			continue
		_deal(e, mult, v / d)
		e.knock(1.5)

func _dash_hits() -> void:
	var mult := SkillDefs.DASH_DMG   # сквозь врагов — 20% урона
	for e in enemies.alive_near(global_position, 3.0):
		if _dash_hit.has(e):
			continue
		var v := _flat(e.global_position - global_position)
		if v.length() > 1.6 + e.T["r"] or absf(e.global_position.y - global_position.y) > 2.5:
			continue
		_dash_hit.append(e)
		# Отбрасываем в сторону от линии рывка
		var side := signf(v.x * _dash_dir.z - v.z * _dash_dir.x)
		if side == 0.0:
			side = 1.0
		_deal(e, mult, Vector3(_dash_dir.z * side, 0, -_dash_dir.x * side))

func take_damage(raw: int, from: Vector3) -> void:
	if _invuln > 0.0 or dead or busy:
		return
	var dmg := Game.reduce_damage(raw)
	var v := _flat(from - global_position)
	var blocked := blocking and v.length() > 0.01 and absf(angle_difference(facing, atan2(v.x, v.z))) < BLOCK_ARC
	if blocked:
		dmg = maxi(1, roundi(dmg * (1.0 - block_reduce())))
	Game.hp = maxf(0.0, Game.hp - dmg)
	_invuln = 0.5
	_hurt_ago = 0.0
	_push = _flat(global_position - from).normalized() * (3.0 if blocked else 10.0)
	if blocked:
		Fx.text("Блок −%d" % dmg, global_position, Color("#cfe0ff"))
		Fx.ring(global_position + Vector3(sin(facing), 1.0, cos(facing)) * 0.6, Color("#cfe0ff"), 0.8, 0.25)
	else:
		Fx.text("−%d" % dmg, global_position, Color("#ff6a5a"))
	Input.vibrate_handheld(60)
	hurt.emit(dmg)
	if Game.hp <= 0.0:
		dead = true
		_dead_t = 0.0
		attack_t = -1.0
		_spin_t = -1.0
		_dash_t = -1.0
		died.emit()

func respawn(pos: Vector3) -> void:
	dead = false
	Game.hp = Game.max_hp
	global_position = pos
	velocity = Vector3.ZERO
	_push = Vector3.ZERO
	_model.rotation.x = 0.0
	_model.position.y = 0.0

func drink_potion() -> void:
	if dead:
		return
	var heal := Game.use_potion()
	if heal > 0.0:
		Fx.text("+%d ❤" % roundi(heal), global_position, Color("#7dff8a"))

# ---------- Движение
func _physics_process(dt: float) -> void:
	_time += dt
	_since_swing += dt
	for k in cd:
		cd[k] = maxf(0.0, cd[k] - dt)
	var mv: Vector2 = touch.move if touch and not dead and not busy else Vector2.ZERO
	var yaw: float = rig.yaw if rig else 0.0
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var dir := fwd * mv.y + right * mv.x
	var mag := minf(1.0, dir.length())
	var swimming := not underground and global_position.y < WorldGen.WATER - 1.0
	var speed := (RUN if touch and touch.run else WALK) * maxf(0.3, mag)
	speed *= 1.0 + 0.08 * Game.rank("agility") + Game.speed_bonus
	if swimming:
		speed *= 0.5
	if attack_t >= 0.0:
		speed *= 0.45
	blocking = touch != null and touch.block and not dead and not busy and attack_t < 0.0 and _spin_t < 0.0 and _dash_t < 0.0
	if blocking:
		speed *= 0.4
	var hv := Vector3.ZERO
	if mag > 0.12:
		dir = dir.normalized()
		if attack_t < 0.0:
			facing += angle_difference(facing, atan2(dir.x, dir.z)) * minf(1.0, dt * 12.0)
		hv = dir * speed
		_speed_now = lerpf(_speed_now, speed, minf(1.0, dt * 10.0))
	else:
		_speed_now = lerpf(_speed_now, 0.0, minf(1.0, dt * 10.0))
	# Рывок: быстрое движение вперёд сквозь врагов, герой неуязвим
	if _dash_t >= 0.0:
		_dash_t += dt
		hv = _dash_dir * DASH_SPEED * _dash_speed
		_invuln = maxf(_invuln, 0.1)
		# Мерцание: герой исчезает на время рывка и появляется со вспышкой
		var blink := SkillDefs.dash_form(Game.skills) == "blink"
		_model.visible = not (blink and _dash_t > 0.03)
		if _dash_t >= DASH_TIME:
			_dash_t = -1.0
			_model.visible = true
			if blink:
				Fx.ring(global_position + Vector3(0, 0.1, 0), Color("#b9a8ff"), 2.5, 0.45, true)
	hv += _push
	_push *= exp(-dt * 7.0)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y -= GRAVITY * dt
	if is_on_floor() and touch and touch.jump and not swimming and not dead and not busy:
		velocity.y = JUMP
	# Плавание: держимся у поверхности воды
	if not underground and global_position.y < WorldGen.WATER - 1.1:
		global_position.y = WorldGen.WATER - 1.1
		velocity.y = maxf(velocity.y, 0.0)
	move_and_slide()
	if _dash_t >= 0.0:
		_dash_hits()
	var lim := WorldGen.HALF - 4.0
	global_position.x = clampf(global_position.x, -lim, lim)
	global_position.z = clampf(global_position.z, -lim, lim)
	_heal(dt)
	_animate(dt)

## Здоровье восстанавливается вне боя, у костра — быстро; «Регенерация» лечит всегда
func _heal(dt: float) -> void:
	_invuln -= dt
	_hurt_ago += dt
	if dead or Game.hp >= Game.max_hp:
		return
	var rate := Game.rank("regen") * 1.5
	var near_fire := global_position.distance_to(campfire_pos) < 7.0
	if near_fire:
		rate += 15.0
	elif _hurt_ago > 5.0:
		rate += 4.0
	Game.hp = minf(Game.max_hp, Game.hp + rate * dt)

func _animate(dt: float) -> void:
	var on_floor := is_on_floor()
	var moving := _speed_now > 0.3
	_walk += dt * _speed_now * 1.6
	var amp := minf(1.0, _speed_now / 6.0) * 0.9 if moving else 0.0
	var sw := sin(_walk)
	_legs[0].rotation.x = sw * amp if on_floor else -0.6
	_legs[1].rotation.x = -sw * amp if on_floor else 0.3
	_arms[0].rotation = Vector3(-sw * amp * 0.8 if on_floor else -2.4, 0, 0)
	_arms[1].rotation = Vector3(sw * amp * 0.8 if on_floor else -2.4, 0, 0)
	# Удар мечом: замах над головой → рубящий удар вперёд → возврат
	var sm := _slash.material_override as StandardMaterial3D
	sm.albedo_color.a = 0.0
	if attack_t >= 0.0:
		attack_t += dt * (1.0 + 0.1 * Game.rank("agility")) * ATTACK_SPEED * (0.85 if combo == 2 else 1.0)
		var t := attack_t
		var ax: float
		var az: float
		if t < 0.12:
			var k := t / 0.12
			ax = lerpf(0.0, -2.7, k)
			az = lerpf(0.0, 0.45, k)
		elif t < 0.3:
			var k := smoothstep(0.0, 1.0, (t - 0.12) / 0.18)
			ax = lerpf(-2.7, 0.5, k)
			az = lerpf(0.45, -0.3, k)
		else:
			var k := minf(1.0, (t - 0.3) / 0.18)
			ax = lerpf(0.5, 0.0, k)
			az = lerpf(-0.3, 0.0, k)
		_arms[0].rotation = Vector3(ax, 0, az)
		if t > 0.14 and t < 0.36:
			sm.albedo_color.a = 0.55 * (1.0 - absf(t - 0.22) / 0.14)
		if not _attack_hit and t >= 0.2:
			_attack_hit = true
			_sword_hit()
		if t >= 0.48:
			attack_t = -1.0
			_since_swing = 0.0
			if _combo_queued and combo < 2:
				combo += 1
				_start_swing()
	# Вихрь: герой крутится с вытянутым мечом
	var spin := 0.0
	if _spin_t >= 0.0:
		_spin_t += dt
		# С анимацией модели оборот делает сама анимация; у блочной модели — крутим её целиком
		var whirl_anim := _anim != null and _anim.has_animation(A_WHIRL)
		var total := WHIRL_TIME if whirl_anim else 0.45
		if not whirl_anim:
			spin = minf(1.0, _spin_t / total) * TAU
		_arms[0].rotation = Vector3(0, 0, -1.4)
		_arms[1].rotation = Vector3(0, 0, 1.2)
		if not _spin_hit and _spin_t >= (WHIRL_HIT if whirl_anim else 0.2):
			_spin_hit = true
			_whirl_hit()
		if _spin_t >= total:
			_spin_t = -1.0
	var bob := absf(cos(_walk)) * 0.08 if moving and on_floor else sin(_time * 1.7) * 0.015
	if _char:
		bob = 0.0
		_animate_char(on_floor, moving)
	_model.position.y = bob
	if _dash_t >= 0.0:
		# Длинный прыжок: тело летит по дуге над землёй
		var u := clampf(_dash_t / DASH_TIME, 0.0, 1.0)
		_model.position.y += 4.0 * DASH_JUMP * u * (1.0 - u)
	_model.rotation.y = facing + spin
	if dead:
		_dead_t += dt
		var k := minf(1.0, _dead_t * 2.5)
		_model.rotation.x = -k * 1.45
		_model.position.y = k * 0.25
	else:
		# В прыжке рывка: на взлёте корпус чуть назад, к приземлению — вперёд
		# Наклон в прыжке рывка — только у блочной модели (у модели героя есть своя анимация прыжка)
		var lean_jump := _dash_t >= 0.0 and not (_anim and _anim.has_animation(A_DASH))
		_model.rotation.x = lerpf(-0.15, 0.3, clampf(_dash_t / DASH_TIME, 0.0, 1.0)) if lean_jump else 0.0
