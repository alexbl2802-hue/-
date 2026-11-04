## Все мобы в ряд (аниме-раскраска, клипы Meshy): снимок спереди. godot ... res://tests/mobs_look.tscn -- <папка>
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
	Game.time_of_day = 0.4
	main.day_night.apply()
	var kinds := ["skeleton", "skeleton_king", "frost_king", "goblin", "wolf", "spider", "kobold", "rabbit"]
	var base := Vector3(-60, 0, -120)
	var script := preload("res://scripts/enemy.gd")
	var list := []
	for i in kinds.size():
		var p := base + Vector3(i * 3.0 - 10.5, 0, 0)
		p.y = WorldGen.ground_at(p.x, p.z)
		var e: CharacterBody3D = script.new()
		e.setup(kinds[i], p, main.hero, 3)
		main.add_child(e)
		e.facing = 0.0
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
		list.append(e)
	main.hero.global_position = base + Vector3(0, 0.3, -30)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 45
	var c := base + Vector3(0, WorldGen.ground_at(base.x, base.z) + 1.2, 0)
	cam.global_position = c + Vector3(0, 1.5, 16)
	cam.look_at(c)
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "mobs.png")
	for e in list:
		e.st = "windup"
		e._t = 0.0
		e._wind_len = 0.6
		e._start_attack()
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "mobs_attack.png")
	get_tree().quit()
