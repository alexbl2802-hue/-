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

var main: Node
var hero: Node
var issues := {}            # ключ → {sev, code, subject, msg, count, first}
var playing := false
var audit_done := false
var started_at := 0.0

var _logger: CardinalErrorLogger
var _wp := Vector3.INF      # куда идти, если монстров рядом нет
var _wp_t := 0.0
var _target: Node3D
var _atk_t := 0.0
var _skill_t := 2.0
var _jump_t := 0.0
var _stuck_pos := Vector3.ZERO
var _stuck_t := 0.0
var _mon_t := 0.0
var _low_fps_t := 0.0
var _hero_pose := Vector3.ZERO
var _hero_frozen_t := 0.0
var _mobs := {}             # монстр → {pos, slide_t, chase_d, chase_t}
var _overlay: CanvasLayer
var _ov_label: Label
var _rng := RandomNumberGenerator.new()


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

func save_report() -> void:
	var list: Array = issues.values()
	list.sort_custom(func(a, b): return ["ERROR", "WARNING", "INFO"].find(a["sev"]) < ["ERROR", "WARNING", "INFO"].find(b["sev"]))
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"seconds": snappedf(Time.get_ticks_msec() / 1000.0 - started_at, 1.0),
			"counts": counts(), "issues": list}, "  "))


# ---------------------------------------------------------------- запуск и остановка

func start(m: Node) -> void:
	main = m
	hero = m.get("hero")
	if hero == null:
		return
	issues.clear()
	_mobs.clear()
	started_at = Time.get_ticks_msec() / 1000.0
	playing = true
	audit_done = false
	_logger = CardinalErrorLogger.new()
	OS.add_logger(_logger)
	_stuck_pos = hero.global_position
	_make_overlay()
	CardinalDirector.core.log_event("▶ Кардинал играет и ищет ошибки")
	changed.emit()
	await audit_models()
	audit_done = true
	changed.emit()

func stop() -> void:
	if not playing:
		return
	playing = false
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
	var c := counts()
	CardinalDirector.core.log_event("■ Автотест: %d с — ошибок %d, предупреждений %d, заметок %d. Отчёт: cardinal_autotest.json" % [
		roundi(Time.get_ticks_msec() / 1000.0 - started_at), c["ERROR"], c["WARNING"], c["INFO"]])
	changed.emit()

func _exit_tree() -> void:
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
	box.position = Vector2(-190, 74)
	box.custom_minimum_size = Vector2(380, 34)
	_overlay.add_child(box)
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UiKit.box(Color(0.02, 0.06, 0.1, 0.8), Color(0.45, 0.8, 1, 0.6), 8, 4, 1))
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(bg)
	_ov_label = UiKit.label("", 12, Color(0.75, 0.92, 1))
	bg.add_child(_ov_label)
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
	if not NO_TILT.any(func(x): return low.contains(x)) and tilt_max > TILT_MAX:
		add("ERROR", "TILT", who, "«%s»: тело поворачивается на %d° — модель встаёт вертикально или заваливается" % [name, roundi(tilt_max)])
	if stretch != "":
		add("WARNING", "STRETCH", who, "«%s»: кость растягивается или сжимается: %s" % [name, stretch])
	if gait and not feet.is_empty():
		var fwd := 0.0
		var side := 0.0
		for f in fx:
			side = maxf(side, fx[f][1] - fx[f][0])
			fwd = maxf(fwd, fx[f][3] - fx[f][2])
		if fwd < height * 0.04:
			add("ERROR", "FEET_STILL", who, "«%s»: ноги почти не шагают (размах %d см)" % [name, roundi(fwd * 100)])
		elif side > fwd * 0.8 and side > height * 0.06:
			add("ERROR", "LEG_SWING", who, "«%s»: ноги машут вбок (вбок %d см, вперёд-назад %d см)" % [name, roundi(side * 100), roundi(fwd * 100)])
	# Стык цикла: первый и последний кадр должны совпадать
	if gait or ((low.contains("idle") or low.contains("stance")) and anim.loop_mode != Animation.LOOP_NONE):
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
		if rest[b].origin.y < lo + height * 0.12 and sk.get_bone_parent(b) >= 0:
			var p := sk.get_bone_parent(b)
			if rest[p].origin.y >= lo + height * 0.12:   # самая нижняя кость цепочки
				out.append(b)
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
	var d := Vector3(goal.x - hp.x, 0, goal.z - hp.z)
	var dist := d.length()
	var mv := Vector2.ZERO
	if dist > reach:
		var yaw: float = hero.rig.yaw if hero.rig else 0.0
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var dn := d / dist
		mv = Vector2(dn.dot(right), dn.dot(fwd)).normalized()
	touch.move = mv
	touch.run = dist > 7.0
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
			for k in ["whirl", "dash", "horizontal"]:
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
			_jump_t = 0.3
			_target = null
			_new_waypoint(hp)
		_stuck_pos = hp
		_stuck_t = 0.0

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
	var step := _mon_t
	_mon_t = 0.0
	if _ov_label:
		var c := counts()
		_ov_label.text = " ◈ Кардинал играет%s · ошибок %d · предупр. %d" % ["" if audit_done else " (проверяет модели)", c["ERROR"], c["WARNING"]]
	var hp: Vector3 = hero.global_position
	if not hp.is_finite():
		add("ERROR", "HERO_NAN", "Герой", "позиция стала неверной (NaN)")
	# Анимация героя замерла, хотя он бежит
	var sk: Skeleton3D = hero.get("_sk")
	if sk and not hero.dead:
		var probe := Vector3.ZERO
		for b in [sk.find_bone("mixamorig_LeftFoot"), sk.find_bone("mixamorig_RightHand"), mini(5, sk.get_bone_count() - 1)]:
			if b >= 0:
				probe += sk.get_bone_pose_position(b) + sk.get_bone_pose_rotation(b).get_euler()
		var vel: Vector3 = hero.velocity
		if Vector2(vel.x, vel.z).length() > 1.5 and probe.is_equal_approx(_hero_pose):
			_hero_frozen_t += step
			if _hero_frozen_t > 1.5:
				add("ERROR", "HERO_ANIM", "Герой", "бежит, а анимация стоит на месте")
				_hero_frozen_t = 0.0
		else:
			_hero_frozen_t = 0.0
		_hero_pose = probe
	# Монстры рядом
	var en = main.get("enemies")
	if en == null:
		return
	for e in en.list:
		if not is_instance_valid(e) or not e.visible or not e.is_physics_processing():
			continue
		var ep: Vector3 = e.global_position
		var who: String = e.T.get("name", e.type)
		if not ep.is_finite() or ep.y < CardinalDirector.FALL_Y:
			add("ERROR", "MOB_FELL", who, "провалился под мир или позиция неверна")
			continue
		if ep.distance_to(hp) > 40.0:
			continue
		var m: Dictionary = _mobs.get(e, {"pos": ep, "slide": 0.0, "cd": ep.distance_to(hp), "ct": 0.0})
		var spd := Vector2(ep.x - m["pos"].x, ep.z - m["pos"].z).length() / maxf(step, 0.01)
		var ap: AnimationPlayer = e.get("_ap")
		if ap and not e.dead:
			if not ap.is_playing():
				add("WARNING", "MOB_ANIM_STOP", who, "анимация остановилась (стоит в позе)")
			var cur := String(ap.current_animation)
			var C: Dictionary = e.get("C") if e.get("C") is Dictionary else {}
			var stance: String = C.get("stance", "")
			if spd > 1.6 and (cur == "" or cur == stance or cur.to_lower().contains("idle")) and str(e.st) in ["chase", "wander", "home", "idle"]:
				m["slide"] += step
				if m["slide"] > 1.0:
					add("WARNING", "MOB_SLIDE", who, "двигается без анимации шага («%s», %.1f м/с)" % [cur, spd])
					m["slide"] = -10.0
			else:
				m["slide"] = maxf(0.0, m["slide"])
		# Гонится, но не приближается
		if str(e.st) == "chase" and not e.dead:
			m["ct"] += step
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
