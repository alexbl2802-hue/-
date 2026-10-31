## Крупные кадры прыжка кролика сбоку: фаза цикла в имени файла.
## Запуск: godot --path godot res://tests/hop.tscn -- <папка>
extends Node

var main: Node

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud.visible = false
	for e in main.enemies.list:
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
	var p := Vector3(-60, 0, -120)
	main.hero.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z + 40) + 0.2, p.z + 40)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	main.rig.target = null
	var e: Node3D = main.enemies.list.filter(func(x): return x.type == "rabbit")[0]
	e.home = Vector3(p.x, WorldGen.ground_at(p.x, p.z), p.z)
	e.reset_home()
	e.set_active(true)
	e._wander = p + Vector3(40, 0, 0)
	e._wander_t = 100.0
	for i in 20:
		await get_tree().process_frame
	# Ровно по фазам цикла: останавливаем время и выставляем фазу вручную
	main.enemies.set_process(false)
	e.set_physics_process(false)
	e._ap.play(e.B_PUNCH)
	e._ap.seek(e.B_GUARD[0] + 0.3, true)
	e._ap.speed_scale = 0.0
	for k in 10:
		e._hop_p = k / 10.0
		e._hop_w = 1.0
		e._hop_legs(0.0, true)
		var c := Vector3(e.global_position.x, WorldGen.ground_at(e.global_position.x, e.global_position.z), e.global_position.z)
		var fwd: Vector3 = e._model.global_basis.z
		fwd.y = 0.0
		cam.global_position = c + fwd.normalized().cross(Vector3.UP) * 3.6 + Vector3(0, 0.6, 0)
		cam.look_at(c + Vector3(0, 0.6, 0))
		for i in 3:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "hop_%d.png" % k)
	get_tree().quit()
