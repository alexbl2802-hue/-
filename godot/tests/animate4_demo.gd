## ANIMATE 4.0: демонстрационные движения на герое — генерация по описанию, проверка, предпросмотр.
## Запуск: godot --path godot res://tests/animate4_demo.tscn -- <папка> [имя,имя]   (кадры предпросмотра — при отрисовке)
##         godot --headless --path godot res://tests/animate4_demo.tscn -- <папка>    (только проверки)
extends Node3D

const DEMOS := [
	["thrust_dash", "Молниеносный колющий выпад с рывком"],
	["horizontal", "Горизонтальный удар мечом"],
	["whirl", "Вихрь — круговой удар мечом"],
	["block_sword", "Блок мечом"],
	["block_shield", "Блок щитом"],
	["dash_forward", "Рывок с места вперёд"], ["dash_back", "Рывок с места назад"],
	["dash_left", "Рывок с места влево"], ["dash_right", "Рывок с места вправо"],
	["dash_run_forward", "Рывок с бега вперёд"], ["dash_run_back", "Рывок с бега назад"],
	["dash_run_left", "Рывок с бега влево"], ["dash_run_right", "Рывок с бега вправо"],
	["stance", "Стойка с мечом"],
]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = (args[0] if args.size() > 0 else "user://animate4_preview") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	var only: Array = (args[1] as String).split(",") if args.size() > 1 else []
	var draw := DisplayServer.get_name() != "headless"
	if draw:
		_scene()
	for k in Game.equip:
		Game.equip[k] = null
	Game.equip["weapon"] = Items.make("sword_iron")
	var h: CharacterBody3D = preload("res://scripts/hero.gd").new()
	add_child(h)
	await get_tree().process_frame
	await get_tree().process_frame
	h.set_physics_process(false)
	h.global_position = Vector3.ZERO
	var ap: AnimationPlayer = h._anim
	if h._ha:
		h._ha.tree.active = false
	ap.active = true
	var sk: Skeleton3D = h._sk
	var prefix := String(ap.get_node(ap.root_node).get_path_to(sk))
	var blade: Vector3 = h._sword.transform.basis.y.normalized()
	var ref: Animation = ap.get_animation("Combat_Stance") if ap.has_animation("Combat_Stance") else null
	# Щит для предпросмотра — пластина на левом предплечье
	var shield := BoneAttachment3D.new()
	sk.add_child(shield)
	shield.bone_idx = PoseLib.bone(sk, "LeftForeArm")
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.5, 0.04)
	plate.mesh = bm
	plate.position = Vector3(0, 0.14, 0.08)
	shield.add_child(plate)
	print("NODES hero %s model %s char %s skel %s" % [h.global_position, h._model.global_position, h._char.global_position, sk.global_transform.origin])
	var cs := ap.get_animation("Combat_Stance")
	var hp := cs.find_track(NodePath(prefix + ":" + sk.get_bone_name(PoseLib.bone(sk, "Hips"))), Animation.TYPE_POSITION_3D)
	print("CLIP_HIPS ", cs.position_track_interpolate(hp, 0.0) if hp >= 0 else "none", " REST ", sk.get_bone_rest(PoseLib.bone(sk, "Hips")).origin)
	var tmc := AnimateIK.track_map(sk, cs)
	var gc := AnimateIK.globals(sk, cs, tmc, 0.0)
	print("CLIP_TOE_Y %.3f %.3f" % [(gc[PoseLib.bone(sk, "LeftToeBase")] as Transform3D).origin.y, (gc[PoseLib.bone(sk, "LeftFoot")] as Transform3D).origin.y])
	# Пол — под стопами: точка героя выше подошв (модель смещена вниз), земля — по клипу-образцу
	if _floor:
		_floor.global_position.y = (sk.global_transform * Vector3(0, AnimatePipeline.ground_height(sk, ref, 0.0), 0)).y - 0.005
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.current = true
	var all_ok := true
	print("SKELETON ", AnimateValidator4.check_skeleton(sk))
	for d in DEMOS:
		if not only.is_empty() and not only.has(d[0]):
			continue
		var r := AnimatePipeline.generate(d[1], sk, prefix, {"blade": blade, "ref": ref, "ref_t": 0.0})
		if not r.has("animation"):
			print("FAIL %s «%s»: %s" % [d[0], d[1], r["error"]])
			all_ok = false
			continue
		var anim: Animation = r["animation"]
		var name := AnimatePipeline.export_to(ap, d[0], anim)
		AnimatePipeline.save(anim, "user://animate4/%s.res" % d[0])
		var line := ""
		for c in r["report"]["checks"]:
			line += "\n    %s %-13s %s" % ["ok " if c["ok"] else "BAD", c["name"], c["detail"]]
		print("  IK до привязки, сдвиг стоп: ", r["ik"], "  опора: %.3f м" % r["ground_shift"])
		print("%s %s «%s» → %s (%.2f с, шаблон %s, слова %s, контактов %d)%s" % ["PASS" if r["ok"] else "FAIL", d[0], d[1], name, anim.length,
			r["template"]["name"], r["spec"]["matched"], r["contacts"].size(), line])
		all_ok = all_ok and r["ok"]
		plate.visible = d[0] == "block_shield"
		if draw:
			for view in ["side", "front"]:
				for f in 6:
					var t := anim.length * f / 5.0
					ap.play(name, 0.0)
					ap.speed_scale = 0.0
					ap.seek(t, true, true)
					var base_y: float = sk.global_transform.origin.y
					cam.global_position = Vector3(3.2, base_y + 1.15, 0.3) if view == "side" else Vector3(-1.0, base_y + 1.25, 3.2)
					cam.look_at(Vector3(0, base_y + 0.85, 0.2))
					if f == 0 and view == "side":
						var tmh := AnimateIK.track_map(sk, anim)
						var ys := []
						for q in 6:
							var gg := AnimateIK.globals(sk, anim, tmh, anim.length * q / 5.0)
							ys.append("%.2f" % (gg[PoseLib.bone(sk, "Hips")] as Transform3D).origin.y)
						print("HIPS_Y %s %s" % [d[0], ys])
						var g0 := AnimateIK.globals(sk, anim, tmh, 0.0)
						print("ANIM_TOE_Y %.3f %.3f" % [(g0[PoseLib.bone(sk, "LeftToeBase")] as Transform3D).origin.y, (g0[PoseLib.bone(sk, "LeftFoot")] as Transform3D).origin.y])
					for i in 2:
						await get_tree().process_frame
					get_viewport().get_texture().get_image().save_png(out + "%s_%s_%d.png" % [d[0], view, f])
	print("RESULT: %s" % ("ALL OK" if all_ok else "FAILED"))
	get_tree().quit(0 if all_ok else 1)

var _floor: Node3D

func _scene() -> void:
	_floor = Node3D.new()
	add_child(_floor)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.65, 0.75)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3(3, 6, 4), Vector3.ZERO)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.35, 0.45, 0.3)
	floor.material_override = fm
	_floor.add_child(floor)
	for i in range(-10, 11):
		for axis in 2:
			var l := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(20, 0.01, 0.02) if axis == 0 else Vector3(0.02, 0.01, 20)
			l.mesh = b
			l.position = Vector3(0, 0.005, i * 0.5) if axis == 0 else Vector3(i * 0.5, 0.005, 0)
			_floor.add_child(l)
