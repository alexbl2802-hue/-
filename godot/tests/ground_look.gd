## Снимки земли и воды: трава вблизи, луг, берег озера с пеной, склон горы, Плато ветров
extends Node

func _shot(cam: Camera3D, from: Vector3, to: Vector3, file: String) -> void:
	cam.global_position = from
	cam.look_at(to)
	for i in 25:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(file)

func _g(x: float, z: float) -> Vector3:
	return Vector3(x, WorldGen.ground_at(x, z), z)

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud.visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.far = 900.0
	Game.time_of_day = 0.4
	main.day_night.apply()
	var p := _g(-30, 70)
	main.hero.global_position = p + Vector3(0, 0.3, 0)
	await _shot(cam, p + Vector3(0, 1.6, -4), p + Vector3(0, 0, 5), out + "1_grass.png")
	await _shot(cam, p + Vector3(0, 6, 0), p + Vector3(40, 0, 60), out + "2_meadow.png")
	var w := _g(-195, -52)
	main.hero.global_position = w + Vector3(0, 0.3, 0)
	await _shot(cam, _g(-180, -40) + Vector3(0, 4, 0), w, out + "3_lake.png")
	var w2 := _g(160, 160)
	main.hero.global_position = w2 + Vector3(0, 0.3, 0)
	await _shot(cam, _g(150, 150) + Vector3(0, 3, 0), w2 + Vector3(10, 0, 10), out + "4_lake2.png")
	var t: Vector3 = main.world.tower["pos"]
	await _shot(cam, t + Vector3(30, 20, 30), t + Vector3(-60, 30, -60), out + "5_mountain.png")
	Game.time_of_day = 0.74
	main.day_night.apply()
	main.hero.global_position = w + Vector3(0, 0.3, 0)
	await _shot(cam, _g(-180, -40) + Vector3(0, 4, 0), w, out + "6_lake_dusk.png")
	Game.time_of_day = 0.4
	main.day_night.apply()
	main.enter_world2()
	for i in 30:
		await get_tree().process_frame
	var hp: Vector3 = main.hero.global_position
	await _shot(cam, hp + Vector3(0, 3, -6), hp + Vector3(0, 0, 10), out + "7_plateau.png")
	get_tree().quit()
