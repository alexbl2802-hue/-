## CARDINAL: автотест. Запускается из окна CARDINAL кнопкой «Кардинал играет».
## 1) Проверка моделей: у героя и у каждой модели монстров — есть ли все клипы, которые просит игра;
##    дорожки на кости, которых нет в скелете; кости ног без анимации в ходьбе и беге;
##    «встаёт вертикально / заваливается» (корень поворачивается сильнее 55°); ноги не шагают;
##    ноги машут вбок вместо шага; кости растягиваются; рывок на стыке цикла; пустые и битые клипы;
##    нет нужных костей в человекоподобном скелете.
## 2) Игра сама: Кардинал водит героя — бродит по миру, находит монстров, бьёт, ставит блок,
##    уклоняется, применяет приёмы, пьёт зелья. Во время игры следит: ошибки и предупреждения движка
##    и скриптов; герой застрял или провалился; анимация героя замерла; монстр скользит без анимации,
##    у монстра остановилась анимация, монстр застрял или провалился; кадров в секунду мало.
## Найденное — в журнале окна CARDINAL и в файле user://cardinal_autotest.json.
class_name CardinalAutotest
extends Node

signal changed

const REPORT := "user://cardinal_autotest.json"
const TILT_MAX := 55.0
const NO_TILT := ["death", "die", "dead", "roll", "dodge", "fall", "knock", "lie", "sleep", "crawl", "jump", "flip", "dash", "spin", "stun", "down", "get_up", "getup"]
const GAIT := ["walk", "run", "sprint", "chase"]
const NOT_STRAIGHT := ["left", "right", "turn", "strafe", "side", "diagonal", "back", "circle"]
const NOT_LOOP := ["turn", "stop", "start", "to_", "sudden", "jump", "land"]

var main: Node
var hero: Node
var issues := {}            # ключ → {sev, code, subject, msg, count, first}
var playing := false
var speed := 2              # ускорение игры во время автотеста: ×1, ×2, ×4
var audit_done := false
var started_at := 0.0

var _logger: CardinalErrorLogger
var _wp := Vector3.INF      # куда идти, если монстров рядом нет
var _wp_t := 0.0
var _target: Node3D
var _atk_t := 0.0
var _skill_t := 2.0
var _jump_t := 0.0
var _detour := 0.0          # обход препятствия: угол отклонения
var _detour_t := 0.0
var _stuck_pos := Vector3.ZERO
var _stuck_t := 0.0
var _mon_t := 0.0
var _low_fps_t := 0.0
var _hero_pose := Vector3.ZERO
var _hero_frozen_t := 0.0
var _mobs := {}             # монстр → {pos, slide_t, chase_d, chase_t}
var _overlay: CanvasLayer
var _ov_label: Label
var _sp_btn: Button
var _rng := RandomNumberGenerator.new()
# CARDINAL 3.1: подтверждённые проверки, а не число убитых монстров.
var checks: Dictionary = {}
var _initial_enemy_states: Dictionary = {}
var _last_hp := -1.0
var _last_position := Vector3.ZERO
var _coverage_time := 0.0
var _combat_seen := false
var _killed := 0
var _run_seconds := 0.0
const CHECK_NAMES := ["hero_movement", "hero_health", "enemy_spawn", "enemy_combat", "enemy_death", "loot", "weapon_drop", "inventory", "equipment", "skills", "forge", "alchemist", "trade", "dungeon", "boss", "texture_clip", "script_errors", "performance", "save_load", "navigation_stall", "npc", "quests"]
## Названия проверок для отчёта и окна
const CHECK_TITLES := {"hero_movement": "Движение героя", "hero_health": "Здоровье героя", "enemy_spawn": "Появление монстров",
	"enemy_combat": "Бой с монстрами", "enemy_death": "Смерть монстров", "loot": "Выпадение и подбор добычи",
	"weapon_drop": "Выпадение оружия", "inventory": "Инвентарь", "equipment": "Снаряжение", "skills": "Навыки",
	"forge": "Кузница", "alchemist": "Лавка алхимика", "trade": "Торговля", "dungeon": "Подземелья и этажи башни",
	"boss": "Босс и лестница", "texture_clip": "Сквозь текстуры (стены, пол, камера)", "script_errors": "Ошибки скриптов и движка",
	"performance": "Просадки кадров и лаги", "save_load": "Сохранение", "navigation_stall": "Застревания", "npc": "NPC", "quests": "Задания"}
const FIELD_SECONDS := 60.0   # столько секунд игрового времени Кардинал сначала играет с монстрами
const TEST_LIMIT_SECONDS := 900.0
const SCENARIO_TIMEOUT := 25.0
const MAX_RETRIES := 2
var registry: Dictionary = {}
var scenario_log: Array = []
var _scenario_index := 0
var _scenario_elapsed := 0.0
var _scenario_attempt := 0
var _test_elapsed := 0.0
var _scenario_order: Array = []
var _last_enemy_activity := 0.0
var _last_enemy_hp := -1.0
var _last_enemy_id := 0
var _auto_complete := false
var step := ""                 # что Кардинал сейчас проверяет (для окна и надписи)
var _scripted := false         # идут сценарии — бот не управляет героем
var _field_t := 0.0
var _save_snapshot := ""       # сохранение до теста (возвращается после)
var _start_pos := Vector3.ZERO
# Сквозь текстуры
var _clip := {"inside": 0, "void": 0, "camera": 0}
var _void_t := 0.0
# Производительность (реальное время кадра)
var _perf := {"frames": 0, "time": 0.0, "worst": 0.0, "over50": 0, "over100": 0, "freezes": 0, "zones": {}}
var _loot_seen := false
var _loot_picked := false
var _items_before := 0
var _gold_before := 0
var _stall_long := 0
var _stall_short := 0
var _stall_seq := 0
var _stall_at := Vector3.INF

func set_step(t: String) -> void:
	step = t
	changed.emit()

func _skip(id: String, detail: String) -> void:
	if checks.has(id) and checks[id]["status"] == "NOT_TESTED":
		checks[id] = {"status": "SKIPPED", "detail": detail}
		changed.emit()

## Есть ли пол под точкой (луч вниз до 6 м)
func floor_under(p: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = hero.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p + Vector3(0, -6.0, 0))
	q.exclude = [hero.get_rid()]
	return not space.intersect_ray(q).is_empty()

## Точка внутри неподвижной геометрии (стены, дома, скалы)?
func _inside_static(p: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = hero.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collide_with_areas = false
	q.exclude = [hero.get_rid()]
	for r in space.intersect_point(q, 4):
		if r["collider"] is StaticBody3D:
			return true
	return false

func _zone() -> String:
	var m := int(main.get("mode")) if main.get("mode") != null else -1
	if m >= 0:
		return "подземелье"
	if m == -2:
		return "плато"
	var p: Vector3 = hero.global_position
	return "город" if WorldGen.town_dist(p.x, p.z) < WorldGen.TOWN_WALL else "лес и поля"

## Кадр: реальное время (без ускорения автотеста)
func _process(dt: float) -> void:
	if not playing:
		return
	var real := dt / maxf(Engine.time_scale, 0.001)
	if real <= 0.0 or real > 5.0:
		return
	_perf["frames"] += 1
	_perf["time"] += real
	_perf["worst"] = maxf(_perf["worst"], real)
	if real > 0.05:
		_perf["over50"] += 1
	if real > 0.1:
		_perf["over100"] += 1
	if real > 0.5:
		_perf["freezes"] += 1
		add("WARNING", "FREEZE", "Производительность", "подвисание %.1f с — %s" % [real, _zone()])
	var z := _zone()
	var zr: Dictionary = _perf["zones"].get(z, {"frames": 0, "time": 0.0, "over50": 0})
	zr["frames"] += 1
	zr["time"] += real
	if real > 0.05:
		zr["over50"] += 1
	_perf["zones"][z] = zr

## Сквозь текстуры: герой внутри стены, пустота под ногами, камера внутри геометрии
func _clip_check(step_t: float) -> void:
	if hero.dead or hero.busy:
		return
	var p: Vector3 = hero.global_position
	if _inside_static(p + Vector3(0, 1.0, 0)):
		_clip["inside"] += 1
		add("ERROR", "CLIP_INSIDE", "Сквозь текстуры", "герой внутри стены/здания у (%d, %d, %d) — %s" % [roundi(p.x), roundi(p.y), roundi(p.z), _zone()])
	if hero.is_on_floor() or floor_under(p):
		_void_t = 0.0
	else:
		_void_t += step_t
		if _void_t > 1.5:
			_clip["void"] += 1
			add("ERROR", "CLIP_VOID", "Сквозь текстуры", "под героем пустота у (%d, %d, %d) — %s" % [roundi(p.x), roundi(p.y), roundi(p.z), _zone()])
			_void_t = -5.0
	var cam: Camera3D = hero.get_viewport().get_camera_3d()
	if cam and _inside_static(cam.global_position):
		_clip["camera"] += 1
		add("WARNING", "CLIP_CAMERA", "Сквозь текстуры", "камера внутри стены/здания у (%d, %d, %d) — %s" % [roundi(cam.global_position.x), roundi(cam.global_position.y), roundi(cam.global_position.z), _zone()])

## Подбор добычи: после убийства что-то выпало и попало в инвентарь или кошелёк
func _loot_tick() -> void:
	var loot = main.get("loot")
	if loot and loot.get("_items") is Array and (loot._items as Array).size() > 0:
		_loot_seen = true
	var n := 0
	for st in Game.inv:
		n += int(st.get("n", 1))
	if _loot_seen and (n > _items_before or Game.gold > _gold_before):
		_loot_picked = true
	_items_before = n
	_gold_before = Game.gold

## Ход теста: поле (бой с монстрами) → сценарии систем → итог
func _scenario_tick(dt: float) -> void:
	_test_elapsed += dt
	if _scripted:
		return
	_field_t += dt
	if _field_t < FIELD_SECONDS and _test_elapsed < TEST_LIMIT_SECONDS:
		return
	_scripted = true
	_run_scenarios()

func _run_scenarios() -> void:
	var t: Node = hero.get("touch")
	if t:
		t.move = Vector2.ZERO
		t.run = false
		t.block = false
	set_step("сценарии")
	# Итоги полевой части
	if _loot_seen and _loot_picked:
		_pass("loot", "Из монстров выпадает добыча и подбирается в инвентарь/кошелёк")
	elif _loot_seen:
		_fail("loot", "Добыча выпадала, но не подобралась")
	var sc: CardinalScenarios = CardinalScenarios.new(self)
	await sc.run()
	if not playing:
		return
	_finish_checks()
	_auto_complete = true
	stop()

func _finish_checks() -> void:
	# Ошибки скриптов и движка за весь тест
	var eng := 0
	var first := ""
	for k in issues:
		var i: Dictionary = issues[k]
		if i["code"] == "ENGINE" and i["sev"] == "ERROR":
			eng += i["count"]
			if first == "":
				first = "%s: %s" % [i["subject"], i["msg"]]
	if eng == 0:
		_pass("script_errors", "Ни одной ошибки скриптов и движка за весь тест")
	else:
		_fail("script_errors", "Ошибок: %d, первая — %s" % [eng, first])
	# Сквозь текстуры
	if _clip["inside"] + _clip["void"] + _clip["camera"] == 0:
		_pass("texture_clip", "Герой ни разу не оказался внутри стен, над пустотой; камера не заходила в стены")
	else:
		_fail("texture_clip", "Внутри стен: %d, пустота под ногами: %d, камера в стене: %d (места — в списке находок)" % [_clip["inside"], _clip["void"], _clip["camera"]])
	# Производительность
	var fr: int = _perf["frames"]
	if fr > 0:
		var avg: float = fr / maxf(_perf["time"], 0.001)
		var zones: Array = []
		for z in _perf["zones"]:
			var zr: Dictionary = _perf["zones"][z]
			zones.append("%s %.0f к/с" % [z, zr["frames"] / maxf(zr["time"], 0.001)])
		var detail := "в среднем %.0f кадров/с (%s); кадров дольше 50 мс: %d, дольше 100 мс: %d; подвисаний >0,5 с: %d, худший кадр %.2f с" % [
			avg, ", ".join(zones), _perf["over50"], _perf["over100"], _perf["freezes"], _perf["worst"]]
		if avg >= 25.0 and _perf["freezes"] == 0 and float(_perf["over100"]) / fr < 0.05:
			_pass("performance", detail)
		else:
			_fail("performance", detail)
	# Застревания
	if _stall_long == 0:
		_pass("navigation_stall", "Ловушек нет: герой нигде не застревал надолго (коротких остановок у препятствий: %d)" % _stall_short)
	else:
		_fail("navigation_stall", "Ловушек на карте: %d (места — в списке находок); коротких остановок: %d" % [_stall_long, _stall_short])
	for id in checks:
		if checks[id]["status"] == "NOT_TESTED":
			checks[id] = {"status": "NOT_TESTED", "detail": "Не подтверждено за время теста"}

## Сохранение игры до теста — после теста возвращается как было
func _snapshot() -> void:
	Game.save_game()
	_save_snapshot = FileAccess.get_file_as_string(Game.SAVE_PATH) if FileAccess.file_exists(Game.SAVE_PATH) else ""
	_start_pos = hero.global_position

func _restore() -> void:
	if int(main.get("mode")) != -1 and main.has_method("_set_mode"):
		main._set_mode(-1)
	if _save_snapshot != "":
		var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(_save_snapshot)
			f.close()
		Game.load_game()
		Game.refresh()
	hero.global_position = _start_pos
	hero.velocity = Vector3.ZERO
	if hero.has_method("update_look"):
		hero.update_look()
	for pn in ["inventory", "forge", "alchemist"]:
		var pnl = main.hud.get(pn)
		if pnl and pnl.visible and pnl.has_method("close"):
			pnl.close()

func _init_checks() -> void:
	checks.clear()
	for id in CHECK_NAMES:
		checks[id] = {"status": "NOT_TESTED", "detail": "Сценарий ещё не подтверждён"}

func _pass(id: String, detail: String) -> void:
	if not checks.has(id) or checks[id]["status"] == "PASS":
		return
	checks[id] = {"status": "PASS", "detail": detail}
	changed.emit()

func _fail(id: String, detail: String) -> void:
	if not checks.has(id):
		return
	checks[id] = {"status": "FAIL", "detail": detail}
	add("ERROR", "CHECK_FAILED", id, detail)

func coverage() -> Dictionary:
	var result := {"PASS": 0, "FAIL": 0, "SKIPPED": 0, "NOT_TESTED": 0}
	for id in checks:
		var status: String = checks[id]["status"]
		result[status] = int(result.get(status, 0)) + 1
	return result

func _coverage_tick(dt: float) -> void:
	_coverage_time += dt
	if _coverage_time < 0.5:
		return
	_coverage_time = 0.0
	if not is_instance_valid(hero) or not is_instance_valid(main):
		return
	var pos: Vector3 = hero.global_position
	if pos.is_finite() and pos.distance_to(_last_position) > 1.5:
		_pass("hero_movement", "Персонаж перемещается по игровому миру")
	_last_position = pos
	if Game.max_hp > 0 and Game.hp >= 0 and Game.hp <= Game.max_hp:
		_pass("hero_health", "Значения здоровья находятся в допустимых пределах")
	var enemies = main.get("enemies")
	if enemies != null and enemies.get("list") is Array:
		for e in enemies.list:
			if not is_instance_valid(e):
				continue
			var id: int = e.get_instance_id()
			if not _initial_enemy_states.has(id):
				_initial_enemy_states[id] = {"dead": bool(e.dead), "hp": float(e.hp) if e.get("hp") != null else -1.0}
			if not e.dead and e.visible:
				_pass("enemy_spawn", "Обнаружен активный противник")
			if not bool(_initial_enemy_states[id]["dead"]) and e.dead:
				_killed += 1
				_initial_enemy_states[id]["dead"] = true
				_pass("enemy_death", "Подтверждена смерть противника; убийств: %d" % _killed)
			var old_hp: float = float(_initial_enemy_states[id]["hp"])
			if old_hp >= 0 and e.get("hp") != null and float(e.hp) < old_hp:
				_combat_seen = true
				_pass("enemy_combat", "Подтверждено изменение здоровья противника при атаке")
			if e.get("hp") != null:
				_initial_enemy_states[id]["hp"] = float(e.hp)
	# Не объявляем неподключённые механики успешными: они остаются NOT_TESTED.



## Ошибки и предупреждения движка и скриптов во время автотеста (Godot 4.5+: OS.add_logger)
class CardinalErrorLogger extends Logger:
	var lock := Mutex.new()
	var items: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		lock.lock()
		if items.size() < 500:
			items.append({"type": error_type, "where": "%s:%d (%s)" % [file.get_file(), line, function], "msg": rationale if rationale != "" else code})
		lock.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass
	func take() -> Array:
		lock.lock()
		var out := items
		items = []
		lock.unlock()
		return out


func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_PAUSABLE


# ---------------------------------------------------------------- журнал находок

func add(sev: String, code: String, subject: String, msg: String) -> void:
	var key := code + "|" + subject + "|" + msg
	if issues.has(key):
		issues[key]["count"] += 1
		return
	issues[key] = {"sev": sev, "code": code, "subject": subject, "msg": msg, "count": 1,
		"first": snappedf(Time.get_ticks_msec() / 1000.0 - started_at, 0.1)}
	var mark: String = {"ERROR": "✖", "WARNING": "⚠"}.get(sev, "•")
	if CardinalDirector.core:
		CardinalDirector.core.log_event("%s %s: %s" % [mark, subject, msg])
	changed.emit()

func counts() -> Dictionary:
	var c := {"ERROR": 0, "WARNING": 0, "INFO": 0}
	for k in issues:
		c[issues[k]["sev"]] = c.get(issues[k]["sev"], 0) + 1
	return c

func _result_status() -> String:
	var c := coverage()
	if int(c["FAIL"]) > 0 or int(counts()["ERROR"]) > 0:
		return "FAILED"
	if int(c["NOT_TESTED"]) > 0 or int(c["SKIPPED"]) > 0:
		return "INCOMPLETE"
	return "PASSED"

func save_report() -> void:
	var list: Array = issues.values()
	list.sort_custom(func(a, b): return ["ERROR", "WARNING", "INFO"].find(a["sev"]) < ["ERROR", "WARNING", "INFO"].find(b["sev"]))
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"seconds": snappedf(Time.get_ticks_msec() / 1000.0 - started_at, 1.0),
			"counts": counts(), "issues": list, "coverage": coverage(), "checks": checks, "registry": registry, "scenario_log": scenario_log, "auto_complete": _auto_complete, "kills": _killed, "result": _result_status()}, "  "))


# ---------------------------------------------------------------- запуск и остановка

func start(m: Node) -> void:
	main = m
	hero = m.get("hero")
	if hero == null:
		return
	issues.clear()
	_init_checks()
	registry.clear()
	step = "бой с монстрами"
	_scripted = false
	_field_t = 0.0
	_clip = {"inside": 0, "void": 0, "camera": 0}
	_void_t = 0.0
	_perf = {"frames": 0, "time": 0.0, "worst": 0.0, "over50": 0, "over100": 0, "freezes": 0, "zones": {}}
	_loot_seen = false
	_loot_picked = false
	_stall_long = 0
	_stall_short = 0
	_stall_seq = 0
	_stall_at = Vector3.INF
	_gold_before = Game.gold
	_items_before = 0
	_snapshot()
	scenario_log.clear()
	_scenario_index = 0
	_scenario_elapsed = 0.0
	_scenario_attempt = 0
	_test_elapsed = 0.0
	_auto_complete = false
	_initial_enemy_states.clear()
	_killed = 0
	_coverage_time = 0.0
	_combat_seen = false
	_last_position = hero.global_position
	_mobs.clear()
	started_at = Time.get_ticks_msec() / 1000.0
	playing = true
	audit_done = false
	_logger = CardinalErrorLogger.new()
	OS.add_logger(_logger)
	_stuck_pos = hero.global_position
	_make_overlay()
	_apply_speed()
	CardinalDirector.core.log_event("▶ Кардинал играет и ищет ошибки (скорость ×%d)" % speed)
	changed.emit()
	# Проверка моделей и анимаций принадлежит отдельной системе ANIMATE.
	audit_done = true
	changed.emit()

func stop() -> void:
	if not playing:
		return
	playing = false
	_set_scale(1)
	_restore()
	_flush_logger()
	if _logger:
		OS.remove_logger(_logger)
		_logger = null
	var t: Node = hero.get("touch") if hero else null
	if t:
		t.move = Vector2.ZERO
		t.run = false
		t.block = false
		t.jump = false
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	save_report()
	var cov := coverage()
	CardinalDirector.core.log_event("Покрытие: пройдено %d, ошибки %d, пропущено %d, не проверено %d; итог %s" % [cov["PASS"], cov["FAIL"], cov["SKIPPED"], cov["NOT_TESTED"], _result_status()])
	var c := counts()
	CardinalDirector.core.log_event("■ Автотест: %d с — ошибок %d, предупреждений %d, заметок %d. Отчёт: cardinal_autotest.json" % [
		roundi(Time.get_ticks_msec() / 1000.0 - started_at), c["ERROR"], c["WARNING"], c["INFO"]])
	changed.emit()

## Ускорение: время идёт быстрее, физика считается чаще (чтобы ничего не проскакивало сквозь стены)
func set_speed(k: int) -> void:
	speed = k
	if playing:
		_apply_speed()
	changed.emit()

func cycle_speed() -> void:
	set_speed({1: 2, 2: 4, 4: 1}.get(speed, 1))

func _apply_speed() -> void:
	_set_scale(speed)
	if _sp_btn:
		_sp_btn.text = "×%d" % speed

func _set_scale(k: int) -> void:
	Fx.base_scale = float(k)
	Engine.time_scale = float(k)
	Engine.physics_ticks_per_second = 60 * k
	Engine.max_physics_steps_per_frame = 8 * k

func _exit_tree() -> void:
	if playing:
		_set_scale(1)
	if _logger:
		OS.remove_logger(_logger)
		_logger = null

func _make_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 50
	add_child(_overlay)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-215, 74)
	box.custom_minimum_size = Vector2(430, 34)
	_overlay.add_child(box)
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UiKit.box(Color(0.02, 0.06, 0.1, 0.8), Color(0.45, 0.8, 1, 0.6), 8, 4, 1))
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(bg)
	_ov_label = UiKit.label("", 12, Color(0.75, 0.92, 1))
	bg.add_child(_ov_label)
	_sp_btn = UiKit.button("×%d" % speed, false, 12)
	_sp_btn.custom_minimum_size = Vector2(46, 34)
	_sp_btn.pressed.connect(cycle_speed)
	box.add_child(_sp_btn)
	var b := UiKit.button("■ Стоп", false, 12)
	b.custom_minimum_size = Vector2(80, 34)
	b.pressed.connect(stop)
	box.add_child(b)


# ---------------------------------------------------------------- 1) проверка моделей

## Клипы, которые игра просит у модели: {путь glb: {имя: [клипы]}}
func _wanted() -> Dictionary:
	var out := {}
	var es: Script = load("res://scripts/enemy.gd")
	var chars: Dictionary = es.get_script_constant_map().get("CHARS", {})
	for k in chars:
		var c: Dictionary = chars[k]
		var clips: Array = []
		for key in ["walk", "run"]:
			if c.get(key) is Array:
				clips.append(c[key][0])
		for key in ["stance", "hit", "aim"]:
			if c.get(key, "") is String and c.get(key, "") != "":
				clips.append(c[key])
		for a in c.get("atk", {}).values():
			clips.append(a[0])
		var glb: String = c["glb"]
		if not out.has(glb):
			out[glb] = {"names": [], "clips": [], "humanoid": false}
		out[glb]["names"].append(k)
		for n in clips:
			if not out[glb]["clips"].has(n):
				out[glb]["clips"].append(n)
		if k in ["goblin", "kobold", "skeleton", "skeleton_king", "golem", "rabbit"]:
			out[glb]["humanoid"] = true
	return out

func _hero_clips() -> Array:
	var out: Array = []
	var m: Dictionary = hero.get_script().get_script_constant_map()
	for k in m:
		var v = m[k]
		if v is String and (k.begins_with("A_") or k.ends_with("_CLIP") or k == "RUN_FIGHT"):
			out.append(v)
		elif v is Array and k.ends_with("CLIPS"):
			for a in v:
				if a is Array and a.size() > 0 and a[0] is String:
					out.append(a[0])
	return out

func audit_models() -> void:
	# Герой — по живому проигрывателю (там и клипы, добавленные при запуске)
	var hap: AnimationPlayer = hero.get("_anim")
	var hsk: Skeleton3D = hero.get("_sk")
	if hsk == null:
		var l: Array = hero.find_children("*", "Skeleton3D", true, false)
		hsk = l[0] if not l.is_empty() else null
	if hap and hsk:
		await _audit("Герой", hap, hsk, _hero_clips(), true, hero.get("_char"))
	else:
		add("ERROR", "NO_MODEL", "Герой", "нет модели или скелета")
	var w := _wanted()
	for glb in w:
		var who: String = ", ".join(w[glb]["names"])
		if not ResourceLoader.exists(glb):
			add("ERROR", "NO_MODEL", who, "файл модели не найден: " + glb.get_file())
			continue
		var inst: Node = (load(glb) as PackedScene).instantiate()
		var aps := inst.find_children("*", "AnimationPlayer", true, false)
		var sks := inst.find_children("*", "Skeleton3D", true, false)
		if aps.is_empty() or sks.is_empty():
			add("ERROR", "NO_MODEL", who, "в модели нет анимаций или скелета")
		else:
			await _audit(who, aps[0], sks[0], w[glb]["clips"], w[glb]["humanoid"], inst)
		inst.free()
		if not playing:
			return
	var c := counts()
	CardinalDirector.core.log_event("Модели проверены: ошибок %d, предупреждений %d" % [c["ERROR"], c["WARNING"]])

func _audit(who: String, ap: AnimationPlayer, sk: Skeleton3D, wanted: Array, humanoid: bool, model_root: Node) -> void:
	for n in wanted:
		if not ap.has_animation(n):
			add("ERROR", "NO_CLIP", who, "нет анимации «%s», а игра её запускает" % n)
	if humanoid:
		var a := CardinalAutoSkeletonRepair.audit(sk, CardinalDirector._profile(sk))
		if not a["ok"]:
			add("ERROR", "NO_BONES", who, "в скелете не хватает костей: " + ", ".join(a["missing"]))
	var to_model := _to_model(sk, model_root)
	var rest := _rest_globals(sk, to_model)
	var lo := INF
	var hi := -INF
	for p in rest:
		lo = minf(lo, p.origin.y)
		hi = maxf(hi, p.origin.y)
	var height := maxf(0.05, hi - lo)
	var feet := _feet(sk, rest, lo, height)
	var root := _root_bone(sk)
	var checked := 0
	for name in ap.get_animation_list():
		var anim := ap.get_animation(name)
		if anim == null:
			continue
		_audit_clip(who, String(name), anim, sk, to_model, rest, height, feet, root)
		checked += 1
		if checked % 4 == 0:
			await get_tree().process_frame   # не подвешивать игру
		if not playing:
			return

func _audit_clip(who: String, name: String, anim: Animation, sk: Skeleton3D, to_model: Transform3D, rest: Array, height: float, feet: Array, root: int) -> void:
	var low := name.to_lower()
	if anim.length <= 0.001:
		add("ERROR", "EMPTY_CLIP", who, "«%s»: нулевая длительность" % name)
		return
	if anim.get_track_count() == 0:
		add("WARNING", "EMPTY_CLIP", who, "«%s»: в клипе нет дорожек" % name)
		return
	# Дорожки: кость → индексы дорожек; дорожки на несуществующие кости; битые значения
	var tracks := {}
	var lost: Array = []
	for i in anim.get_track_count():
		var tt := anim.track_get_type(i)
		if tt != Animation.TYPE_POSITION_3D and tt != Animation.TYPE_ROTATION_3D and tt != Animation.TYPE_SCALE_3D:
			continue
		var path := anim.track_get_path(i)
		var bone := String(path.get_concatenated_subnames()) if path.get_subname_count() > 0 else ""
		var b := sk.find_bone(bone)
		if b < 0:
			if bone != "" and not lost.has(bone):
				lost.append(bone)
			continue
		if not tracks.has(b):
			tracks[b] = {}
		tracks[b][tt] = i
		if anim.track_get_key_count(i) > 0:
			var v = anim.track_get_key_value(i, 0)
			if (v is Vector3 and not v.is_finite()) or (v is Quaternion and not v.is_finite()):
				add("ERROR", "BAD_KEYS", who, "«%s»: неверные значения ключей (NaN) у кости %s" % [name, sk.get_bone_name(b)])
	if not lost.is_empty():
		add("WARNING", "NO_BONE", who, "«%s»: анимирует кости, которых нет в скелете: %s" % [name, ", ".join(lost.slice(0, 6))])
	var gait := GAIT.any(func(g): return low.contains(g))
	# Ноги без анимации в ходьбе и беге
	if gait:
		var still: Array = []
		for f in feet:
			var b: int = f
			var chain := 0
			var animated := false
			while b >= 0 and chain < 3:
				if tracks.has(b) and tracks[b].has(Animation.TYPE_ROTATION_3D):
					animated = true
				b = sk.get_bone_parent(b)
				chain += 1
			if not animated:
				still.append(sk.get_bone_name(f))
		if not still.is_empty():
			add("WARNING", "NO_TRACK", who, "«%s»: кости ног без анимации: %s" % [name, ", ".join(still)])
	# Позы по кадрам
	var steps := 12
	var tilt_max := 0.0
	var stretch := ""
	var fx := {}   # нога → [min x, max x, min z, max z] относительно корня
	var first: Array = []
	var last: Array = []
	var root_rest: Transform3D = rest[root] if root >= 0 else Transform3D()
	for s in steps + 1:
		var t := anim.length * float(s) / steps
		var pose := _pose(sk, anim, tracks, t, to_model)
		if s == 0:
			first = pose
		if s == steps:
			last = pose
		if root >= 0:
			var up_rest: Vector3 = root_rest.basis.y.normalized()
			var up: Vector3 = pose[root].basis.y.normalized()
			tilt_max = maxf(tilt_max, rad_to_deg(up_rest.angle_to(up)))
		for b in sk.get_bone_count():
			var p := sk.get_bone_parent(b)
			if p < 0:
				continue
			var r0: float = (rest[b].origin - rest[p].origin).length()
			if r0 < height * 0.01:
				continue
			var r1: float = (pose[b].origin - pose[p].origin).length()
			if (r1 / r0 > 1.35 or r1 / r0 < 0.65) and stretch == "":
				stretch = "%s (×%.2f)" % [sk.get_bone_name(b), r1 / r0]
		for f in feet:
			var rel: Vector3 = pose[f].origin - (pose[root].origin if root >= 0 else Vector3.ZERO)
			if not fx.has(f):
				fx[f] = [rel.x, rel.x, rel.z, rel.z]
			else:
				fx[f] = [minf(fx[f][0], rel.x), maxf(fx[f][1], rel.x), minf(fx[f][2], rel.z), maxf(fx[f][3], rel.z)]
	var upright := gait or low.contains("idle") or low.contains("stance")
	if upright and not NO_TILT.any(func(x): return low.contains(x)) and tilt_max > TILT_MAX:
		add("ERROR", "TILT", who, "«%s»: тело поворачивается на %d° — модель встаёт вертикально или заваливается" % [name, roundi(tilt_max)])
	if stretch != "":
		add("WARNING", "STRETCH", who, "«%s»: кость растягивается или сжимается: %s" % [name, stretch])
	if gait and not feet.is_empty():
		var fwd := 0.0
		var side := 0.0
		for f in fx:
			side = maxf(side, fx[f][1] - fx[f][0])
			fwd = maxf(fwd, fx[f][3] - fx[f][2])
		if fwd < height * 0.01:
			add("ERROR", "FEET_STILL", who, "«%s»: ноги не шагают (размах %d см)" % [name, roundi(fwd * 100)])
		elif fwd < height * 0.04:
			add("INFO", "FEET_SMALL", who, "«%s»: шаг едва заметный (размах %d см)" % [name, roundi(fwd * 100)])
		elif side > fwd * 0.8 and side > height * 0.06 and not NOT_STRAIGHT.any(func(x): return low.contains(x)):
			add("ERROR", "LEG_SWING", who, "«%s»: ноги машут вбок (вбок %d см, вперёд-назад %d см)" % [name, roundi(side * 100), roundi(fwd * 100)])
	# Стык цикла: первый и последний кадр должны совпадать
	if upright and not NOT_LOOP.any(func(x): return low.contains(x)):
		var jump := 0.0
		var rp0: Vector3 = first[root].origin if root >= 0 else Vector3.ZERO
		var rp1: Vector3 = last[root].origin if root >= 0 else Vector3.ZERO
		for b in sk.get_bone_count():
			jump = maxf(jump, ((first[b].origin - rp0) - (last[b].origin - rp1)).length())
		if jump > height * 0.08:
			add("WARNING", "LOOP_JUMP", who, "«%s»: рывок на стыке цикла (%d см)" % [name, roundi(jump * 100)])

## Скелет → система координат модели (Y вверх, как модель стоит в игре)
func _to_model(sk: Skeleton3D, model_root: Node) -> Transform3D:
	var t := Transform3D()
	var n: Node = sk
	while n and n != model_root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

func _rest_globals(sk: Skeleton3D, to_model: Transform3D) -> Array:
	var g: Array = []
	g.resize(sk.get_bone_count())
	for b in _order(sk):
		var p := sk.get_bone_parent(b)
		g[b] = (to_model * sk.get_bone_rest(b)) if p < 0 else (g[p] * sk.get_bone_rest(b))
	return g

func _order(sk: Skeleton3D) -> Array:
	var out: Array = []
	var seen := {}
	for b in sk.get_bone_count():
		_visit(sk, b, seen, out)
	return out

func _visit(sk: Skeleton3D, b: int, seen: Dictionary, out: Array) -> void:
	if seen.has(b):
		return
	var p := sk.get_bone_parent(b)
	if p >= 0:
		_visit(sk, p, seen, out)
	seen[b] = true
	out.append(b)

func _pose(sk: Skeleton3D, anim: Animation, tracks: Dictionary, t: float, to_model: Transform3D) -> Array:
	var g: Array = []
	g.resize(sk.get_bone_count())
	for b in _order(sk):
		var r := sk.get_bone_rest(b)
		var pos := r.origin
		var rot := r.basis.get_rotation_quaternion()
		var scl := r.basis.get_scale()
		if tracks.has(b):
			var tr: Dictionary = tracks[b]
			if tr.has(Animation.TYPE_POSITION_3D) and anim.track_get_key_count(tr[Animation.TYPE_POSITION_3D]) > 0:
				pos = anim.position_track_interpolate(tr[Animation.TYPE_POSITION_3D], t)
			if tr.has(Animation.TYPE_ROTATION_3D) and anim.track_get_key_count(tr[Animation.TYPE_ROTATION_3D]) > 0:
				rot = anim.rotation_track_interpolate(tr[Animation.TYPE_ROTATION_3D], t)
			if tr.has(Animation.TYPE_SCALE_3D) and anim.track_get_key_count(tr[Animation.TYPE_SCALE_3D]) > 0:
				scl = anim.scale_track_interpolate(tr[Animation.TYPE_SCALE_3D], t)
		var local := Transform3D(Basis(rot.normalized()).scaled(scl), pos)
		var p := sk.get_bone_parent(b)
		g[b] = (to_model * local) if p < 0 else (g[p] * local)
	return g

## Корень тела: первая кость без родителя, у которой есть дети (у Mixamo — Hips)
func _root_bone(sk: Skeleton3D) -> int:
	for b in sk.get_bone_count():
		if sk.get_bone_name(b).ends_with("Hips"):
			return b
	for b in sk.get_bone_count():
		if sk.get_bone_parent(b) < 0 and sk.get_bone_children(b).size() > 0:
			# если у корня один ребёнок (Armature → тело), берём его
			var c := sk.get_bone_children(b)
			return c[0] if c.size() == 1 and sk.get_bone_children(c[0]).size() > 1 else b
	return -1

## Ступни: у человека — Left/RightFoot; у зверей — нижние концы цепочек (у земли)
func _feet(sk: Skeleton3D, rest: Array, lo: float, height: float) -> Array:
	var out: Array = []
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b)
		if n.ends_with("LeftFoot") or n.ends_with("RightFoot"):
			out.append(b)
	if not out.is_empty():
		return out
	for b in sk.get_bone_count():
		if sk.get_bone_children(b).is_empty() and sk.get_bone_parent(b) >= 0 and rest[b].origin.y < lo + height * 0.25:
			out.append(b)   # концы лап у земли
	return out


# ---------------------------------------------------------------- 2) Кардинал играет

func _physics_process(dt: float) -> void:
	if not playing or not is_instance_valid(hero):
		return
	_flush_logger()
	var touch = hero.get("touch")
	if touch == null:
		return
	_monitor(dt)
	_coverage_tick(dt)
	_scenario_tick(dt)
	if not playing or _scripted:
		return
	if hero.dead:
		touch.move = Vector2.ZERO
		return
	# Зелье, когда здоровья мало
	if Game.hp < Game.max_hp * 0.35 and int(touch.potions) > 0:
		hero.drink_potion()
	var hp: Vector3 = hero.global_position
	_pick_target(hp)
	var goal: Vector3
	var reach := 1.9
	if is_instance_valid(_target):
		goal = _target.global_position
		reach = float(_target.T.get("reach", 1.8)) * 0.8 + 0.4
	else:
		_wp_t -= dt
		if _wp == Vector3.INF or _wp_t <= 0.0 or Vector2(_wp.x - hp.x, _wp.z - hp.z).length() < 2.0:
			_new_waypoint(hp)
		goal = _wp
		reach = 1.5
	var sub := _route(hp, goal)
	var d := Vector3(sub.x - hp.x, 0, sub.z - hp.z)
	var dist := d.length()
	if sub != goal:
		reach = 0.8
	var mv := Vector2.ZERO
	if dist > reach:
		var yaw: float = hero.rig.yaw if hero.rig else 0.0
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var dn := d / dist
		_detour_t -= get_physics_process_delta_time()
		if _detour_t > 0.0:
			dn = dn.rotated(Vector3.UP, _detour)
		mv = Vector2(dn.dot(right), dn.dot(fwd)).normalized()
	touch.move = mv
	touch.run = dist > 7.0 or sub != goal
	# Бой
	touch.block = false
	if is_instance_valid(_target) and dist < reach + 1.2:
		_atk_t -= dt
		_skill_t -= dt
		var winding: bool = str(_target.get("st")) == "windup"
		if winding and _rng.randf() < 0.04:
			if _rng.randf() < 0.5:
				touch.block = true
			else:
				hero.dodge()
		elif _skill_t <= 0.0:
			_skill_t = _rng.randf_range(3.0, 6.0)
			var ids: Array = []
			for k in ["dash", "horizontal"]:
				if int(touch.skill_ranks.get(k, 0)) > 0 and hero.cd.get(k, 1.0) <= 0.0:
					ids.append(k)
			if touch.art_icon != "" and hero.cd.get("art", 1.0) <= 0.0:
				ids.append("art")
			if not ids.is_empty():
				hero.use_skill(ids[_rng.randi() % ids.size()])
		elif _atk_t <= 0.0:
			_atk_t = 0.32
			hero.attack()
	# Застрял: пытается идти, а почти не сдвинулся
	_jump_t -= dt
	touch.jump = _jump_t > 0.0
	_stuck_t += dt
	if _stuck_t > 3.0:
		var moved := Vector2(hp.x - _stuck_pos.x, hp.z - _stuck_pos.z).length()
		if mv.length() > 0.5 and moved < 0.6 and not hero.busy and hero.get("attack_t") < 0.0:
			add("WARNING", "HERO_STUCK", "Герой", "застрял у (%d, %d, %d)" % [roundi(hp.x), roundi(hp.y), roundi(hp.z)])
			_stall_short += 1
			# в одном месте 3 раза подряд (9+ с) — ловушка на карте, из которой не выйти
			_stall_seq = _stall_seq + 1 if hp.distance_to(_stall_at) < 3.0 else 1
			_stall_at = hp
			if _stall_seq == 3:
				_stall_long += 1
				add("ERROR", "HERO_TRAPPED", "Застревания", "герой не может выбраться у (%d, %d, %d) — %s" % [roundi(hp.x), roundi(hp.y), roundi(hp.z), _zone()])
			_jump_t = 0.3
			# обойти: свернуть в сторону на 2 с; если не помогает — новая цель
			_detour = deg_to_rad(_rng.randf_range(60.0, 110.0)) * (1.0 if _rng.randf() < 0.5 else -1.0)
			_detour_t = 2.0
			if _rng.randf() < 0.4:
				_target = null
				_new_waypoint(hp)
		_stuck_pos = hp
		_stuck_t = 0.0

## Город окружён стеной — входить и выходить через ворота (север и юг, x = 0)
func _route(hp: Vector3, goal: Vector3) -> Vector3:
	var hero_world: bool = int(main.get("mode")) < 0 if main.get("mode") != null else true
	if not hero_world:
		return goal
	var w := WorldGen.TOWN_WALL
	var hin := WorldGen.town_dist(hp.x, hp.z) < w - 0.5
	var gin := WorldGen.town_dist(goal.x, goal.z) < w - 0.5
	if hin == gin:
		return goal
	var sz := signf(goal.z if hin else hp.z)
	if sz == 0.0:
		sz = 1.0
	var inner := Vector3(0, hp.y, sz * (w - 4.0))
	var outer := Vector3(0, hp.y, sz * (w + 6.0))
	if hin:
		return inner if absf(hp.x) > 1.5 or absf(hp.z) < w - 5.0 else outer
	return outer if absf(hp.x) > 1.5 or absf(hp.z) > w + 5.0 else inner

func _pick_target(hp: Vector3) -> void:
	if is_instance_valid(_target) and not _target.dead and _target.visible and _target.global_position.distance_to(hp) < 45.0:
		return
	_target = null
	var en = main.get("enemies")
	if en == null:
		return
	var best := 35.0
	for e in en.list:
		if not is_instance_valid(e) or e.dead or not e.visible:
			continue
		var dd: float = e.global_position.distance_to(hp)
		if dd < best and absf(e.global_position.y - hp.y) < 6.0:
			best = dd
			_target = e

func _new_waypoint(hp: Vector3) -> void:
	# чаще — к ближайшему монстру где-нибудь в мире (так Кардинал выходит из города)
	var en = main.get("enemies")
	if en and _rng.randf() < 0.6:
		var best := 160.0
		var pick := Vector3.INF
		for e in en.list:
			if is_instance_valid(e) and not e.dead and not e.get("in_dungeon") and not e.get("world2"):
				var dd: float = e.global_position.distance_to(hp)
				if dd < best:
					best = dd
					pick = e.global_position
		if pick != Vector3.INF:
			_wp = pick
			_wp_t = 40.0
			return
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(18.0, 45.0)
	var p := hp + Vector3(cos(a) * r, 0, sin(a) * r)
	_wp = p
	_wp_t = 25.0

func _flush_logger() -> void:
	if _logger == null:
		return
	for it in _logger.take():
		var sev := "WARNING" if it["type"] == 1 else "ERROR"   # 1 — предупреждение
		add(sev, "ENGINE", it["where"], str(it["msg"]).left(160))

## Наблюдение за героем и монстрами (каждые полсекунды)
func _monitor(dt: float) -> void:
	_mon_t += dt
	if Engine.get_frames_per_second() < 20:
		_low_fps_t += dt
		if _low_fps_t > 4.0:
			var hp: Vector3 = hero.global_position
			add("INFO", "LOW_FPS", "Производительность", "меньше 20 кадров/с у (%d, %d)" % [roundi(hp.x / 10) * 10, roundi(hp.z / 10) * 10])
			_low_fps_t = -30.0
	else:
		_low_fps_t = maxf(0.0, _low_fps_t)
	if _mon_t < 0.5:
		return
	var step_t := _mon_t
	_mon_t = 0.0
	_clip_check(step_t)
	_loot_tick()
	if _ov_label:
		var c := counts()
		_ov_label.text = " ◈ CARDINAL · %s · пройдено %d/%d · ошибок %d" % [step, coverage()["PASS"], checks.size(), coverage()["FAIL"]]
	var hp: Vector3 = hero.global_position
	if not hp.is_finite():
		add("ERROR", "HERO_NAN", "Герой", "позиция стала неверной (NaN)")
	# Монстры рядом
	var en = main.get("enemies")
	if en == null:
		return
	for e in en.list:
		if not is_instance_valid(e) or not e.visible or not e.is_physics_processing():
			continue
		var ep: Vector3 = e.global_position
		var who: String = e.T.get("name", e.type)
		if not ep.is_finite() or ep.y < CardinalDirector.fall_y_at(ep):
			add("ERROR", "MOB_FELL", who, "провалился под мир или позиция неверна")
			continue
		if ep.distance_to(hp) > 40.0:
			continue
		var m: Dictionary = _mobs.get(e, {"pos": ep, "slide": 0.0, "cd": ep.distance_to(hp), "ct": 0.0})
		var spd := Vector2(ep.x - m["pos"].x, ep.z - m["pos"].z).length() / maxf(step_t, 0.01)
		# Гонится, но не приближается
		if str(e.st) == "chase" and not e.dead:
			m["ct"] += step_t
			if m["ct"] > 6.0:
				var dnow := ep.distance_to(hp)
				if dnow > 4.0 and dnow > m["cd"] - 0.5 and hero.velocity.length() < 1.0:
					add("WARNING", "MOB_STUCK", who, "гонится, но застрял у (%d, %d, %d)" % [roundi(ep.x), roundi(ep.y), roundi(ep.z)])
				m["cd"] = dnow
				m["ct"] = 0.0
		else:
			m["ct"] = 0.0
			m["cd"] = ep.distance_to(hp)
		m["pos"] = ep
		_mobs[e] = m
