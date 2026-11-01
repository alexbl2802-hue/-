## Снимки графики: склеп (затенение углов), трава вблизи, ночное небо
extends Node

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
	# Трава вблизи
	Game.time_of_day = 0.38
	var p := Vector3(-30, 0, 70)
	p.y = WorldGen.ground_at(p.x, p.z)
	main.hero.global_position = p + Vector3(0, 0.3, 0)
	cam.global_position = p + Vector3(0, 1.4, -4)
	cam.look_at(p + Vector3(0, 0.3, 6))
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "g_grass.png")
	# Ночное небо
	Game.time_of_day = 0.95
	main.day_night.apply()
	cam.look_at(cam.global_position + Vector3(0.3, 0.6, 1))
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "g_night.png")
	Game.time_of_day = 0.72
	main.day_night.apply()
	cam.look_at(cam.global_position + Vector3(-1, 0.25, 0))
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "g_dusk.png")
	# Склеп
	main.enter_dungeon(0)
	for i in 80:
		await get_tree().process_frame
	var d = main.dungeons[0]
	main.hero.global_position = d.start_pos + Vector3(0, 0.3, 0)
	cam.global_position = d.start_pos + Vector3(0, 1.7, 0)
	cam.look_at(d.start_pos + Vector3(4, 0.0, 6))
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "g_crypt.png")
	get_tree().quit()
