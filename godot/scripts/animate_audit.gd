## ANIMATE: проверка моделей и анимаций (перенесена из автотеста CARDINAL — это зона ANIMATE).
## У героя и у каждой модели монстров: есть ли все клипы, которые просит игра; дорожки на кости,
## которых нет в скелете; кости ног без анимации в ходьбе и беге; «встаёт вертикально / заваливается»;
## ноги не шагают или машут вбок; кости растягиваются; рывок на стыке цикла; пустые и битые клипы;
## нехватка костей в человекоподобном скелете. Ничего не меняет — только отчёт
## (окно ANIMATE и файл user://animate_audit.json).
class_name AnimateAudit
extends Node

signal finished

const REPORT := "user://animate_audit.json"
const TILT_MAX := 55.0
const NO_TILT := ["death", "die", "dead", "roll", "dodge", "fall", "knock", "lie", "sleep", "crawl", "jump", "flip", "dash", "spin", "stun", "down", "get_up", "getup"]
const GAIT := ["walk", "run", "sprint", "chase"]
const NOT_STRAIGHT := ["left", "right", "turn", "strafe", "side", "diagonal", "back", "circle"]
const NOT_LOOP := ["turn", "stop", "start", "to_", "sudden", "jump", "land"]

var hero: Node
var issues := {}            # ключ → {sev, code, subject, msg, count}
var running := false

func add(sev: String, code: String, subject: String, msg: String) -> void:
	var key := code + "|" + subject + "|" + msg
	if issues.has(key):
		issues[key]["count"] += 1
		return
	issues[key] = {"sev": sev, "code": code, "subject": subject, "msg": msg, "count": 1}

func counts() -> Dictionary:
	var c := {"ERROR": 0, "WARNING": 0, "INFO": 0}
	for k in issues:
		c[issues[k]["sev"]] = c.get(issues[k]["sev"], 0) + 1
	return c

## Проверить всё; по окончании — сигнал finished и отчёт в файле
func run(h: Node) -> void:
	if running:
		return
	running = true
	hero = h
	issues.clear()
	await audit_models()
	var list: Array = issues.values()
	list.sort_custom(func(a, b): return ["ERROR", "WARNING", "INFO"].find(a["sev"]) < ["ERROR", "WARNING", "INFO"].find(b["sev"]))
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"counts": counts(), "issues": list}, "  "))
	running = false
	finished.emit()

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


## Кости человекоподобного скелета (имена Mixamo; приставка — как у этого скелета)
const HUMANOID := ["Hips", "Spine", "Neck", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm",
	"RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]

func _missing_bones(sk: Skeleton3D) -> Array:
	var pre := ""
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.ends_with("Hips"):
			pre = n.substr(0, n.length() - 4)
			break
	var out: Array = []
	for b in HUMANOID:
		if sk.find_bone(pre + b) < 0:
			out.append(b)
	return out

func _audit(who: String, ap: AnimationPlayer, sk: Skeleton3D, wanted: Array, humanoid: bool, model_root: Node) -> void:
	for n in wanted:
		if not ap.has_animation(n):
			add("ERROR", "NO_CLIP", who, "нет анимации «%s», а игра её запускает" % n)
	if humanoid:
		var missing := _missing_bones(sk)
		if not missing.is_empty():
			add("ERROR", "NO_BONES", who, "в скелете не хватает костей: " + ", ".join(missing))
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
