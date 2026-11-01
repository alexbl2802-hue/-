## Кадры умений героя: Вихрь (удар с разворотом) и Рывок (длинный прыжок).
## Запуск: godot --path godot res://tests/skills_anim.tscn -- <папка>
extends Node

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud.visible = false
	for e in main.enemies.list:
		e.set_active(false)
		e.visible = false
	main.enemies.set_process(false)
	Game.level = 12
	Game.skills = {"dash": 1, "whirl": 1}
	var h: Node3D = main.hero
	print("anims: ", h._anim.get_animation_list())
	var p := Vector3(-60, 0, -120)
	var cam := Camera3D.new()
	add_child(cam)
	main.rig.target = null
	cam.current = true
	cam.fov = 50.0
	for skill in ["whirl", "dash"]:
		h.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
		h.facing = PI * 0.5
		var base := h.global_position
		var dx := 4.0 if skill == "dash" else 0.0
		cam.global_position = base + Vector3(dx, 1.3, 6.5 if skill == "dash" else 4.0)
		cam.look_at(base + Vector3(dx, 1.0, 0))
		for i in 20:
			await get_tree().physics_frame
		h.cd[skill] = 0.0
		h.use_skill(skill)
		var n := 8
		var total: float = h.WHIRL_TIME if skill == "whirl" else h.DASH_TIME
		for k in n:
			var target_t := total * (k + 0.5) / n
			while (h._spin_t if skill == "whirl" else h._dash_t) >= 0.0 and (h._spin_t if skill == "whirl" else h._dash_t) < target_t:
				await get_tree().physics_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out + "%s_%d.png" % [skill, k])
		for i in 40:
			await get_tree().physics_frame
		get_viewport().get_texture().get_image().save_png(out + "%s_end.png" % skill)
	get_tree().quit()
