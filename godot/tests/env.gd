## Камни, горы и вода крупным планом.
## Запуск: godot --path godot res://tests/env.tscn -- <папка>
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
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 1500.0
	add_child(cam)
	main.rig.target = null
	cam.current = true
	var rocks: Array = WorldGen.props["rocks"]
	# Большой и маленький камень рядом
	var big: Array = rocks.filter(func(r): return r[3] > 1.8)[3]
	var small: Array = rocks.filter(func(r): return r[3] < 0.7)[5]
	for pair in [["rock_big", big], ["rock_small", small]]:
		var r: Array = pair[1]
		var c := Vector3(r[0], r[2], r[1])
		var d: float = 4.0 + r[3] * 3.0
		main.hero.global_position = c + Vector3(d, 0.5, d)
		cam.global_position = c + Vector3(d * 0.8, 1.5 + r[3], d * 0.8)
		cam.look_at(c + Vector3(0, r[3] * 0.5, 0))
		await _shot(out + pair[0] + ".png")
	# Камни в долине
	var c2 := Vector3(-60, WorldGen.ground_at(-60, -120), -120)
	cam.global_position = c2 + Vector3(0, 12, 0)
	cam.look_at(c2 + Vector3(30, 0, -30))
	await _shot(out + "rocks_field.png")
	# Горы: с равнины на массив и кольцо гор
	for v in [[Vector3(40, 0, -150), Vector3(102, 60, -315), "mountains_1"], [Vector3(-250, 0, 150), Vector3(-392, 60, 182), "mountains_2"], [Vector3(0, 0, 60), Vector3(0, 40, 400), "mountains_3"]]:
		var p: Vector3 = v[0]
		p.y = maxf(WorldGen.ground_at(p.x, p.z), 0.0) + 6.0
		main.hero.global_position = p
		cam.global_position = p
		cam.look_at(v[1])
		await _shot(out + v[2] + ".png")
	# Склон горы вблизи
	var sp := Vector3(60, 0, -250)
	sp.y = WorldGen.ground_at(sp.x, sp.z) + 4.0
	main.hero.global_position = sp
	cam.global_position = sp
	cam.look_at(Vector3(102, 70, -315))
	await _shot(out + "mountain_slope.png")
	# Вода: ищем озеро
	var lake := Vector3.ZERO
	for i in 4000:
		var x := randf_range(-250, 250)
		var z := randf_range(-250, 250)
		if WorldGen.ground_at(x, z) < -1.0:
			lake = Vector3(x, 0, z)
			break
	main.hero.global_position = lake + Vector3(14, 3, 14)
	cam.global_position = lake + Vector3(14, 6, 14)
	cam.look_at(lake)
	await _shot(out + "water.png")
	get_tree().quit()

func _shot(path: String) -> void:
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
