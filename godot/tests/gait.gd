## Замер шага: с какой скоростью опорная стопа уходит назад в анимации (м/с при speed_scale 1).
## Делим скорость монстра на это число — получаем speed_scale без скольжения ног.
extends Node
func _ready() -> void:
	var jobs := [["res://models/goblin.glb", ["Slow_Orc_Walk", "Running"], 0.92],
		["res://models/hero.glb", ["Running", "RunFast"], 1.05],
		["res://models/bunny.glb", [], 0.95]]
	for j in jobs:
		var n: Node3D = (load(j[0]) as PackedScene).instantiate()
		add_child(n)
		var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
		var names := []
		for i in sk.get_bone_count(): names.append(sk.get_bone_name(i))
		print("  skel xform to root: ", _rel(sk, n))
		for a in j[1]:
			var anim := ap.get_animation(a)
			ap.play(a)
			var feet := []
			for i in sk.get_bone_count():
				var nm := sk.get_bone_name(i)
				if nm.ends_with("LeftFoot") or nm.ends_with("RightFoot"): feet.append(i)
			var hips := 0
			var len := anim.length
			var steps := 120
			var prev := {}
			var sum := 0.0
			var cnt := 0
			var miny := INF
			var ys := []
			for s in steps + 1:
				ap.seek(len * s / steps, true)
				sk.force_update_all_bone_transforms()
				for f in feet:
					var p := _rel(sk, n) * sk.get_bone_global_pose(f).origin
					ys.append(p.y)
					miny = minf(miny, p.y)
			var ymin := miny
			for s in steps + 1:
				ap.seek(len * s / steps, true)
				sk.force_update_all_bone_transforms()
				var hp := _rel(sk, n) * sk.get_bone_global_pose(hips).origin
				for f in feet:
					var p := _rel(sk, n) * sk.get_bone_global_pose(f).origin
					if prev.has(f) and p.y < ymin + 0.04:
						var d: Vector3 = p - prev[f]
						sum += -d.z
						cnt += 1
					prev[f] = p
				if s % 30 == 0: print("   t=", snappedf(len * s / steps, 0.01), " hips=", hp)
			var dt := len / steps
			print("  ", a, " len=", snappedf(len, 0.01), " planted foot speed (model units/s)=", snappedf(sum / maxf(1, cnt) / dt, 0.01), " scaled=", snappedf(sum / maxf(1, cnt) / dt * j[2], 0.01))
	get_tree().quit()

func _rel(sk: Node3D, top: Node3D) -> Transform3D:
	var t := Transform3D()
	var c: Node = sk
	while c != top:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t
