## ANIMATE 4.0 — конвейер: описание → параметры движения → ключевые позы → тайминг и кривые →
## IK и контакты → проверка → экспорт/предпросмотр.
## Шаблонный (детерминированный) генератор: слова описания выбирают шаблон и его параметры
## (AnimateSpec), позы всего тела берутся из библиотеки (AnimateTemplates). Это не ИИ «текст → движение».
class_name AnimatePipeline
extends RefCounted

const LIBRARY := "ANIMATE4"

## opts: "blade" — направление клинка в системе кисти (для наведения меча), "ref" / "ref_t" —
## анимация-образец для костей вне поз (пальцы), "spec" — готовые параметры вместо текста.
## Итог: {ok, error, animation, spec, template, contacts, ik, skeleton, report}
static func generate(text: String, sk: Skeleton3D, track_prefix: String, opts := {}) -> Dictionary:
	var out := {"ok": false, "error": ""}
	# 0. Скелет
	var sc := AnimateValidator4.check_skeleton(sk)
	out["skeleton"] = sc
	if not sc["ok"]:
		out["error"] = sc["instruction"] if sc["instruction"] != "" else "; ".join(sc["problems"])
		return out
	# 1–2. Описание → параметры
	var spec: Dictionary = opts.get("spec", AnimateSpec.parse(text))
	out["spec"] = spec
	if not spec["ok"]:
		out["error"] = spec["error"]
		return out
	# 3. Ключевые позы
	var tpl := AnimateTemplates.build(spec)
	if tpl.is_empty():
		out["error"] = "Нет шаблона для движения «%s»" % spec["motion"]
		return out
	# 4. Тайминг и кривые: фазы получают своё время (подготовка и восстановление — мягче,
	#    активная фаза — быстрее при «молниеносно»), позы между ключами — кубические кривые
	tpl = _timing(tpl, float(spec.get("speed", 1.0)))
	out["template"] = tpl
	var anim := PoseLib.build(sk, tpl["keys"], {}, tpl["length"], bool(tpl.get("loop", false)), opts.get("ref", null), float(opts.get("ref_t", 0.0)),
		track_prefix, opts.get("blade", Vector3.ZERO))
	# Опора: в стойке (первый ключ) носки стоят на земле — как в клипе-образце (или в позе покоя)
	out["ground_shift"] = ground(sk, anim, opts.get("ref", null), float(opts.get("ref_t", 0.0)))
	# Кисти — линейная интерполяция поворота: кубическая кривая перелетает пределы запястья между ключами
	for i in anim.get_track_count():
		var bn := String(anim.track_get_path(i)).get_slice(":", 1)
		if bn.ends_with("Hand") and anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			anim.track_set_interpolation_type(i, Animation.INTERPOLATION_LINEAR)
	# Пределы суставов: суставы с пределами пересчитываются с шагом 1/30 с и ограничиваются (между
	# ключами кривая может выйти за предел — например, запястье или колено)
	clamp_joints(sk, anim)
	# 5. IK и контакты: стопа, стоящая в двух ключах подряд, не скользит между ними
	var contacts := contacts_of(tpl)
	out["contacts"] = contacts
	out["ik"] = AnimateIK.pin_feet(sk, anim, track_prefix, contacts)
	# 6. Проверка
	var rep := AnimateValidator4.check_animation(sk, anim, tpl, contacts, opts.get("blade", Vector3.ZERO))
	out["report"] = rep
	out["animation"] = anim
	out["ok"] = rep["ok"]
	if not rep["ok"]:
		var bad: Array = rep["checks"].filter(func(c): return not c["ok"]).map(func(c): return "%s: %s" % [c["name"], c["detail"]])
		out["error"] = "; ".join(bad)
	return out

## Время ключей: доли u → секунды. speed > 1 ускоряет в первую очередь активную фазу.
static func _timing(tpl: Dictionary, speed: float) -> Dictionary:
	var keys: Array = tpl["keys"].duplicate(true)
	var w := {"ready": 1.0, "anticipation": 1.0 / sqrt(speed), "active": 1.0 / speed, "recovery": 1.0 / sqrt(speed)}
	var acc := 0.0
	var times := [0.0]
	for i in range(1, keys.size()):
		var du: float = keys[i]["u"] - keys[i - 1]["u"]
		acc += du * float(w.get(keys[i]["phase"], 1.0))
		times.append(acc)
	var length: float = tpl["length"] * acc
	for i in keys.size():
		keys[i]["t"] = times[i] / acc * length if acc > 0.0 else 0.0
	var out := tpl.duplicate()
	out["keys"] = keys
	out["length"] = length
	return out

## Интервалы контакта стоп из ключей: стопа, стоящая в ключах i…j подряд, — [t_i, t_j]
static func contacts_of(tpl: Dictionary) -> Array:
	var out: Array = []
	var keys: Array = tpl["keys"]
	for foot in ["LeftFoot", "RightFoot"]:
		var start := -1
		for i in keys.size() + 1:
			var on: bool = i < keys.size() and (keys[i]["plant"] as Array).has(foot)
			if on and start < 0:
				start = i
			elif not on and start >= 0:
				if i - 1 > start:
					out.append({"foot": foot, "t0": keys[start]["t"], "t1": keys[i - 1]["t"]})
				start = -1
	return out

## Экспорт: анимация в библиотеку ANIMATE4 проигрывателя (имя без библиотеки)
static func export_to(player: AnimationPlayer, anim_name: String, anim: Animation) -> String:
	var lib := player.get_animation_library(LIBRARY) if player.has_animation_library(LIBRARY) else null
	if lib == null:
		lib = AnimationLibrary.new()
		player.add_animation_library(LIBRARY, lib)
	if lib.has_animation(anim_name):
		lib.remove_animation(anim_name)
	lib.add_animation(anim_name, anim)
	return LIBRARY + "/" + anim_name

## Сохранить в файл ресурса (.res / .tres)
static func save(anim: Animation, path: String) -> int:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return ResourceSaver.save(anim, path)

## Высота земли под скелетом: ниже всех носков в клипе-образце (или в позе покоя)
static func ground_height(sk: Skeleton3D, ref: Animation, ref_t: float) -> float:
	var toes := [PoseLib.bone(sk, "LeftToeBase"), PoseLib.bone(sk, "RightToeBase"), PoseLib.bone(sk, "LeftFoot"), PoseLib.bone(sk, "RightFoot")]
	var g: Array = AnimateIK.globals(sk, ref, AnimateIK.track_map(sk, ref), ref_t) if ref else []
	var y := INF
	for b in toes:
		if b < 0:
			continue
		var p: Vector3 = (g[b] as Transform3D).origin if ref else sk.get_bone_global_rest(b).origin
		y = minf(y, p.y)
	return y if y < INF else 0.0

## Сдвинуть таз так, чтобы в первом ключе нижняя точка стоп была на земле. Возвращает сдвиг (м)
static func ground(sk: Skeleton3D, anim: Animation, ref: Animation, ref_t: float) -> float:
	var hips := PoseLib.bone(sk, "Hips")
	var tm := AnimateIK.track_map(sk, anim)
	if hips < 0 or not tm.has(hips) or not tm[hips].has("pos"):
		return 0.0
	var want := ground_height(sk, ref, ref_t)
	var g := AnimateIK.globals(sk, anim, tm, 0.0)
	var low := INF
	for n in ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]:
		var b := PoseLib.bone(sk, n)
		if b >= 0:
			low = minf(low, (g[b] as Transform3D).origin.y)
	var dy := want - low
	var tr: int = tm[hips]["pos"]
	for k in anim.track_get_key_count(tr):
		anim.track_set_key_value(tr, k, (anim.track_get_key_value(tr, k) as Vector3) + Vector3(0, dy, 0))
	return dy

## Пересчитать повороты суставов с пределами (PoseLib.LIMITS) с шагом 1/fps и ограничить
static func clamp_joints(sk: Skeleton3D, anim: Animation, fps := 30.0) -> void:
	var n := maxi(2, ceili(anim.length * fps))
	for tr in anim.get_track_count():
		if anim.track_get_type(tr) != Animation.TYPE_ROTATION_3D:
			continue
		var b := sk.find_bone(String(anim.track_get_path(tr)).get_slice(":", 1))
		if b < 0 or AnimateValidator4._limits(sk, b).is_empty():
			continue
		var vals: Array = []
		for i in n + 1:
			var t := anim.length * i / n
			vals.append([t, PoseLib.limit(sk, b, Basis(anim.rotation_track_interpolate(tr, t))).get_rotation_quaternion()])
		for k in range(anim.track_get_key_count(tr) - 1, -1, -1):
			anim.track_remove_key(tr, k)
		for v in vals:
			anim.rotation_track_insert_key(tr, v[0], v[1])
