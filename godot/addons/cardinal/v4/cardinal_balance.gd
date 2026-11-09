## CARDINAL 4.0 — баланс: адаптивная сложность (победы/гибели героя), множитель урона монстров,
## множитель добавочной добычи (сохраняется в CardinalConfig.SETTINGS_PATH). Состояние сложности —
## в autoload Cardinal (Cardinal.difficulty), здесь только правила.
class_name CardinalBalance
extends RefCounted

static var _wins := 0          # победы с последней гибели (до 40)
static var _deaths := 0.0      # недавние гибели (со временем «забываются»)
static var loot_multiplier := 1.0

static func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(CardinalConfig.SETTINGS_PATH) == OK:
		loot_multiplier = clampf(float(cf.get_value("cardinal", "loot", 1.0)), CardinalConfig.LOOT_MULT_MIN, CardinalConfig.LOOT_MULT_MAX)

static func on_kill() -> void:
	_wins = mini(_wins + 1, 40)
	_deaths = maxf(0.0, _deaths - 0.1)
	Cardinal.set_player_performance(roundi(_deaths), _wins)

static func on_death() -> void:
	_deaths += 1.0
	_wins = 0
	Cardinal.set_player_performance(roundi(_deaths), _wins)

## Множитель урона монстров: сложность 0,5…3 → 0,75…1,25
static func damage_mult() -> float:
	var k := inverse_lerp(CardinalConfig.DIFFICULTY_MIN, CardinalConfig.DIFFICULTY_MAX, Cardinal.difficulty)
	return clampf(lerpf(CardinalConfig.MONSTER_DAMAGE_MIN, CardinalConfig.MONSTER_DAMAGE_MAX, k),
		CardinalConfig.MONSTER_DAMAGE_MIN, CardinalConfig.MONSTER_DAMAGE_MAX)

static func set_loot_mult(v: float) -> float:
	loot_multiplier = clampf(snappedf(v, 0.1), CardinalConfig.LOOT_MULT_MIN, CardinalConfig.LOOT_MULT_MAX)
	var cf := ConfigFile.new()
	cf.load(CardinalConfig.SETTINGS_PATH)
	cf.set_value("cardinal", "loot", loot_multiplier)
	cf.save(CardinalConfig.SETTINGS_PATH)
	return loot_multiplier
