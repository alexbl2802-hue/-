## ANIMATE 4.0 — шаг 6 конвейера: проверка скелета и анимации.
## Скелет: нужные кости (по окончанию имени — подходит для любых приставок, ретаргетинг Mixamo и
## похожих), их расположение и ориентация. Отсутствующие кости автоматически не добавляются: у новой
## кости нет весов скининга, и меш за ней не пойдёт. Безопасно можно добавить только кость-сокет без
## весов (для оружия) — add_socket(). Иначе — отчёт и инструкция.
## Анимация: конечные значения, диапазоны суставов, скольжение стоп на контактах, движение всего тела,
## направление клинка в ключевых позах, щит перед собой, порядок фаз.
class_name AnimateValidator4
extends RefCounted

const REQUIRED := ["Hips", "Spine", "Neck", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm",
	"RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]
const FOOT_SLIDE_MAX := 0.02      # м — допустимый сдвиг стоящей стопы
const JOINT_TOL := 3.0            # градусы сверх пределов PoseLib.LIMITS
const BODY_MOTION_MIN := 8.0      # градусы — «часть тела участвует в движении»
const BLADE_DOT_MIN := 0.85       # совпадение клинка с ключом (косинус)

static func check_skeleton(sk: Skeleton3D) -> Dictionary:
	var missing: Array = []
	for n in REQUIRED:
		if PoseLib.bone(sk, n) < 0:
			missing.append(n)
	var problems: Array = []
	if missing.is_empty():
		var g := func(n: String) -> Vector3: return sk.get_bone_global_rest(PoseLib.bone(sk, n)).origin
		var hips: Vector3 = g.call("Hips")
		if not (g.call("LeftArm").x > hips.x and g.call("RightArm").x < hips.x):
			problems.append("левая рука не слева (+X) или правая не справа: скелет повёрнут или зеркален")
		if not (g.call("Head").y > hips.y and g.call("LeftFoot").y < hips.y and g.call("RightFoot").y < hips.y):
			problems.append("голова не выше таза или стопы не ниже: ось Y скелета не вверх")
		var toe := PoseLib.bone(sk, "LeftToeBase")
		if toe >= 0 and sk.get_bone_global_rest(toe).origin.z <= g.call("LeftFoot").z:
			problems.append("носок не впереди пятки: персонаж смотрит не по +Z")
	var instr := ""
	if not missing.is_empty():
		instr = "Нет костей: %s. Автодобавление не выполняется — у новой кости нет весов скининга, меш за ней не пойдёт. Добавьте кости в 3D-редакторе (или перепривяжите модель через Mixamo) и переэкспортируйте GLB. Для крепления оружия можно добавить кость-сокет без весов: AnimateValidator4.add_socket()." % ", ".join(missing)
	return {"ok": missing.is_empty() and problems.is_empty(), "missing": missing, "problems": problems, "instruction": instr}

## Кость-сокет без весов (например, для оружия) — безопасна для скининга: ни одна вершина к ней не привязана
static func add_socket(sk: Skeleton3D, name: String, parent_suffix: String, local: Transform3D) -> int:
	var parent := PoseLib.bone(sk, parent_suffix)
	if parent < 0 or sk.find_bone(name) >= 0:
		return sk.find_bone(name)
	sk.add_bone(name)
	var b := sk.find_bone(name)
	sk.set_bone_parent(b, parent)
	sk.set_bone_rest(b, local)
	sk.reset_bone_pose(b)
	return b

## Проверки анимации. tpl — шаблон (ключи с "t" в секундах), contacts — интервалы стоп,
## blade — направление клинка в системе кости правой кисти (или ZERO)
static func check_animation(sk: Skeleton3D, anim: Animation, tpl: Dictionary, contacts: Array, blade: Vector3) -> Dictionary:
	var checks: Array = []
	var tm := AnimateIK.track_map(sk, anim)
	var fps := 30.0
	var n := maxi(2, ceili(anim.length * fps))
	var frames: Array = []
	for i in n + 1:
		var t := anim.length * i / n
		frames.append([t, AnimateIK.globals(sk, anim, tm, t)])
	# 1. Конечные значения
	var finite := true
	for f in frames:
		for x in f[1]:
			if not (x as Transform3D).origin.is_finite():
				finite = false
	checks.append({"name": "finite", "ok": finite, "detail": "все позы — конечные числа" if finite else "NaN/бесконечность в позах"})
	# 2. Диапазоны суставов
	var worst := {"bone": "", "over": 0.0, "t": 0.0, "e": Vector3.ZERO}
	for b in tm:
		if not tm[b].has("rot"):
			continue
		var lim := _limits(sk, b)
		if lim.is_empty():
			continue
		var r0 := sk.get_bone_rest(b).basis.orthonormalized()
		for i in n + 1:
			var t := anim.length * i / n
			var local := Basis(anim.rotation_track_interpolate(tm[b]["rot"], t))
			var e := (r0.inverse() * local).get_euler(EULER_ORDER_XZY) * (180.0 / PI)
			var over := maxf(maxf(lim[0] - e.x, e.x - lim[1]), maxf(maxf(lim[2] - e.z, e.z - lim[3]), maxf(lim[4] - e.y, e.y - lim[5])))
			if over > worst["over"]:
				worst = {"bone": sk.get_bone_name(b), "over": over, "t": t, "e": e.round()}
	checks.append({"name": "joint_ranges", "ok": worst["over"] <= JOINT_TOL,
		"detail": "все суставы в пределах" if worst["over"] <= 0.0 else "наибольший выход: %s на %.1f° (t=%.2f с, сгиб/кручение/вбок %s)" % [worst["bone"], worst["over"], worst["t"], worst["e"]]})
	# 3. Скольжение стоп на контактах
	var slide := 0.0
	var slide_at := ""
	for c in contacts:
		var fb := PoseLib.bone(sk, c["foot"])
		var anchor: Vector3 = (AnimateIK.globals(sk, anim, tm, c["t0"])[fb] as Transform3D).origin
		for f in frames:
			if f[0] >= c["t0"] - 0.0001 and f[0] <= c["t1"] + 0.0001:
				var dd: float = (f[1][fb] as Transform3D).origin.distance_to(anchor)
				if dd > slide:
					slide = dd
					slide_at = "%s t=%.2f" % [c["foot"], f[0]]
	checks.append({"name": "foot_sliding", "ok": slide <= FOOT_SLIDE_MAX,
		"detail": "контактов %d, наибольший сдвиг стопы %.3f м %s" % [contacts.size(), slide, slide_at]})
	# 4. Всё тело в движении (атака/рывок/защита — не «одна рука»)
	var groups := {"таз/позвоночник": ["Hips", "Spine", "Spine1"], "левая нога": ["LeftUpLeg", "LeftLeg"], "правая нога": ["RightUpLeg", "RightLeg"],
		"правая рука": ["RightArm", "RightForeArm"], "левая рука": ["LeftArm", "LeftForeArm"]}
	var still: Array = []
	for gname in groups:
		var best := 0.0
		for bn in groups[gname]:
			var b := PoseLib.bone(sk, bn)
			if b < 0 or not tm.has(b) or not tm[b].has("rot"):
				continue
			var q0 := anim.rotation_track_interpolate(tm[b]["rot"], 0.0)
			for f in frames:
				best = maxf(best, rad_to_deg(q0.angle_to(anim.rotation_track_interpolate(tm[b]["rot"], f[0]))))
		if best < BODY_MOTION_MIN:
			still.append("%s (%.0f°)" % [gname, best])
	checks.append({"name": "full_body", "ok": still.is_empty(), "detail": "участвуют таз/позвоночник, обе руки и обе ноги" if still.is_empty() else "почти не движутся: " + ", ".join(still)})
	# 5. Клинок по ключам
	var hand := PoseLib.bone(sk, "RightHand")
	checks.append({"name": "weapon_bone", "ok": hand >= 0 and tm.has(hand), "detail": "кисть с оружием (RightHand) анимирована" if hand >= 0 and tm.has(hand) else "нет анимации кисти RightHand"})
	if blade != Vector3.ZERO and hand >= 0:
		var low := 1.0
		var low_t := 0.0
		for key in tpl["keys"]:
			if not key.has("sword"):
				continue
			var g := AnimateIK.globals(sk, anim, tm, key["t"])
			var bd: Vector3 = ((g[hand] as Transform3D).basis * blade).normalized()
			var dt: float = bd.dot(key["sword"])
			if dt < low:
				low = dt
				low_t = key["t"]
		checks.append({"name": "weapon_aim", "ok": low >= BLADE_DOT_MIN, "detail": "клинок в ключевых позах: худшее совпадение %.2f (t=%.2f с)" % [low, low_t]})
	# 6. Щит перед собой (блок щитом): предплечье почти вертикально и впереди груди
	if tpl.get("name", "") == "block_shield":
		var g := AnimateIK.globals(sk, anim, tm, anim.length * 0.6)
		var fa: Transform3D = g[PoseLib.bone(sk, "LeftForeArm")]
		var lh: Transform3D = g[PoseLib.bone(sk, "LeftHand")]
		var sp: Transform3D = g[PoseLib.bone(sk, "Spine1")] if PoseLib.bone(sk, "Spine1") >= 0 else g[PoseLib.bone(sk, "Spine")]
		var up := (lh.origin - fa.origin).normalized()
		var front := (fa.origin.z + lh.origin.z) * 0.5 - sp.origin.z
		checks.append({"name": "shield_front", "ok": up.y > 0.6 and front > 0.15, "detail": "предплечье со щитом: вертикальность %.2f, впереди груди на %.2f м" % [up.y, front]})
	# 7. Фазы: атака — подготовка → активная → восстановление
	var phases: Array = tpl["keys"].map(func(k): return k["phase"])
	var need := ["active", "recovery"] if tpl.get("name", "").begins_with("block") else ["anticipation", "active", "recovery"]
	if tpl.get("name", "").begins_with("dash_run"):
		need = ["active", "recovery"]
	var order_ok := true
	var last := -1
	for p in need:
		var i := phases.find(p)
		if i < 0 or i < last:
			order_ok = false
		last = maxi(last, i)
	checks.append({"name": "phases", "ok": order_ok, "detail": " → ".join(phases)})
	var ok := true
	for c in checks:
		ok = ok and c["ok"]
	return {"ok": ok, "checks": checks}

static func _limits(sk: Skeleton3D, b: int) -> Array:
	var name := sk.get_bone_name(b)
	for k in PoseLib.LIMITS:
		if name.ends_with(k) and (name.length() == k.length() or not name[name.length() - k.length() - 1].to_lower() in "abcdefghijklmnopqrstuvwxyz"):
			return PoseLib.LIMITS[k]
	return []
