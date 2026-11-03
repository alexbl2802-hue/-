## Просмотр модели с анимациями: кадры каждого клипа сбоку и спереди.
## godot ... res://tests/glb_view.tscn -- <папка> <res://модель.glb> <клип1,клип2> [кадров]
extends Node3D

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] + "/"
	var model: Node3D = (load(a[1]) as PackedScene).instantiate()
	add_child(model)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.65, 0.75)
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3(3, 6, 4), Vector3.ZERO)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.35, 0.45, 0.3)
	fl.material_override = fm
	add_child(fl)
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	print("anims: ", ap.get_animation_list())
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40
	var n := int(a[3]) if a.size() > 3 else 5
	for nm in (a[2] as String).split(","):
		ap.play(nm)
		var L := ap.get_animation(nm).length
		for i in n:
			ap.seek(L * i / maxf(1, n - 1), true)
			for v in [["side", Vector3(4.5, 1.2, 0.3)], ["front", Vector3(1.6, 1.4, 4.2)]]:
				cam.global_position = v[1]
				cam.look_at(Vector3(0, 0.7, -0.1))
				await get_tree().process_frame
				await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png(out + "%s_%s_%d.png" % [nm, v[0], i])
	get_tree().quit()
