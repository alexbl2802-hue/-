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
const A_STANCE := "Combat_Stance"   # боевая стойка с мечом — анимация модели Shadowwarden
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
	for n in [WALK_CLIP, RUN_CLIP]:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
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
		# Хват по сжатым пальцам из анимации удара: рукоять лежит в ладони — проходит через
		# середину кулака (внутри согнутых пальцев), клинок выходит со стороны большого
		# и указательного пальцев поперёк кисти (при прямом запястье, чуть наклонён к пальцам)
		var hg := HandGrip.new()   # сжимает пальцы в кулак поверх анимации
		sk.add_child(hg)
		hg.setup(sk, "Right")
		var fist := _fist_grip(sk, _anim.get_animation(A_SLASH), hg)
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
		# Ходьба по скорости: стойка → боевой шаг → спринт (клипы Meshy)
		_ha.setup(_anim, sk, acts, [[A_STANCE if _anim.has_animation(A_STANCE) else A_IDLE, 0.0], [WALK_CLIP, LOCO_WALK_FROM], [WALK_CLIP, LOCO_FAST_FROM], [RUN_CLIP, LOCO_FAST_FULL]], RUN)
	# След клинка
	_trail = SwordTrail.new()
	add_child(_trail)
	_sk = sk
	# Ноги на склонах
	var feet := FootIK.new()
	add_child(feet)
	if feet.setup(self, sk):
		_feet = feet
	update_look()

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
			if curl.has(b):
				r = r * curl[b]
			tr = tr * Transform3D(Basis(r), sk.get_bone_rest(b).origin)
			pts.append(tr.origin)
			if k == 1:
				knuckle[f] = tr.origin
	if pts.size() < 8 or not knuckle.has("Index") or not knuckle.has("Pinky"):
		return []
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
		# в T-позе левая рука вдоль +X ладонью вниз; щит — на тыльной стороне предплечья (+Y),
		# лицом наружу, верхом к большому пальцу (+Z): в стойке, когда ладонь смотрит к телу,
		# щит стоит вертикально и прикрывает бок
		var center := elbow.lerp(wrist, 0.45) + Vector3(0, 0.075, 0)
		var basis := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
		sh.transform = g.affine_inverse() * Transform3D(basis, center)
		sh.scale = Vector3.ONE / CHAR_SCALE * 1.0
		_shields[kind] = sh

func _bone_local(sk: Skeleton3D, parent: int, suffix: String) -> Vector3:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with(suffix):
			return sk.get_bone_global_rest(parent).affine_inverse() * sk.get_bone_global_rest(i).origin
	return Vector3.UP * 0.1

## Анимации модели: стойка, ходьба, бег, удар, вихрь, рывок, прыжок
## Анимация через дерево: ходьба смешивается по скорости, действия накладываются поверх
func _animate_tree(dt: float, on_floor: bool, moving: bool) -> void:
	# Темп шага — по длине шага модели, чтобы стопы не скользили
	var fast := clampf((_speed_now - LOCO_FAST_FROM) / (LOCO_FAST_FULL - LOCO_FAST_FROM), 0.0, 1.0)
	# Рядом враги — бег с мечом наготове, иначе — спринт
	var run_stride: float = RUN_STRIDE_M
	if _anim.has_animation(RUN_FIGHT) and enemies:
		_fight_check -= dt
		if _fight_check <= 0.0:
			_fight_check = 0.5
			_in_fight = not enemies.alive_near(global_position, FIGHT_NEAR).is_empty()
			_ha.set_loco_anim(3, RUN_FIGHT if _in_fight else RUN_CLIP)
		if _in_fight:
			run_stride = RUN_FIGHT_STRIDE
	var stride_t := _speed_now / lerpf(WALK_STRIDE_M, run_stride, fast)
	if _anim.has_animation(BACKSTEP_CLIP):
		var walk_anim := BACKSTEP_CLIP if _backstep else WALK_CLIP
		_ha.set_loco_anim(1, walk_anim)
		_ha.set_loco_anim(2, walk_anim)
	_ha.locomotion(_speed_now, lerpf(1.0, stride_t, clampf(_speed_now / LOCO_WALK_FROM, 0.0, 1.0)))
	var upper := on_floor and moving and _speed_now > 1.0
	if _move != "":
		# Уклонения, Switch, реакции, «Горизонталь» — анимация целиком, с начала
		var start := 0.0
		var sc := 1.0
		if MESHY_MOVES.has(_move) and _ha._names.get(_move, "") == MESHY_MOVES[_move][0]:
			start = MESHY_MOVES[_move][1]
			sc = MESHY_MOVES[_move][2]
		_ha.act(_move, start if _move_new else -1.0, sc)
		_move_new = false
	elif blocking:
		if _ha._names.has("block"):
			_ha.act("block", BLOCK_CLIP[1], 0.0, upper)   # меч вертикально перед собой
		else:
			_ha.act("slash", BLOCK_POSE, 0.0, upper)
	elif _art_t >= 0.0 and _ha._names.has("art_" + _art):
		# Приём — клип Meshy: удар клипа совпадает с моментом удара приёма
		var ac: Array = ART_CLIPS[_art]
		var start: float = maxf(0.0, ac[1] - (ART_CHARGE + 0.08) * ac[2])
		_ha.act("art_" + _art, start if _new_swing or _ha.current() != "art_" + _art else -1.0, ac[2])
	elif _art_t >= 0.0:
		if _art_t < ART_CHARGE:   # стойка: меч отведён для удара
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
			_ha.act("whirl", WHIRL_CLIP[1] if _new_swing or _ha.current() != "whirl" else -1.0, WHIRL_CLIP[2])
		else:
			_ha.act("whirl", 0.0 if _new_swing or _ha.current() != "whirl" else -1.0, _anim.get_animation(A_WHIRL).length / WHIRL_TIME)
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
			# Прыжок с ударом: отрезок клипа от толчка, проигрывается один раз
			_ha.act("air", JUMP_CLIP[1] if _ha.current() != "air" else -1.0, JUMP_CLIP[2])
		else:
			_ha.act("air", 0.17, 0.0)   # в прыжке — поза полёта из бега
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
		if _art_t < ART_CHARGE:   # стойка: меч отведён для удара
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
	# Без доспеха — обычная одежда героя (своя аниме-раскраска «base», если есть)
	if key == "" or not ResourceLoader.exists(ARMOR_DIR + key + "_base_color.jpg"):
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
				m = m.duplicate()
				m.cull_mode = BaseMaterial3D.CULL_DISABLED   # полы видны и с изнанки
				Mats.toon(m)
				mi.set_surface_override_material(si, m)
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
const RUN_CLIP := "Lean_Forward_Sprint"            # спринт (Meshy)
const WALK_STRIDE_M := 0.6     # м за секунду клипа шага (замер tests/pose_view.tscn)
const RUN_STRIDE_M := 3.2
const BACKSTEP_CLIP := "Walk_Backward_with_Sword"   # шаг назад с мечом — в блоке
const STOP_FROM := 8.5         # с какой скорости бега отпущенный джойстик — резкая остановка
const LAND_FALL := 3.5         # с какой высоты падения — тяжёлое приземление
const WHIRL_CLIP := ["Sword_Spin_360", 0.0, 0.92 / WHIRL_TIME]   # [клип, с какой секунды, темп] — весь оборот за время вихря
const JUMP_CLIP := ["Basic_Jump", 1.45, 1.1]
const RUN_FIGHT := "ForwardRight_Run_Fight"            # бег, когда рядом враги — меч наготове
const RUN_FIGHT_STRIDE := 3.0
const FIGHT_NEAR := 12.0
## Комбо из трёх ударов: [клип, момент удара в клипе (с)]
const ATTACK_CLIPS := [["Left_Slash", 0.7], ["Double_Combo_Attack", 0.63], ["Charged_Upward_Slash", 1.03]]
const ATTACK_SEG := 0.8        # сколько секунд клипа занимает один удар героя
## Приёмы меча: тип оружия → [клип, момент (первого) удара, темп]
const ART_CLIPS := {"sword": ["Thrust_Slash", 0.73, 1.0], "great": ["Charged_Slash", 1.2, 1.0], "rapier": ["Triple_Combo_Attack", 0.77, 2.4], "dagger": ["Weapon_Combo_2", 1.3, 1.6]}
const BLOCK_CLIP := ["Sword_Parry", 0.6]
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
	if _move == "horizontal" and not _move_hit and _move_t >= HZ_HIT:
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
	Fx.ring(global_position + Vector3(0, 1.0, 0), SkillDefs.ART_COLOR["sword"], 3.5, 0.3)
	if hits > 0:
		_finisher_fx()

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
	return ART_CHARGE + {"sword": 0.25, "great": 0.3, "rapier": 0.6, "dagger": 0.15}[_art]

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
	var t := _art_t - ART_CHARGE
	if t >= 0.0:
		match _art:
			"sword":   # рывок вперёд, урон всем на пути
				if t < 0.25:
					hv = _art_dir * 20.0
					_invuln = maxf(_invuln, 0.05)
					for e in enemies.alive_near(global_position, 2.4):
						if not _art_hit.has(e):
							_art_hit.append(e)
							_deal(e, SkillDefs.art_mult(2.2, r), _art_dir)
			"great":   # удар сверху по площади, оглушение
				if t >= 0.15 and _art_hits == 0:
					_art_hits = 1
					var c := global_position + _art_dir * 1.6
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
						Fx.ring(global_position + Vector3(0, 0.1, 0), SkillDefs.ART_COLOR["dagger"], 1.5, 0.3)
						var dmg := roundi((Game.dmg + randf() * 8.0) * SkillDefs.art_mult(3.0, r))
						e.hit(dmg, back, true)
	if _art_t >= _art_action_end() + ART_RECOVER:
		_art_t = -1.0
		_set_blade_glow(Color(0, 0, 0, 0))
		update_look()
	return hv

## Свечение клинка (приём меча); прозрачный цвет — выключить
func _set_blade_glow(c: Color) -> void:
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
	if finisher:
		Fx.ring(global_position + Vector3(sin(facing), 0.1, cos(facing)) * 1.4, Color("#ffd479"), 2.0, 0.35)
		if _finisher_landed:
			_finisher_fx()
	_finisher_landed = false

var _finisher_landed := false

## Урон с учётом навыков «Критический удар» и «Вампиризм»
func _deal(e: Node3D, mult: float, dir: Vector3) -> void:
	var dmg := roundi((Game.dmg + randf() * 8.0) * mult)
	var crit: bool = randf() < Game.rank("crit") * 0.08 + Game.crit_bonus + _wt()["crit"] + Game.stats["agi"] * Game.STAT_AGI_CRIT
	if crit:
		dmg *= 2
	e.hit(dmg, dir, crit)
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
		# Аниме-рывок: герой исчезает со вспышкой там, где стоял (с места или на бегу)
		Fx.ring(global_position + Vector3(0, 0.1, 0), _dash_color(), 2.0, 0.4, true)

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
		Fx.ring(global_position + Vector3(sin(facing), 1.0, cos(facing)) * 0.6, Color("#ffe060"), 1.4, 0.3)
		if attacker and attacker.has_method("stun"):
			attacker.stun(PARRY_STUN, true)
		# «Переключение»: отскок назад, пока враг оглушён
		Fx.text("Switch!", global_position + Vector3(0, 0.4, 0), Color("#9fe4ff"), true)
		_start_move("switch", -Vector3(sin(facing), 0, cos(facing)))
		return
	if _art_t >= 0.0 and _art_t > _art_action_end():
		raw = roundi(raw * 1.2)   # заминка после приёма — герой беззащитен
	var dmg := Game.reduce_damage(roundi(raw * DayNight.monster_mult()))   # ночью монстры бьют сильнее
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
		died.emit()

# ---------- След клинка: светится в ударе, вихре, приёмах и «Горизонтали»
const TRAIL_LEN := 1.0        # длина клинка до кончика (м), у двуручника длиннее
func _update_trail(dt: float) -> void:
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
	elif _art_t >= ART_CHARGE and _art_t < _art_action_end():
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
	var was_blocking := blocking
	blocking = touch != null and touch.block and not dead and not busy and attack_t < 0.0 and _spin_t < 0.0 and _dash_t < 0.0 and _art_t < 0.0 and _move == ""
	if blocking and not was_blocking:
		_block_start = _time
	if blocking:
		speed *= 0.4
	var hv := Vector3.ZERO
	if mag > 0.12:
		dir = dir.normalized()
		# В блоке герой не разворачивается — смотрит на врага и отступает спиной вперёд
		if attack_t < 0.0 and _move == "" and not blocking:
			facing += angle_difference(facing, atan2(dir.x, dir.z)) * minf(1.0, dt * 12.0)
		hv = dir * speed
		_speed_now = lerpf(_speed_now, speed, minf(1.0, dt * 10.0))
		_backstep = blocking and dir.dot(Vector3(sin(facing), 0, cos(facing))) < -0.3
	else:
		# Отпустил джойстик на спринте — резкая остановка (клип Meshy)
		if _speed_now > STOP_FROM and is_on_floor() and _move == "" and attack_t < 0.0 and _art_t < 0.0 \
				and _spin_t < 0.0 and _dash_t < 0.0 and not blocking and _ha and _ha._names.has("stop"):
			_start_move("stop", Vector3(sin(facing), 0, cos(facing)))
		_speed_now = lerpf(_speed_now, 0.0, minf(1.0, dt * 10.0))
		_backstep = false
	# Приём меча
	if _art_t >= 0.0:
		hv = _art_update(dt)
	# Уклонение, реакция или «Горизонталь» — своё движение вместо джойстика
	if _move != "":
		hv = _update_move(dt)
		_speed_now = lerpf(_speed_now, 0.0, minf(1.0, dt * 10.0))
	# Рывок: быстрое движение вперёд сквозь врагов, герой неуязвим
	if _dash_t >= 0.0:
		_dash_t += dt
		hv = _dash_dir * DASH_SPEED * _dash_speed
		_invuln = maxf(_invuln, 0.1)
		# Аниме-рывок (tools/godot_anime_dash): герой исчезает на время рывка и появляется в конце
		# пути со вспышкой; сквозь стены не проходит — движение физическое (move_and_slide)
		_model.visible = _dash_t <= 0.03
		if _dash_t >= DASH_TIME:
			_dash_t = -1.0
			_model.visible = true
			Fx.ring(global_position + Vector3(0, 0.1, 0), _dash_color(), 2.5, 0.45, true)
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
		_fall_top = -INF
	if _dash_t >= 0.0:
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
	_update_trail(dt)
	if _feet:
		var calm := on_floor and _speed_now < 0.8 and not dead and _dash_t < 0.0 and _spin_t < 0.0 and _art_t < 0.0 and _move == ""
		_model.position.y += _feet.update(dt, calm, facing)
	if _dash_t >= 0.0:
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
