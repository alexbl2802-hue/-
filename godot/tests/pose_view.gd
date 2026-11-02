## Просмотр своих анимаций: герой в нескольких моментах анимации, сбоку и спереди.
## Запуск: godot --path godot res://tests/pose_view.tscn -- <папка> <анимация> [кадров]
extends Node3D

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] + "/"
	var names: Array = (args[1] as String).split(",")
	var frames := int(args[2]) if args.size() > 2 else 6
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
	add_child(floor)
	# Сетка на полу — видно скольжение и шаг
	for i in range(-10, 11):
		for axis in 2:
			var l := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(20, 0.01, 0.02) if axis == 0 else Vector3(0.02, 0.01, 20)
			l.mesh = b
			l.position = Vector3(0, 0.005, i * 0.5) if axis == 0 else Vector3(i * 0.5, 0.005, 0)
			add_child(l)
	# Без снаряжения (щит закрывал бы руку) и с замером отклонения клинка
	for k in Game.equip:
		if k != "weapon":
			Game.equip[k] = null
	PoseLib.aim_log = true
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
	# Метки на стопах: печатаем высоту пяток и носков над полом
	var sk: Skeleton3D = h._sk
	var marks := {}
	for nm2 in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
		var ba := BoneAttachment3D.new()
		sk.add_child(ba)
		ba.bone_idx = PoseLib.bone(sk, nm2)
		marks[nm2] = ba
	if OS.get_environment("SPREAD") != "":
		for arm in h._arm_axes:
			h._arms_mod.set_angle(arm[0], arm[1], float(OS.get_environment("SPREAD")))
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.current = true
	for nm in names:
		var a := ap.get_animation(nm)
		for view in ["side", "front"]:
			for f in frames:
				var t := a.length * f / maxf(1.0, float(frames - (0 if a.loop_mode != Animation.LOOP_NONE else 1)))
				ap.play(nm, 0.0)
				ap.speed_scale = 0.0
				ap.seek(t, true, true)
				if view == "side":
					cam.global_position = Vector3(4.2, 1.1, -0.3)
				else:
					cam.global_position = Vector3(-1.2, 1.2, -4.0)
				cam.look_at(Vector3(0, 0.9, 0))
				if OS.get_environment("ZOOM") != "":
					# Крупно: кисть с мечом
					var hp: Vector3 = sk.global_transform * sk.get_bone_global_pose(PoseLib.bone(sk, "RightHand")).origin
					cam.global_position = hp + (Vector3(0.9, 0.2, -0.1) if view == "side" else Vector3(-0.3, 0.2, -0.9))
					cam.look_at(hp)
				for i in 3:
					await get_tree().process_frame
				if view == "side":
					var txt := "%s t=%.2f " % [nm, t]
					for m in marks:
						txt += "%s %.2f/%.2f  " % [m.replace("Base", ""), marks[m].global_position.y, marks[m].global_position.z]
					print(txt)
				var img := get_viewport().get_texture().get_image()
				img.save_png(out + "%s_%s_%d.png" % [nm.replace("/", "_"), view, f])
	get_tree().quit()
