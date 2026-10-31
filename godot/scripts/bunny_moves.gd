## Движения боевого кролика по раскадровке: ходьба, бег, прыжок, удары руками
## (джеб, крюк, прямой), комбо и удар в прыжке.
## Основа — боксёрская стойка из анимации модели; поверх неё:
##  • ноги, корпус (наклон и поворот) — добавочные повороты костей (PoseOffsets);
##  • руки в ударах — IK двух костей (TwoBoneIK3D): кулак летит в заданную точку.
## Все точки — в системе скелета: +Z — вперёд (к герою), +X — сторона левой руки.
## В стойке впереди левая рука и левая нога («передняя»), правая — «задняя».
class_name BunnyMoves
extends RefCounted

# ---------- Точки кулаков и локтей (система скелета, высота кролика ~1 м)
const GUARD_L := Vector3(-0.02, 0.90, 0.32)   # кулаки в стойке (как в анимации)
const GUARD_R := Vector3(-0.35, 0.87, 0.06)
const JAB_HIT := Vector3(-0.05, 0.90, 0.56)   # джеб передней рукой — прямо в лицо
const STR_HIT := Vector3(-0.06, 0.90, 0.54)   # прямой задней рукой — с разворотом корпуса
const HOOK_WIND := Vector3(0.28, 0.90, 0.28)  # крюк: замах в сторону…
const HOOK_HIT := Vector3(-0.08, 0.92, 0.44)  # …удар по дуге перед собой…
const HOOK_OUT := Vector3(-0.30, 0.90, 0.30)  # …и проводка дальше
const SMASH_UP := Vector3(-0.22, 1.18, 0.14)  # удар в прыжке: кулак над головой…
const SMASH_HIT := Vector3(-0.08, 0.64, 0.50) # …и сверху вниз при приземлении
const POLE_L := Vector3(0.35, 0.55, 0.25)     # локти в прямых ударах — вниз и в сторону
const POLE_R := Vector3(-0.55, 0.55, -0.10)
const POLE_HOOK := Vector3(0.45, 0.95, 0.15)  # локоть в крюке — поднят на уровень плеча
const POLE_SMASH := Vector3(-0.55, 1.0, -0.1)

# ---------- Атаки: дорожки ключей [время, значение]; между ключами — плавный переход.
# lw/rw — сила IK передней/задней руки, lt/rt — точка кулака, lp/rp — куда смотрит локоть,
# twist — поворот корпуса (°, + — задним плечом вперёд), lean — наклон вперёд (°),
# kt/kk — удар ногой передней ногой: бедро вперёд и сгиб колена (°).
const ATTACKS := {
	"jab": {
		"dur": 0.42, "hits": [0.12],
		"lw": [[0.0, 0.0], [0.05, 1.0], [0.26, 1.0], [0.42, 0.0]],
		"lt": [[0.0, GUARD_L], [0.12, JAB_HIT], [0.28, GUARD_L]],
		"twist": [[0.0, 0.0], [0.12, -12.0], [0.3, 0.0]],
		"lean": [[0.0, 0.0], [0.12, 6.0], [0.3, 0.0]],
	},
	"straight": {
		"dur": 0.55, "hits": [0.2],
		"rw": [[0.0, 0.0], [0.06, 1.0], [0.36, 1.0], [0.55, 0.0]],
		"rt": [[0.0, GUARD_R], [0.2, STR_HIT], [0.38, GUARD_R]],
		"twist": [[0.0, 0.0], [0.2, 38.0], [0.45, 0.0]],
		"lean": [[0.0, 0.0], [0.2, 8.0], [0.45, 0.0]],
	},
	"hook": {
		"dur": 0.62, "hits": [0.24],
		"lw": [[0.0, 0.0], [0.06, 1.0], [0.42, 1.0], [0.62, 0.0]],
		"lt": [[0.0, GUARD_L], [0.1, HOOK_WIND], [0.24, HOOK_HIT], [0.36, HOOK_OUT], [0.52, GUARD_L]],
		"lp": [[0.0, POLE_HOOK]],
		"twist": [[0.0, 0.0], [0.1, 14.0], [0.24, -34.0], [0.4, -18.0], [0.6, 0.0]],
		"lean": [[0.0, 0.0], [0.24, 5.0], [0.5, 0.0]],
	},
	# Комбо: джеб → прямой → крюк → удар ногой
	"combo": {
		"dur": 1.55, "hits": [0.12, 0.42, 0.74, 1.16],
		"lw": [[0.0, 0.0], [0.05, 1.0], [0.95, 1.0], [1.05, 0.0]],
		"lt": [[0.0, GUARD_L], [0.12, JAB_HIT], [0.26, GUARD_L], [0.46, GUARD_L], [0.6, HOOK_WIND], [0.74, HOOK_HIT], [0.86, HOOK_OUT], [1.0, GUARD_L]],
		"lp": [[0.0, POLE_L], [0.46, POLE_L], [0.56, POLE_HOOK], [0.95, POLE_HOOK], [1.05, POLE_L]],
		"rw": [[0.15, 0.0], [0.22, 1.0], [0.55, 1.0], [0.65, 0.0]],
		"rt": [[0.15, GUARD_R], [0.42, STR_HIT], [0.56, GUARD_R]],
		"twist": [[0.0, 0.0], [0.12, -12.0], [0.26, 0.0], [0.42, 38.0], [0.56, 10.0], [0.6, 14.0], [0.74, -34.0], [0.9, -10.0], [1.0, 0.0]],
		"lean": [[0.0, 0.0], [0.12, 6.0], [0.42, 8.0], [0.74, 5.0], [1.0, 0.0], [1.16, -12.0], [1.4, 0.0]],
		"kt": [[0.95, 0.0], [1.06, 55.0], [1.16, 80.0], [1.3, 50.0], [1.5, 0.0]],
		"kk": [[0.95, 0.0], [1.06, 60.0], [1.16, -10.0], [1.3, 55.0], [1.5, 0.0]],
	},
}
const ORDER := ["jab", "straight", "hook", "combo"]   # по очереди, первым — быстрый джеб

# ---------- Прыжок: присел → толчок → в воздухе поджал ноги → вытянул → приземлился в присед.
# Ноги: [время, Vector3(бедро вперёд, сгиб колена, носок вниз)] — для обеих ног.
const LEAP_DUR := 0.95
const LEAP_AIR := [0.28, 0.78]      # отрыв и касание земли (доли — в секундах цикла)
const LEAP_HIT := 0.8               # удар в прыжке приходится на приземление
const LEAP_LEGS := [
	[0.0, Vector3(0, 0, 0)],
	[0.18, Vector3(30, 60, -10)],    # присел, наклонился вперёд
	[0.28, Vector3(-15, 0, 30)],     # толчок: ноги выпрямлены, на носках
	[0.4, Vector3(45, 75, 20)],      # в воздухе ноги поджаты
	[0.62, Vector3(40, 65, 15)],
	[0.76, Vector3(18, 22, 5)],      # вытянул ноги к земле
	[0.84, Vector3(32, 62, -8)],     # приземлился в присед
	[0.95, Vector3(0, 0, 0)],
]
# В боксёрской стойке ноги стоят одна впереди другой и развёрнуты — в прыжке они бы
# перекрещивались. Перед толчком ноги плавно становятся ровно и параллельно (поза покоя),
# отталкивается и приземляется кролик на обе ноги, после приземления возвращается в стойку.
const LEAP_SQUARE := [[0.0, 0.0], [0.14, 1.0], [0.86, 1.0], [0.95, 0.0]]
const LEAP_LEAN := [[0.0, 0.0], [0.18, 18.0], [0.28, 10.0], [0.5, 4.0], [0.84, 15.0], [0.95, 0.0]]
const LEAP_SMASH := {
	"rw": [[0.2, 0.0], [0.3, 1.0], [0.88, 1.0], [0.95, 0.0]],
	"rt": [[0.2, GUARD_R], [0.45, SMASH_UP], [0.7, SMASH_UP], [0.8, SMASH_HIT], [0.9, SMASH_HIT]],
	"rp": [[0.0, POLE_SMASH]],
}

# ---------- Шаг и бег: стопа на земле не скользит — частота шагов от скорости и длины ног
const WALK := {"duty": 0.62, "swing": 22.0, "knee": 35.0, "lean": 4.0, "bob": 0.015}
const RUN := {"duty": 0.3, "swing": 40.0, "knee": 70.0, "lean": 16.0, "bob": 0.05}
# Ноги оборотня: растяжение костей и поза «на носках» (бедро вперёд, голень назад,
# плюсна круто вниз — сгиб назад ниже колена, пальцы лежат на земле)
const LEG_STRETCH := 1.0    # у оборотня Shadowclaw ноги длинные сами по себе
const META_STRETCH := 1.0
const DIGI := Vector3(24.0, 55.0, -9.0)
const TOE_LEVEL := 1.0
const TURN := 0.9   # в стойке корпус развёрнут на ~50°: на ходу доворачиваем грудью вперёд
const FIGHT_TURN := 0.5   # в бою — наполовину: голова смотрит на противника, стойка остаётся боковой

var _char: Node3D
var _sk: Skeleton3D
var _mod: PoseOffsets
var _ik := {}            # "L"/"R" → TwoBoneIK3D
var _target := {}        # "L"/"R" → Node3D (точка кулака)
var _pole := {}          # "L"/"R" → Node3D (куда смотрит локоть)
var _legs := {}          # "L"/"R" → [[бедро, колено, стопа], [оси сгиба в системе костей]]
var _spine := -1
var _hips := -1
var _spine_axis := Vector3.RIGHT
var _twist_bones := []
var _leg_len := 0.3
var _flex := Vector3.RIGHT

var _order_i := 0
var attack := ""          # текущая атака или ""
var attack_t := 0.0
var leap_t := -1.0        # < 0 — не в прыжке
var leap_dist := 3.0
var leap_attack := false
var _phase := 0.0
var _loco_w := 0.0
var _turn_w := 0.0
var _dust_done := {}
var _toes := []
var _toe_ends := {}
var _loco_y := 0.0
var _lift_square := 0.0   # подъём тела, когда ноги в ровной позе (в прыжке)
var _lift := 0.0          # на сколько поднять тело, чтобы длинные ноги стояли на земле
var _calib := 0           # кадров до замера подъёма

func setup(char_node: Node3D) -> bool:
	_char = char_node
	_sk = _char.find_children("*", "Skeleton3D", true, false)[0]
	var find := func(suffix: String) -> int:
		for i in _sk.get_bone_count():
			if _sk.get_bone_name(i).ends_with(suffix):
				return i
		return -1
	var gr := func(i: int) -> Transform3D: return _sk.get_bone_global_rest(i)
	var foot: int = find.call("LeftFoot")
	var toe: int = find.call("LeftToeBase")
	if foot < 0 or toe < 0:
		return false
	# Ось сгиба — поперёк направления взгляда модели (+Z). По пальцам её брать нельзя:
	# стопы у модели чуть развёрнуты наружу, и колени тогда уходили бы в стороны.
	# Поворот вокруг этой оси уводит направленную вниз кость вперёд.
	_flex = Vector3.DOWN.cross(Vector3(0, 0, 1)).normalized()
	for side in ["Left", "Right"]:
		var bones: Array = [find.call(side + "UpLeg"), find.call(side + "Leg"), find.call(side + "Foot"), find.call(side + "ToeBase")]
		if bones.has(-1):
			return false
		var axes: Array = bones.map(func(b): return (gr.call(b).basis.orthonormalized().inverse() * _flex).normalized())
		_legs[side[0]] = [bones, axes]
	var lb: Array = _legs["L"][0]
	_leg_len = (gr.call(lb[1]).origin.distance_to(gr.call(lb[0]).origin) + gr.call(lb[2]).origin.distance_to(gr.call(lb[1]).origin)) * _char.scale.x
	_leg_len *= LEG_STRETCH
	_toes = [_legs["L"][0][3], _legs["R"][0][3]]
	_toe_ends = {"L": find.call("LeftToe_End"), "R": find.call("RightToe_End")}
	_hips = find.call("Hips")
	_spine = find.call("Spine")
	if _spine >= 0:
		_spine_axis = (gr.call(_spine).basis.orthonormalized().inverse() * _flex).normalized()
	for s in ["Spine1", "Spine2"]:
		var b: int = find.call(s)
		if b >= 0:
			_twist_bones.append(b)
	_mod = PoseOffsets.new()
	_sk.add_child(_mod)
	# Ноги как у оборотня: бедро и голень длиннее, плюсна (кость стопы) длинная —
	# кролик стоит на носках, и ниже колена нога сгибается назад
	for k in ["L", "R"]:
		var bones: Array = _legs[k][0]
		_mod.set_bone_stretch(bones[0], Vector3(1, LEG_STRETCH, 1))
		_mod.set_bone_stretch(bones[1], Vector3(1, LEG_STRETCH, 1))
		_mod.set_bone_stretch(bones[2], Vector3(1, META_STRETCH, 1))
	# IK рук — после поворотов корпуса, чтобы кулак попадал в точку уже с учётом разворота
	for side in ["Left", "Right"]:
		var k: String = side[0]
		var t := Node3D.new()
		var p := Node3D.new()
		_sk.add_child(t)
		_sk.add_child(p)
		var ik := TwoBoneIK3D.new()
		_sk.add_child(ik)
		ik.setting_count = 1
		ik.set_root_bone_name(0, _sk.get_bone_name(find.call(side + "Arm")))
		ik.set_middle_bone_name(0, _sk.get_bone_name(find.call(side + "ForeArm")))
		ik.set_end_bone_name(0, _sk.get_bone_name(find.call(side + "Hand")))
		ik.set_target_node(0, ik.get_path_to(t))
		ik.set_pole_node(0, ik.get_path_to(p))
		ik.influence = 0.0
		ik.active = false
		_ik[k] = ik
		_target[k] = t
		_pole[k] = p
	return true

# ---------- Управление из enemy.gd
func next_attack() -> String:
	var k: String = ORDER[_order_i % ORDER.size()]
	_order_i += 1
	return k

## Начать атаку; возвращает моменты ударов (с)
func start_attack(kind: String) -> Array:
	attack = kind
	attack_t = 0.0
	return ATTACKS[kind]["hits"]

func attack_dur(kind: String) -> float:
	return ATTACKS[kind]["dur"]

func cancel_attack() -> void:
	attack = ""

func start_leap(dist: float, with_attack: bool) -> void:
	leap_t = 0.0
	leap_dist = dist
	leap_attack = with_attack
	cancel_attack()
	_dust_done = {}

func leaping() -> bool:
	return leap_t >= 0.0

## Скорость вперёд в прыжке: только в полёте, на земле — на месте
func leap_speed() -> float:
	if leap_t < LEAP_AIR[0] or leap_t > LEAP_AIR[1]:
		return 0.0
	return leap_dist / (LEAP_AIR[1] - LEAP_AIR[0])

func reset() -> void:
	attack = ""
	leap_t = -1.0

# ---------- Каждый кадр
func update(dt: float, moving: bool, speed: float, frozen: bool) -> void:
	var legs := {"L": Vector3.ZERO, "R": Vector3.ZERO}
	var lean := 0.0
	var twist := 0.0
	var y := 0.0
	var arm_w := {"L": 0.0, "R": 0.0}
	var def: Dictionary = {}
	var t := 0.0
	if frozen:   # кувырок — своя анимация, ничего не добавляем
		attack = ""
		leap_t = -1.0
	if attack != "":
		attack_t += dt
		def = ATTACKS[attack]
		t = attack_t
		if attack_t >= def["dur"]:
			attack = ""
			def = {}
	var leap_now := leap_t >= 0.0
	if leap_now:
		leap_t += dt
		if leap_t >= LEAP_DUR:
			leap_t = -1.0
			leap_now = false
	var square: float = _track(LEAP_SQUARE, leap_t) if leap_now else 0.0
	# Шаг/бег — только когда идёт, не бьёт и не прыгает
	var walking := moving and not leap_now and def.is_empty() and not frozen
	_loco_w = move_toward(_loco_w, 1.0 if walking else 0.0, dt * 6.0)
	_turn_w = move_toward(_turn_w, 1.0 if (walking or (leap_now and not leap_attack)) else 0.0, dt * 5.0)
	var loco := {"L": Vector3.ZERO, "R": Vector3.ZERO}
	var stance_drop := 0.0
	if _loco_w > 0.0:
		var g := _gait(speed)
		_phase = fmod(_phase + dt * g["f"], 1.0)
		for k in ["L", "R"]:
			var p := fmod(_phase + (0.0 if k == "L" else 0.5), 1.0)
			loco[k] = _step(p, g) * _loco_w
			# Тело опускается только по опорной ноге: нога в воздухе согнута, но тело не тянет
			if p < g["duty"]:
				var th := deg_to_rad(loco[k].x)
				stance_drop = maxf(stance_drop, _leg_len * (1.0 - cos(th)))
		lean += g["lean"] * _loco_w
		stance_drop -= g["bob"] * (1.0 - cos(TAU * 2.0 * _phase)) * 0.5
	# Покачивание тела на шагу — плавно: опора переходит с ноги на ногу скачком,
	# и без сглаживания тело дёргалось вверх-вниз на каждом шаге
	_loco_y = lerpf(_loco_y, -stance_drop * _loco_w, 1.0 - exp(-dt * 12.0))
	if leap_now:
		var lp: Vector3 = _track(LEAP_LEGS, leap_t)
		legs["L"] += lp
		legs["R"] += lp
		lean += _track(LEAP_LEAN, leap_t)
		if leap_t > LEAP_AIR[0] and leap_t < LEAP_AIR[1]:
			var f := (leap_t - LEAP_AIR[0]) / (LEAP_AIR[1] - LEAP_AIR[0])
			y += sin(PI * f) * clampf(leap_dist * 0.13, 0.3, 0.6)
		_dust_at(0.26, 0.6)
		_dust_at(LEAP_AIR[1], 1.0)
		if leap_attack:
			def = LEAP_SMASH
			t = leap_t
	# Модель довёрнута на rot: точки ударов задаём «вперёд, к цели» и переводим в систему скелета
	var rot := lerpf(FIGHT_TURN, TURN, _turn_w)
	# В прыжке таз встаёт прямо (поза покоя), и тогда ноги сгибаются строго назад —
	# доворачивать модель уже не нужно
	rot = lerpf(rot, 0.0, square)
	# Атака: руки, корпус, удар ногой
	if not def.is_empty():
		for k in ["L", "R"]:
			var key := ("l" if k == "L" else "r")
			if def.has(key + "w"):
				arm_w[k] = _track(def[key + "w"], t)
				_target[k].position = _track(_fwd_keys(def[key + "t"], rot), t)
				var pole_def: Array = def.get(key + "p", [[0.0, POLE_L if k == "L" else POLE_R]])
				_pole[k].position = _track(_fwd_keys(pole_def, rot), t)
		if def.has("twist"):
			twist += _track(def["twist"], t)
		if def.has("lean"):
			lean += _track(def["lean"], t)
		if def.has("kt"):
			legs["L"] += Vector3(_track(def["kt"], t), _track(def["kk"], t), 0.0)
	# Высота тела: присед (прыжок) опускает тело, чтобы стопы оставались на земле
	var drop := 0.0
	for k in ["L", "R"]:
		var a: Vector3 = legs[k] * deg_to_rad(1.0)
		drop = maxf(drop, _leg_len * (1.0 - (cos(a.x) + cos(a.x - a.y)) / 2.0))
	if leap_now and leap_t > LEAP_AIR[0] + 0.05 and leap_t < LEAP_AIR[1] - 0.04:
		drop = 0.0   # в воздухе поджатые ноги тело не опускают
	if def.has("kt"):
		drop = 0.0   # удар ногой — стоит на опорной ноге
	_calibrate()
	_char.position.y = y - drop + _loco_y + lerpf(_lift, _lift_square, square)
	_char.rotation.y = rot
	# Применяем: ноги и корпус — поворотами костей, руки — IK
	for k in ["L", "R"]:
		var bones: Array = _legs[k][0]
		var axes: Array = _legs[k][1]
		for b in bones:
			_mod.set_rest_blend(b, square)
	_mod.set_rest_blend(_hips, square)
	for k in ["L", "R"]:
		var bones: Array = _legs[k][0]
		var axes: Array = _legs[k][1]
		var a: Vector3 = (legs[k] + loco[k] + DIGI) * deg_to_rad(1.0)
		_mod.set_local(bones[0], axes[0], a.x)
		_mod.set_local(bones[1], axes[1], -a.y)
		_mod.set_local(bones[2], axes[2], -a.z)
		# Пальцы — параллельно земле: снимаем общий наклон бедра, голени и плюсны
		_mod.set_local(bones[3], axes[3], (a.y + a.z - a.x) * TOE_LEVEL)
	if _spine >= 0:
		_mod.set_local(_spine, _spine_axis, -deg_to_rad(lean))
	for b in _twist_bones:
		_mod.set_angle(b, Vector3.UP, deg_to_rad(twist) / _twist_bones.size())
	for k in ["L", "R"]:
		var ik: TwoBoneIK3D = _ik[k]
		ik.influence = clampf(arm_w[k], 0.0, 1.0)
		ik.active = arm_w[k] > 0.001

## Подъём тела под длинные ноги. Скелет отдаёт позу стойки без наших поворотов, поэтому
## сами проводим цепочку бедро → голень → плюсна → пальцы с растяжением и сгибами
## и поднимаем тело на столько, на сколько опустились пальцы.
func _calibrate() -> void:
	if _calib > 3:
		return
	_calib += 1
	if _calib < 3:
		return
	_lift = _leg_lift(false)
	_lift_square = _leg_lift(true)

## Насколько поднять тело, чтобы пальцы стояли на земле: в стойке из анимации или в позе покоя
func _leg_lift(rest: bool) -> float:
	var a := DIGI * deg_to_rad(1.0)
	var turns := [a.x, a.x - a.y, a.x - a.y - a.z, 0.0]
	var stretch := [LEG_STRETCH, LEG_STRETCH, META_STRETCH * LEG_STRETCH, 1.0]
	var lift := -INF
	var pose := func(b: int) -> Vector3: return _sk.get_bone_global_rest(b).origin if rest else _sk.get_bone_global_pose(b).origin
	# Низ стопы в стойке — точка отсчёта (там, где модель стоит на земле)
	var ground := INF
	for k in ["L", "R"]:
		ground = minf(ground, (_sk.get_bone_global_pose(_toe_ends[k] if _toe_ends[k] >= 0 else _legs[k][0][3])).origin.y)
	for k in ["L", "R"]:
		var bones: Array = _legs[k][0]
		var chain: Array = bones.map(pose)
		var tip: int = _toe_ends[k]
		chain.append(pose.call(tip) if tip >= 0 else chain[3])
		var p: Vector3 = chain[0] + (_sk.get_bone_global_pose(bones[0]).origin - chain[0])   # таз — из анимации
		for i in 4:
			var v: Vector3 = (chain[i + 1] - chain[i]) * stretch[i]
			p += v.rotated(_flex, turns[i]) if turns[i] != 0.0 else v
		lift = maxf(lift, ground - p.y)
	return lift * _char.scale.y

## Параметры шага при этой скорости: от спокойного шага к бегу
func _gait(speed: float) -> Dictionary:
	var s := clampf((speed - 1.0) / 4.0, 0.0, 1.0)
	var g := {}
	for key in WALK:
		g[key] = lerpf(WALK[key], RUN[key], s)
	# За время опоры бедро проходит от +swing до −swing: стопа уходит назад на 2·L·sin(swing)
	var stride := 2.0 * _leg_len * sin(deg_to_rad(g["swing"]))
	g["f"] = clampf(maxf(speed, 0.3) * g["duty"] / stride, 0.8, 5.0)
	return g

## Поза ноги в фазе шага: опора (бедро вперёд → назад) и перенос (колено сгибается)
func _step(p: float, g: Dictionary) -> Vector3:
	var d: float = g["duty"]
	var sw: float = g["swing"]
	if p < d:
		var s := p / d
		return Vector3(sw * (1.0 - 2.0 * s), 6.0, 18.0 * smoothstep(0.7, 1.0, s))
	var s := (p - d) / (1.0 - d)
	return Vector3(sw * (-1.0 + 2.0 * smoothstep(0.0, 1.0, s)), g["knee"] * sin(PI * s), -8.0 * sin(PI * s))

## Точка удара «вперёд, к цели» → система скелета довёрнутой модели.
## Кулаки в стойке взяты прямо из анимации — их не переводим.
func _fwd(q: Vector3, rot: float) -> Vector3:
	if q.is_equal_approx(GUARD_L) or q.is_equal_approx(GUARD_R):
		return _body(q)
	return Basis(Vector3.UP, -rot) * _body(q)

## Точки заданы для тела прежнего кролика; скелет оборотня подогнан под новое тело тем же
## переносом (tools/prepare_models.py shadowclaw): по высоте — ступни, плечи, макушка,
## по ширине — размах рук
const BODY_Y_OLD := [0.0, 0.734, 1.66]
const BODY_Y_NEW := [0.0, 1.02, 1.839]
const BODY_SX := 1.104
const BODY_DZ := 0.01
func _body(p: Vector3) -> Vector3:
	var y := p.y
	if y <= BODY_Y_OLD[1]:
		y = remap(y, BODY_Y_OLD[0], BODY_Y_OLD[1], BODY_Y_NEW[0], BODY_Y_NEW[1])
	else:
		y = remap(y, BODY_Y_OLD[1], BODY_Y_OLD[2], BODY_Y_NEW[1], BODY_Y_NEW[2])
	return Vector3(p.x * BODY_SX, y, p.z + BODY_DZ)

func _fwd_keys(keys: Array, rot: float) -> Array:
	return keys.map(func(k): return [k[0], _fwd(k[1], rot)])

## Значение дорожки ключей в момент t (числа или Vector3), с плавными переходами
func _track(keys: Array, t: float):
	if t <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var f := smoothstep(0.0, 1.0, (t - keys[i - 1][0]) / (keys[i][0] - keys[i - 1][0]))
			return lerp(keys[i - 1][1], keys[i][1], f)
	return keys[keys.size() - 1][1]

## Облачко пыли при толчке и приземлении
func _dust_at(at: float, size: float) -> void:
	if leap_t < at or _dust_done.has(at) or not Fx.root:
		return
	_dust_done[at] = true
	var base: Vector3 = _char.global_position
	base.y = _char.get_parent().global_position.y + 0.05
	for i in 7:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12 * size
		sm.height = 0.18 * size
		sm.radial_segments = 8
		sm.rings = 4
		m.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.62, 0.57, 0.48, 0.55)
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Fx.root.add_child(m)
		var a := TAU * i / 7.0 + randf() * 0.4
		m.global_position = base + Vector3(cos(a), 0, sin(a)) * 0.15
		var tw := m.create_tween().set_parallel(true)
		tw.tween_property(m, "global_position", base + Vector3(cos(a) * 0.6 * size, 0.12, sin(a) * 0.6 * size), 0.5)
		tw.tween_property(m, "scale", Vector3.ONE * 2.2, 0.5)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
		tw.chain().tween_callback(m.queue_free)
