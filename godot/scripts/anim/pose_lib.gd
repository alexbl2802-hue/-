## Свои анимации для скелетов Mixamo: позы задаются поворотами костей в осях персонажа
## (X — влево, Y — вверх, Z — вперёд), в градусах, и собираются в настоящие анимации Godot.
##
## Поворот кости — «в осях персонажа, поверх поворотов родителей»: если повернуть плечо,
## вся рука поворачивается вместе с ним, а сгиб локтя задаётся в тех же осях, как будто
## рука в исходной позе. Так позы легко описывать словами: «рука вниз на 60°, локоть 30°».
##
## Ключ анимации: {"t": секунда, "p": {кость: Vector3(x, y, z) в градусах, ...},
##                 "hips": Vector3 — сдвиг таза в метрах (в осях персонажа)}
## Кости не из ключей берутся из базовой позы, пальцы — из анимации-образца (хват меча).
class_name PoseLib
extends RefCounted

## Порядок углов: сначала поворот вокруг Y (разворот), потом X (наклон вперёд), потом Z (вбок)
static func rot(deg: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)), EULER_ORDER_YXZ)

## Индекс кости по окончанию имени ("RightArm" → "mixamorig_RightArm")
static func bone(sk: Skeleton3D, suffix: String) -> int:
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.ends_with(suffix) and (n.length() == suffix.length() or not n[n.length() - suffix.length() - 1].to_lower() in "abcdefghijklmnopqrstuvwxyz"):
			return i
	return -1

## Собрать анимацию.
## keys — ключи (см. выше); base — поза под всеми ключами; length — длина, loop — петля;
## ref — анимация-образец и секунда в ней: из неё берутся кости, которых нет в позах (пальцы);
## track_prefix — путь к скелету в треках ("SmartRigArmature/Skeleton3D")
## blade — направление клинка в системе кости правой кисти: тогда в ключе можно указать
## "sword": Vector3 — куда смотрит клинок (в осях персонажа), и кисть повернётся сама
## Повороты костей в каждом ключе: поза ключа = база + ключ, пределы суставов,
## кисть «по клинку». other(кость, № ключа) — локальный поворот костей, которых нет в позе
## (для своих анимаций — покой, для наложения на запись — кадр записи).
## Возвращает [имя → кость, кость → [локальный поворот в каждом ключе]]
static func _solve(sk: Skeleton3D, keys: Array, base: Dictionary, blade: Vector3, other: Callable) -> Array:
	var used := {}
	for k in base:
		used[k] = true
	for key in keys:
		for k in key["p"]:
			used[k] = true
	var hand := bone(sk, "RightHand")
	var aims := false
	for key in keys:
		if key.has("sword"):
			aims = true
	if aims and hand >= 0 and blade != Vector3.ZERO:
		used["RightHand"] = true
	var idx := {}
	for k in used:
		var b := bone(sk, k)
		if b >= 0:
			idx[k] = b
	var locals := {}
	for k in idx:
		var b: int = idx[k]
		var arr := []
		for key in keys:
			var deg: Vector3 = key["p"].get(k, base.get(k, Vector3.ZERO))
			arr.append(limit(sk, b, _rest_p(sk, b).inverse() * rot(deg) * _rest_g(sk, b)))
		locals[b] = arr
	# Кисть «по клинку»: поворот кисти, при котором клинок смотрит куда указано, —
	# по уже ограниченным плечу и локтю; сама кисть тоже не выходит за пределы запястья
	if aims and hand >= 0 and blade != Vector3.ZERO:
		var chain := []
		var c := sk.get_bone_parent(hand)
		while c >= 0:
			chain.push_front(c)
			c = sk.get_bone_parent(c)
		var arm := bone(sk, "RightArm")
		for ki in keys.size():
			var key: Dictionary = keys[ki]
			if not key.has("sword"):
				continue
			var want: Vector3 = (key["sword"] as Vector3).normalized()
			# Если кистью не достать — ещё и поворачиваем плечо вокруг своей оси (в пределах сустава)
			var best_d := -2.0
			var best_hand := Basis()
			var arm0: Basis = locals[arm][ki] if locals.has(arm) else other.call(arm, ki)
			var best_arm: Basis = arm0
			for tw in [0.0, -20.0, 20.0, -40.0, 40.0, -60.0, 60.0]:
				var arm_l: Basis = limit(sk, arm, arm0 * Basis(Vector3.UP, deg_to_rad(tw))) if locals.has(arm) else arm0
				var dp := Basis()   # глобальный поворот предплечья относительно покоя (в осях персонажа)
				for cb in chain:
					var l: Basis = arm_l if cb == arm else (locals[cb][ki] if locals.has(cb) else other.call(cb, ki))
					dp = dp * (_rest_p(sk, cb) * l * _rest_g(sk, cb).inverse())
				var res := _aim_hand(sk, hand, dp, blade, want)
				if res[1] > best_d + 0.005:
					best_d = res[1]
					best_hand = res[0]
					best_arm = arm_l
				if best_d > 0.985 or not locals.has(arm):
					break
			locals[hand][ki] = best_hand
			if locals.has(arm):
				locals[arm][ki] = best_arm
			if aim_log and best_d < 0.94:
				print("  клинок отклонён на %d°" % roundi(rad_to_deg(acos(clampf(best_d, -1, 1)))))
	return [idx, locals]

## Перенести запись движения с другого скелета Mixamo (например, ходьбу гоблина на героя):
## поворот каждой кости относительно её покоя в осях персонажа переносится как есть,
## сдвиг таза — с поправкой на рост. frames — кадров на всю запись.
static func retarget(src_sk: Skeleton3D, src: Animation, dst_sk: Skeleton3D, track_prefix: String, frames := 30) -> Animation:
	var anim := Animation.new()
	anim.length = src.length
	anim.loop_mode = src.loop_mode
	var loop := src.loop_mode != Animation.LOOP_NONE
	# Треки вращения записи по костям исходного скелета
	var rot_tr := {}
	var pos_tr := -1
	var src_hips := bone(src_sk, "Hips")
	for t in src.get_track_count():
		var bn := String(src.track_get_path(t)).get_slice(":", 1)
		var b := src_sk.find_bone(bn)
		if b < 0:
			continue
		if src.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot_tr[b] = t
		elif src.track_get_type(t) == Animation.TYPE_POSITION_3D and b == src_hips:
			pos_tr = t
	# Соответствие костей по окончанию имени
	var pairs := []   # [кость героя, кость источника]
	for db in dst_sk.get_bone_count():
		var dn := dst_sk.get_bone_name(db)
		var suffix := dn.get_slice("_", dn.get_slice_count("_") - 1)
		var sb := bone(src_sk, suffix)
		if sb >= 0 and rot_tr.has(sb):
			pairs.append([db, sb])
	var tracks := {}
	for pr in pairs:
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath(track_prefix + ":" + dst_sk.get_bone_name(pr[0])))
		anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_LINEAR)
		anim.track_set_interpolation_loop_wrap(tr, loop)
		tracks[pr[0]] = tr
	var dst_hips := bone(dst_sk, "Hips")
	var htr := -1
	var scale := 1.0
	if pos_tr >= 0 and dst_hips >= 0:
		htr = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(htr, NodePath(track_prefix + ":" + dst_sk.get_bone_name(dst_hips)))
		anim.track_set_interpolation_loop_wrap(htr, loop)
		scale = dst_sk.get_bone_global_rest(dst_hips).origin.y / maxf(0.01, src_sk.get_bone_global_rest(src_hips).origin.y)
	for f in frames + 1:
		var t := src.length * f / frames
		# Глобальные повороты источника в этом кадре
		var sg := {}
		for b in src_sk.get_bone_count():
			var l: Basis = Basis(src.rotation_track_interpolate(rot_tr[b], t)) if rot_tr.has(b) else src_sk.get_bone_rest(b).basis.orthonormalized()
			var p := src_sk.get_bone_parent(b)
			sg[b] = (sg[p] as Basis) * l if p >= 0 else l
		# Глобальные повороты героя: тот же поворот относительно покоя
		var dg := {}
		for pr in pairs:
			var delta: Basis = (sg[pr[1]] as Basis) * _rest_g(src_sk, pr[1]).inverse()
			dg[pr[0]] = delta * _rest_g(dst_sk, pr[0])
		for pr in pairs:
			var db: int = pr[0]
			var p := dst_sk.get_bone_parent(db)
			var pg: Basis = dg[p] if dg.has(p) else (_rest_g(dst_sk, p) if p >= 0 else Basis())
			var local: Basis = pg.inverse() * (dg[db] as Basis)
			anim.rotation_track_insert_key(tracks[db], t, local.orthonormalized().get_rotation_quaternion())
		if htr >= 0:
			var sp: Vector3 = src.position_track_interpolate(pos_tr, t) - src_sk.get_bone_rest(src_hips).origin
			anim.position_track_insert_key(htr, t, dst_sk.get_bone_rest(dst_hips).origin + sp * scale)
	return anim

## Наложить свою позу на запись: кости из ключей (и кисть по клинку) заменяются,
## остальное — как в записи. Ключи "t" — секунды записи.
static func override(anim: Animation, sk: Skeleton3D, keys: Array, base: Dictionary, track_prefix: String, blade := Vector3.ZERO) -> Animation:
	var out := anim.duplicate(true) as Animation
	var loop := out.loop_mode != Animation.LOOP_NONE
	var rot_tr := {}
	for t in out.get_track_count():
		if out.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			var b := sk.find_bone(String(out.track_get_path(t)).get_slice(":", 1))
			if b >= 0:
				rot_tr[b] = t
	var sample := func(b: int, ki: int) -> Basis:
		if rot_tr.has(b):
			return Basis(out.rotation_track_interpolate(rot_tr[b], keys[ki]["t"]))
		return sk.get_bone_rest(b).basis.orthonormalized()
	var solved := _solve(sk, keys, base, blade, sample)
	var idx: Dictionary = solved[0]
	var locals: Dictionary = solved[1]
	for k in idx:
		var b: int = idx[k]
		if rot_tr.has(b):
			out.remove_track(rot_tr[b])
			# Индексы треков сдвинулись — пересчитываем
			rot_tr.clear()
			for t in out.get_track_count():
				if out.track_get_type(t) == Animation.TYPE_ROTATION_3D:
					var bb := sk.find_bone(String(out.track_get_path(t)).get_slice(":", 1))
					if bb >= 0:
						rot_tr[bb] = t
		var tr := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, NodePath(track_prefix + ":" + sk.get_bone_name(b)))
		out.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
		out.track_set_interpolation_loop_wrap(tr, loop)
		for ki in keys.size():
			out.rotation_track_insert_key(tr, keys[ki]["t"], (locals[b][ki] as Basis).get_rotation_quaternion())
	return out

static func build(sk: Skeleton3D, keys: Array, base: Dictionary, length: float, loop: bool, ref: Animation, ref_t: float, track_prefix: String, blade := Vector3.ZERO) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var solved := _solve(sk, keys, base, blade, func(b: int, _ki: int) -> Basis: return sk.get_bone_rest(b).basis.orthonormalized())
	var idx: Dictionary = solved[0]
	var locals: Dictionary = solved[1]
	for k in idx:
		var b: int = idx[k]
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath(track_prefix + ":" + sk.get_bone_name(b)))
		anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
		anim.track_set_interpolation_loop_wrap(tr, loop)
		for ki in keys.size():
			anim.rotation_track_insert_key(tr, keys[ki]["t"], (locals[b][ki] as Basis).get_rotation_quaternion())
	# Таз: сдвиг вверх-вниз и в стороны
	var hips := bone(sk, "Hips")
	if hips >= 0:
		var tr := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(tr, NodePath(track_prefix + ":" + sk.get_bone_name(hips)))
		anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
		anim.track_set_interpolation_loop_wrap(tr, loop)
		var rest := sk.get_bone_rest(hips).origin
		for key in keys:
			anim.position_track_insert_key(tr, key["t"], rest + key.get("hips", Vector3.ZERO))
	# Остальные кости (пальцы, кончики) — как в образце, без движения
	if ref:
		var have := {}
		for b in idx.values():
			have[b] = true
		for t in ref.get_track_count():
			if ref.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var path := String(ref.track_get_path(t))
			var bn := path.get_slice(":", 1)
			var b := sk.find_bone(bn)
			if b < 0 or have.has(b) or b == hips:
				continue
			var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(tr, NodePath(track_prefix + ":" + bn))
			anim.rotation_track_insert_key(tr, 0.0, ref.rotation_track_interpolate(t, ref_t))
	return anim

static func _rest_g(sk: Skeleton3D, b: int) -> Basis:
	return sk.get_bone_global_rest(b).basis.orthonormalized()

static func _rest_p(sk: Skeleton3D, b: int) -> Basis:
	var p := sk.get_bone_parent(b)
	return sk.get_bone_global_rest(p).basis.orthonormalized() if p >= 0 else Basis()

## Пределы суставов как у человека — по готовым анимациям живых движений (замер: углы кости
## относительно покоя в её собственных осях, порядок X·Z·Y; Y — вдоль кости, это кручение).
## Локоть и колено — только сгиб вокруг X от 0 до ~145°, почти без кручения и бокового хода.
## [x от, x до, z от, z до, кручение от, кручение до], градусы
const LIMITS := {
	"Spine": [-15, 40, -20, 20, -25, 25], "Spine1": [-15, 35, -15, 15, -25, 25], "Spine2": [-10, 20, -10, 10, -15, 15],
	"Neck": [-30, 30, -25, 25, -40, 40], "Head": [-45, 30, -30, 30, -60, 60],
	"LeftShoulder": [-15, 30, -25, 45, -15, 15], "RightShoulder": [-15, 30, -25, 45, -15, 15],
	"LeftArm": [-100, 115, -85, 75, -95, 95], "RightArm": [-100, 115, -85, 75, -95, 95],
	"LeftForeArm": [0, 145, -12, 12, -20, 20], "RightForeArm": [0, 145, -12, 12, -20, 20],
	# Запястье: сгиб/разгиб, отведение к мизинцу/большому пальцу; кручение — поворот предплечья
	"LeftHand": [-60, 50, -35, 35, -70, 70], "RightHand": [-60, 50, -35, 35, -70, 70],
	"LeftUpLeg": [-125, 45, -45, 45, -45, 45], "RightUpLeg": [-125, 45, -45, 45, -45, 45],
	"LeftLeg": [0, 150, -8, 8, -10, 10], "RightLeg": [0, 150, -8, 8, -10, 10],
	"LeftFoot": [-45, 50, -25, 25, -30, 30], "RightFoot": [-45, 50, -25, 25, -30, 30],
}

## Поворот кисти в пределах запястья, при котором клинок ближе всего к нужному направлению:
## перебор углов сгиба, отведения и кручения кисти (грубо, потом точнее)
static var aim_log := false
static func _aim_hand(sk: Skeleton3D, hand: int, dp: Basis, blade: Vector3, want: Vector3) -> Array:
	var lim: Array = LIMITS["RightHand"]
	var r0 := sk.get_bone_rest(hand).basis.orthonormalized()
	var parent_g := dp * _rest_p(sk, hand)   # глобальный поворот предплечья (в осях персонажа)
	var best := Vector3.ZERO
	var best_d := -2.0
	var step := 15.0
	var lo := Vector3(lim[0], lim[4], lim[2])
	var hi := Vector3(lim[1], lim[5], lim[3])
	for pass_i in 3:
		var center := best
		var span := step * 2.0 if pass_i > 0 else 1000.0
		var x := maxf(lo.x, center.x - span)
		while x <= minf(hi.x, center.x + span) + 0.01:
			var z := maxf(lo.z, center.z - span)
			while z <= minf(hi.z, center.z + span) + 0.01:
				var y := maxf(lo.y, center.y - span)
				while y <= minf(hi.y, center.y + span) + 0.01:
					var e := Vector3(x, y, z)
					var l := r0 * Basis.from_euler(e * (PI / 180.0), EULER_ORDER_XZY)
					var d := (parent_g * l * blade).normalized().dot(want)
					if d > best_d:
						best_d = d
						best = e
					y += step
				z += step
			x += step
		step /= 3.0
	return [r0 * Basis.from_euler(best * (PI / 180.0), EULER_ORDER_XZY), best_d]

## Ограничить локальный поворот кости пределами её сустава
static func limit(sk: Skeleton3D, b: int, local: Basis) -> Basis:
	var name := sk.get_bone_name(b)
	var lim: Array = []
	for k in LIMITS:
		if name.ends_with(k) and (name.length() == k.length() or not name[name.length() - k.length() - 1].to_lower() in "abcdefghijklmnopqrstuvwxyz"):
			lim = LIMITS[k]
			break
	if lim.is_empty():
		return local
	var r0 := sk.get_bone_rest(b).basis.orthonormalized()
	var e := (r0.inverse() * local.orthonormalized()).get_euler(EULER_ORDER_XZY) * (180.0 / PI)
	var c := Vector3(clampf(e.x, lim[0], lim[1]), clampf(e.y, lim[4], lim[5]), clampf(e.z, lim[2], lim[3]))
	return r0 * Basis.from_euler(c * (PI / 180.0), EULER_ORDER_XZY)

## Слить две позы: b поверх a
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k in b:
		out[k] = b[k]
	return out

## Зеркальная поза: левое ↔ правое (повороты отражаются относительно плоскости симметрии)
static func mirror(pose: Dictionary) -> Dictionary:
	var out := {}
	for k in pose:
		var v: Vector3 = pose[k]
		var nk: String = k
		if k.begins_with("Left"):
			nk = "Right" + k.substr(4)
		elif k.begins_with("Right"):
			nk = "Left" + k.substr(5)
		out[nk] = Vector3(v.x, -v.y, -v.z)
	return out
