## Навыки: очко навыка за каждое повышение уровня героя
class_name SkillDefs
extends RefCounted

static func icon_path(id: String) -> String:
	return "res://assets/icons/skills/%s.png" % id

const EVOLUTION_ENABLED := false  # эволюция остальных навыков на максимальном ранге — откроем позже

# Сила и Ловкость — характеристики; навык «Стойкость» убран — его повторяет характеристика Выносливость (окно «Характеристики», Game.stats)
const LIST := [
	{"id": "regen", "icon": "🌿", "name": "Регенерация", "max": 7, "lvl": 2},
	{"id": "whirl", "icon": "🌀", "name": "Вихрь", "max": 7, "lvl": 3, "active": true},
	{"id": "crit", "icon": "🎯", "name": "Крит. удар", "max": 7, "lvl": 4},
	{"id": "dash", "icon": "💨", "name": "Рывок", "max": 10, "lvl": 5, "active": true},
	# Приём «Горизонталь»: широкий взмах справа налево по всем впереди
	{"id": "horizontal", "icon": "↔", "name": "Горизонталь", "max": 5, "lvl": 3, "active": true},
	{"id": "vamp", "icon": "🩸", "name": "Вампиризм", "max": 7, "lvl": 6},
	# Приёмы меча — у каждого типа оружия свой, кнопка ✦ на экране
	{"id": "art_sword", "icon": "⚡", "name": "Резкий выпад", "max": 5, "lvl": 2, "active": true, "art": "sword"},
	{"id": "art_great", "icon": "💥", "name": "Сокрушающий удар", "max": 5, "lvl": 2, "active": true, "art": "great"},
	{"id": "art_rapier", "icon": "✴️", "name": "Звёздный укол", "max": 5, "lvl": 2, "active": true, "art": "rapier"},
	{"id": "art_dagger", "icon": "🌑", "name": "Теневой надрез", "max": 5, "lvl": 2, "active": true, "art": "dagger"},
]

## Приёмы меча: урон (множитель) растёт на 15% за ранг, откат меньше
const ART_COLOR := {"sword": Color("#7fd0ff"), "great": Color("#ff8a3a"), "rapier": Color("#ffe27a"), "dagger": Color("#b07cff")}
static func art_mult(base: float, r: int) -> float:
	return base * (1.0 + 0.15 * (maxi(1, r) - 1))

static func art_cd(r: int) -> float:
	return maxf(4.0, 8.0 - 0.8 * (maxi(1, r) - 1))

static func find(id: String) -> Dictionary:
	for s in LIST:
		if s["id"] == id:
			return s
	return {}

static func horizontal_cd(r: int) -> float:
	return maxf(3.0, 7.0 - 1.0 * (maxi(1, r) - 1))

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
		"horizontal": return "Широкий взмах по всем впереди: %d%% урона, откат %s с" % [roundi((1.6 + 0.2 * (maxi(1, r) - 1)) * 100), String.num(horizontal_cd(r))]
		"art_sword": return "С мечом: стойка, рывок вперёд на 5 м — %d%% урона всем на пути, откат %s с" % [roundi(art_mult(2.2, r) * 100), String.num(art_cd(r))]
		"art_great": return "С двуручником: удар сверху по площади — %d%% урона и оглушение, откат %s с" % [roundi(art_mult(2.8, r) * 100), String.num(art_cd(r))]
		"art_rapier": return "С рапирой: пять быстрых уколов по %d%% урона, откат %s с" % [roundi(art_mult(0.75, r) * 100), String.num(art_cd(r))]
		"art_dagger": return "С кинжалом: мгновенно за спину врага, крит %d%% урона, откат %s с" % [roundi(art_mult(3.0, r) * 100), String.num(art_cd(r))]
	return ""
