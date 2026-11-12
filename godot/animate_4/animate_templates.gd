## ANIMATE 4.0 — шаг 3 конвейера: библиотека ключевых поз всего тела (детерминированные шаблоны).
## Позы — повороты костей в осях персонажа (X — влево, Y — вверх, Z — вперёд), градусы, поверх стойки
## (см. PoseLib): «рука вперёд» = −X, «колено согнуто» = +X, «корпус влево» = +Y, «отвести правую
## руку в сторону» = −Z. Таз: сдвиг "hips" в метрах. Клинок: "sword" — куда смотрит (оси персонажа).
## Контакты: "plant" — стопы, стоящие на земле в этом ключе (стопа, стоящая в двух ключах подряд,
## не скользит между ними — это обеспечивает IK). Фазы: ready / anticipation / active / recovery.
class_name AnimateTemplates
extends RefCounted

## Стойка с одним мечом: меч в правой руке опущен вправо-вниз, левая рука отведена назад,
## ноги расставлены, колени чуть согнуты
const STANCE := {
	"Spine": Vector3(6, 0, 0), "Spine1": Vector3(2, 0, 0), "Neck": Vector3(-4, 0, 0),
	"LeftUpLeg": Vector3(-12, 0, 8), "LeftLeg": Vector3(18, 0, 0), "LeftFoot": Vector3(-6, 0, -4),
	"RightUpLeg": Vector3(10, 0, -9), "RightLeg": Vector3(16, 0, 0), "RightFoot": Vector3(-26, 0, 4),
	"RightArm": Vector3(-8, 0, 8), "RightForeArm": Vector3(-25, 0, 0),
	"LeftArm": Vector3(28, 0, -4), "LeftForeArm": Vector3(-18, 0, 0),
}
const STANCE_HIPS := Vector3(0, -0.035, 0)
const STANCE_SWORD := Vector3(-0.62, -0.72, 0.3)

## Шаблон движения по параметрам: {length, keys: [{u, phase, p, hips, sword?, plant}], name}
static func build(spec: Dictionary) -> Dictionary:
	match spec["motion"]:
		"thrust_dash": return _thrust_dash()
		"horizontal": return _horizontal()
		"whirl": return _whirl()
		"block_sword": return _block_sword()
		"block_shield": return _block_shield()
		"dash": return _dash(spec["dir"], spec["from_run"])
		"stance": return _stance_loop()
		"sheathe": return _sheathe()
	return {}

static func _k(u: float, phase: String, p: Dictionary, hips: Vector3, plant: Array, sword := Vector3.ZERO) -> Dictionary:
	var key := {"u": u, "phase": phase, "p": PoseLib.merge(STANCE, p), "hips": hips, "plant": plant}
	if sword != Vector3.ZERO:
		key["sword"] = sword.normalized()
	return key

static func _stance(u: float, phase: String, plant := ["LeftFoot", "RightFoot"]) -> Dictionary:
	return _k(u, phase, {}, STANCE_HIPS, plant, STANCE_SWORD)

## Стойка с одним мечом (петля): лёгкое дыхание — таз чуть опускается, корпус чуть наклоняется
static func _stance_loop() -> Dictionary:
	var both := ["LeftFoot", "RightFoot"]
	var breath := {"Spine": Vector3(8, 0, 0), "Spine1": Vector3(3, 0, 0), "RightArm": Vector3(-9, 0, 9), "LeftArm": Vector3(30, 0, -5)}
	return {"name": "stance", "length": 2.4, "loop": true, "keys": [
		_stance(0.0, "ready", both),
		_k(0.5, "ready", breath, STANCE_HIPS + Vector3(0, -0.012, 0), both, STANCE_SWORD),
		_stance(1.0, "ready", both),
	]}

# ---------------------------------------------------------------- атаки

## Молниеносный колющий выпад с рывком: подготовка (корпус и меч назад, вес на задней ноге,
## присед) → взрывной выпад (таз вперёд и вниз, передняя нога шагает, задняя выпрямляется,
## корпус наклонён, рука и клинок прямо вперёд, левая рука назад) → фиксация → возврат в стойку
static func _thrust_dash() -> Dictionary:
	var load_p := {"Spine": Vector3(10, -24, 0), "Spine1": Vector3(4, -10, 0),
		"RightArm": Vector3(30, 0, 12), "RightForeArm": Vector3(-85, 0, 0), "LeftArm": Vector3(-40, 0, -18), "LeftForeArm": Vector3(-30, 0, 0),
		"LeftUpLeg": Vector3(-26, 0, 8), "LeftLeg": Vector3(38, 0, 0), "LeftFoot": Vector3(-12, 0, -4),
		"RightUpLeg": Vector3(6, 0, -9), "RightLeg": Vector3(38, 0, 0), "RightFoot": Vector3(-44, 0, 4)}
	var hit := {"Spine": Vector3(20, 22, 0), "Spine1": Vector3(6, 10, 0), "Neck": Vector3(-14, -12, 0),
		"RightArm": Vector3(-84, 0, 4), "RightForeArm": Vector3(-4, 0, 0), "LeftArm": Vector3(42, 0, -26), "LeftForeArm": Vector3(-10, 0, 0),
		"LeftUpLeg": Vector3(-62, 0, 6), "LeftLeg": Vector3(66, 0, 0), "LeftFoot": Vector3(-4, 0, -4),
		"RightUpLeg": Vector3(30, 0, -6), "RightLeg": Vector3(20, 0, 0), "RightFoot": Vector3(-24, 0, 4)}
	return {"name": "thrust_dash", "length": 0.9, "keys": [
		_stance(0.0, "ready"),
		_k(0.22, "anticipation", load_p, Vector3(0, -0.1, -0.06), ["LeftFoot", "RightFoot"], Vector3(-0.1, 0.1, 1)),
		_k(0.33, "active", PoseLib.merge(hit, {"LeftUpLeg": Vector3(-70, 0, 6), "LeftLeg": Vector3(95, 0, 0), "LeftFoot": Vector3(-20, 0, -4),
			"RightArm": Vector3(-60, 0, 8), "RightForeArm": Vector3(-30, 0, 0)}), Vector3(0, -0.15, 0.12), ["RightFoot"], Vector3(0, 0.05, 1)),
		_k(0.42, "active", hit, Vector3(0, -0.2, 0.2), ["LeftFoot", "RightFoot"], Vector3(0, 0.02, 1)),
		_k(0.6, "active", hit, Vector3(0, -0.21, 0.21), ["LeftFoot", "RightFoot"], Vector3(0, 0.02, 1)),
		_k(0.82, "recovery", PoseLib.merge(hit, {"RightArm": Vector3(-30, 0, 8), "RightForeArm": Vector3(-30, 0, 0), "Spine": Vector3(10, 8, 0)}),
			Vector3(0, -0.1, 0.1), ["RightFoot"], Vector3(-0.3, -0.3, 0.9)),
		_stance(1.0, "recovery"),
	]}

## Горизонтальный удар: замах вправо-назад (корпус и таз повёрнуты вправо, вес на правой ноге) →
## проводка клинка горизонтально через центр → завершение влево (вес на левой ноге) → стойка
static func _horizontal() -> Dictionary:
	var wind := {"Hips": Vector3(0, -16, 0), "Spine": Vector3(6, -40, 0), "Spine1": Vector3(0, -14, 0), "Neck": Vector3(-4, 30, 0),
		"RightArm": Vector3(-25, 0, -70), "RightForeArm": Vector3(-35, 0, 0), "LeftArm": Vector3(-48, 0, -12), "LeftForeArm": Vector3(-35, 0, 0),
		"LeftUpLeg": Vector3(-14, 0, 10), "LeftLeg": Vector3(26, 0, 0), "LeftFoot": Vector3(-12, 0, -4),
		"RightUpLeg": Vector3(6, 0, -10), "RightLeg": Vector3(28, 0, 0), "RightFoot": Vector3(-34, 0, 4)}
	var mid := {"Spine": Vector3(10, 0, 0), "RightArm": Vector3(-82, 0, -14), "RightForeArm": Vector3(-8, 0, 0),
		"LeftArm": Vector3(10, 0, -20), "LeftForeArm": Vector3(-20, 0, 0),
		"LeftUpLeg": Vector3(-18, 0, 9), "LeftLeg": Vector3(30, 0, 0), "LeftFoot": Vector3(-12, 0, -4),
		"RightUpLeg": Vector3(8, 0, -9), "RightLeg": Vector3(30, 0, 0), "RightFoot": Vector3(-38, 0, 4)}
	var follow := {"Hips": Vector3(0, 20, 0), "Spine": Vector3(10, 42, 0), "Spine1": Vector3(0, 14, 0), "Neck": Vector3(-6, -30, 0),
		"RightArm": Vector3(-74, 0, 40), "RightForeArm": Vector3(-14, 0, 0), "LeftArm": Vector3(36, 0, -30), "LeftForeArm": Vector3(-14, 0, 0),
		"LeftUpLeg": Vector3(-20, 0, 9), "LeftLeg": Vector3(32, 0, 0), "LeftFoot": Vector3(-12, 0, -4),
		"RightUpLeg": Vector3(10, 0, -9), "RightLeg": Vector3(24, 0, 0), "RightFoot": Vector3(-34, 0, 4)}
	var both := ["LeftFoot", "RightFoot"]
	return {"name": "horizontal", "length": 0.85, "keys": [
		_stance(0.0, "ready"),
		_k(0.3, "anticipation", wind, Vector3(-0.05, -0.08, -0.03), both, Vector3(-0.85, 0.15, -0.4)),
		_k(0.4, "active", PoseLib.merge(mid, {"Hips": Vector3(0, -8, 0), "Spine": Vector3(8, -22, 0), "RightArm": Vector3(-58, 0, -48), "RightForeArm": Vector3(-18, 0, 0)}),
			Vector3(-0.02, -0.09, 0.0), both, Vector3(-0.95, 0.08, 0.3)),
		_k(0.48, "active", mid, Vector3(0, -0.1, 0.02), both, Vector3(0, 0.02, 1)),
		_k(0.64, "active", follow, Vector3(0.05, -0.1, 0.03), both, Vector3(0.85, 0.05, 0.4)),
		_k(0.82, "recovery", PoseLib.merge(follow, {"RightArm": Vector3(-30, 0, 20), "RightForeArm": Vector3(-30, 0, 0), "Spine": Vector3(8, 18, 0), "Hips": Vector3(0, 8, 0)}),
			Vector3(0.02, -0.07, 0.01), both, Vector3(0.2, -0.6, 0.7)),
		_stance(1.0, "recovery"),
	]}

## Вихрь: замах, полный оборот на левой ноге с мечом, вытянутым вбок, — круговой удар → стойка
static func _whirl() -> Dictionary:
	var spin := {"Spine": Vector3(10, 0, 0), "RightArm": Vector3(-14, 0, -80), "RightForeArm": Vector3(-10, 0, 0),
		"LeftArm": Vector3(10, 0, 50), "LeftForeArm": Vector3(-20, 0, 0),
		"LeftUpLeg": Vector3(-20, 0, 6), "LeftLeg": Vector3(32, 0, 0), "LeftFoot": Vector3(-12, 0, -4),
		"RightUpLeg": Vector3(-10, 0, -22), "RightLeg": Vector3(44, 0, 0), "RightFoot": Vector3(-20, 0, 4)}
	var keys := [_stance(0.0, "ready"),
		_k(0.15, "anticipation", PoseLib.merge(spin, {"Hips": Vector3(0, -35, 0), "Spine": Vector3(8, -25, 0)}), Vector3(0, -0.09, 0), ["LeftFoot", "RightFoot"],
			Vector3(-0.9, 0.05, -0.4))]
	var i := 0
	for yaw in [60.0, 150.0, 240.0, 330.0]:
		var u: float = 0.3 + 0.13 * i
		var dir := Vector3(-1, 0.02, 0.25).rotated(Vector3.UP, deg_to_rad(yaw))
		keys.append(_k(u, "active", PoseLib.merge(spin, {"Hips": Vector3(0, yaw, 0)}), Vector3(0, -0.1, 0), ["LeftFoot"], dir))
		i += 1
	keys.append(_k(0.86, "recovery", PoseLib.merge(spin, {"Hips": Vector3(0, 360, 0), "RightArm": Vector3(-30, 0, -30)}), Vector3(0, -0.07, 0), ["LeftFoot", "RightFoot"], Vector3(-0.5, -0.4, 0.7)))
	keys.append(_stance(1.0, "recovery"))
	return {"name": "whirl", "length": 1.1, "keys": keys}

# ---------------------------------------------------------------- защита

## Блок мечом: клинок горизонтально перед лицом, левая рука поддерживает, колени согнуты
static func _block_sword() -> Dictionary:
	var guard := {"Spine": Vector3(8, -8, 0), "Neck": Vector3(-6, 6, 0),
		"RightArm": Vector3(-72, 0, -6), "RightForeArm": Vector3(-72, 0, 0),
		"LeftArm": Vector3(-58, 0, -12), "LeftForeArm": Vector3(-82, 0, 0),
		"LeftUpLeg": Vector3(-20, 0, 9), "LeftLeg": Vector3(32, 0, 0), "LeftFoot": Vector3(-12, 0, -4),
		"RightUpLeg": Vector3(10, 0, -9), "RightLeg": Vector3(30, 0, 0), "RightFoot": Vector3(-40, 0, 4)}
	var both := ["LeftFoot", "RightFoot"]
	return {"name": "block_sword", "length": 0.8, "hold_from": 0.35, "keys": [
		_stance(0.0, "ready"),
		_k(0.35, "active", guard, Vector3(0, -0.08, -0.02), both, Vector3(1, 0.06, 0.12)),
		_k(0.75, "active", guard, Vector3(0, -0.08, -0.02), both, Vector3(1, 0.06, 0.12)),
		_k(1.0, "recovery", guard, Vector3(0, -0.08, -0.02), both, Vector3(1, 0.06, 0.12)),
	]}

## Блок щитом: щит на левом предплечье выставлен вперёд (предплечье вертикально перед грудью),
## корпус развёрнут щитом вперёд, меч справа сзади наготове, левая нога впереди, присед
static func _block_shield() -> Dictionary:
	var guard := {"Spine": Vector3(12, 14, 0), "Neck": Vector3(-8, -12, 0),
		"LeftArm": Vector3(-78, 0, -24), "LeftForeArm": Vector3(-100, 0, 0),
		"RightArm": Vector3(16, 0, -14), "RightForeArm": Vector3(-62, 0, 0),
		"LeftUpLeg": Vector3(-26, 0, 8), "LeftLeg": Vector3(36, 0, 0), "LeftFoot": Vector3(-10, 0, -4),
		"RightUpLeg": Vector3(14, 0, -9), "RightLeg": Vector3(30, 0, 0), "RightFoot": Vector3(-44, 0, 4)}
	var both := ["LeftFoot", "RightFoot"]
	return {"name": "block_shield", "length": 0.8, "hold_from": 0.35, "keys": [
		_stance(0.0, "ready"),
		_k(0.35, "active", guard, Vector3(0, -0.1, -0.02), both, Vector3(-0.2, 0.45, 0.85)),
		_k(0.75, "active", guard, Vector3(0, -0.1, -0.02), both, Vector3(-0.2, 0.45, 0.85)),
		_k(1.0, "recovery", guard, Vector3(0, -0.1, -0.02), both, Vector3(-0.2, 0.45, 0.85)),
	]}

# ---------------------------------------------------------------- рывок

const DIRS := {"forward": Vector3(0, 0, 1), "back": Vector3(0, 0, -1), "left": Vector3(1, 0, 0), "right": Vector3(-1, 0, 0)}

## Рывок с места или с бега в одну из четырёх сторон: (присед) → толчок и полёт с наклоном корпуса
## в сторону рывка → приземление в присед → стойка. Анимация на месте: перемещение даёт игра.
static func _dash(dir: String, from_run: bool) -> Dictionary:
	var d: Vector3 = DIRS.get(dir, DIRS["forward"])
	var lean := Vector3(d.z * 24.0, 0, -d.x * 16.0)          # наклон корпуса в сторону рывка
	var tuck := {"LeftUpLeg": Vector3(-48, 0, 8), "LeftLeg": Vector3(80, 0, 0), "LeftFoot": Vector3(-20, 0, -4),
		"RightUpLeg": Vector3(-30, 0, -9), "RightLeg": Vector3(70, 0, 0), "RightFoot": Vector3(-30, 0, 4)}
	var push := {"Spine": Vector3(6, 0, 0) + lean, "Spine1": lean * 0.4,
		"RightArm": Vector3(40, 0, -14), "RightForeArm": Vector3(-20, 0, 0), "LeftArm": Vector3(42, 0, 16), "LeftForeArm": Vector3(-20, 0, 0)}
	if dir == "forward":
		tuck = {"LeftUpLeg": Vector3(-62, 0, 8), "LeftLeg": Vector3(84, 0, 0), "LeftFoot": Vector3(-14, 0, -4),
			"RightUpLeg": Vector3(28, 0, -9), "RightLeg": Vector3(46, 0, 0), "RightFoot": Vector3(-30, 0, 4)}
	elif dir == "back":
		push["RightArm"] = Vector3(-30, 0, -20)
		push["LeftArm"] = Vector3(-34, 0, 20)
	var crouch := {"LeftUpLeg": Vector3(-30, 0, 10), "LeftLeg": Vector3(56, 0, 0), "LeftFoot": Vector3(-26, 0, -4),
		"RightUpLeg": Vector3(-14, 0, -11), "RightLeg": Vector3(52, 0, 0), "RightFoot": Vector3(-38, 0, 4),
		"Spine": Vector3(14, 0, 0) - lean * 0.3, "RightArm": Vector3(16, 0, -10), "LeftArm": Vector3(30, 0, 10)}
	var land := PoseLib.merge(crouch, {"Spine": Vector3(12, 0, 0) + lean * 0.4})
	var both := ["LeftFoot", "RightFoot"]
	var keys := []
	if from_run:
		var run := {"Spine": Vector3(14, 0, 0), "LeftUpLeg": Vector3(-36, 0, 6), "LeftLeg": Vector3(40, 0, 0), "LeftFoot": Vector3(-6, 0, -4),
			"RightUpLeg": Vector3(26, 0, -6), "RightLeg": Vector3(72, 0, 0), "RightFoot": Vector3(-10, 0, 4),
			"RightArm": Vector3(30, 0, 6), "RightForeArm": Vector3(-60, 0, 0), "LeftArm": Vector3(-36, 0, -6), "LeftForeArm": Vector3(-60, 0, 0)}
		keys = [_k(0.0, "ready", run, Vector3(0, -0.04, 0), ["LeftFoot"], Vector3(-0.3, -0.5, 0.8)),
			_k(0.3, "active", PoseLib.merge(push, tuck), d * 0.12 + Vector3(0, 0.02, 0), [], Vector3(-0.4, -0.5, 0.75)),
			_k(0.7, "recovery", land, d * 0.04 + Vector3(0, -0.12, 0), both, STANCE_SWORD),
			_stance(1.0, "recovery")]
		return {"name": "dash_run_" + dir, "length": 0.5, "keys": keys}
	keys = [_stance(0.0, "ready"),
		_k(0.22, "anticipation", crouch, -d * 0.04 + Vector3(0, -0.12, 0), both, STANCE_SWORD),
		_k(0.48, "active", PoseLib.merge(push, tuck), d * 0.14 + Vector3(0, 0.03, 0), [], Vector3(-0.4, -0.5, 0.75)),
		_k(0.76, "recovery", land, d * 0.04 + Vector3(0, -0.12, 0), both, STANCE_SWORD),
		_stance(1.0, "recovery")]
	return {"name": "dash_" + dir, "length": 0.6, "keys": keys}

# ---------------------------------------------------------------- уборка меча

## Уборка меча в ножны за спину (раскадровка владельца, 1,33 с): подготовка → подъём меча (сгиб
## локтя) → замах и перевод через правое плечо → поиск ножен (рука и клинок за спину, клинок вниз
## к левому бедру) → ввод меча → фиксация (отпускание хвата) → рука опускается, спокойная стойка.
## Корпус чуть поворачивается вправо (5–15°), голова провожает руку
static func _sheathe() -> Dictionary:
	var both := ["LeftFoot", "RightFoot"]
	# ноги стоят как в стойке весь клип (стопы не скользят); руки — спокойно опущены
	var calm := {"RightShoulder": Vector3.ZERO, "RightArm": Vector3(4, 0, 6), "RightForeArm": Vector3(-14, 0, 0), "LeftArm": Vector3(4, 0, -6), "LeftForeArm": Vector3(-14, 0, 0), "Spine": Vector3(2, 0, 0)}
	# Углы руки подобраны замером положения кисти относительно головы (ключица поднята на 25°):
	# подъём — кисть перед лицом выше головы; замах — над головой; поиск ножен — за головой справа;
	# ввод — за шеей, клинок вниз за спину
	var sh := {"RightShoulder": Vector3(0, 0, -25)}
	var lift := PoseLib.merge(sh, {"Spine": Vector3(4, -6, 0), "RightArm": Vector3(0, 0, -120), "RightForeArm": Vector3(-30, 0, 0)})
	var over := PoseLib.merge(sh, {"Spine": Vector3(0, -12, 0), "Spine1": Vector3(-2, -4, 0), "Neck": Vector3(0, -8, 0),
		"RightArm": Vector3(-60, 0, -90), "RightForeArm": Vector3(-80, 0, 0)})
	var behind := PoseLib.merge(sh, {"Spine": Vector3(0, -14, 0), "Spine1": Vector3(-2, -5, 0), "Neck": Vector3(0, -10, 0),
		"RightArm": Vector3(-90, 0, -90), "RightForeArm": Vector3(-130, 0, 0)})
	var push := PoseLib.merge(sh, {"Spine": Vector3(2, -10, 0), "Spine1": Vector3(0, -4, 0), "Neck": Vector3(0, -6, 0),
		"RightArm": Vector3(-60, 0, -120), "RightForeArm": Vector3(-130, 0, 0)})
	var release := {"RightShoulder": Vector3(0, 0, -10), "Spine": Vector3(2, -6, 0), "RightArm": Vector3(-30, 0, -90), "RightForeArm": Vector3(-100, 0, 0)}
	var down := Vector3(0.55, -1.0, -0.3)      # клинок за спиной: вниз, к левому бедру, чуть назад
	return {"name": "sheathe", "length": 1.33, "keys": [
		_stance(0.0, "ready", both),
		_k(0.15, "ready", PoseLib.merge(calm, {"RightArm": Vector3(-10, 0, 4), "RightForeArm": Vector3(-30, 0, 0)}), STANCE_HIPS, both, Vector3(-0.3, -0.6, 0.7)),
		_k(0.25, "anticipation", PoseLib.merge(calm, lift), STANCE_HIPS, both, Vector3(-0.1, 1.0, 0.3)),
		_k(0.40, "active", PoseLib.merge(calm, over), STANCE_HIPS, both, Vector3(-0.1, 0.4, -1.0)),
		_k(0.55, "active", PoseLib.merge(calm, behind), STANCE_HIPS, both, down),
		_k(0.75, "active", PoseLib.merge(calm, push), STANCE_HIPS, both, down),
		_k(0.86, "recovery", PoseLib.merge(calm, release), STANCE_HIPS, both, down),
		_k(1.0, "recovery", calm, STANCE_HIPS, both),
	]}
