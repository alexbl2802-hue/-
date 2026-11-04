## Подключение системы Cardinal (addons/cardinal) к игре:
## • учёт всех монстров и боссов (enemy.gd регистрирует себя), лимит — под размер мира;
## • адаптивная сложность: недавние победы без гибели повышают её, гибели героя — снижают;
##   сложность меняет урон монстров по герою (0,75…1,25) и количество добавочной добычи;
## • страж Cardinal (CardinalGuardian) проверяет состояние и пишет сообщения в журнал.
class_name CardinalDirector
extends RefCounted

static var _wins := 0          # победы с последней гибели (до 40)
static var _deaths := 0.0      # недавние гибели (со временем «забываются»)
static var _guardian: Node

static func setup(parent: Node) -> void:
	Cardinal.max_active_mobs = 2000   # монстры мира создаются заранее и «спят» вдали
	_guardian = CardinalGuardian.new()
	_guardian.name = "CardinalGuardian"
	parent.add_child(_guardian)
	_guardian.diagnostic.connect(func(level: String, code: String, msg: String): print("[Cardinal] %s %s: %s" % [level, code, msg]))

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
	return clampf(0.75 + (Cardinal.difficulty - 0.5) * 0.2, 0.75, 1.25)
