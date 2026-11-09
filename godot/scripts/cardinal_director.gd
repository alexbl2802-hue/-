## Подключение системы Cardinal (addons/cardinal) к игре:
## • учёт всех монстров и боссов (enemy.gd регистрирует себя), лимит — под размер мира;
## • адаптивная сложность: недавние победы без гибели повышают её, гибели героя — снижают;
##   сложность меняет урон монстров по герою (0,75…1,25) и количество добавочной добычи;
## • страж Cardinal (CardinalGuardian) проверяет состояние и пишет сообщения в журнал.
## CARDINAL 4.0: настройки — CardinalConfig, баланс — CardinalBalance, реестр систем — CardinalRegistry;
## проверка анимаций/скелетов — ANIMATE (AnimateAudit.check_actors), здесь только запуск и журнал.
## Cardinal 2.1 (addons/cardinal/v2):
## • ядро CardinalCore — журнал событий и счётчик ошибок;
## • Error Guardian — возвращает героя, если он провалился под мир (CardinalHeroGuard);
## • Performance Manager — следит за частотой кадров и пишет в журнал, когда она падает;
## • после загрузки мира просит ANIMATE проверить анимации и скелеты героя и монстров;
##   отчёт ANIMATE — user://cardinal_animation_report.json, итог — в журнале CARDINAL.
class_name CardinalDirector
extends RefCounted

static var _guardian: Node
static var core: CardinalCore
static var autotest: CardinalAutotest
const FALL_Y := -200.0   # под поверхностью мира и плато; у подземелий и этажей башни — свой пол (fall_y_at)
const FALL_BELOW := 40.0  # на столько ниже пола подземелья — значит провалился
static var _main: Node

static func setup(parent: Node) -> void:
	_main = parent
	_guardian = CardinalGuardian.new()
	_guardian.name = "CardinalGuardian"
	parent.add_child(_guardian)
	_guardian.diagnostic.connect(func(level: String, code: String, msg: String): print("[Cardinal] %s %s: %s" % [level, code, msg]))
	# Cardinal 2.1
	core = CardinalCore.new()
	core.name = "CardinalCore"
	parent.add_child(core)
	core.event_logged.connect(func(m: String): print("[Cardinal] ", m))
	CardinalBalance.load_settings()
	core.log_event("CARDINAL SYSTEM запущена")
	var perf := CardinalPerformanceManager.new()
	perf.name = "CardinalPerformance"
	perf.core = core
	core.add_child(perf)
	var hero = parent.get("hero")
	if hero is Node3D:
		var g := CardinalHeroGuard.new()
		g.name = "CardinalHeroGuard"
		g.core = core
		g.monitored_player = hero
		g.minimum_y = FALL_Y
		core.add_child(g)
	autotest = CardinalAutotest.new()
	autotest.name = "CardinalAutotest"
	core.add_child(autotest)
	# Проверка анимаций — когда мир уже показан и монстры рядом проснулись
	parent.get_tree().create_timer(6.0).timeout.connect(func(): check_animations(parent))

## Проверка анимаций и скелетов — обязанность ANIMATE (AnimateAudit.check_actors); CARDINAL только
## запускает её после загрузки мира и пишет итог в свой журнал (диагностика).
static func check_animations(parent: Node) -> Dictionary:
	if not is_instance_valid(parent) or core == null:
		return {}
	var r := AnimateAudit.check_actors(parent, core)
	var counts: Dictionary = r.get("counts", {})
	var bad: Array = r.get("bad", [])
	core.log_event("Проверка анимаций (ANIMATE): моделей %d — ошибок %d, предупреждений %d, заметок %d" % [r.get("actors", 0),
		counts.get("ERROR", 0), counts.get("WARNING", 0), counts.get("INFO", 0)])
	core.log_event("Скелеты (ANIMATE): %d проверено — %s" % [r.get("skeletons", {}).size(), "все кости на месте" if bad.is_empty() else "; ".join(bad)])
	return r

static func on_kill() -> void:
	CardinalBalance.on_kill()

static func on_death() -> void:
	CardinalBalance.on_death()

## Ниже какой высоты в этом месте — провал. Подземелья и этажи башни лежат глубоко внизу
## (этажи — от −900 м), поэтому у каждого — своя граница: на 40 м ниже его пола.
static func fall_y_at(p: Vector3, mode := -999) -> float:
	if not is_instance_valid(_main):
		return FALL_Y
	var ds: Array = _main.get("dungeons") if _main.get("dungeons") is Array else []
	if mode == -999:
		for d in ds:
			if absf(p.y - float(d.Y)) < 60.0:
				return float(d.Y) - FALL_BELOW
		return FALL_Y
	if mode >= 0 and mode < ds.size():
		return float(ds[mode].Y) - FALL_BELOW
	return FALL_Y

## Множитель добавочной добычи Cardinal (окно CARDINAL: 0,1…3; сохраняется)
static func loot_mult() -> float:
	return CardinalBalance.loot_multiplier

static func set_loot_mult(v: float) -> void:
	var m := CardinalBalance.set_loot_mult(v)
	if core:
		core.log_event("Множитель добычи: ×%.1f" % m)

## Множитель урона монстров: сложность 0,5…3 → 0,75…1,25
static func damage_mult() -> float:
	return CardinalBalance.damage_mult()
