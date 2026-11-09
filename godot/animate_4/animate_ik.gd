## ANIMATE 4.0 — шаг 5 конвейера: IK и контакты. Стопа, стоящая на земле (интервал контакта),
## остаётся на месте: бедро и голень решаются двухзвенным IK (колено — в плоскости прежнего сгиба),
## ориентация стопы сохраняется. Плюс прямая кинематика по трекам анимации (для IK и проверок).
class_name AnimateIK
extends RefCounted

## Треки анимации по костям: {кость: {"rot": номер трека, "pos": номер трека}}
static func track_map(sk: Skeleton3D, anim: Animation) -> Dictionary:
	var m := {}
	for t in anim.get_track_count():
		var bn := String(anim.track_get_path(t)).get_slice(":", 1)
		var b := sk.find_bone(bn)
		if b < 0:
			continue
		var e: Dictionary = m.get(b, {})
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			e["rot"] = t
		elif anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			e["pos"] = t
		m[b] = e
	return m

## Позы всех костей (в системе скелета) в момент t
static func globals(sk: Skeleton3D, anim: Animation, tm: Dictionary, t: float) -> Array:
	var out: Array = []
	out.resize(sk.get_bone_count())
	for b in sk.get_bone_count():
		var rest := sk.get_bone_rest(b)
		var basis := rest.basis.orthonormalized()
		var origin := rest.origin
		var e: Dictionary = tm.get(b, {})
		if e.has("rot"):
			basis = Basis(anim.rotation_track_interpolate(e["rot"], t))
		if e.has("pos"):
			origin = anim.position_track_interpolate(e["pos"], t)
		var local := Transform3D(basis, origin)
		var p := sk.get_bone_parent(b)
		out[b] = (out[p] as Transform3D) * local if p >= 0 else local
	return out

## Удержать стопы на земле в интервалах контакта. contacts: [{"foot": "LeftFoot", "t0": c, "t1": c}]
## fps — частота ключей IK. Возвращает {foot: наибольший сдвиг до IK (м)}
static func pin_feet(sk: Skeleton3D, anim: Animation, track_prefix: String, contacts: Array, fps := 30.0) -> Dictionary:
	var report := {}
	for c in contacts:
		var side: String = String(c["foot"]).replace("Foot", "")
		var up := PoseLib.bone(sk, side + "UpLeg")
		var leg := PoseLib.bone(sk, side + "Leg")
		var foot := PoseLib.bone(sk, side + "Foot")
		if up < 0 or leg < 0 or foot < 0:
			continue
		var tracks := {}
		for b in [up, leg, foot]:
			tracks[b] = _rot_track(sk, anim, track_prefix, b)
		var tm := track_map(sk, anim)
		var anchor: Vector3 = (globals(sk, anim, tm, c["t0"])[foot] as Transform3D).origin
		var worst := 0.0
		var n := maxi(1, ceili((float(c["t1"]) - float(c["t0"])) * fps))
		var solved: Array = []
		for i in n + 1:
			var t := lerpf(c["t0"], c["t1"], float(i) / n)
			var g := globals(sk, anim, tm, t)
			worst = maxf(worst, (g[foot] as Transform3D).origin.distance_to(anchor))
			solved.append([t, _solve_leg(sk, g, up, leg, foot, anchor)])
		# прежние ключи внутри интервала мешали бы: между ключами IK кривая шла бы через них
		for b in tracks:
			var tr: int = tracks[b]
			for k in range(anim.track_get_key_count(tr) - 1, -1, -1):
				var kt := anim.track_get_key_time(tr, k)
				if kt > float(c["t0"]) - 0.0001 and kt < float(c["t1"]) + 0.0001:
					anim.track_remove_key(tr, k)
		for s in solved:
			for b in s[1]:
				anim.rotation_track_insert_key(tracks[b], s[0], (s[1][b] as Basis).get_rotation_quaternion())
		report[c["foot"]] = maxf(report.get(c["foot"], 0.0), worst)
	return report

static func _rot_track(sk: Skeleton3D, anim: Animation, prefix: String, b: int) -> int:
	var path := NodePath(prefix + ":" + sk.get_bone_name(b))
	var t := anim.find_track(path, Animation.TYPE_ROTATION_3D)
	if t < 0:
		t = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, path)
		anim.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
		anim.rotation_track_insert_key(t, 0.0, sk.get_bone_rest(b).basis.get_rotation_quaternion())
	return t

## Базис по двум направлениям: y — ось кости, второе задаёт кручение (вперёд колена / плоскость сгиба)
static func _frame(y: Vector3, side: Vector3) -> Basis:
	var yy := y.normalized()
	var x := side.cross(yy)
	if x.length() < 0.0001:
		x = Vector3.RIGHT.cross(yy)
	x = x.normalized()
	return Basis(x, yy, x.cross(yy).normalized())

## Двухзвенный IK ноги: новые локальные повороты бедра, голени и стопы, чтобы голеностоп был в target.
## Колено сгибается вперёд по тазу (кручение ноги следует за тазом — без перекрута при развороте);
## стопа сохраняет прежнюю ориентацию.
static func _solve_leg(sk: Skeleton3D, g: Array, up: int, leg: int, foot: int, target: Vector3) -> Dictionary:
	var gu: Transform3D = g[up]
	var gl: Transform3D = g[leg]
	var gf: Transform3D = g[foot]
	var hips := PoseLib.bone(sk, "Hips")
	var fwd: Vector3 = ((g[hips] as Transform3D).basis * Vector3(0, 0, 1)) if hips >= 0 else Vector3(0, 0, 1)
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3(0, 0, 1)
	var H := gu.origin
	var K := gl.origin
	var A := gf.origin
	var a := H.distance_to(K)
	var b := K.distance_to(A)
	var to_t := target - H
	var d := clampf(to_t.length(), absf(a - b) + 0.001, a + b - 0.0005)
	var dir := to_t.normalized()
	var pole := fwd - dir * fwd.dot(dir)
	if pole.length() < 0.001:
		pole = (K - H) - dir * (K - H).dot(dir)
	pole = pole.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var K2 := H + dir * (cos_a * a) + pole * (sqrt(1.0 - cos_a * cos_a) * a)
	var A2 := H + dir * d
	# прежние кадры костей (ось кости + вперёд) → новые: перенос с сохранением «посадки» кости в кадре
	var old_u := _frame(K - H, _side(K - H, A - K, fwd))
	var new_u := _frame(K2 - H, _side(K2 - H, A2 - K2, fwd))
	var gu2 := new_u * old_u.inverse() * gu.basis
	var old_l := _frame(A - K, _side(K - H, A - K, fwd))
	var new_l := _frame(A2 - K2, _side(K2 - H, A2 - K2, fwd))
	var gl2 := new_l * old_l.inverse() * gl.basis
	var parent := sk.get_bone_parent(up)
	var gp: Basis = (g[parent] as Transform3D).basis if parent >= 0 else Basis()
	return {
		up: (gp.inverse() * gu2).orthonormalized(),
		leg: _no_hyperextend(sk, leg, (gu2.inverse() * gl2).orthonormalized()),
		# стопа — прежняя ориентация, но в пределах голеностопа
		foot: PoseLib.limit(sk, foot, (gl2.inverse() * gf.basis).orthonormalized()),
	}

## Ось сгиба ноги: нормаль плоскости бедро–голень; почти прямая нога — поперёк направления таза
static func _side(thigh: Vector3, shin: Vector3, fwd: Vector3) -> Vector3:
	var n := thigh.cross(shin)
	if n.length() < 0.0005:
		n = thigh.cross(fwd)
	return n.normalized()

## Колено не разгибается назад: сгиб не меньше нижнего предела, остальные оси — как решил IK
static func _no_hyperextend(sk: Skeleton3D, b: int, local: Basis) -> Basis:
	var lim := AnimateValidator4._limits(sk, b)
	if lim.is_empty():
		return local
	var r0 := sk.get_bone_rest(b).basis.orthonormalized()
	var e := (r0.inverse() * local).get_euler(EULER_ORDER_XZY)
	if rad_to_deg(e.x) >= lim[0]:
		return local
	e.x = deg_to_rad(lim[0])
	return r0 * Basis.from_euler(e, EULER_ORDER_XZY)
