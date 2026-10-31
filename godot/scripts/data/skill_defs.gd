## Навыки: очко за каждый новый уровень до 10-го (как в веб-версии)
class_name SkillDefs
extends RefCounted

const MAX_SKILL_LEVEL := 10
const EVOLUTION_ENABLED := false  # эволюция остальных навыков на максимальном ранге — откроем позже

const LIST := [
	{"id": "strength", "icon": "💪", "name": "Сила", "max": 7, "lvl": 1},
	{"id": "vitality", "icon": "❤️", "name": "Стойкость", "max": 7, "lvl": 1},
	{"id": "agility", "icon": "🪶", "name": "Ловкость", "max": 7, "lvl": 2},
	{"id": "regen", "icon": "🌿", "name": "Регенерация", "max": 7, "lvl": 2},
	{"id": "whirl", "icon": "🌀", "name": "Вихрь", "max": 7, "lvl": 3, "active": true},
	{"id": "crit", "icon": "🎯", "name": "Крит. удар", "max": 7, "lvl": 4},
	{"id": "dash", "icon": "💨", "name": "Рывок", "max": 10, "lvl": 5, "active": true},
	{"id": "vamp", "icon": "🩸", "name": "Вампиризм", "max": 7, "lvl": 6},
]

static func find(id: String) -> Dictionary:
	for s in LIST:
		if s["id"] == id:
			return s
	return {}

static func whirl_cd(r: int) -> float:
	return maxf(2.5, 8.0 - 1.5 * (r - 1))

# ---------- Рывок и его эволюция: Рывок (10 ур.) → Скользящий шаг (5 ур.) → прорыв: Мерцание.
# Урон сквозь врагов — 20%. Скорость — надбавка к базовой скорости рывка.
const DASH_DMG := 0.2
const SLIDE_MAX := 5
const DASH_FORMS := {
	"dash": {"icon": "💨", "name": "Рывок"},
	"slide": {"icon": "🌬️", "name": "Скользящий шаг"},
	"blink": {"icon": "✨", "name": "Мерцание"},
}

## Рывок: +10% скорости за уровень (на 10-м — +100%), откат 10 с и −0,5 с за каждый уровень после первого
static func dash_cd(r: int) -> float:
	return 10.0 - 0.5 * (maxi(1, r) - 1)

## Текущая форма рывка по навыкам героя: dash_slide — уровень Скользящего шага, dash_blink — прорыв
static func dash_form(skills: Dictionary) -> String:
	if int(skills.get("dash_blink", 0)) > 0:
		return "blink"
	if int(skills.get("dash_slide", 0)) > 0:
		return "slide"
	return "dash"

## Скорость (во сколько раз быстрее базовой) и откат текущей формы
static func dash_stats(skills: Dictionary) -> Dictionary:
	var r := maxi(1, int(skills.get("dash", 0)))
	match dash_form(skills):
		"blink":
			return {"speed": 3.0, "cd": 3.0}
		"slide":
			# Скользящий шаг: +10% за уровень сверх +100% Рывка (на 5-м — +150%), откат −0,2 с за уровень
			var sl := int(skills.get("dash_slide", 0))
			return {"speed": 2.0 + 0.1 * sl, "cd": dash_cd(10) - 0.2 * sl}
	return {"speed": 1.0 + 0.1 * r, "cd": dash_cd(r)}

static func dash_desc(speed: float, cd: float) -> String:
	return "Сквозь врагов: %d%% урона, неуязвим, скорость +%d%%, откат %s с" % [roundi(DASH_DMG * 100), roundi((speed - 1.0) * 100), String.num(snappedf(cd, 0.1))]

## Описание эффекта навыка на ранге r
static func desc(id: String, r: int) -> String:
	match id:
		"strength": return "Урон +%d" % (5 * r)
		"vitality": return "Здоровье +%d" % (20 * r)
		"agility": return "Бег +%d%%, удары быстрее на %d%%" % [8 * r, 10 * r]
		"regen": return "+%s здоровья/с, даже в бою" % String.num(1.5 * r)
		"whirl": return "Удар вокруг: %d%% урона, откат %s с" % [120 + 30 * (r - 1), String.num(whirl_cd(r))]
		"crit": return "%d%% шанс двойного урона" % (8 * r)
		"dash": return dash_desc(1.0 + 0.1 * r, dash_cd(r))
		"vamp": return "Лечение: %d%% от урона" % (4 * r)
	return ""
