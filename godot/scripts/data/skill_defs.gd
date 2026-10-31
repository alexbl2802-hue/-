## Навыки: очко за каждый новый уровень до 10-го (как в веб-версии)
class_name SkillDefs
extends RefCounted

const MAX_SKILL_LEVEL := 10
const EVOLUTION_ENABLED := false  # эволюция навыков на максимальном ранге — откроем позже

const LIST := [
	{"id": "strength", "icon": "💪", "name": "Сила", "max": 7, "lvl": 1},
	{"id": "vitality", "icon": "❤️", "name": "Стойкость", "max": 7, "lvl": 1},
	{"id": "agility", "icon": "🪶", "name": "Ловкость", "max": 7, "lvl": 2},
	{"id": "regen", "icon": "🌿", "name": "Регенерация", "max": 7, "lvl": 2},
	{"id": "whirl", "icon": "🌀", "name": "Вихрь", "max": 7, "lvl": 3, "active": true},
	{"id": "crit", "icon": "🎯", "name": "Крит. удар", "max": 7, "lvl": 4},
	{"id": "dash", "icon": "💨", "name": "Рывок", "max": 7, "lvl": 5, "active": true},
	{"id": "vamp", "icon": "🩸", "name": "Вампиризм", "max": 7, "lvl": 6},
]

static func find(id: String) -> Dictionary:
	for s in LIST:
		if s["id"] == id:
			return s
	return {}

static func whirl_cd(r: int) -> float:
	return maxf(2.5, 8.0 - 1.5 * (r - 1))

static func dash_cd(r: int) -> float:
	return maxf(2.0, 6.0 - (r - 1))

## Описание эффекта навыка на ранге r
static func desc(id: String, r: int) -> String:
	match id:
		"strength": return "Урон +%d" % (5 * r)
		"vitality": return "Здоровье +%d" % (20 * r)
		"agility": return "Бег +%d%%, удары быстрее на %d%%" % [8 * r, 10 * r]
		"regen": return "+%s здоровья/с, даже в бою" % String.num(1.5 * r)
		"whirl": return "Удар вокруг: %d%% урона, откат %s с" % [120 + 30 * (r - 1), String.num(whirl_cd(r))]
		"crit": return "%d%% шанс двойного урона" % (8 * r)
		"dash": return "Сквозь врагов: %d%% урона, неуязвим, откат %s с" % [80 + 30 * (r - 1), String.num(dash_cd(r))]
		"vamp": return "Лечение: %d%% от урона" % (4 * r)
	return ""
