## Движения героя в стиле игры про мечника (свои анимации, см. PoseLib).
## Меч в правой руке. Оси персонажа: X — влево, Y — вверх, Z — вперёд; углы в градусах.
## "sword" — куда смотрит клинок (кисть поворачивается сама).
class_name HeroMoves
extends RefCounted

## Руки опущены вдоль тела, ноги прямо (исходная поза модели — руки разведены)
const BASE := {
	"LeftArm": Vector3(0, 15, -52), "RightArm": Vector3(0, -15, 52),
	"LeftForeArm": Vector3(-10, 0, 0), "RightForeArm": Vector3(-10, 0, 0),
}

## Длина шага: метров за секунду анимации (для темпа шага по скорости героя)
const WALK_STRIDE := 1.37   # ходьба гоблина на скелете героя: 1,37 м за секунду анимации (замер tests/pose_view.tscn)
const RUN_STRIDE := 4.8     # бег модели героя: 4,8 м за секунду анимации (замер tests/gait.tscn)

static func _k(t: float, p: Dictionary, hips := Vector3.ZERO, sword = null) -> Dictionary:
	var k := {"t": t, "p": p, "hips": hips}
	if sword != null:
		k["sword"] = sword
	return k

# ---------- Стойка
## Вполоборота, колени согнуты, левая нога впереди, меч опущен справа остриём вниз-вперёд
static func stance_pose() -> Dictionary:
	return {
		"Hips": Vector3(0, -18, 0), "Spine": Vector3(6, 0, 0), "Spine1": Vector3(3, 4, 0), "Spine2": Vector3(3, 4, 0),
		"Neck": Vector3(0, 6, 0), "Head": Vector3(4, 4, 0),
		"LeftUpLeg": Vector3(-22, 18, 8), "LeftLeg": Vector3(26, 0, 0), "LeftFoot": Vector3(-4, 0, 0),
		"RightUpLeg": Vector3(14, 18, -8), "RightLeg": Vector3(14, 0, 0), "RightFoot": Vector3(-26, 0, 0),
		"RightArm": Vector3(-14, -10, 50), "RightForeArm": Vector3(-55, 0, 0),
		"LeftArm": Vector3(-34, 10, -46), "LeftForeArm": Vector3(-38, 0, 0),
	}
## Меч в стойке — как держит человек (фото-образец): кулак, клинок вперёд и вверх по диагонали
const STANCE_SWORD := Vector3(-0.05, 0.55, 0.85)
## Левая рука вытянута вперёд, тыльная сторона ладони смотрит вверх
const STANCE_LBACK := Vector3(0, 1, 0.15)
const STANCE_HIPS := Vector3(0, -0.09, 0)

static func stance() -> Array:
	var p := stance_pose()
	var p2 := p.duplicate()
	p2["Spine2"] = Vector3(5, 4, 0)
	p2["LeftArm"] = Vector3(-36, 10, -45)
	var out := [
		_k(0.0, p, STANCE_HIPS, STANCE_SWORD),
		_k(1.2, p2, STANCE_HIPS + Vector3(0, -0.012, 0), STANCE_SWORD),
		_k(2.4, p, STANCE_HIPS, STANCE_SWORD),
	]
	for k in out:
		k["lback"] = STANCE_LBACK
	return out

# ---------- Ходьба и бег: ноги и корпус — из записей живых движений (ходьба гоблина
# переносится на героя, бег — собственная запись модели героя), а правая рука — своя:
# опущена вдоль тела, запястье прямое, меч смотрит вперёд (как держит человек, фото-образец)
const WALK_SWORD := Vector3(-0.12, -0.2, 1.0)
const RUN_SWORD := Vector3(-0.15, -0.25, 1.0)

static func _arm_keys(length: float, arm_back: float, arm_fwd: float, elbow: float, sword: Vector3, left_swing := 0.0) -> Array:
	var a := {"RightArm": Vector3(arm_back, -12, 48), "RightForeArm": Vector3(-elbow, 0, 0)}
	var b := {"RightArm": Vector3(arm_fwd, -12, 48), "RightForeArm": Vector3(-elbow - 6, 0, 0)}
	if left_swing > 0.0:
		# Левая рука опущена и качается в такт шагу (навстречу правой ноге)
		a["LeftArm"] = Vector3(-left_swing, 12, -52)
		a["LeftForeArm"] = Vector3(-18, 0, 0)
		b["LeftArm"] = Vector3(left_swing, 12, -52)
		b["LeftForeArm"] = Vector3(-10, 0, 0)
	return [_k(0.0, a, Vector3.ZERO, sword), _k(length * 0.5, b, Vector3.ZERO, sword), _k(length, a, Vector3.ZERO, sword)]

# ---------- Уклонения
static func _crouch(depth: float) -> Dictionary:
	return {
		"Spine": Vector3(18, 0, 0), "Spine1": Vector3(6, 0, 0), "Neck": Vector3(-14, 0, 0),
		"LeftUpLeg": Vector3(-35 * depth, 10, 6), "LeftLeg": Vector3(60 * depth, 0, 0), "LeftFoot": Vector3(-25 * depth, 0, 0),
		"RightUpLeg": Vector3(-35 * depth, -10, -6), "RightLeg": Vector3(60 * depth, 0, 0), "RightFoot": Vector3(-25 * depth, 0, 0),
		"RightArm": Vector3(-25, -10, 55), "RightForeArm": Vector3(-40, 0, 0),
		"LeftArm": Vector3(-30, 10, -50), "LeftForeArm": Vector3(-50, 0, 0),
	}

## Отскок назад: присел → прыжок назад, ноги вперёд → приземлился → стойка
static func dodge_back() -> Array:
	var air := _crouch(0.5)
	air["LeftUpLeg"] = Vector3(-30, 10, 6)
	air["RightUpLeg"] = Vector3(-22, -10, -6)
	air["LeftLeg"] = Vector3(25, 0, 0)
	air["RightLeg"] = Vector3(35, 0, 0)
	air["Spine"] = Vector3(10, 0, 0)
	air["LeftArm"] = Vector3(-40, 10, -35)
	air["RightArm"] = Vector3(-35, -10, 40)
	return [
		_k(0.0, stance_pose(), STANCE_HIPS, STANCE_SWORD),
		_k(0.08, _crouch(1.0), Vector3(0, -0.24, 0), STANCE_SWORD),
		_k(0.22, air, Vector3(0, 0.02, -0.05), Vector3(-0.3, -0.6, 0.7)),
		_k(0.36, _crouch(0.9), Vector3(0, -0.2, 0), STANCE_SWORD),
		_k(0.55, stance_pose(), STANCE_HIPS, STANCE_SWORD),
	]

## Шаг-отскок влево (вправо — зеркально): корпус наклонён против движения
static func dodge_left() -> Array:
	var push := _crouch(0.9)
	var air := _crouch(0.4)
	air["LeftUpLeg"] = Vector3(-15, 10, 28)
	air["RightUpLeg"] = Vector3(-10, -10, 12)
	air["Spine"] = Vector3(10, 0, -14)
	air["Spine1"] = Vector3(4, 0, -6)
	air["Neck"] = Vector3(-10, 0, 14)
	air["LeftArm"] = Vector3(-30, 10, -30)
	return [
		_k(0.0, stance_pose(), STANCE_HIPS, STANCE_SWORD),
		_k(0.07, push, Vector3(0, -0.2, 0), STANCE_SWORD),
		_k(0.2, air, Vector3(0.05, -0.02, 0), STANCE_SWORD),
		_k(0.32, _crouch(0.8), Vector3(0, -0.18, 0), STANCE_SWORD),
		_k(0.5, stance_pose(), STANCE_HIPS, STANCE_SWORD),
	]

static func dodge_right() -> Array:
	var out := []
	for k in dodge_left():
		var p := PoseLib.mirror(k["p"])
		# Меч остаётся в правой руке
		for b in ["RightArm", "RightForeArm"]:
			p[b] = k["p"][b]
		var h: Vector3 = k["hips"]
		out.append(_k(k["t"], p, Vector3(-h.x, h.y, h.z), k.get("sword")))
	return out

## Кувырок вперёд: группировка, оборот через голову, встаёт в стойку
static func roll() -> Array:
	var tuck := {
		"Spine": Vector3(45, 0, 0), "Spine1": Vector3(20, 0, 0), "Spine2": Vector3(10, 0, 0), "Neck": Vector3(25, 0, 0), "Head": Vector3(15, 0, 0),
		"LeftUpLeg": Vector3(-110, 8, 6), "LeftLeg": Vector3(130, 0, 0), "LeftFoot": Vector3(-20, 0, 0),
		"RightUpLeg": Vector3(-110, -8, -6), "RightLeg": Vector3(130, 0, 0), "RightFoot": Vector3(-20, 0, 0),
		"RightArm": Vector3(-60, -10, 40), "RightForeArm": Vector3(-60, 0, 0),
		"LeftArm": Vector3(-60, 10, -40), "LeftForeArm": Vector3(-70, 0, 0),
	}
	var sw := Vector3(0, -0.4, 1)
	var t1 := tuck.duplicate()
	t1["Hips"] = Vector3(100, 0, 0)
	var t2 := tuck.duplicate()
	t2["Hips"] = Vector3(200, 0, 0)
	var t3 := tuck.duplicate()
	t3["Hips"] = Vector3(300, 0, 0)
	var up := _crouch(1.0)
	up["Hips"] = Vector3(355, 0, 0)
	return [
		_k(0.0, stance_pose(), STANCE_HIPS, STANCE_SWORD),
		_k(0.1, _crouch(1.2), Vector3(0, -0.3, 0), sw),
		_k(0.22, t1, Vector3(0, -0.45, 0), sw),
		_k(0.34, t2, Vector3(0, -0.5, 0), sw),
		_k(0.46, t3, Vector3(0, -0.45, 0), sw),
		_k(0.58, up, Vector3(0, -0.28, 0), STANCE_SWORD),
		_k(0.72, stance_pose(), STANCE_HIPS, STANCE_SWORD),
	]

## «Переключение» после отбитого удара: отскок назад с мечом в защите, левая рука вперёд
static func switch() -> Array:
	var guard := _crouch(0.6)
	guard["RightArm"] = Vector3(-55, -30, 30)
	guard["RightForeArm"] = Vector3(-50, 0, 0)
	guard["LeftArm"] = Vector3(-60, 20, -30)
	guard["LeftForeArm"] = Vector3(-10, 0, 0)
	var air := guard.duplicate()
	air["LeftUpLeg"] = Vector3(-28, 10, 6)
	air["RightUpLeg"] = Vector3(-18, -10, -6)
	air["LeftLeg"] = Vector3(25, 0, 0)
	air["RightLeg"] = Vector3(30, 0, 0)
	var sw := Vector3(-0.2, 0.7, 0.7)
	return [
		_k(0.0, stance_pose(), STANCE_HIPS, STANCE_SWORD),
		_k(0.07, guard, Vector3(0, -0.18, 0), sw),
		_k(0.2, air, Vector3(0, 0.02, -0.05), sw),
		_k(0.32, guard, Vector3(0, -0.16, 0), sw),
		_k(0.5, stance_pose(), STANCE_HIPS, STANCE_SWORD),
	]

# ---------- Реакции
## Сильное попадание: корпус откинуло назад, руки взлетели, шаг назад
static func hit_heavy() -> Array:
	var back := stance_pose()
	back["Spine"] = Vector3(-22, 0, 0)
	back["Spine1"] = Vector3(-10, 0, 0)
	back["Neck"] = Vector3(-10, 0, 0)
	back["Head"] = Vector3(-18, 0, 0)
	back["RightArm"] = Vector3(-30, -10, 30)
	back["LeftArm"] = Vector3(-40, 10, -20)
	back["LeftForeArm"] = Vector3(-30, 0, 0)
	var step := stance_pose()
	step["Spine"] = Vector3(10, 0, 0)
	step["RightUpLeg"] = Vector3(24, 18, -8)
	step["RightLeg"] = Vector3(30, 0, 0)
	step["LeftUpLeg"] = Vector3(-10, 18, 8)
	return [
		_k(0.0, stance_pose(), STANCE_HIPS, STANCE_SWORD),
		_k(0.08, back, Vector3(0, -0.06, -0.12), Vector3(-0.6, -0.2, 0.5)),
		_k(0.3, step, Vector3(0, -0.14, -0.08), STANCE_SWORD),
		_k(0.55, stance_pose(), STANCE_HIPS, STANCE_SWORD),
	]

## Оглушение (петля): сгорбился, голова опущена, покачивается
static func stun() -> Array:
	var p := {
		"Spine": Vector3(28, 0, 4), "Spine1": Vector3(10, 0, 0), "Neck": Vector3(10, 0, 0), "Head": Vector3(20, 0, 6),
		"LeftUpLeg": Vector3(-14, 10, 6), "LeftLeg": Vector3(26, 0, 0), "LeftFoot": Vector3(-12, 0, 0),
		"RightUpLeg": Vector3(-6, -10, -6), "RightLeg": Vector3(20, 0, 0), "RightFoot": Vector3(-14, 0, 0),
		"RightArm": Vector3(-10, -10, 68), "RightForeArm": Vector3(-15, 0, 0),
		"LeftArm": Vector3(-14, 10, -66), "LeftForeArm": Vector3(-20, 0, 0),
	}
	var p2 := p.duplicate()
	p2["Spine"] = Vector3(30, 0, -5)
	p2["Head"] = Vector3(24, 0, -8)
	var sw := Vector3(-0.2, -1, 0.2)
	return [
		_k(0.0, p, Vector3(0.03, -0.12, 0), sw),
		_k(0.6, p2, Vector3(-0.03, -0.14, 0), sw),
		_k(1.2, p, Vector3(0.03, -0.12, 0), sw),
	]

## Сбит с ног: откинуло назад, падает на спину и лежит
static func lying_pose() -> Dictionary:
	return {
		"Hips": Vector3(-88, 0, 0), "Spine": Vector3(4, 0, 0), "Neck": Vector3(14, 0, 0), "Head": Vector3(10, 0, 0),
		"LeftUpLeg": Vector3(-14, 10, 10), "LeftLeg": Vector3(20, 0, 0), "LeftFoot": Vector3(30, 0, 0),
		"RightUpLeg": Vector3(-24, -10, -8), "RightLeg": Vector3(36, 0, 0), "RightFoot": Vector3(30, 0, 0),
		"RightArm": Vector3(0, -40, 30), "RightForeArm": Vector3(-10, 0, 0),
		"LeftArm": Vector3(0, 40, -30), "LeftForeArm": Vector3(-20, 0, 0),
	}
const LYING_HIPS := Vector3(0, -0.8, -0.35)

static func knockdown() -> Array:
	var thrown := stance_pose()
	thrown["Spine"] = Vector3(-26, 0, 0)
	thrown["Head"] = Vector3(-20, 0, 0)
	thrown["RightArm"] = Vector3(-50, -10, 20)
	thrown["LeftArm"] = Vector3(-50, 10, -20)
	var fall := lying_pose()
	fall["Hips"] = Vector3(-50, 0, 0)
	fall["LeftUpLeg"] = Vector3(-50, 10, 10)
	fall["RightUpLeg"] = Vector3(-40, -10, -8)
	var sw := Vector3(-0.8, 0, 0.4)
	return [
		_k(0.0, stance_pose(), STANCE_HIPS, STANCE_SWORD),
		_k(0.1, thrown, Vector3(0, -0.05, -0.15), sw),
		_k(0.32, fall, Vector3(0, -0.5, -0.3), sw),
		_k(0.5, lying_pose(), LYING_HIPS + Vector3(0, 0.04, 0), sw),
		_k(0.65, lying_pose(), LYING_HIPS, sw),
	]

## Подъём: сел → на колено → встал в стойку
static func getup() -> Array:
	var sit := {
		"Hips": Vector3(-30, 0, 0), "Spine": Vector3(40, 0, 0), "Spine1": Vector3(10, 0, 0), "Neck": Vector3(-10, 0, 0),
		"LeftUpLeg": Vector3(-60, 10, 10), "LeftLeg": Vector3(90, 0, 0), "LeftFoot": Vector3(-20, 0, 0),
		"RightUpLeg": Vector3(-40, -10, -8), "RightLeg": Vector3(50, 0, 0), "RightFoot": Vector3(10, 0, 0),
		"RightArm": Vector3(20, -10, 50), "RightForeArm": Vector3(-20, 0, 0),
		"LeftArm": Vector3(20, 10, -50), "LeftForeArm": Vector3(-20, 0, 0),
	}
	var kneel := {
		"Spine": Vector3(30, 0, 0), "Spine1": Vector3(8, 0, 0), "Neck": Vector3(-14, 0, 0),
		"LeftUpLeg": Vector3(-80, 10, 6), "LeftLeg": Vector3(90, 0, 0), "LeftFoot": Vector3(-10, 0, 0),
		"RightUpLeg": Vector3(5, -10, -6), "RightLeg": Vector3(95, 0, 0), "RightFoot": Vector3(-30, 0, 0),
		"RightArm": Vector3(-20, -10, 60), "RightForeArm": Vector3(-30, 0, 0),
		"LeftArm": Vector3(-30, 10, -50), "LeftForeArm": Vector3(-40, 0, 0),
	}
	var sw := Vector3(-0.5, -0.6, 0.6)
	return [
		_k(0.0, lying_pose(), LYING_HIPS, Vector3(-0.8, 0, 0.4)),
		_k(0.25, sit, Vector3(0, -0.62, -0.25), sw),
		_k(0.5, kneel, Vector3(0, -0.42, 0), sw),
		_k(0.8, stance_pose(), STANCE_HIPS, STANCE_SWORD),
	]

# ---------- Приём «Горизонталь»: замах вправо-назад → широкий взмах справа налево
const HZ_CHARGE := 0.3        # конец замаха (стойка приёма, клинок светится)
const HZ_HIT := 0.4           # середина взмаха — момент удара
const HZ_LEN := 0.95

static func horizontal() -> Array:
	var legs := {
		"LeftUpLeg": Vector3(-32, 25, 12), "LeftLeg": Vector3(40, 0, 0), "LeftFoot": Vector3(-8, 0, 0),
		"RightUpLeg": Vector3(18, 25, -12), "RightLeg": Vector3(24, 0, 0), "RightFoot": Vector3(-38, 0, 0),
	}
	var wind := PoseLib.merge(legs, {
		"Hips": Vector3(0, -40, 0), "Spine": Vector3(8, -18, 0), "Spine1": Vector3(4, -12, 0), "Spine2": Vector3(0, -8, 0),
		"Neck": Vector3(0, 40, 0), "Head": Vector3(0, 20, 0),
		"RightArm": Vector3(0, -45, -5), "RightForeArm": Vector3(0, -20, 0),
		"LeftArm": Vector3(-60, 30, -30), "LeftForeArm": Vector3(-20, 0, 0),
	})
	var mid := PoseLib.merge(legs, {
		"Hips": Vector3(0, -5, 0), "Spine": Vector3(8, 0, 0), "Spine1": Vector3(4, 2, 0), "Spine2": Vector3(0, 2, 0),
		"Neck": Vector3(0, 4, 0),
		"RightArm": Vector3(0, 35, -12), "RightForeArm": Vector3(0, -10, 0),
		"LeftArm": Vector3(-20, 30, -55), "LeftForeArm": Vector3(-30, 0, 0),
	})
	var follow := PoseLib.merge(legs, {
		"Hips": Vector3(0, 25, 0), "Spine": Vector3(8, 18, 0), "Spine1": Vector3(4, 12, 0), "Spine2": Vector3(0, 8, 0),
		"Neck": Vector3(0, -30, 0), "Head": Vector3(0, -15, 0),
		"RightArm": Vector3(0, 95, -10), "RightForeArm": Vector3(0, 10, 0),
		"LeftArm": Vector3(10, 30, -62), "LeftForeArm": Vector3(-30, 0, 0),
	})
	return [
		_k(0.0, stance_pose(), STANCE_HIPS, STANCE_SWORD),
		_k(HZ_CHARGE, wind, Vector3(0, -0.15, 0), Vector3(-0.75, 0.1, -0.65)),
		_k(HZ_HIT, mid, Vector3(0, -0.16, 0.08), Vector3(-0.1, 0.0, 1.0)),
		_k(0.5, follow, Vector3(0, -0.15, 0.1), Vector3(0.95, 0.0, 0.2)),
		_k(0.65, follow, Vector3(0, -0.13, 0.1), Vector3(0.8, -0.2, -0.4)),
		_k(HZ_LEN, stance_pose(), STANCE_HIPS, STANCE_SWORD),
	]

## Все движения: имя → [ключи, длина, петля]
static func all() -> Dictionary:
	return {
		"dodge_back": [dodge_back(), 0.55, false],
		"dodge_left": [dodge_left(), 0.5, false],
		"dodge_right": [dodge_right(), 0.5, false],
		"roll": [roll(), 0.72, false],
		"switch": [switch(), 0.5, false],
		"hit_heavy": [hit_heavy(), 0.55, false],
		"stun": [stun(), 1.2, true],
		"knockdown": [knockdown(), 0.65, false],
		"getup": [getup(), 0.8, false],
		"horizontal": [horizontal(), HZ_LEN, false],
	}

const GOBLIN_PATH := "res://models/goblin.glb"
static var walk_stride := WALK_STRIDE
static var run_stride := RUN_STRIDE
const MESHY_RUN_STRIDE := 3.2    # спринт Meshy: 3,2 м за секунду анимации (замер tests/pose_view.tscn)
const MESHY_WALK_STRIDE := 0.6   # боевой шаг Meshy: 0,6 м/с

## Собрать библиотеку анимаций для скелета героя. player — анимации модели героя (бег)
static func library(sk: Skeleton3D, player: AnimationPlayer, ref: Animation, ref_t: float, prefix: String, blade: Vector3) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var moves := all()
	for name in moves:
		var m: Array = moves[name]
		if PoseLib.aim_log:
			print(name)
		lib.add_animation(name, PoseLib.build(sk, m[0], BASE, m[1], m[2], ref, ref_t, prefix, blade))
	# Бег: спринт из библиотеки Meshy (корпус вперёд) как есть, без своих поз рук
	var run_name := "Lean_Forward_Sprint" if player.has_animation("Lean_Forward_Sprint") else "Running"
	run_stride = MESHY_RUN_STRIDE if run_name == "Lean_Forward_Sprint" else RUN_STRIDE
	if player.has_animation(run_name):
		var run_src := player.get_animation(run_name)
		run_src.loop_mode = Animation.LOOP_LINEAR
		if PoseLib.aim_log:
			print("run")
		if run_name == "Lean_Forward_Sprint":
			lib.add_animation("run", run_src.duplicate(true))
		else:
			lib.add_animation("run", PoseLib.override(run_src, sk, _arm_keys(run_src.length, 18, 6, 18, RUN_SWORD), {}, prefix, blade))
	# Ходьба: боевой шаг из библиотеки Meshy (меч поднят наготове) — или ходьба гоблина
	if player.has_animation("Walk_Fight_Forward"):
		var wf := player.get_animation("Walk_Fight_Forward").duplicate(true) as Animation
		wf.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("walk", wf)
		walk_stride = MESHY_WALK_STRIDE
	elif ResourceLoader.exists(GOBLIN_PATH):
		var g: Node = (load(GOBLIN_PATH) as PackedScene).instantiate()
		var gsk: Skeleton3D = g.find_children("*", "Skeleton3D", true, false)[0]
		var gap: AnimationPlayer = g.find_children("*", "AnimationPlayer", true, false)[0]
		if gap.has_animation("Walking"):
			var w := PoseLib.retarget(gsk, gap.get_animation("Walking"), sk, prefix)
			w.loop_mode = Animation.LOOP_LINEAR
			_shift_hips(w, Vector3(0, -0.06, 0))   # ноги гоблина короче — опускаем таз, чтобы стопы стояли на земле
			if PoseLib.aim_log:
				print("walk")
			w = PoseLib.override(w, sk, _arm_keys(w.length, 10, -4, 14, WALK_SWORD, 16.0), {}, prefix, blade)
			# Пальцы, которых нет у гоблина, — из образца (хват меча)
			_add_missing(w, sk, ref, ref_t)
			lib.add_animation("walk", w)
		g.free()
	return lib

static func _shift_hips(anim: Animation, d: Vector3) -> void:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			for k in anim.track_get_key_count(t):
				anim.track_set_key_value(t, k, (anim.track_get_key_value(t, k) as Vector3) + d)

## Кости, которых нет в анимации (пальцы), — постоянной позой из образца
static func _add_missing(anim: Animation, sk: Skeleton3D, ref: Animation, ref_t: float) -> void:
	var have := {}
	for t in anim.get_track_count():
		have[String(anim.track_get_path(t))] = true
	for t in ref.get_track_count():
		if ref.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var path := String(ref.track_get_path(t))
		if have.has(path) or path.ends_with("Hips"):
			continue
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath(path))
		anim.rotation_track_insert_key(tr, 0.0, ref.rotation_track_interpolate(t, ref_t))
