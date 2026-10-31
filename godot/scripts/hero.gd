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
var _dead_t := 0.0
var _char: Node3D           # модель персонажа из models/hero.glb
var _anim: AnimationPlayer
var _new_swing := false
var _gear := {}            # детали брони и шлема на костях модели: имя → MeshInstance3D

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

## Модель персонажа (Meshy, скелет Mixamo, анимации бега, ходьбы и удара мечом).
## Блочная модель остаётся запасной: её прячем, а меч переносим в правую кисть.
const CHAR_PATH := "res://models/hero.glb"
const CHAR_SCALE := 1.1
const A_WALK := "Walking"
const A_RUN := "Running"
const A_SLASH := "Right_Hand_Sword_Slash"

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
	# Хват: рукоять поперёк ладони, клинок выходит над большим и указательным пальцами.
	# В системе кости кисти пальцы смотрят по +Y, линия костяшек — от мизинца к указательному.
	var idx := _bone_local(sk, hand, "RightHandIndex1")
	var pinky := _bone_local(sk, hand, "RightHandPinky1")
	var fingers := ((idx + pinky) / 2.0).normalized()
	var blade := (idx - pinky)
	blade = (blade - fingers * blade.dot(fingers)).normalized()
	var flat := fingers.cross(blade).normalized()
	var grip := fingers * ((idx + pinky) / 2.0).length() * 0.7 - flat * 0.02
	_sword.get_parent().remove_child(_sword)
	att.add_child(_sword)
	_sword.transform = Transform3D(Basis(fingers, blade, flat), grip + blade * 0.02)
	_sword.scale = Vector3.ONE / CHAR_SCALE
	_build_gear(sk)
	_anim.play(A_WALK)
	update_look()

## Броня и шлем — детали на костях модели, двигаются вместе с телом.
## Размеры подобраны по модели: торс ~0,4 м в ширину, голова ~0,2 м.
func _build_gear(sk: Skeleton3D) -> void:
	var on_bone := func(bone: String) -> BoneAttachment3D:
		var att := BoneAttachment3D.new()
		sk.add_child(att)
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).ends_with(bone):
				att.bone_name = sk.get_bone_name(i)
				att.bone_idx = i
		return att
	var part := func(parent: Node3D, mesh: Mesh, pos: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = pos
		mi.scale = scale
		mi.rotation = rot
		mi.material_override = StandardMaterial3D.new()
		parent.add_child(mi)
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
	# Нагрудник: овальный панцирь на позвоночнике, поверх — пояс
	var chest: BoneAttachment3D = on_bone.call("Spine1")
	_gear["cuirass"] = part.call(chest, tube, Vector3(0, 0.07, 0.0), Vector3(0.22, 0.36, 0.2))
	_gear["chest_top"] = part.call(chest, dome, Vector3(0, 0.25, -0.01), Vector3(0.22, 0.08, 0.2))
	_gear["belt"] = part.call(chest, tube, Vector3(0, -0.12, 0.005), Vector3(0.245, 0.06, 0.225))
	# Наплечники
	for side in ["Left", "Right"]:
		var arm: BoneAttachment3D = on_bone.call(side + "Arm")
		_gear["pauldron_" + side] = part.call(arm, dome, Vector3(0, 0.04, 0), Vector3(0.11, 0.09, 0.11), Vector3(0, 0, PI / 2 if side == "Left" else -PI / 2))
	# Шлем: купол, обод и наносник
	var head: BoneAttachment3D = on_bone.call("Head")
	_gear["helm"] = part.call(head, dome, Vector3(0, 0.12, -0.015), Vector3(0.128, 0.13, 0.14))
	_gear["helm_rim"] = part.call(head, tube, Vector3(0, 0.12, -0.015), Vector3(0.135, 0.02, 0.147))
	_gear["helm_nose"] = part.call(head, box, Vector3(0, 0.07, 0.125), Vector3(0.025, 0.09, 0.02))

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
	if attack_t >= 0.0 or _spin_t >= 0.0:
		want = A_SLASH
		# Вся анимация удара длится 1,5 с — сжимаем её в один удар героя
		speed = 2.6 * (1.0 + 0.1 * Game.rank("agility"))
	elif _dash_t >= 0.0 or not on_floor:
		want = A_RUN
		speed = 1.6 if _dash_t >= 0.0 else 0.0
	elif moving:
		want = A_RUN if _speed_now > 7.0 else A_WALK
		speed = _speed_now / (9.0 if want == A_RUN else 3.2)
	else:
		speed = 0.0   # стойка: первый кадр ходьбы
	if _anim.current_animation != want or (want == A_SLASH and _new_swing):
		_anim.play(want, 0.1 if want == A_SLASH else -1.0)
		if want == A_SLASH:
			_anim.seek(0.08, true)
		elif speed == 0.0:
			_anim.seek(0.0, true)
		_new_swing = false
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
	_tunic_mat.set_shader_parameter("albedo", WorldGen.hex(a.get("color", 0x2e6b8a)))
	_tunic_mat.set_shader_parameter("metallic", 0.55 if a.get("metal", false) else 0.0)
	_tunic_mat.set_shader_parameter("roughness", 0.45 if a.get("metal", false) else 0.8)
	_helmet.visible = not h.is_empty()
	if not h.is_empty():
		_helmet_mat.set_shader_parameter("albedo", WorldGen.hex(h["color"]))
	if not _gear.is_empty():
		var am: bool = a.get("metal", false)
		_set_gear(["cuirass", "chest_top", "belt"], not a.is_empty(), WorldGen.hex(a.get("color", 0)), am)
		_set_gear(["belt"], not a.is_empty(), WorldGen.hex(0x4a3220), false)
		# Наплечники — только у металлических доспехов
		_set_gear(["pauldron_Left", "pauldron_Right"], am, WorldGen.hex(a.get("color", 0)), true)
		var hm: bool = h.get("id", "") == "helm_iron" or (not h.is_empty() and h["color"] != 0x6a4626)
		_set_gear(["helm"], not h.is_empty(), WorldGen.hex(h.get("color", 0)), hm)
		_set_gear(["helm_rim", "helm_nose"], hm, WorldGen.hex(h.get("color", 0)).darkened(0.15), true)

# ---------- Бой
func attack() -> void:
	if attack_t >= 0.0 or _spin_t >= 0.0 or _dash_t >= 0.0 or dead or busy:
		return
	attack_t = 0.0
	_attack_hit = false
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
	_new_swing = true

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

func _sword_hit() -> void:
	for e in enemies.alive_near(global_position, 4.0):
		var v := _flat(e.global_position - global_position)
		var d := maxf(0.01, v.length())
		if d > 2.3 + e.T["r"] or absf(e.global_position.y - global_position.y) > 2.5:
			continue
		if absf(angle_difference(facing, atan2(v.x, v.z))) > 1.25 and d > e.T["r"] + 0.7:
			continue
		_deal(e, 1.0, v / d)

## Урон с учётом навыков «Критический удар» и «Вампиризм»
func _deal(e: Node3D, mult: float, dir: Vector3) -> void:
	var dmg := roundi((Game.dmg + randf() * 8.0) * mult)
	var crit := randf() < Game.rank("crit") * 0.08
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
		cd["dash"] = SkillDefs.dash_cd(r)

func cooldown_total(id: String) -> float:
	var r := maxi(1, Game.rank(id))
	return SkillDefs.whirl_cd(r) if id == "whirl" else SkillDefs.dash_cd(r)

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
	var mult := 0.8 + 0.3 * (Game.rank("dash") - 1)
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
	Game.hp = maxf(0.0, Game.hp - dmg)
	_invuln = 0.5
	_hurt_ago = 0.0
	_push = _flat(global_position - from).normalized() * 10.0
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
	speed *= 1.0 + 0.08 * Game.rank("agility")
	if swimming:
		speed *= 0.5
	if attack_t >= 0.0:
		speed *= 0.45
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
		hv = _dash_dir * 28.0
		_invuln = maxf(_invuln, 0.1)
		if _dash_t >= 0.26:
			_dash_t = -1.0
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
		attack_t += dt * (1.0 + 0.1 * Game.rank("agility"))
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
	# Вихрь: герой крутится с вытянутым мечом
	var spin := 0.0
	if _spin_t >= 0.0:
		_spin_t += dt
		spin = minf(1.0, _spin_t / 0.45) * TAU
		_arms[0].rotation = Vector3(0, 0, -1.4)
		_arms[1].rotation = Vector3(0, 0, 1.2)
		if not _spin_hit and _spin_t >= 0.2:
			_spin_hit = true
			_whirl_hit()
		if _spin_t >= 0.45:
			_spin_t = -1.0
	var bob := absf(cos(_walk)) * 0.08 if moving and on_floor else sin(_time * 1.7) * 0.015
	if _char:
		bob = 0.0
		_animate_char(on_floor, moving)
	_model.position.y = bob
	_model.rotation.y = facing + spin
	if dead:
		_dead_t += dt
		var k := minf(1.0, _dead_t * 2.5)
		_model.rotation.x = -k * 1.45
		_model.position.y = k * 0.25
	else:
		_model.rotation.x = 0.35 if _dash_t >= 0.0 else 0.0
