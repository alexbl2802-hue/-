## Подключение системы Cardinal (addons/cardinal) к игре:
## • учёт всех монстров и боссов (enemy.gd регистрирует себя), лимит — под размер мира;
## • адаптивная сложность: недавние победы без гибели повышают её, гибели героя — снижают;
##   сложность меняет урон монстров по герою (0,75…1,25) и количество добавочной добычи;
## • страж Cardinal (CardinalGuardian) проверяет состояние и пишет сообщения в журнал.
## Cardinal 2.1 (addons/cardinal/v2):
## • ядро CardinalCore — журнал событий и счётчик ошибок;
## • Error Guardian — возвращает героя, если он провалился под мир (CardinalHeroGuard);
## • Performance Manager — следит за частотой кадров и пишет в журнал, когда она падает;
## • Animation Guardian и Auto Skeleton Repair — один раз после загрузки мира проверяют анимации
##   и скелеты героя и монстров; отчёт — user://cardinal_animation_report.json и в журнале.
class_name CardinalDirector
extends RefCounted

static var _wins := 0          # победы с последней гибели (до 40)
static var _deaths := 0.0      # недавние гибели (со временем «забываются»)
static var _guardian: Node
static var core: CardinalCore
static var autotest: CardinalAutotest
const FALL_Y := -200.0   # ниже любой земли и подземелий
## Кости, которые должны быть у человекоподобного скелета (имена Mixamo, без приставки)
const HUMANOID := ["Hips", "Spine", "Neck", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm",
	"RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]

static func setup(parent: Node) -> void:
	Cardinal.max_active_mobs = 2000   # монстры мира создаются заранее и «спят» вдали
	_guardian = CardinalGuardian.new()
	_guardian.name = "CardinalGuardian"
	parent.add_child(_guardian)
	_guardian.diagnostic.connect(func(level: String, code: String, msg: String): print("[Cardinal] %s %s: %s" % [level, code, msg]))
	# Cardinal 2.1
	core = CardinalCore.new()
	core.name = "CardinalCore"
	parent.add_child(core)
	core.event_logged.connect(func(m: String): print("[Cardinal] ", m))
	var cf := ConfigFile.new()
	if cf.load("user://cardinal.cfg") == OK:
		core.set_loot_multiplier(float(cf.get_value("cardinal", "loot", 1.0)))
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

## Animation Guardian + Auto Skeleton Repair: проверить клипы и кости героя и монстров (по одному
## монстру каждого вида). Ничего не меняет — только отчёт (журнал и user://cardinal_animation_report.json).
static func check_animations(parent: Node) -> Dictionary:
	if not is_instance_valid(parent) or core == null:
		return {}
	var ag := CardinalAnimationGuardian.new()
	ag.name = "CardinalAnimationGuardian"
	core.add_child(ag)
	var seen := {}
	var actors: Array = []
	var hero = parent.get("hero")
	if hero:
		actors.append(["hero", hero])
	var en = parent.get("enemies")
	if en and en.get("list") is Array:
		for e in en.list:
			if not is_instance_valid(e):
				continue
			var key: String = e.model if e.model != "" else str(e.T.get("name", "?"))
			if not seen.has(key):
				seen[key] = true
				actors.append([key, e])
	var skel := {}
	for a in actors:
		var node: Node = a[1]
		var players := node.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty():
			continue   # монстр ещё «спит» далеко — модель не загружена
		ag.scan_player(players[0])
		var sks := node.find_children("*", "Skeleton3D", true, false)
		if not sks.is_empty() and a[0] in ["hero", "skeleton", "skeleton_king", "goblin", "kobold"]:
			skel[a[0]] = CardinalAutoSkeletonRepair.audit(sks[0], _profile(sks[0]))
	var counts := {}
	for r in ag.reports:
		counts[r["severity"]] = counts.get(r["severity"], 0) + 1
	ag.reports.append({"severity": "INFO", "subject": "skeletons", "message": JSON.stringify(skel), "advice": ""})
	ag.export_report_json()
	var bad: Array = []
	for k in skel:
		if not skel[k]["ok"]:
			bad.append("%s (нет: %s)" % [k, ", ".join(skel[k]["missing"])])
	core.log_event("Проверка анимаций: моделей %d — ошибок %d, предупреждений %d, заметок %d" % [actors.size(),
		counts.get("ERROR", 0), counts.get("WARNING", 0), counts.get("INFO", 0)])
	core.log_event("Скелеты: %d проверено — %s" % [skel.size(), "все кости на месте" if bad.is_empty() else "; ".join(bad)])
	ag.queue_free()
	return {"counts": counts, "skeletons": skel, "reports": ag.reports}

## Имена костей с той же приставкой, что у этого скелета (mixamorig_Hips → mixamorig_…)
static func _profile(sk: Skeleton3D) -> Array[String]:
	var pre := ""
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.ends_with("Hips"):
			pre = n.substr(0, n.length() - 4)
			break
	var out: Array[String] = []
	for b in HUMANOID:
		out.append(pre + b)
	return out

static func on_kill() -> void:
	_wins = mini(_wins + 1, 40)
	_deaths = maxf(0.0, _deaths - 0.1)
	Cardinal.set_player_performance(roundi(_deaths), _wins)

static func on_death() -> void:
	_deaths += 1.0
	_wins = 0
	Cardinal.set_player_performance(roundi(_deaths), _wins)

## Множитель добавочной добычи Cardinal (окно CARDINAL: 0,1…3; сохраняется)
static func loot_mult() -> float:
	return core.loot_multiplier if core else 1.0

static func set_loot_mult(v: float) -> void:
	if core:
		core.set_loot_multiplier(snappedf(v, 0.1))
		var cf := ConfigFile.new()
		cf.set_value("cardinal", "loot", core.loot_multiplier)
		cf.save("user://cardinal.cfg")
		core.log_event("Множитель добычи: ×%.1f" % core.loot_multiplier)

## Множитель урона монстров: сложность 0,5…3 → 0,75…1,25
static func damage_mult() -> float:
	return clampf(0.75 + (Cardinal.difficulty - 0.5) * 0.2, 0.75, 1.25)
