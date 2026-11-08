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
var cd := {"whirl": 0.0, "dash": 0.0, "art": 0.0, "dodge": 0.0, "horizontal": 0.0}

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
# Рывок как у Кирито (присланное видео): тёмный размытый след по пути, в конце — низкий присед
# и подъём в стойку с мечом вперёд (отрезок клипа Sword_Judgment)
const DASH_LAND_CLIP := ["Sword_Judgment", 1.35, 2.1]   # [клип, начало приседа, стойка]
const DASH_LAND := 0.45                                  # сколько длится присед → стойка, с
var _dash_from := Vector3.ZERO
var _dash_streak: MeshInstance3D
var _dead_t := 0.0
var _char: Node3D           # модель персонажа из models/hero.glb
var _anim: AnimationPlayer
var _new_swing := false
var _idle_pose := false
var _longsword: Node3D
var _shields := {}           # щиты по виду: round / heater / tower
var _body_mat: Material
var _armor_skin := ""
const ARMOR_SKINS := {"armor_leather": "leather", "armor_chain": "chain", "armor_plate": "plate"}
const ARMOR_DIR := "res://models/armor/"
var _body_mi: MeshInstance3D
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
	_slash.visible = false   # белая дуга взмаха — выключена

## Модель персонажа — следопыт (Meshy, скелет Mixamo; tools/prepare_models.py вырезал его
## собственные клинки и собрал анимации удара, бега и быстрого бега в один файл).
## Блочная модель остаётся запасной: её прячем, а меч переносим в правую кисть.
const CHAR_PATH := "res://models/hero.glb"
const GRIP_PATH := "res://models/hero_grip.json"
const SWORD_PATH := "res://models/longsword.glb"
const RUST_TEX := "res://models/longsword_rust.jpg"
const CHAR_SCALE := 1.05
const GRIP_TILT := 10.0      # наклон клинка от поперечного к пальцам, градусы
const SHOW_GEAR := true   # надетое снаряжение видно на герое (накладки на костях модели)
const A_IDLE := "Idle"         # дыхание и осмотр (есть у Shadowwarden)
const A_STANCE := "Combat_Stance"   # стойка на месте — из присланного файла (меч в сжатой руке)
const A_WALK := "Running"      # отдельной ходьбы нет — медленный бег
const A_RUN := "RunFast"
const A_SLASH := "Right_Hand_Sword_Slash"
const A_WHIRL := "Sword_Spin_360"   # круговой удар мечом на 360° (присланный клип Meshy)
const A_DASH := "DashJump"      # прыжок через препятствие (Jump_Over_Obstacle)
# Вихрь: длительность и момент удара — середина оборота в анимации
const WHIRL_TIME := 0.75
const WHIRL_HIT := 0.5
const STRIDE_WALK := 4.8       # м/с, на которые уходит стопа за секунду анимации Running
const STRIDE_RUN := 8.25       # то же для RunFast (замер: tests/gait.tscn)
var _sk: Skeleton3D
var in_world2 := false       # герой на Плато ветров (второй мир над башней)
var _ragdoll := Ragdoll.new()  # падение по физике при гибели
var _feet: FootIK            # стопы встают на склон, когда герой стоит
var _ha: HeroAnim            # дерево анимаций (если у модели есть все нужные анимации)
## Шаг тела в ударах (root motion): как таз уходит вперёд в клипе (models/hero_rootmotion.json,
## tools/rig_from_mannequin.py). В самом клипе таз на месте — героя двигает игра, ноги не скользят.
const ROOT_MOTION_PATH := "res://models/hero_rootmotion.json"
var _rm := {}                # клип → PackedFloat32Array смещения вперёд (м) по кадрам 60 Гц
var _rm_key := ""
var _rm_prev := 0.0
var _rm_t := 0.0
const LOCO_WALK_FROM := 0.6    # м/с: с этой скорости — шаг
const LOCO_FAST_FROM := 2.6    # отсюда шаг плавно переходит в бег
const LOCO_FAST_FULL := 4.0
var _trail: SwordTrail
var _fight_check := 0.0
var _in_fight := false

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
	if _anim.has_animation(A_STANCE):
		_anim.get_animation(A_STANCE).loop_mode = Animation.LOOP_LINEAR
	if _anim.has_animation(BACKSTEP_CLIP):
		_anim.get_animation(BACKSTEP_CLIP).loop_mode = Animation.LOOP_LINEAR
	if _anim.has_animation(RUN_FIGHT):
		_anim.get_animation(RUN_FIGHT).loop_mode = Animation.LOOP_LINEAR
	for n in [WALK_CLIP, RUN_CLIP, "MS_strafe_left", "MS_strafe_right"]:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_has_idle = _anim.has_animation(A_IDLE)
	if _has_idle:
		_anim.get_animation(A_IDLE).loop_mode = Animation.LOOP_LINEAR
	var sk: Skeleton3D = _char.find_children("*", "Skeleton3D", true, false)[0]
	_animate_31(sk)
	_setup_combat_pack()
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
		# Хват по сжатым пальцам из анимации удара: рукоять лежит в ладони — проходит через
		# середину кулака (внутри согнутых пальцев), клинок выходит со стороны большого
		# и указательного пальцев поперёк кисти (при прямом запястье, чуть наклонён к пальцам)
		var hg := HandGrip.new()   # сжимает пальцы в кулак поверх анимации
		sk.add_child(hg)
		hg.setup(sk, "Right")
		var fist := _fist_grip(sk, _anim.get_animation(A_STANCE if _anim.has_animation(A_STANCE) else A_SLASH), hg)
		hg.queue_free()   # пальцы — только из клипов Meshy, без своей позы
		if not fist.is_empty():
			var axis := Vector3.UP   # ось кисти (от запястья к пальцам) в системе кости
			var across: Vector3 = fist[1]
			var blade := (across - axis * across.dot(axis)).normalized()
			blade = blade.rotated(blade.cross(axis).normalized(), deg_to_rad(GRIP_TILT)).normalized()
			var width := (axis - blade * axis.dot(blade)).normalized()
			_sword.transform = Transform3D(Basis(width, blade, width.cross(blade).normalized()), fist[0])
	_sword.scale = Vector3.ONE / CHAR_SCALE
	_attach_blades()
	_build_gear(sk)
	_anim.play(A_IDLE if _has_idle else A_SLASH)
	_anim.seek(0.0, true)
	# Все движения — клипы Meshy (сценарий «Meshy animations» → tools/prepare_models.py meshy_clips)
	# Дерево анимаций: плавные переходы и удар на бегу (только верх тела)
	if _has_idle and _anim.has_animation(A_WHIRL) and _anim.has_animation(A_DASH):
		_ha = HeroAnim.new()
		add_child(_ha)
		var acts := {"slash": A_SLASH, "whirl": A_WHIRL, "dash": A_DASH, "air": RUN_CLIP}
		# Движения из библиотеки Meshy (сценарий «Meshy animations», tools/prepare_models.py meshy_clips)
		for m in MESHY_MOVES:
			if _anim.has_animation(MESHY_MOVES[m][0]):
				acts[m] = MESHY_MOVES[m][0]
		for i in ATTACK_CLIPS.size():
			if _anim.has_animation(ATTACK_CLIPS[i][0]):
				acts["atk%d" % i] = ATTACK_CLIPS[i][0]
		for k in ART_CLIPS:
			if _anim.has_animation(ART_CLIPS[k][0]):
				acts["art_" + k] = ART_CLIPS[k][0]
		if _anim.has_animation(BLOCK_CLIP[0]):
			acts["block"] = BLOCK_CLIP[0]
		# Вихрь — удар в прыжке с разворотом, прыжок — прыжок с ударом вниз
		if _anim.has_animation(WHIRL_CLIP[0]):
			acts["whirl"] = WHIRL_CLIP[0]
		if _anim.has_animation(JUMP_CLIP[0]):
			acts["air"] = JUMP_CLIP[0]
		if _anim.has_animation(DASH_LAND_CLIP[0]):
			acts["dash_land"] = DASH_LAND_CLIP[0]
		# Ходьба по скорости: стойка → боевой шаг → спринт (клипы Meshy)
		# Шаг → бег → спринт (клипы Meshy), у каждого свой темп по длине шага
		var walk := WALK_PLAIN if _anim.has_animation(WALK_PLAIN) else WALK_CLIP
		var sprint := SPRINT_CLIP if _anim.has_animation(SPRINT_CLIP) else RUN_CLIP
		if _anim.has_animation(SPRINT_CLIP):
			_anim.get_animation(SPRINT_CLIP).loop_mode = Animation.LOOP_LINEAR
		if _anim.has_animation(WALK_PLAIN):
			_anim.get_animation(WALK_PLAIN).loop_mode = Animation.LOOP_LINEAR
		_ha.setup(_anim, sk, acts, [[A_STANCE if _anim.has_animation(A_STANCE) else A_IDLE, 0.0], [walk, LOCO_WALK_FROM],
			[walk, LOCO_WALK_TOP], [RUN_CLIP, LOCO_FAST_FULL], [RUN_CLIP, LOCO_RUN_TOP], [sprint, LOCO_SPRINT]], RUN)
		_loco_clips = ["", walk, walk, RUN_CLIP, RUN_CLIP, sprint]
	# След клинка
	_trail = SwordTrail.new()
	add_child(_trail)
	_sk = sk
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with("RightHand"):
			_hand_bone = i
	_load_root_motion()
	# Ноги на склонах
	var feet := FootIK.new()
	add_child(feet)
	if feet.setup(self, sk):
		_feet = feet
	update_look()

func _load_root_motion() -> void:
	if not FileAccess.file_exists(ROOT_MOTION_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(ROOT_MOTION_PATH))
	if d is Dictionary:
		for k in d.get("clips", {}):
			_rm[k] = PackedFloat32Array(d["clips"][k])

func _rm_at(c: PackedFloat32Array, t: float) -> float:
	var x := clampf(t * 60.0, 0.0, c.size() - 1.001)
	var i := int(x)
	return lerpf(c[i], c[i + 1], x - i)

## Скорость от шага в клипе удара (только удар на всё тело — на бегу ногами правит бег)
func _root_motion(dt: float) -> Vector3:
	if attack_t < 0.0 or _ha == null or _ha._upper or _move != "" or dt <= 0.0:
		_rm_key = ""
		return Vector3.ZERO
	var clip: String = _ha._names.get(_ha.current(), "")
	if not _rm.has(clip):
		_rm_key = ""
		return Vector3.ZERO
	var a := _rm_at(_rm[clip], _ha.act_time)
	var key := _ha.current()
	if key != _rm_key or _ha.act_time < _rm_t:
		_rm_key = key
		_rm_prev = a
	_rm_t = _ha.act_time
	var d := (a - _rm_prev) * CHAR_SCALE
	_rm_prev = a
	return Vector3(sin(facing), 0, cos(facing)) * clampf(d / dt, -7.0, 7.0)

## Где у сжатого кулака середина (там лежит рукоять) и куда смотрит поперечная ось ладони:
## по суставам четырёх пальцев в позе анимации (в системе кости кисти).
## Возвращает [середина кулака, ось от мизинца к указательному] или [] если костей нет.
func _fist_grip(sk: Skeleton3D, anim: Animation, hg: HandGrip) -> Array:
	var curl := {}   # кость → добавочный сгиб пальца (HandGrip)
	for bb in hg._bones:
		curl[bb[0]] = Quaternion(bb[1], bb[2])
	var hand := -1
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with("RightHand"):
			hand = i
	if hand < 0:
		return []
	var rot := {}   # кость → поворот в анимации (кадр стойки удара)
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			var b := sk.find_bone(String(anim.track_get_path(t)).get_slice(":", 1))
			if b >= 0:
				rot[b] = anim.rotation_track_interpolate(t, 0.0)
	var pts := []
	var knuckle := {}
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		var tr := Transform3D()
		for k in [1, 2, 3, 4]:
			var b := -1
			for i in sk.get_bone_count():
				if sk.get_bone_name(i).ends_with("RightHand%s%d" % [f, k]):
					b = i
			if b < 0:
				break
			var r: Quaternion = rot.get(b, sk.get_bone_rest(b).basis.get_rotation_quaternion())
			if curl.has(b) and not rot.has(b):   # клип без пальцев — сжать; с пальцами — как в клипе
				r = r * curl[b]
			tr = tr * Transform3D(Basis(r), sk.get_bone_rest(b).origin)
			pts.append(tr.origin)
			if k == 1:
				knuckle[f] = tr.origin
	if pts.size() < 8 or not knuckle.has("Index") or not knuckle.has("Pinky"):
		# Модель без пальцев: рукоять — в середине ладони (между запястьем и концом кисти), поперёк
		# кисти — сторона большого пальца: в T-позе ладонь вниз, большой палец смотрит вперёд (+Z)
		var tip := -1
		for i in sk.get_bone_count():
			if sk.get_bone_parent(i) == hand:
				tip = i
		var palm := sk.get_bone_rest(tip).origin * 0.45 if tip >= 0 else Vector3(0, 0.07, 0)
		var across := (sk.get_bone_global_rest(hand).basis.inverse() * Vector3(0, 0, 1)).normalized()
		return [palm, across]
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	return [c, (knuckle["Index"] - knuckle["Pinky"]).normalized()]

## Модели клинков: у всех клинок по −Y, середина рукояти на y ≈ 0,65, ширина по X.
## Переворачиваем клинком вверх и ставим серединой рукояти в начало хвата.
## Длинный меч — ржавый (ржавая текстура), железный и стальной; костяной и кристальный — свои модели.
const BLADES := {
	"longsword": "res://models/longsword.glb",
	"bone_blade": "res://models/bone_blade.glb",
	"crystal_blade": "res://models/crystal_blade.glb",
}
const BLADE_OF := {"sword_bone": "bone_blade", "sword_crystal": "crystal_blade", "rapier_star": "crystal_blade", "dagger_venom": "bone_blade",
	"u_bone_king": "bone_blade", "u_queen": "crystal_blade", "u_frost": "crystal_blade", "u_chief": "bone_blade"}

## Клинки в духе SAO (scripts/sao_gear.gd): по одному на тип оружия, цвет — по предмету
const BLADE_REF_LEN := {"sword": 1.0, "great": 1.4, "rapier": 1.15, "dagger": 0.55}

func _attach_blades() -> void:
	for wt in SaoGear.BLADE:
		var node := SaoGear.blade(wt)
		node.visible = false
		# кулак держит рукоять у гарды: начало клинка чуть выше центра хвата
		node.position.y = float(SaoGear.BLADE[wt]["grip"]) * 0.42
		_sword.add_child(node)
		SaoGear.paint_blade(node, Color.WHITE, Color("#3a3a44"), Color("#2a1e16"), Color.BLACK, 0.0)
		var mi: MeshInstance3D = node.get_node("Blade")
		var base: StandardMaterial3D = mi.material_override
		_blades["sao_" + wt] = {"node": node, "mesh": mi, "base": base, "glow": base.duplicate()}
	for c in _sword.get_children():
		if not c in _blades.values().map(func(x): return x["node"]):
			c.visible = false
	_longsword = _blades["sao_sword"]["node"]

## Броня и шлем — детали на костях модели, двигаются вместе с телом.
## Размеры подобраны по модели: торс ~0,4 м в ширину, голова ~0,2 м.
func _build_gear(sk: Skeleton3D) -> void:
	# Доспехи — сама модель героя в другой раскраске (перекраска Meshy, те же сетка и UV):
	# кожаный доспех, кольчуга, латы. Ничего не надето поверх — значит, ничто и не проступает.
	var body: MeshInstance3D = null
	for m in _char.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			body = m
	if body == null:
		return
	_body_mi = body
	_body_mat = body.mesh.surface_get_material(0)
	# Щиты на тыльной стороне левого предплечья, снаружи руки (не касаются её)
	var b := -1
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with("LeftForeArm"):
			b = i
	# Щит НА руке: на ремнях предплечья (не крутится вместе с кистью), центр — середина предплечья
	var att := BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_name = sk.get_bone_name(b)
	att.bone_idx = b
	var elbow: Vector3 = sk.get_bone_global_rest(b).origin
	var wrist: Vector3 = sk.get_bone_global_rest(sk.find_bone(sk.get_bone_name(b).replace("ForeArm", "Hand"))).origin
	var g: Transform3D = sk.get_bone_global_rest(b)
	_shields = {}
	for kind in ["round", "heater", "tower"]:
		var sh := SaoGear.shield(kind)
		sh.visible = false
		att.add_child(sh)
		# в T-позе левая рука вдоль +X ладонью вниз; щит — снаружи предплечья (+Y), лицом наружу,
		# верхом к большому пальцу (+Z). Рука целиком за щитом: от оси предплечья до задней стороны
		# щита — больше толщины руки и кулака, поэтому щит не входит в руку
		var center := elbow.lerp(wrist, 0.5) + Vector3(0, SHIELD_OFF, 0)
		var basis := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
		# Крепление щита — узел ShieldMount боевого модуля (addons/combat_pack): смещение и поворот
		# от кости предплечья, щит снаружи руки
		var tf := g.affine_inverse() * Transform3D(basis, center)
		var mount := AdventureShieldMount.new()
		mount.name = "ShieldMount_" + kind
		att.add_child(mount)
		mount.offset_meters = tf.origin
		mount.rotation_degrees_offset = tf.basis.orthonormalized().get_euler() * (180.0 / PI)
		sh.get_parent().remove_child(sh)
		mount.add_child(sh)
		sh.transform = Transform3D.IDENTITY
		sh.scale = Vector3.ONE / CHAR_SCALE * 1.0
		_shields[kind] = sh

const SHIELD_OFF := 0.085   # от оси предплечья до щита: щит прижат к руке снаружи, рука его не прорезает

func _bone_local(sk: Skeleton3D, parent: int, suffix: String) -> Vector3:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with(suffix):
			return sk.get_bone_global_rest(parent).affine_inverse() * sk.get_bone_global_rest(i).origin
	return Vector3.UP * 0.1

## Анимации модели: стойка, ходьба, бег, удар, вихрь, рывок, прыжок
## Анимация через дерево: ходьба смешивается по скорости, действия накладываются поверх
func _animate_tree(dt: float, on_floor: bool, moving: bool) -> void:
	# Рядом враги — боевой шаг и бег с мечом наготове; в блоке — шаг назад
	if enemies:
		_fight_check -= dt
		if _fight_check <= 0.0:
			_fight_check = 0.5
			_in_fight = not enemies.alive_near(global_position, FIGHT_NEAR).is_empty()
	var walk_anim: String = _loco_clips[1]
	var run_anim: String = RUN_CLIP
	if _in_fight:
		walk_anim = WALK_CLIP   # бег в бою — тот же Kirito_Sword_Run: Sword_Run шагает на месте (проверка ANIMATE)
	if _backstep and _anim.has_animation(BACKSTEP_CLIP):
		walk_anim = BACKSTEP_CLIP
	elif _sidestep != 0:
		walk_anim = "MS_strafe_left" if _sidestep > 0 else "MS_strafe_right"
	for i in [1, 2]:
		_set_loco(i, walk_anim)
	for i in [3, 4]:
		_set_loco(i, run_anim)
	# Темп шага — по длине шага клипа на этой скорости, чтобы опорная стопа не скользила
	var stride_t := _speed_now / _stride_at(_speed_now)
	_ha.locomotion(_speed_now, lerpf(1.0, stride_t, clampf(_speed_now / LOCO_WALK_FROM, 0.0, 1.0)))
	var upper := on_floor and moving and _speed_now > 1.0
	if _move != "":
		# Уклонения, Switch, реакции, «Горизонталь» — анимация целиком, с начала
		var start := 0.0
		var sc := 1.0
		if MESHY_MOVES.has(_move) and _ha._names.get(_move, "") == MESHY_MOVES[_move][0]:
			start = MESHY_MOVES[_move][1]
			sc = MESHY_MOVES[_move][2]
		if _move == "horizontal" and _ha._names.get("horizontal", "") == MESHY_MOVES["horizontal"][0]:
			# «Горизонталь» по ключевым позам клипа: замах — в конец стойки, удар — в момент удара
			_ha.follow(_move, _key_t(HZ_KEYS, _move_t), dt)
		else:
			_ha.act(_move, start if _move_new else -1.0, sc)
		_move_new = false
	elif blocking:
		if _ha._names.has("block"):
			# Защита по клипу: меч поднимается в стойку за BLOCK_RAISE и держится вертикально перед собой
			_ha.follow("block", lerpf(BLOCK_FROM, BLOCK_CLIP[1], clampf((_time - _block_start) / BLOCK_RAISE, 0.0, 1.0)), dt, upper)
		else:
			_ha.act("slash", BLOCK_POSE, 0.0, upper)
	elif _unblock_t >= 0.0 and _ha._names.has("block") and attack_t < 0.0 and _spin_t < 0.0 and _dash_t < 0.0 and _art_t < 0.0:
		# Кнопку отпустили — меч опускается обратно по тому же клипу
		_ha.follow("block", lerpf(BLOCK_CLIP[1], BLOCK_FROM, clampf(_unblock_t / BLOCK_LOWER, 0.0, 1.0)), dt, upper)
	elif _art_t >= 0.0 and _ha._names.has("art_" + _art):
		# Приём — клип Meshy: удар клипа совпадает с моментом удара приёма
		var ac: Array = ART_CLIPS[_art]
		var sp: float = LUNGE_CLIP_SPEED if _art == "sword" else ac[2]
		var start: float = maxf(0.0, ac[1] - (_art_charge() + 0.08) * sp)
		_ha.act("art_" + _art, start if _new_swing or _ha.current() != "art_" + _art else -1.0, sp)
	elif _art_t >= 0.0:
		if _art_t < _art_charge():   # стойка: меч отведён для удара
			_ha.act("slash", 0.4, 0.0)
		else:
			var sp := 3.2 if _art == "rapier" else 2.2
			if _ha.act_scale == 0.0:
				_ha.act("slash", 0.4, sp)
			elif _art == "rapier" and _ha.act_time > 1.1:
				_ha.act("slash", 0.55, sp)   # уколы — повтор середины удара
			else:
				_ha.act("slash", -1.0, sp)
	elif _spin_t >= 0.0:
		if _ha._names.get("whirl", "") == WHIRL_CLIP[0]:
			# Вихрь по ключевым позам: оборот клипа (0,15→0,75 с) — на время ударов вихря
			_ha.follow("whirl", _key_t(WHIRL_KEYS, _spin_t), dt)
		else:
			_ha.act("whirl", 0.0 if _new_swing or _ha.current() != "whirl" else -1.0, _anim.get_animation(A_WHIRL).length / WHIRL_TIME)
	elif _dash_t >= DASH_TIME and _ha._names.has("dash_land"):
		# Появление: низкий присед → стойка с мечом вперёд
		var u := clampf((_dash_t - DASH_TIME) / DASH_LAND, 0.0, 1.0)
		_ha.follow("dash_land", lerpf(DASH_LAND_CLIP[1], DASH_LAND_CLIP[2], u), dt)
	elif _dash_t >= 0.0:
		_ha.act("dash", 0.0 if _ha.current() != "dash" else -1.0, _anim.get_animation(A_DASH).length / DASH_TIME)
	elif attack_t >= 0.0:
		# Вся анимация удара длится 1,5 с — сжимаем её в один удар героя
		var sp: float = 2.6 * (1.0 + 0.1 * Game.rank("agility")) * ATTACK_SPEED * _wt()["speed"] * (1.0 + Game.stats["agi"] * Game.STAT_AGI_SPEED)
		var key := "atk%d" % combo
		if _ha._names.has(key):
			# Удар — отрезок клипа Meshy вокруг момента удара (удар героя — на 0,2 из 0,48)
			var hit: float = ATTACK_CLIPS[combo][1]
			var seg := ATTACK_SEG
			_ha.act(key, maxf(0.0, hit - seg * 0.2 / 0.48) if _new_swing or _ha.current() != key else -1.0, sp * seg / 1.5, upper)
		else:
			_ha.act("slash", 0.08 if _new_swing or _ha.current() != "slash" else -1.0, sp, upper)
	elif not on_floor:
		if _ha._names.get("air", "") == JUMP_CLIP[0]:
			# Прыжок по ключевым позам клипа, в такт полёту: на подъёме — от отрыва к верхней
			# точке по скорости взлёта, на спуске — от верхней точки к касанию земли
			_ha.follow("air", _jump_clip_t(), dt)
		else:
			_ha.act("air", 0.17, 0.0)   # в прыжке — поза полёта из бега
	elif _land_t >= 0.0 and _ha._names.get("air", "") == JUMP_CLIP[0]:
		# Приземление: амортизация по клипу (присел на касании — выпрямился)
		_ha.follow("air", minf(JUMP_TOUCH + _land_t * JUMP_LAND_RATE, JUMP_RECOVER), dt)
	else:
		_ha.stop()
	_new_swing = false
	_ha.update(dt)

func _animate_char(on_floor: bool, moving: bool) -> void:
	if _ha:
		_animate_tree(get_physics_process_delta_time(), on_floor, moving)
		return
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
		return
	if _art_t >= 0.0:
		want = A_SLASH
		if _art_t < _art_charge():   # стойка: меч отведён для удара
			speed = 1.0
			if _anim.current_animation != A_SLASH:
				_anim.play(A_SLASH, 0.08)
			if absf(_anim.current_animation_position - 0.4) > 0.005:
				_anim.seek(0.4, false)
		else:
			speed = 3.2 if _art == "rapier" else 2.2
			if _art == "rapier" and _anim.current_animation_position > 1.1:
				_anim.seek(0.55, false)   # уколы — повтор середины удара
		_anim.speed_scale = speed
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
		speed = 2.6 * (1.0 + 0.1 * Game.rank("agility")) * ATTACK_SPEED * _wt()["speed"] * (1.0 + Game.stats["agi"] * Game.STAT_AGI_SPEED)
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
			var wt: String = w.get("wt", "sword")
			var key := "sao_" + wt
			for k in _blades:
				_blades[k]["node"].visible = k == key
			var bl: Dictionary = _blades[key]
			# Длина клинка по предмету (рукоять та же)
			var blade_mi: MeshInstance3D = bl["mesh"]
			blade_mi.scale = Vector3(1.0, float(w["len"]) / float(BLADE_REF_LEN[wt]), 1.0)
			# Гарда и рукоять: простое оружие — тёмное железо и кожа, редкое — золото,
			# уникальное — цвет своего свечения
			var guard := Color("#3a3a44")
			if r >= 2:
				guard = Color("#c8a040")
			if w.get("unique", false):
				guard = WorldGen.hex(w["glow"]).lerp(Color("#202028"), 0.45)
			if id == "sword_rusty":
				guard = Color("#5a4030")
			var grip := Color("#2a1e16") if r < 2 else Color("#1a1a30")
			SaoGear.paint_blade(bl["node"], WorldGen.hex(w["color"]), guard, grip, Color.BLACK, 0.0)
			var mat: StandardMaterial3D = blade_mi.material_override
			if id == "sword_rusty":
				mat.metallic = 0.3
				mat.roughness = 0.75
				if ResourceLoader.exists(RUST_TEX):
					mat.albedo_texture = load(RUST_TEX)
			var glow := Color.BLACK
			var energy := 0.0
			if w.has("glow"):
				glow = WorldGen.hex(w["glow"])
				energy = 1.2 if w.get("unique", false) else 0.7
			elif r >= 3:
				glow = Items.RANKS[r]["color"]
				energy = 0.8
			if energy > 0.0:
				mat.emission_enabled = true
				mat.emission = glow
				mat.emission_energy_multiplier = energy
			bl["base"] = mat
			bl["glow"] = mat.duplicate()
	_tunic_mat.set_shader_parameter("albedo", WorldGen.hex(a.get("color", 0x2e6b8a)))
	_tunic_mat.set_shader_parameter("metallic", 0.55 if a.get("metal", false) else 0.0)
	_tunic_mat.set_shader_parameter("roughness", 0.45 if a.get("metal", false) else 0.8)
	_helmet.visible = not h.is_empty()
	if not h.is_empty():
		_helmet_mat.set_shader_parameter("albedo", WorldGen.hex(h["color"]))
	# У следопыта своя броня и капюшон — накладки брони и шлема на нём не показываем
	if _body_mi != null and SHOW_GEAR:
		_show_armor(a, h)

## Доспехи в духе SAO: кожаная куртка — лёгкий кожаный нагрудник с поясом; кольчуга — кольчужный
## нагрудник с пластинами на бёдрах и наплечниками; латы — белые латы с золотой кромкой
## (нагрудник, наплечники, наручи, перчатки, наколенники, набедренники).
func _show_armor(a: Dictionary, h: Dictionary) -> void:
	_apply_armor_skin(ARMOR_SKINS.get(Game.equip["armor"]["id"] if Game.equip.get("armor") != null else "", ""))
	_show_shield()
	_show_cloak()

## Раскраска модели под доспех: текстуры из models/armor/<набор>_*.jpg (tools/prepare_models.py armor)
func _apply_armor_skin(key: String) -> void:
	if key == _armor_skin and _body_mi.material_override != null:
		return
	_armor_skin = key
	# Раскраски доспехов сделаны под прежнюю модель героя — у нового героя свои цвета, без перекраски
	key = "base"
	var base := ARMOR_DIR + key + "_base_color.jpg"
	var m := (_body_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	Mats.toon(m)
	if not ResourceLoader.exists(base):
		_body_mi.material_override = m
		return
	m.albedo_texture = load(base)
	m.albedo_color = Color.WHITE
	if ResourceLoader.exists(ARMOR_DIR + key + "_normal.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(ARMOR_DIR + key + "_normal.jpg")
	if ResourceLoader.exists(ARMOR_DIR + key + "_metallic.jpg"):
		m.metallic = 1.0
		m.metallic_texture = load(ARMOR_DIR + key + "_metallic.jpg")
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if ResourceLoader.exists(ARMOR_DIR + key + "_roughness.jpg"):
		m.roughness = 1.0
		m.roughness_texture = load(ARMOR_DIR + key + "_roughness.jpg")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	_body_mi.material_override = m

## Мантия Теневого стража — модель на скелете героя (tools/blender/fit_cloak.py), видна, когда надета
const MANTLE_PATH := "res://models/cloak_mantle.glb"
var _mantle: MeshInstance3D
const CLOTH_SHADER := preload("res://shaders/cloth.gdshader")
var _cloth_mats: Array = []
var _cloth_lag := Vector3.ZERO      # отставание низа плаща (мир, м)
var _cloth_vel := Vector3.ZERO      # скорость пружины
var _prev_vel := Vector3.ZERO

## Пружина плаща: низ отстаёт от движения (бег — полы назад, остановка — вперёд по инерции,
## прыжок — вверх, падение — подлетают), плюс ветер
func _update_cloth(dt: float) -> void:
	if _cloth_mats.is_empty() or _mantle == null or not _mantle.visible or dt <= 0.0:
		return
	var v := velocity
	var acc := (v - _prev_vel) / dt
	_prev_vel = v
	var wind := Vector3(sin(_time * 0.7), 0, cos(_time * 0.53)) * 0.04
	var target := Vector3(-v.x, 0, -v.z) * 0.045 + Vector3(0, clampf(-v.y * 0.03, -0.05, 0.25), 0) + wind
	target -= Vector3(acc.x, 0, acc.z) * 0.004
	if target.length() > 0.42:
		target = target.normalized() * 0.42
	# Пружина с затуханием — полы качаются и успокаиваются
	_cloth_vel += ((target - _cloth_lag) * 60.0 - _cloth_vel * 9.0) * dt
	_cloth_lag += _cloth_vel * dt
	var run := clampf(Vector2(v.x, v.z).length() / RUN, 0.0, 1.0)
	for m in _cloth_mats:
		m.set_shader_parameter("lag", _cloth_lag)
		m.set_shader_parameter("flutter", 0.25 + run * 1.0)
		m.set_shader_parameter("hero_y", global_position.y)
		m.set_shader_parameter("top_h", 1.42 * CHAR_SCALE)

func _show_cloak() -> void:
	var e = Game.equip.get("cloak")
	var on: bool = e != null and e["id"] == "cloak_mantle"
	if on and _mantle == null and _sk and ResourceLoader.exists(MANTLE_PATH):
		var sc: Node = (load(MANTLE_PATH) as PackedScene).instantiate()
		var mi: MeshInstance3D = sc.find_children("*", "MeshInstance3D", true, false)[0]
		var skin := mi.skin
		mi.get_parent().remove_child(mi)
		sc.free()
		_sk.add_child(mi)
		mi.transform = Transform3D.IDENTITY
		mi.skin = skin
		mi.skeleton = NodePath("..")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for si in mi.mesh.get_surface_count():
			var m := mi.get_active_material(si)
			if m is BaseMaterial3D:
				# Живая ткань: полы отстают от движения и колышутся (shaders/cloth.gdshader)
				var b := m as BaseMaterial3D
				var cm := ShaderMaterial.new()
				cm.shader = CLOTH_SHADER
				cm.set_shader_parameter("albedo_tex", b.albedo_texture)
				cm.set_shader_parameter("albedo_color", b.albedo_color)
				if b.normal_enabled and b.normal_texture:
					cm.set_shader_parameter("normal_tex", b.normal_texture)
					cm.set_shader_parameter("has_normal", true)
				cm.set_shader_parameter("roughness", b.roughness)
				mi.set_surface_override_material(si, cm)
				_cloth_mats.append(cm)
		_mantle = mi
	if _mantle:
		_mantle.visible = on

func _show_shield() -> void:
	var e = Game.equip.get("shield")
	var kind := ""
	if e != null:
		kind = {"shield_wood": "round", "shield_iron": "heater", "shield_tower": "tower"}.get(e["id"], "heater")
		var it := Items.get_item(e["id"])
		var sc := WorldGen.hex(it.get("color", 0x777777))
		if kind == "tower":
			sc = Color("#eeeef2")
		SaoGear.paint_shield(_shields[kind], sc, it.get("metal", false))
	for k in _shields:
		_shields[k].visible = k == kind

# ---------- Бой
# ---------- Уклонения, Switch, реакции на удары, приём «Горизонталь»
## Движение: длина (с), скорость (м/с) с from по to, неуязвимость [с, по], что дальше
const MOVES := {
	"dodge_back": {"len": 0.7, "speed": 6.0, "from": 0.08, "to": 0.45, "inv": [0.03, 0.45]},
	"dodge_left": {"len": 0.58, "speed": 6.5, "from": 0.06, "to": 0.36, "inv": [0.03, 0.36]},
	"dodge_right": {"len": 0.58, "speed": 6.5, "from": 0.06, "to": 0.36, "inv": [0.03, 0.36]},
	"roll": {"len": 0.9, "speed": 6.0, "from": 0.1, "to": 0.65, "inv": [0.05, 0.6]},
	"switch": {"len": 0.65, "speed": 5.0, "from": 0.06, "to": 0.4, "inv": [0.0, 0.4]},
	"hit_heavy": {"len": 0.8, "speed": 2.0, "from": 0.0, "to": 0.35},
	"stun": {"len": 0.9},
	"knockdown": {"len": 1.4, "speed": 3.0, "from": 0.05, "to": 0.5, "inv": [0.0, 1.4], "next": "getup"},
	"getup": {"len": 1.2, "inv": [0.0, 1.2]},
	"horizontal": {"len": HZ_LEN, "speed": 3.0, "from": HZ_CHARGE, "to": HZ_HIT + 0.05},
	"stop": {"len": 0.7, "speed": 3.5, "from": 0.0, "to": 0.3},     # резкая остановка после спринта
	"land": {"len": 0.4},                                           # приземление после высокого падения
}
const DODGE_CD := 0.7
const HZ_CHARGE := 0.3        # «Горизонталь»: конец замаха
const HZ_HIT := 0.4           # момент удара
const HZ_LEN := 0.95
## Клипы Meshy для движений: действие → [клип, с какой секунды, темп]
const MESHY_MOVES := {
	"dodge_back": ["Stand_Dodge", 0.0, 2.0],
	"dodge_left": ["Quick_Step_and_Spin_Dodge", 0.0, 2.0],
	"dodge_right": ["Quick_Step_and_Spin_Dodge", 0.0, 2.0],
	"roll": ["Roll_Dodge", 0.0, 2.0],
	"switch": ["Sword_Parry_Backward", 0.0, 2.0],
	"hit_heavy": ["Hit_Reaction", 0.0, 2.0],
	"knockdown": ["Knock_Down", 0.0, 1.8],
	"getup": ["Rightward_Spin", 2.0, 2.9],   # перекат по земле и подъём в стойку
	"horizontal": ["Reaping_Swing", 2.6, 1.8],   # широкий взмах по дуге: удар клипа ≈3,3 с = HZ_HIT
	"stop": ["Sprint_and_Sudden_Stop", 0.6, 1.4],
	"land": ["Dive_Down_and_Land", 1.25, 0.9],
	"stun": ["Hit_Reaction", 0.0, 1.0],      # оглушение — та же реакция медленнее
}
const WALK_CLIP := "Walk_Fight_Forward"           # боевой шаг (Meshy)
const RUN_CLIP := "Kirito_Sword_Run"               # бег героя (из модели героя)
const WALK_STRIDE_M := 0.6     # шаг назад в блоке (Walk_Backward_with_Sword): м за секунду клипа
# Шаг → бег → спринт: клипы и длина шага (м за секунду клипа: опорная стопа уходит назад с этой
# скоростью; замер по стопе, tests/gait.tscn). Темп клипа = скорость героя / длина шага.
const WALK_PLAIN := "Walking"                       # обычный шаг
const SPRINT_CLIP := "RunFast"                      # быстрый бег: длинный шаг, долгая фаза полёта
const STRIDE_M := {"Walking": 1.61, "Walk_Fight_Forward": 1.14, "Kirito_Sword_Run": 5.37, "RunFast": 12.49,
	"Sword_Run": 3.0, "Walk_Backward_with_Sword": 0.6, "MS_strafe_left": 0.33, "MS_strafe_right": 0.33}
const SIDESTEP_SPEED := 1.0    # м/с: приставной шаг в блоке (клип Moveset — шаг 0,33 м за секунду клипа)
var _sidestep := 0             # в блоке идёт вбок: 1 — влево, −1 — вправо
const LOCO_WALK_TOP := 2.2     # м/с: до этой скорости — шаг
const FOOT_IK_MAX_SPEED := 2.6 # IK ног — стоя и на шаге; на бегу выключен
const LOCO_RUN_TOP := 7.5      # бег до этой скорости, дальше переходит в спринт
const LOCO_SPRINT := 10.0      # с этой скорости — спринт целиком
var _loco_clips := []          # клип в каждой точке смеси шаг/бег/спринт
var _loco_now := {}            # что сейчас стоит в точке

## Наклон корпуса: в поворот на бегу (внутрь дуги) и вперёд при разгоне, назад при торможении
const LEAN_TURN := 0.045      # рад на (рад/с поворота × м/с)
const LEAN_TURN_MAX := 0.22
const LEAN_ACCEL := 0.018     # рад на м/с²
const LEAN_ACCEL_MAX := 0.12
var _lean_prev_facing := 0.0
var _lean_prev_speed := 0.0
var _lean := Vector2.ZERO     # x — вперёд/назад, y — вбок

func _lean_update(dt: float, on_floor: bool) -> void:
	if _char == null or dt <= 0.0:
		return
	var turn := angle_difference(_lean_prev_facing, facing) / dt
	var accel := (_speed_now - _lean_prev_speed) / dt
	_lean_prev_facing = facing
	_lean_prev_speed = _speed_now
	var want := Vector2.ZERO
	if on_floor and not dead and _dash_t < 0.0 and _move == "" and _art_t < 0.0:
		want.y = clampf(-turn * _speed_now * LEAN_TURN, -LEAN_TURN_MAX, LEAN_TURN_MAX)
		want.x = clampf(accel * LEAN_ACCEL, -LEAN_ACCEL_MAX, LEAN_ACCEL_MAX)
	_lean = _lean.lerp(want, 1.0 - exp(-8.0 * dt))
	_char.rotation = Vector3(_lean.x, 0.0, _lean.y)

func _set_loco(i: int, clip: String) -> void:
	if _loco_now.get(i, "") != clip:
		_loco_now[i] = clip
		_ha.set_loco_anim(i, clip)

## Длина шага на этой скорости: по клипам точек смеси, между точками — плавно
func _stride_at(v: float) -> float:
	var pts := [[LOCO_WALK_FROM, 1], [LOCO_WALK_TOP, 2], [LOCO_FAST_FULL, 3], [LOCO_RUN_TOP, 4], [LOCO_SPRINT, 5]]
	var st := func(i: int) -> float: return float(STRIDE_M.get(_loco_now.get(i, _loco_clips[i]), 1.0))
	if v <= pts[0][0]:
		return st.call(1)
	for k in range(1, pts.size()):
		if v <= pts[k][0]:
			var t: float = (v - pts[k - 1][0]) / (pts[k][0] - pts[k - 1][0])
			return lerpf(st.call(pts[k - 1][1]), st.call(pts[k][1]), t)
	return st.call(5)
const BACKSTEP_CLIP := "Walk_Backward_with_Sword"   # шаг назад с мечом — в блоке
const STOP_FROM := 8.5         # с какой скорости бега отпущенный джойстик — резкая остановка
const LAND_FALL := 3.5         # с какой высоты падения — тяжёлое приземление
const WHIRL_CLIP := ["Sword_Spin_360", 0.0, 0.92 / WHIRL_TIME]   # [клип, с какой секунды, темп] — весь оборот за время вихря
const JUMP_CLIP := ["Basic_Jump", 1.45, 1.1]
# Ключевые позы прыжка в Basic_Jump (секунды клипа, замер по стопам и тазу — tools/gait):
# присед 1,38–1,60 · отрыв 1,72 · верхняя точка 2,02 · касание 2,38 · амортизация до 3,40
const JUMP_TAKEOFF := 1.70
const JUMP_APEX := 2.02
const JUMP_TOUCH := 2.38
const JUMP_RECOVER := 3.10
const JUMP_LAND_RATE := 2.4     # амортизация 2,38→3,10 за ~0,3 с
# Высота нижней стопы в клипе (ед. модели) — клип сам «подлетает»; это вычитается, полёт ведёт физика
const JUMP_TOE := [[1.70, 0.01], [1.75, 0.19], [1.80, 0.53], [1.85, 0.90], [1.90, 1.21], [1.95, 1.49], [2.00, 1.73],
	[2.05, 1.75], [2.10, 1.61], [2.15, 1.30], [2.20, 1.01], [2.25, 0.72], [2.30, 0.42], [2.35, 0.11], [2.40, 0.03]]
var _land_t := -1.0            # время с касания земли после прыжка (−1 — не приземляется)
var _jump_t := 0.0             # текущая секунда клипа прыжка

## Секунда клипа прыжка по фазе полёта (скорость по вертикали)
func _jump_clip_t() -> float:
	var vy := velocity.y
	if vy > 0.0:
		_jump_t = lerpf(JUMP_TAKEOFF, JUMP_APEX, clampf(1.0 - vy / JUMP, 0.0, 1.0))
	else:
		_jump_t = lerpf(JUMP_APEX, JUMP_TOUCH - 0.05, clampf(-vy / JUMP, 0.0, 1.0))
	return _jump_t

## На сколько клип прыжка поднял ноги (м) — модель опускается на это, чтобы стопы были там, где герой
func _jump_lift(t: float) -> float:
	if t <= JUMP_TOE[0][0] or t >= JUMP_TOE[-1][0]:
		return 0.0
	for i in range(1, JUMP_TOE.size()):
		if t <= JUMP_TOE[i][0]:
			var a: Array = JUMP_TOE[i - 1]
			var b: Array = JUMP_TOE[i]
			return lerpf(a[1], b[1], (t - a[0]) / (b[0] - a[0])) * CHAR_SCALE
	return 0.0
const RUN_FIGHT := "Sword_Run"                      # бег, когда рядом враги — присланный клип
const RUN_FIGHT_STRIDE := 3.0
const FIGHT_NEAR := 12.0
## Комбо из трёх ударов: [клип, момент удара в клипе (с)]
## (два удара — отрезки серии Double_Combo_Attack, третий — сильный удар из Attack; tools/rig_from_mannequin.py)
const ATTACK_CLIPS := [["Double_Combo_Attack", 0.63], ["Double_Combo_Attack", 1.17], ["Attack", 1.07]]
const ATTACK_SEG := 0.8        # сколько секунд клипа занимает один удар героя
## Приёмы меча: тип оружия → [клип, момент (первого) удара, темп]
const ART_CLIPS := {"sword": ["Thrust_Slash", 0.73, 1.0], "great": ["Charged_Slash", 1.2, 1.0], "rapier": ["Triple_Combo_Attack", 0.77, 2.4], "dagger": ["Weapon_Combo_2", 1.3, 1.6]}
const BLOCK_CLIP := ["Block10", 0.35]
const REACTIONS := ["hit_heavy", "stun", "knockdown", "getup"]
var _move := ""
var _move_t := 0.0
var _move_dir := Vector3.ZERO
var _move_new := false
var _move_hit := false

## Остановку и приземление можно прервать ударом, уклонением или приёмом
func _cancel_soft_move() -> void:
	if _move in ["stop", "land"]:
		_move = ""

func _start_move(name: String, dir: Vector3) -> void:
	attack_t = -1.0
	_combo_queued = false
	_move = name
	_move_t = 0.0
	_move_dir = dir
	_move_new = true
	_move_hit = false

## Уклонение: куда наклонён джойстик относительно взгляда — назад, вбок или кувырок вперёд;
## без наклона — отскок назад. Короткая неуязвимость.
func dodge() -> void:
	_cancel_soft_move()
	if dead or busy or _dash_t >= 0.0 or _spin_t >= 0.0 or _art_t >= 0.0 or cd["dodge"] > 0.0:
		return
	if _move != "" and not _move.begins_with("dodge") and _move != "roll":
		return
	var fwd := Vector3(sin(facing), 0, cos(facing))
	var left := Vector3(cos(facing), 0, -sin(facing))
	var mv: Vector2 = touch.move if touch else Vector2.ZERO
	var name := "dodge_back"
	var dir := -fwd
	if mv.length() > 0.3 and rig:
		var yaw: float = rig.yaw
		var w := (Vector3(-sin(yaw), 0, -cos(yaw)) * mv.y + Vector3(cos(yaw), 0, -sin(yaw)) * mv.x).normalized()
		var lz := w.dot(fwd)
		var lx := w.dot(left)
		if absf(lx) > absf(lz):
			name = "dodge_left" if lx > 0.0 else "dodge_right"
			dir = left if lx > 0.0 else -left
		elif lz > 0.0:
			name = "roll"
			dir = fwd
	cd["dodge"] = DODGE_CD
	_start_move(name, dir)

func _update_move(dt: float) -> Vector3:
	_move_t += dt
	var m: Dictionary = MOVES[_move]
	if m.has("inv") and _move_t >= m["inv"][0] and _move_t <= m["inv"][1]:
		_invuln = maxf(_invuln, 0.05)
	var hv := Vector3.ZERO
	if m.has("speed") and _move_t >= m["from"] and _move_t < m["to"]:
		hv = _move_dir * m["speed"]
	if _move == "horizontal":
		if _hand_bone >= 0 and _ha and _ha._names.get("horizontal", "") == MESHY_MOVES["horizontal"][0]:
			# Урон тому, мимо кого прошёл клинок (по руке с мечом в анимации), а не всем разом
			if _move_t >= HZ_SWEEP[0] and _move_t <= HZ_SWEEP[1]:
				if not _move_hit:
					_move_hit = true
					_sweep_begin()
					if ATTACK_RINGS:
						Fx.ring(global_position + Vector3(0, 1.0, 0), SkillDefs.ART_COLOR["sword"], 3.5, 0.3)
				_sweep(_blade_reach(), _horizontal_one)
		elif not _move_hit and _move_t >= HZ_HIT:
			_move_hit = true
			_horizontal_hit()
	if _move_t >= m["len"]:
		if _move == "horizontal":
			_set_blade_glow(Color(0, 0, 0, 0))
			update_look()
		var nxt: String = m.get("next", "")
		_move = ""
		if nxt != "":
			_start_move(nxt, Vector3.ZERO)
	return hv

## «Горизонталь»: широкий взмах — урон всем впереди в полукруге, отбрасывает вбок
const HZ_ARC := 1.45          # ±83° от взгляда
func horizontal_mult(r: int) -> float:
	return 1.6 + 0.2 * (maxi(1, r) - 1)

func _horizontal_hit() -> void:
	var r := Game.rank("horizontal")
	var reach: float = 3.4 * _wt()["reach"]
	var left := Vector3(cos(facing), 0, -sin(facing))
	var hits := 0
	for e in enemies.alive_near(global_position, reach + 1.5):
		var v := _flat(e.global_position - global_position)
		var d := maxf(0.01, v.length())
		if d > reach + e.T["r"] or absf(e.global_position.y - global_position.y) > 2.5:
			continue
		if absf(angle_difference(facing, atan2(v.x, v.z))) > HZ_ARC and d > e.T["r"] + 0.7:
			continue
		_deal(e, horizontal_mult(r) * _wt()["dmg"], (v / d + left * 0.8).normalized())
		Game.wear_weapon()
		hits += 1
	if ATTACK_RINGS:
			Fx.ring(global_position + Vector3(0, 1.0, 0), SkillDefs.ART_COLOR["sword"], 3.5, 0.3)
	if hits > 0:
		_finisher_fx()

## Один враг под «Горизонталью»
func _horizontal_one(e: Node3D, v: Vector3, d: float) -> void:
	# «Горизонталь» — полукруг впереди: за спиной клинок уже на доводке и не режет
	if absf(angle_difference(facing, atan2(v.x, v.z))) > HZ_ARC:
		_sweep_hits.erase(e.get_instance_id())
		return
	var left := Vector3(cos(facing), 0, -sin(facing))
	_deal(e, horizontal_mult(Game.rank("horizontal")) * _wt()["dmg"], (v / d + left * 0.8).normalized())
	Game.wear_weapon()
	if _sweep_hits.size() == 1:
		_finisher_fx()

## Один враг под вихрем
func _whirl_one(e: Node3D, v: Vector3, d: float) -> void:
	_deal(e, 1.2 + 0.3 * (Game.rank("whirl") - 1), v / d)
	e.knock(1.5)

# ---------- Ключевые позы приёмов (секунды клипа по времени приёма) и удар по ходу клинка
# Замер клипов: рука с мечом и поворот корпуса (tests: tools/gait). Reaping_Swing: рука у бока 2,80 ·
# замах 3,05 · удар (кисть 7 м/с) 3,28 · доводка 3,70. Sword_Spin_360: начало оборота 0,15 · 180° 0,44 ·
# 360° 0,75. Block10: подъём меча 0 → стойка 0,35.
const HZ_KEYS := [[0.0, 2.80], [HZ_CHARGE, 3.05], [HZ_HIT, 3.28], [HZ_LEN, 3.70]]
const HZ_SWEEP := [0.27, 0.50]           # время приёма, когда клинок режет
const WHIRL_KEYS := [[0.0, 0.10], [0.6, 0.75], [WHIRL_TIME, 0.88]]
const WHIRL_SWEEP := [0.03, 0.62]
const BLOCK_FROM := 0.0
const BLOCK_RAISE := 0.15                # меч в защиту — за столько секунд
const BLOCK_LOWER := 0.12
var _unblock_t := -1.0
var _hand_bone := -1
var _sweep_prev := INF
var _sweep_hits := {}

## Докуда достаёт клинок от центра героя: рука (~0,6 м) + длина клинка оружия + запас
func _blade_reach() -> float:
	return 0.6 + TRAIL_LEN * _wt()["reach"] + 0.3

func _key_t(keys: Array, t: float) -> float:
	if t <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			return lerpf(keys[i - 1][1], keys[i][1], (t - keys[i - 1][0]) / (keys[i][0] - keys[i - 1][0]))
	return keys[-1][1]

## Направление руки с мечом от героя (рад, по миру)
func _hand_angle() -> float:
	var hp: Vector3 = _sk.global_transform * _sk.get_bone_global_pose(_hand_bone).origin
	return atan2(hp.x - global_position.x, hp.z - global_position.z)

func _sweep_begin() -> void:
	_sweep_prev = INF
	_sweep_hits = {}

## Клинок прошёл от прошлого направления руки до нынешнего — урон врагам в этом секторе (один раз каждому)
func _sweep(radius: float, on_hit: Callable) -> void:
	var a := _hand_angle()
	if _sweep_prev == INF:
		_sweep_prev = a
		return
	var da := angle_difference(_sweep_prev, a)
	for e in enemies.alive_near(global_position, radius + 1.5):
		if _sweep_hits.has(e.get_instance_id()):
			continue
		var v := _flat(e.global_position - global_position)
		var d := maxf(0.01, v.length())
		if d > radius + e.T["r"] or absf(e.global_position.y - global_position.y) > 2.5:
			continue
		var rel := angle_difference(_sweep_prev, atan2(v.x, v.z))
		var inside := (rel >= -0.08 and rel <= da + 0.08) if da >= 0.0 else (rel <= 0.08 and rel >= da - 0.08)
		if inside or d < e.T["r"] + 0.3:
			_sweep_hits[e.get_instance_id()] = true
			on_hit.call(e, v, d)
	_sweep_prev = a

## Последний удар серии: тряска камеры
func _finisher_fx() -> void:
	if rig and rig.has_method("shake"):
		rig.shake(0.09, 0.25)

func attack() -> void:
	_cancel_soft_move()
	if _spin_t >= 0.0 or _dash_t >= 0.0 or dead or busy or blocking or _art_t >= 0.0 or _move != "":
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
const BLOCK_POSE := 0.7
const PARRY_WINDOW := 0.25    # блок, поднятый не раньше чем за 0,25 с до удара, — отбитие
const PARRY_STUN := 1.2
var _block_start := -99.0      # кадр удара, где меч поднят перед собой — стойка блока
var blocking := false
var _backstep := false      # в блоке идёт назад — ноги шагают назад
var _fall_top := -INF       # самая высокая точка в полёте (для тяжёлого приземления)

func block_reduce() -> float:
	return minf(0.9, BLOCK_REDUCE + Game.block_bonus())

## Приёмы меча: стойка со свечением клинка → приём → заминка (герой беззащитен)
const ART_CHARGE := 0.3
const ART_RECOVER := 0.5
# «Резкий выпад» быстрее: стойка короче, рывок и клип удара быстрее, заминка меньше
const LUNGE_CHARGE := 0.16
const LUNGE_RECOVER := 0.3
const LUNGE_DASH := 0.17       # рывок вперёд (было 0,25 с) — та же длина, быстрее
const LUNGE_CLIP_SPEED := 1.6  # клип Thrust_Slash быстрее (было 1,0)

func _art_charge() -> float:
	return LUNGE_CHARGE if _art == "sword" else ART_CHARGE

func _art_recover() -> float:
	return LUNGE_RECOVER if _art == "sword" else ART_RECOVER
var _art_t := -1.0
var _art := ""            # тип оружия приёма: sword / great / rapier / dagger
var _art_hits := 0
var _art_hit: Array = []
var _art_dir := Vector3.FORWARD

func art_id() -> String:
	return "art_" + Items.ALL[Game.equip["weapon"]["id"]].get("wt", "sword") if Game.equip["weapon"] != null else ""

func use_art() -> void:
	_cancel_soft_move()
	var id := art_id()
	if id == "" or Game.rank(id) == 0 or cd.get("art", 0.0) > 0.0 or dead or busy or _art_t >= 0.0 or _dash_t >= 0.0 or _spin_t >= 0.0:
		return
	attack_t = -1.0
	_art = id.substr(4)
	_art_t = 0.0
	_art_hits = 0
	_art_hit = []
	cd["art"] = SkillDefs.art_cd(Game.rank(id))
	var best := _nearest_enemy(6.0)
	if best:
		var v := _flat(best.global_position - global_position)
		facing = atan2(v.x, v.z)
	_art_dir = Vector3(sin(facing), 0, cos(facing))
	_new_swing = true
	_set_blade_glow(SkillDefs.ART_COLOR[_art])

func _art_action_end() -> float:
	return _art_charge() + {"sword": LUNGE_DASH, "great": 0.3, "rapier": 0.6, "dagger": 0.15}[_art]

func _nearest_enemy(r: float) -> Node3D:
	var best: Node3D = null
	var bd := r
	for e in enemies.alive_near(global_position, r):
		var d := _flat(e.global_position - global_position).length()
		if d < bd:
			bd = d
			best = e
	return best

func _art_update(dt: float) -> Vector3:
	var hv := Vector3.ZERO
	_art_t += dt
	var r := Game.rank("art_" + _art)
	var t := _art_t - _art_charge()
	if t >= 0.0:
		match _art:
			"sword":   # рывок вперёд, урон всем на пути
				if t < LUNGE_DASH:
					hv = _art_dir * 20.0 * 0.25 / LUNGE_DASH
					_invuln = maxf(_invuln, 0.05)
					for e in enemies.alive_near(global_position, 2.4):
						if not _art_hit.has(e):
							_art_hit.append(e)
							_deal(e, SkillDefs.art_mult(2.2, r), _art_dir)
			"great":   # удар сверху по площади, оглушение
				if t >= 0.15 and _art_hits == 0:
					_art_hits = 1
					var c := global_position + _art_dir * 1.6
					if ATTACK_RINGS:
							Fx.ring(c + Vector3(0, 0.1, 0), SkillDefs.ART_COLOR["great"], 2.6, 0.4)
					for e in enemies.alive_near(c, 3.2):
						_deal(e, SkillDefs.art_mult(2.8, r), _flat(e.global_position - global_position).normalized())
						if not e.dead:
							e.stun(1.0)
			"rapier":  # пять уколов
				var n := mini(5, int(t / 0.12) + 1)
				while _art_hits < n:
					_art_hits += 1
					var e := _nearest_enemy(2.8 * _wt()["reach"])
					if e:
						_deal(e, SkillDefs.art_mult(0.75, r), Vector3.ZERO)   # уколы не отбрасывают — все пять попадают
			"dagger":  # за спину ближайшего врага и крит
				if _art_hits == 0:
					_art_hits = 1
					var e := _nearest_enemy(6.0)
					if e:
						var back: Vector3 = Vector3(sin(e.facing), 0, cos(e.facing))
						global_position = Vector3(e.global_position.x, global_position.y, e.global_position.z) - back * 1.2
						facing = atan2(back.x, back.z)
						if ATTACK_RINGS:
								Fx.ring(global_position + Vector3(0, 0.1, 0), SkillDefs.ART_COLOR["dagger"], 1.5, 0.3)
						var dmg := roundi((Game.dmg + randf() * 8.0) * SkillDefs.art_mult(3.0, r))
						e.hit(dmg, back, true)
	if _art_t >= _art_action_end() + _art_recover():
		_art_t = -1.0
		_set_blade_glow(Color(0, 0, 0, 0))
		update_look()
	return hv

## Свечение клинка (приём меча); прозрачный цвет — выключить
func _set_blade_glow(c: Color) -> void:
	if not BLADE_GLOW:
		return
	for k in _blades:
		var g: StandardMaterial3D = _blades[k]["glow"]
		if c.a > 0.0 and (_blades[k]["node"] as Node3D).visible:
			g.emission_enabled = true
			g.emission = c
			g.emission_energy_multiplier = 2.5
			(_blades[k]["mesh"] as MeshInstance3D).material_override = g

## Комбо из трёх ударов: третий — выпад вперёд, сильнее и отбрасывает
const COMBO_WINDOW := 0.5     # сколько ждать следующего нажатия после удара, с
const COMBO_MULT := [1.0, 1.1, 1.6]
var combo := 0                # номер удара в комбо: 0, 1, 2
var _combo_queued := false
var _since_swing := 99.0

func _start_swing() -> void:
	attack_t = 0.0
	_attack_hit = false
	_swing_hits = {}
	_blade_prev = []
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

## Тип надетого оружия (скорость, урон, дальность, крит)
func _wt() -> Dictionary:
	return Items.wtype_of(Game.equip["weapon"])

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

## Урон по касанию: весь взмах клинок проверяется на столкновение с монстрами — кого задел,
## тому сразу урон (каждому один раз за удар). Между кадрами клинок «протягивается»
## промежуточными положениями, чтобы быстрый взмах не проскакивал сквозь врага.
const BLADE_FROM := 0.06      # доля взмаха, с которой клинок уже бьёт
const BLADE_TO := 0.46
var _swing_hits := {}
var _blade_prev := []         # [основание, кончик] клинка в прошлом кадре

func _blade_sweep(t: float) -> void:
	if t < BLADE_FROM or t > BLADE_TO:
		_blade_prev = []
		return
	if _sword == null or not _sword.is_visible_in_tree():
		if not _attack_hit and t >= 0.2:   # без видимого меча — прежний удар по сектору
			_attack_hit = true
			_sword_hit()
		return
	var g := _sword.global_transform
	var up := g.basis.y.normalized()
	var reach: float = _wt()["reach"]
	var a := g.origin + up * 0.1
	var b := g.origin + up * (TRAIL_LEN * reach + 0.15)
	var segs := [[a, b]]
	if _blade_prev.size() == 2:
		for k in [0.33, 0.66]:
			segs.append([(_blade_prev[0] as Vector3).lerp(a, k), (_blade_prev[1] as Vector3).lerp(b, k)])
	_blade_prev = [a, b]
	var finisher := combo == 2
	var wt := _wt()
	for e in enemies.alive_near(global_position, 6.0):
		if _swing_hits.has(e.get_instance_id()):
			continue
		var sc: float = float(e.T.get("scale", 1.0))
		var er: float = float(e.T.get("r", 0.5)) * sc + 0.3
		var lo: Vector3 = e.global_position + Vector3(0, 0.2, 0)
		var hi: Vector3 = e.global_position + Vector3(0, maxf(0.6, float(e.T.get("bar", 2.0)) * 0.9), 0)
		var touched := false
		for sg in segs:
			var cp := Geometry3D.get_closest_points_between_segments(sg[0], sg[1], lo, hi)
			if cp[0].distance_to(cp[1]) < er:
				touched = true
				break
		if not touched:
			continue
		_swing_hits[e.get_instance_id()] = true
		var v := _flat(e.global_position - global_position)
		var d := maxf(0.01, v.length())
		_deal(e, COMBO_MULT[combo] * wt["dmg"], v / d)
		Game.wear_weapon()
		_finisher_landed = true
		if finisher:
			e.knock(2.2)   # третий удар отбрасывает далеко

## Конец третьего удара: кольцо и эффект добивания, если попал
func _finisher_end() -> void:
	if ATTACK_RINGS:
		Fx.ring(global_position + Vector3(sin(facing), 0.1, cos(facing)) * 1.4, Color("#ffd479"), 2.0, 0.35)
	if _finisher_landed:
		_finisher_fx()
	_finisher_landed = false

func _sword_hit() -> void:
	var finisher := combo == 2
	var wt := _wt()
	var reach: float = (2.9 if finisher else 2.3) * wt["reach"]
	for e in enemies.alive_near(global_position, 4.5):
		var v := _flat(e.global_position - global_position)
		var d := maxf(0.01, v.length())
		if d > reach + e.T["r"] or absf(e.global_position.y - global_position.y) > 2.5:
			continue
		if absf(angle_difference(facing, atan2(v.x, v.z))) > (1.6 if finisher else 1.25) and d > e.T["r"] + 0.7:
			continue
		_deal(e, COMBO_MULT[combo] * wt["dmg"], v / d)
		Game.wear_weapon()
		_finisher_landed = true
		if finisher:
			e.knock(2.2)   # третий удар отбрасывает далеко
	# Кольцо и эффект добивания — в _finisher_end() в конце взмаха

var _finisher_landed := false

## Урон с учётом навыков «Критический удар» и «Вампиризм»
func _deal(e: Node3D, mult: float, dir: Vector3) -> void:
	var dmg := roundi((Game.dmg + randf() * 8.0) * mult)
	var crit: bool = randf() < Game.rank("crit") * 0.08 + Game.crit_bonus + _wt()["crit"] + Game.stats["agi"] * Game.STAT_AGI_CRIT
	if crit:
		dmg *= 2
	e.hit(dmg, dir, crit)
	# Искры, вспышка, короткая остановка кадра и тряска — в точке удара (на стороне героя)
	var r: float = e.T.get("r", 0.5) * float(e.T.get("scale", 1.0))
	var at: Vector3 = e.global_position + Vector3(0, clampf(float(e.T.get("bar", 2.0)) * 0.42, 0.5, 2.2), 0) - dir.normalized() * r * 0.7
	Fx.impact(at, dir, crit, e.dead, rig)
	var vamp := Game.rank("vamp") * 0.04
	if vamp > 0.0 and not dead:
		Game.hp = minf(Game.max_hp, Game.hp + dmg * vamp)

func use_skill(id: String) -> void:
	_cancel_soft_move()
	if id == "art":
		use_art()
		return
	if id == "dodge":
		dodge()
		return
	if id == "horizontal":
		use_horizontal()
		return
	var r := Game.rank(id)
	if r == 0 or cd[id] > 0.0 or dead or busy or _spin_t >= 0.0 or _dash_t >= 0.0:
		return
	attack_t = -1.0
	_new_swing = true
	if id == "whirl":
		_spin_t = 0.0
		if combat:
			combat.attack_whirlwind()
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
		_dash_from = global_position
		_streak_start()
		_dash_speed = SkillDefs.dash_stats(Game.skills)["speed"]
		cd["dash"] = SkillDefs.dash_stats(Game.skills)["cd"]
		# Аниме-рывок: герой исчезает со вспышкой там, где стоял (с места или на бегу)
		if ATTACK_RINGS:
			Fx.ring(global_position + Vector3(0, 0.1, 0), _dash_color(), 2.0, 0.4, true)

## След рывка (как у Кирито на видео): размытая полоса от места старта до героя — тёмно-синяя,
## со штрихами скорости цвета рывка, к хвосту прозрачнее. Полоса всегда повёрнута к камере
## (видна и сбоку, и из-за спины), после появления героя гаснет за 0,35 с.
const STREAK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;
uniform vec3 a;
uniform vec3 b;
uniform float width = 1.4;
uniform float fade = 1.0;
uniform sampler2D tex : filter_linear, repeat_disable;
void vertex() {
	vec3 axis = b - a;
	vec3 mid = (a + b) * 0.5;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 dir = length(axis) > 0.001 ? normalize(axis) : vec3(1.0, 0.0, 0.0);
	vec3 side = cross(dir, normalize(cam - mid));
	side = length(side) > 0.001 ? normalize(side) : vec3(0.0, 1.0, 0.0);
	vec3 p = mid + axis * VERTEX.x + side * VERTEX.y * width;
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
}
void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a * fade;
}
"""
static var _streak_sh: Shader

func _streak_tex(col: Color) -> ImageTexture:
	var w := 128
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rows := PackedFloat32Array()
	var r := RandomNumberGenerator.new()
	for y in h:
		rows.append(r.randf())
	var navy := Color(0.05, 0.07, 0.18)
	for y in h:
		var v := (y + 0.5) / h * 2.0 - 1.0
		var prof := pow(maxf(0.0, 1.0 - v * v), 1.5)
		# штрихи скорости: соседние строки сглажены, яркие — цвета рывка
		var st := (rows[y] + rows[(y + 1) % h] + rows[(y + h - 1) % h]) / 3.0
		for x in w:
			var u := (x + 0.5) / w           # 0 — у героя, 1 — хвост
			var tail := pow(1.0 - u, 0.9) * smoothstep(0.0, 0.05, u)
			var line := smoothstep(0.6, 0.9, st) * (1.0 - u * 0.5)
			var c := navy.lerp(col, line * 0.5)
			c.a = clampf(pow(prof, 0.7) * tail * (0.7 + 0.3 * st) * 1.1, 0.0, 0.95)
			img.set_pixel(x, h - 1 - y, c)
	return ImageTexture.create_from_image(img)

func _streak_start() -> void:
	_streak_end()
	if _streak_sh == null:
		_streak_sh = Shader.new()
		_streak_sh.code = STREAK_SHADER
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.flip_faces = false
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _streak_sh
	mat.set_shader_parameter("tex", _streak_tex(_dash_color()))
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.extra_cull_margin = 16384.0
	get_parent().add_child(m)
	_dash_streak = m
	_streak_update()

func _streak_update() -> void:
	if _dash_streak == null or not is_instance_valid(_dash_streak):
		return
	var up := Vector3(0, 0.85, 0)
	var mat: ShaderMaterial = _dash_streak.material_override
	# a — у героя (u = 0), b — место старта (хвост)
	mat.set_shader_parameter("a", global_position + up)
	mat.set_shader_parameter("b", _dash_from + up)

func _streak_end() -> void:
	if _dash_streak == null or not is_instance_valid(_dash_streak):
		_dash_streak = null
		return
	_streak_update()
	var m := _dash_streak
	_dash_streak = null
	var mat: ShaderMaterial = m.material_override
	var tw := m.create_tween()
	tw.tween_method(func(f: float): mat.set_shader_parameter("fade", f), 1.0, 0.0, 0.35)
	tw.tween_callback(m.queue_free)

## Цвет вспышек рывка: обычный — голубой, скользящий шаг — белый, прорыв — фиолетовый
func _dash_color() -> Color:
	match SkillDefs.dash_form(Game.skills):
		"blink": return Color("#b9a8ff")
		"slide": return Color("#e8f4ff")
	return Color("#8fd8ff")

func use_horizontal() -> void:
	var r := Game.rank("horizontal")
	if r == 0 or cd["horizontal"] > 0.0 or dead or busy or _move != "" or _spin_t >= 0.0 or _dash_t >= 0.0 or _art_t >= 0.0:
		return
	var best := _nearest_enemy(6.0)
	if best:
		var v := _flat(best.global_position - global_position)
		facing = atan2(v.x, v.z)
	cd["horizontal"] = SkillDefs.horizontal_cd(r)
	_start_move("horizontal", Vector3(sin(facing), 0, cos(facing)))
	if combat:
		combat.attack_horizontal()
	_set_blade_glow(SkillDefs.ART_COLOR["sword"])

func cooldown_total(id: String) -> float:
	if id == "art":
		return SkillDefs.art_cd(Game.rank(art_id()))
	if id == "dodge":
		return DODGE_CD
	if id == "horizontal":
		return SkillDefs.horizontal_cd(maxi(1, Game.rank("horizontal")))
	var r := maxi(1, Game.rank(id))
	return SkillDefs.whirl_cd(r) if id == "whirl" else SkillDefs.dash_stats(Game.skills)["cd"]

func _whirl_hit() -> void:
	var mult := 1.2 + 0.3 * (Game.rank("whirl") - 1)
	if ATTACK_RINGS:
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

## kind: "slam" — удар о землю (сбивает с ног)
func take_damage(raw: int, from: Vector3, attacker: Node3D = null, kind := "") -> void:
	if _invuln > 0.0 or dead or busy:
		return
	# Отбитие: блок поднят в последний момент — урона нет, враг оглушён и уязвим
	var fv := _flat(from - global_position)
	if blocking and _time - _block_start < PARRY_WINDOW and fv.length() > 0.01 and absf(angle_difference(facing, atan2(fv.x, fv.z))) < BLOCK_ARC:
		_invuln = 0.3
		Fx.text("Отбито!", global_position, Color("#ffe060"), true)
		if ATTACK_RINGS:
			Fx.ring(global_position + Vector3(sin(facing), 1.0, cos(facing)) * 0.6, Color("#ffe060"), 1.4, 0.3)
		if attacker and attacker.has_method("stun"):
			attacker.stun(PARRY_STUN, true)
		# «Переключение»: отскок назад, пока враг оглушён
		Fx.text("Switch!", global_position + Vector3(0, 0.4, 0), Color("#9fe4ff"), true)
		_start_move("switch", -Vector3(sin(facing), 0, cos(facing)))
		return
	if _art_t >= 0.0 and _art_t > _art_action_end():
		raw = roundi(raw * 1.2)   # заминка после приёма — герой беззащитен
	# ночью монстры бьют сильнее; адаптивная сложность Cardinal — ±25% урона
	var dmg := Game.reduce_damage(roundi(raw * DayNight.monster_mult() * CardinalDirector.damage_mult()))
	var v := _flat(from - global_position)
	var blocked := blocking and v.length() > 0.01 and absf(angle_difference(facing, atan2(v.x, v.z))) < BLOCK_ARC
	if blocked:
		dmg = maxi(1, roundi(dmg * (1.0 - block_reduce())))
		if combat:
			combat.receive_block_hit()
	Game.hp = maxf(0.0, Game.hp - dmg)
	_invuln = 0.5
	_hurt_ago = 0.0
	_push = _flat(global_position - from).normalized() * (3.0 if blocked else 10.0)
	if blocked:
		Fx.text("Блок −%d" % dmg, global_position, Color("#cfe0ff"))
		if ATTACK_RINGS:
			Fx.ring(global_position + Vector3(sin(facing), 1.0, cos(facing)) * 0.6, Color("#cfe0ff"), 0.8, 0.25)
	else:
		Fx.text("−%d" % dmg, global_position, Color("#ff6a5a"))
	Input.vibrate_handheld(60)
	_react(dmg, blocked, from, attacker, kind)
	hurt.emit(dmg)
	if Game.hp <= 0.0:
		dead = true
		_dead_t = 0.0
		# Тело падает по физике в сторону удара
		if _sk and _ragdoll.start(_sk, _flat(global_position - from).normalized() * 2.5 + Vector3.UP * 1.5):
			if _ha:
				_ha.tree.active = false
		attack_t = -1.0
		_spin_t = -1.0
		_dash_t = -1.0
		_model.visible = true
		_streak_end()
		died.emit()

# ---------- След клинка: светится в ударе, вихре, приёмах и «Горизонтали»
const TRAIL_LEN := 1.0        # длина клинка до кончика (м), у двуручника длиннее
const SHOW_TRAIL := false
const ATTACK_RINGS := false   # все кольца-вспышки героя (удары, приёмы, рывок, блок) — выключены
const BLADE_GLOW := false     # свечение клинка во время приёмов — выключено   # белый след взмаха меча — пока выключен

func _update_trail(dt: float) -> void:
	if not SHOW_TRAIL:
		if _trail:
			_trail.emitting = false
			_trail.visible = false
		return
	if _trail == null or _sword == null:
		return
	var swing := attack_t >= 0.06 and attack_t <= 0.36
	var c := Color(0.85, 0.95, 1.0, 0.65)
	if _move == "horizontal":
		swing = _move_t >= HZ_CHARGE - 0.02 and _move_t <= 0.62
		c = SkillDefs.ART_COLOR["sword"]
		c.a = 0.9
	elif _spin_t >= 0.0:
		swing = true
	elif _art_t >= _art_charge() and _art_t < _art_action_end():
		swing = true
		c = SkillDefs.ART_COLOR[_art]
		c.a = 0.85
	_trail.emitting = swing and _sword.is_visible_in_tree()
	_trail.color = c
	var reach: float = _wt()["reach"]
	var g := _sword.global_transform
	_trail.feed(g.origin + g.basis.y.normalized() * 0.15, g.origin + g.basis.y.normalized() * TRAIL_LEN * reach, dt)

# ---------- Реакция на удар: корпус отшатывается от удара и пружиной возвращается

## Реакция на удар: сбит с ног (удар о землю), оглушён (босс пробил блок), отброшен (сильный удар)
func _react(dmg: int, blocked: bool, from: Vector3, attacker: Node3D, kind: String) -> void:
	if Game.hp <= 0.0 or _art_t >= 0.0 or _move == "horizontal" or _move in ["knockdown", "getup"]:
		return   # во время приёма — «броня», лёжа — не реагирует
	var away := _flat(global_position - from).normalized()
	var boss: bool = attacker != null and attacker.T.get("boss", false)
	if kind == "slam" and not blocked:
		facing = atan2(-away.x, -away.z)   # лицом к ударившему, падает на спину
		_start_move("knockdown", away)
		if rig and rig.has_method("shake"):
			rig.shake(0.14, 0.35)
	elif blocked and boss:
		_start_move("stun", Vector3.ZERO)   # босс пробил блок
		Fx.text("Блок пробит!", global_position, Color("#ffb070"))
	elif not blocked and dmg >= Game.max_hp * 0.15:
		facing = atan2(-away.x, -away.z)
		_start_move("hit_heavy", away)
		if rig and rig.has_method("shake"):
			rig.shake(0.07, 0.2)

func respawn(pos: Vector3) -> void:
	_move = ""
	dead = false
	_ragdoll.stop()
	if _ha:
		_ha.tree.active = true
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

## ANIMATE 3.1 (res://animate_3_1/): генератор поз по описанию и проверка клипов и скелета героя.
## Сигналы — в CARDINAL (issue_detected). Генератор клипы сам не создаёт: только по вызову.
var animate_gen: AnimatePoseGenerator
var animate_check: AnimateValidator

## Боевой модуль (addons/combat_pack): состояние блока и приёмов героя и их сигналы.
## Анимации героя остаются его клипами Meshy (дерево анимаций), модуль ведёт состояние.
var combat: AdventureCombatController

func _setup_combat_pack() -> void:
	combat = AdventureCombatController.new()
	combat.name = "CombatPack"
	combat.animation_player = _anim
	combat.play_hook = func(_n: String) -> void: pass
	add_child(combat)
	combat.attack_started.connect(func(n: String): Cardinal.issue_recovered.emit("COMBAT_" + n.to_upper()))

func _animate_31(sk: Skeleton3D) -> void:
	animate_gen = AnimatePoseGenerator.new()
	animate_gen.name = "AnimatePoseGenerator"
	animate_gen.skeleton = sk
	animate_gen.animation_player = _anim
	add_child(animate_gen)
	animate_check = AnimateValidator.new()
	animate_check.name = "AnimateValidator"
	animate_check.skeleton = sk
	animate_check.animation_player = _anim
	add_child(animate_check)
	animate_gen.warning.connect(func(m: String): Cardinal.issue_detected.emit("ANIMATE_WARNING", m))
	animate_check.issue_found.connect(func(code: String, d: Dictionary): Cardinal.issue_detected.emit("ANIMATE_" + code.to_upper(), str(d)))
	animate_check.validate_rig()

# ---------- Движение
## Hybrid Movement 3.0 (res://hybrid_movement/): плавный разгон и торможение героя от джойстика,
## в прыжке управление слабее. Значения — из модуля (acceleration, deceleration, air_control).
const HM_ACCEL := 15.0
const HM_DECEL := 19.0
const HM_AIR := 0.3
const REVERSE_FROM := 6.0      # м/с: быстрее — разворот через резкую остановку
var _hm_vel := Vector3.ZERO

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
		# Удар на всё тело (стоя или медленно): ноги стоят на месте — и герой не едет, иначе ступни
		# скользят по земле. На бегу удар берёт только верх тела, ноги бегут — тогда двигаемся.
		speed *= 0.45 if _ha and _ha._upper else 0.0
	var was_blocking := blocking
	blocking = touch != null and touch.block and not dead and not busy and attack_t < 0.0 and _spin_t < 0.0 and _dash_t < 0.0 and _art_t < 0.0 and _move == ""
	if blocking and not was_blocking:
		_block_start = _time
		_unblock_t = -1.0
		if combat:
			combat.start_block()
	elif was_blocking and not blocking:
		_unblock_t = 0.0
		if combat:
			combat.stop_block()
	if combat and blocking and _time - _block_start > 0.2:
		combat.hold_block()
	if _unblock_t >= 0.0:
		_unblock_t += dt
		if _unblock_t >= BLOCK_LOWER:
			_unblock_t = -1.0
	if blocking:
		speed *= 0.4
	var hv := Vector3.ZERO
	# Разворот на бегу: сначала резкая остановка (клип Meshy), потом бег в другую сторону —
	# без «проскальзывания», когда ноги уже бегут назад, а тело ещё едет вперёд
	if mag > 0.12 and _move == "" and attack_t < 0.0 and _art_t < 0.0 and _spin_t < 0.0 and _dash_t < 0.0 and is_on_floor() \
			and _hm_vel.length() > REVERSE_FROM and dir.normalized().dot(_hm_vel.normalized()) < -0.2 and _ha and _ha._names.has("stop"):
		_start_move("stop", _hm_vel.normalized())
	if mag > 0.12:
		dir = dir.normalized()
		# В блоке герой не разворачивается — смотрит на врага и отступает спиной вперёд
		if attack_t < 0.0 and _move == "" and not blocking:
			facing += angle_difference(facing, atan2(dir.x, dir.z)) * minf(1.0, dt * 12.0)
		# В блоке вбок — приставной шаг Moveset (MS_strafe_*): медленнее, в темп клипа
		var side := dir.dot(Vector3(cos(facing), 0, -sin(facing)))
		_sidestep = 0
		if blocking and absf(side) > 0.7 and _anim and _anim.has_animation("MS_strafe_left"):
			_sidestep = 1 if side > 0.0 else -1
			speed = minf(speed, SIDESTEP_SPEED)
		hv = dir * speed
		_speed_now = lerpf(_speed_now, speed, minf(1.0, dt * 10.0))
		_backstep = blocking and _sidestep == 0 and dir.dot(Vector3(sin(facing), 0, cos(facing))) < -0.3
	else:
		# Отпустил джойстик на спринте — резкая остановка (клип Meshy)
		if _speed_now > STOP_FROM and is_on_floor() and _move == "" and attack_t < 0.0 and _art_t < 0.0 \
				and _spin_t < 0.0 and _dash_t < 0.0 and not blocking and _ha and _ha._names.has("stop"):
			_start_move("stop", Vector3(sin(facing), 0, cos(facing)))
		_speed_now = lerpf(_speed_now, 0.0, minf(1.0, dt * 10.0))
		_backstep = false
	# Hybrid Movement 3.0: скорость от джойстика набирается и гасится плавно; удар на месте — стоп сразу
	if attack_t >= 0.0 and hv.length_squared() < 0.001:
		_hm_vel = Vector3.ZERO
	else:
		var hm_rate := HM_ACCEL if hv.length_squared() > 0.001 else HM_DECEL
		if not is_on_floor():
			hm_rate *= HM_AIR
		_hm_vel.x = move_toward(_hm_vel.x, hv.x, hm_rate * dt)
		_hm_vel.z = move_toward(_hm_vel.z, hv.z, hm_rate * dt)
	hv = _hm_vel
	var hv_stick := hv   # скорость от джойстика (без рывка, приёмов и уклонений)
	# Приём меча
	if _art_t >= 0.0:
		hv = _art_update(dt)
	# Уклонение, реакция или «Горизонталь» — своё движение вместо джойстика
	if _move != "":
		hv = _update_move(dt)
		_speed_now = lerpf(_speed_now, 0.0, minf(1.0, dt * 10.0))
	# Рывок: быстрое движение вперёд сквозь врагов, герой неуязвим
	if _dash_t >= 0.0:
		var was := _dash_t
		_dash_t += dt
		_invuln = maxf(_invuln, 0.1)
		var land := DASH_LAND if _ha and _ha._names.has("dash_land") else 0.0
		if _dash_t < DASH_TIME:
			# Аниме-рывок: герой исчезает, по пути — тёмный размытый след (как у Кирито на видео);
			# сквозь стены не проходит — движение физическое (move_and_slide)
			hv = _dash_dir * DASH_SPEED * _dash_speed
			_model.visible = _dash_t <= 0.03
			_streak_update()
		else:
			hv = Vector3.ZERO   # появился — стоит в приседе и поднимается в стойку
			_model.visible = true
			if was < DASH_TIME:
				_streak_end()
				if ATTACK_RINGS:
					Fx.ring(global_position + Vector3(0, 0.1, 0), _dash_color(), 2.5, 0.45, true)
			if _dash_t >= DASH_TIME + land:
				_dash_t = -1.0
	if _art_t >= 0.0 or _move != "" or _dash_t >= 0.0:
		# Скорость рывка и приёмов не переносится в обычный бег: после рывка (исчез — появился)
		# герой сразу бежит со своей обычной скоростью от джойстика; после остановки — разгон с места
		_hm_vel = Vector3.ZERO if _move == "stop" else hv_stick
	_update_cloth(dt)
	hv += _root_motion(dt)
	hv += _push
	_push *= exp(-dt * 7.0)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y -= GRAVITY * dt
	if is_on_floor() and touch and touch.jump and not swimming and not dead and not busy and _move == "":
		velocity.y = JUMP
	# Плавание: держимся у поверхности воды
	if not underground and global_position.y < WorldGen.WATER - 1.1:
		global_position.y = WorldGen.WATER - 1.1
		velocity.y = maxf(velocity.y, 0.0)
	var was_air := not is_on_floor()
	move_and_slide()
	if not is_on_floor():
		_fall_top = maxf(_fall_top, global_position.y)
	elif was_air:
		if _fall_top - global_position.y > LAND_FALL and _move == "" and not dead and _ha and _ha._names.has("land"):
			_start_move("land", Vector3.ZERO)
		elif _speed_now < 1.5 and _move == "" and attack_t < 0.0:
			_land_t = 0.0   # обычное приземление стоя — амортизация; на бегу — сразу бег
		_fall_top = -INF
	if _land_t >= 0.0:
		_land_t += dt
		if _land_t * JUMP_LAND_RATE >= JUMP_RECOVER - JUMP_TOUCH or _speed_now > 1.5 or not is_on_floor() or attack_t >= 0.0:
			_land_t = -1.0
	if _dash_t >= 0.0 and _dash_t < DASH_TIME:
		_dash_hits()
	if not in_world2:   # во втором мире свои стены по краям плато
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
		attack_t += dt * (1.0 + 0.1 * Game.rank("agility")) * ATTACK_SPEED * _wt()["speed"] * (1.0 + Game.stats["agi"] * Game.STAT_AGI_SPEED) * (0.85 if combo == 2 else 1.0)
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
		_blade_sweep(t)
		if t >= 0.48:
			if combo == 2:
				_finisher_end()
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
		if whirl_anim and _hand_bone >= 0 and _ha and _ha._names.get("whirl", "") == WHIRL_CLIP[0]:
			# Вихрь: удар каждому врагу в момент, когда клинок проходит его сторону
			if _spin_t >= WHIRL_SWEEP[0] and _spin_t <= WHIRL_SWEEP[1]:
				if not _spin_hit:
					_spin_hit = true
					_sweep_begin()
					if ATTACK_RINGS:
						Fx.ring(global_position + Vector3(0, 0.6, 0), Color("#bfefff"), 7.0, 0.4)
				_sweep(_blade_reach(), _whirl_one)
		elif not _spin_hit and _spin_t >= (WHIRL_HIT if whirl_anim else 0.2):
			_spin_hit = true
			_whirl_hit()
		if _spin_t >= total:
			_spin_t = -1.0
	var bob := absf(cos(_walk)) * 0.08 if moving and on_floor else sin(_time * 1.7) * 0.015
	if _char:
		bob = 0.0
		_animate_char(on_floor, moving)
	_model.position.y = bob
	_update_trail(dt)
	if _feet:
		# Стопы встают на землю под собой стоя и на шаге (на склонах и ступенях
		# не проваливаются и не висят); в прыжке, рывке и приёмах — выключено
		# На бегу IK выключен — бег в клипе сам ставит ноги, IK только портил сгиб колена
		var calm := on_floor and not dead and _speed_now < FOOT_IK_MAX_SPEED and _dash_t < 0.0 and _spin_t < 0.0 and _art_t < 0.0 and _move == ""
		_model.position.y += _feet.update(dt, calm, facing)
	_lean_update(dt, on_floor)
	# Прыжок: подъём, заложенный в клипе, вычитается — высоту прыжка задаёт физика
	if _ha and not on_floor and _ha.current() == "air" and _ha._names.get("air", "") == JUMP_CLIP[0]:
		_model.position.y -= _jump_lift(_jump_t)
	if _dash_t >= 0.0 and _dash_t < DASH_TIME:
		# Длинный прыжок: тело летит по дуге над землёй
		var u := clampf(_dash_t / DASH_TIME, 0.0, 1.0)
		_model.position.y += 4.0 * DASH_JUMP * u * (1.0 - u)
	_model.rotation.y = facing + spin
	if dead:
		_dead_t += dt
		if _ragdoll.active():
			_model.position.y = 0.0   # тело лежит само, модель не двигаем
		else:
			var k := minf(1.0, _dead_t * 2.5)
			_model.rotation.x = -k * 1.45
			_model.position.y = k * 0.25
	else:
		# В прыжке рывка: на взлёте корпус чуть назад, к приземлению — вперёд
		# Наклон в прыжке рывка — только у блочной модели (у модели героя есть своя анимация прыжка)
		var lean_jump := _dash_t >= 0.0 and not (_anim and _anim.has_animation(A_DASH))
		_model.rotation.x = lerpf(-0.15, 0.3, clampf(_dash_t / DASH_TIME, 0.0, 1.0)) if lean_jump else 0.0
