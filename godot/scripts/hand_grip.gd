## Сжимает пальцы правой руки в кулак поверх любой анимации — чтобы герой держал рукоять,
## и считает, где внутри кулака проходит рукоять.
## Пальцы сгибаются вокруг линии костяшек (от мизинца к указательному). В позе покоя Mixamo
## ладонь смотрит вниз, поэтому направление сгиба выбирается так, чтобы кончики шли вниз.
class_name HandGrip
extends SkeletonModifier3D

var grip_point := Vector3.ZERO   # центр кулака в системе кости кисти
var grip_axis := Vector3.UP      # ось рукояти (к большому пальцу) в системе кости кисти
var fingers_dir := Vector3.UP    # от запястья к костяшкам, в системе кости кисти

var _bones: Array = []   # [индекс кости, ось в системе кости, угол]

func setup(sk: Skeleton3D, side: String, curl := 1.2) -> bool:
	var find := func(suffix: String) -> int:
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).ends_with(side + suffix):
				return i
		return -1
	var hand: int = find.call("Hand")
	var idx: int = find.call("HandIndex1")
	var pinky: int = find.call("HandPinky1")
	var m := [find.call("HandMiddle1"), find.call("HandMiddle2"), find.call("HandMiddle3"), find.call("HandMiddle4")]
	if hand < 0 or idx < 0 or pinky < 0 or m.has(-1):
		return false
	var gr := func(i: int) -> Transform3D: return sk.get_bone_global_rest(i)
	var knuckles: Vector3 = (gr.call(idx).origin - gr.call(pinky).origin).normalized()
	# Пробный сгиб среднего пальца в обе стороны: выбираем ту, где кончик уходит вниз (к ладони)
	var sign := 1.0
	var best := INF
	var chain: Array = []
	for sg in [1.0, -1.0]:
		var pts := _curl_chain(m.map(func(b): return gr.call(b).origin), knuckles * sg, curl)
		if pts[3].y < best:
			best = pts[3].y
			sign = sg
			chain = pts
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		for k in [1, 2, 3]:
			var b: int = find.call("Hand%s%d" % [f, k])
			if b >= 0:
				var axis: Vector3 = (gr.call(b).basis.inverse() * knuckles * sign).normalized()
				_bones.append([b, axis, curl * (0.8 if k == 1 else 1.0)])
	# Центр кулака — середина согнутого среднего пальца; переводим в систему кости кисти
	var center: Vector3 = (chain[0] + chain[1] + chain[2] + chain[3]) / 4.0
	var hinv: Transform3D = gr.call(hand).affine_inverse()
	grip_point = hinv * center
	grip_axis = (hinv.basis * knuckles).normalized()
	fingers_dir = (hinv.basis * (gr.call(m[0]).origin - gr.call(hand).origin)).normalized()
	return true

## Сгиб цепочки точек пальца: на каждом суставе поворот на угол вокруг оси
func _curl_chain(pts: Array, axis: Vector3, curl: float) -> Array:
	var out: Array = pts.duplicate()
	for j in range(0, 3):
		var a := curl * (0.8 if j == 0 else 1.0)
		for k in range(j + 1, 4):
			out[k] = out[j] + (out[k] - out[j]).rotated(axis.normalized(), a)
	return out

func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk:
		return
	for b in _bones:
		sk.set_bone_pose_rotation(b[0], sk.get_bone_pose_rotation(b[0]) * Quaternion(b[1], b[2]))
