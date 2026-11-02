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
static func build(sk: Skeleton3D, keys: Array, base: Dictionary, length: float, loop: bool, ref: Animation, ref_t: float, track_prefix: String, blade := Vector3.ZERO) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	# Какие кости участвуют в позах
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
	var names := {}
	for k in idx:
		names[idx[k]] = k
	# Кисть «по клинку»: поворот кисти, при котором клинок смотрит куда указано
	if aims and hand >= 0 and blade != Vector3.ZERO:
		for key in keys:
			if not key.has("sword"):
				continue
			var pose: Dictionary = base.duplicate()
			for k in key["p"]:
				pose[k] = key["p"][k]
			var dp := Basis()   # накопленный поворот родителей кисти
			var chain := []
			var b := sk.get_bone_parent(hand)
			while b >= 0:
				chain.push_front(b)
				b = sk.get_bone_parent(b)
			for c in chain:
				if names.has(c):
					dp = dp * rot(pose.get(names[c], Vector3.ZERO))
			var g0 := (dp * sk.get_bone_global_rest(hand).basis.orthonormalized() * blade).normalized()
			var want: Vector3 = (key["sword"] as Vector3).normalized()
			var q := Basis(Quaternion(g0, want))
			var rh := dp.inverse() * q * dp
			var e := rh.get_euler(EULER_ORDER_YXZ)
			key["p"] = (key["p"] as Dictionary).duplicate()   # одна поза может стоять в разных ключах
			key["p"]["RightHand"] = Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))
	# Повороты: поза ключа = база + ключ
	for k in idx:
		var b: int = idx[k]
		var p := sk.get_bone_parent(b)
		var rest_g := sk.get_bone_global_rest(b).basis.orthonormalized()
		var rest_p := sk.get_bone_global_rest(p).basis.orthonormalized() if p >= 0 else Basis()
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath(track_prefix + ":" + sk.get_bone_name(b)))
		anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
		anim.track_set_interpolation_loop_wrap(tr, loop)
		for key in keys:
			var deg: Vector3 = key["p"].get(k, base.get(k, Vector3.ZERO))
			var local := rest_p.inverse() * rot(deg) * rest_g
			anim.rotation_track_insert_key(tr, key["t"], local.get_rotation_quaternion())
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
