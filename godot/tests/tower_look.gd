## Снимки башни и этажей свободной камерой (для проверки вида)
extends Node

var main: Node

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	Game.bosses = []
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	main.hud.visible = false
	Game.time_of_day = 0.42
	var cam := Camera3D.new()
	cam.fov = 65.0
	cam.far = 800.0
	add_child(cam)
	cam.current = true
	var td: Vector3 = main.world.tower["door"]
	main.hero.global_position = td + Vector3(2, 0.3, -6)
	cam.global_position = td + Vector3(22, 7, -16)
	cam.look_at(main.world.tower["pos"] + Vector3(0, 16, 0))
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "look_tower.png")
	cam.global_position = td + Vector3(0, 2.0, -9)
	cam.look_at(td + Vector3(0, 2.5, 0))
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "look_door.png")
	for f in [1, 3, 4]:
		var idx := DungeonDefs.floor_index(f)
		main.enter_floor(f)
		for i in 80:
			await get_tree().process_frame
		var d: Node3D = main.dungeons[idx]
		for e in main.enemies.list:
			if e.in_dungeon:
				e.T = e.T.duplicate()
				e.T["aggro"] = 0.0
		var g: Vector2i = d.gate_cells[0]
		var gc: Vector3 = d.cell_center(g.x, g.y)
		var into := Vector3.ZERO
		for dv in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			if d.room.has(d.cell_of(gc + dv * 4.0)):
				into = dv
		main.hero.global_position = gc - into * 7.0 + Vector3(0, 0.3, 0)
		cam.global_position = gc - into * 9.5 + Vector3(0.5, 3.2, 0.3)
		cam.look_at(gc + into * 6.0 + Vector3(0, 1.0, 0))
		for i in 15:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "look_f%d_gate.png" % f)
		d.set_gate(true)
		cam.global_position = d.boss_pos + (gc - d.boss_pos).normalized() * 3.0 + Vector3(0, 3.5, 0)
		cam.global_position = gc + into * 1.5 + Vector3(0, 3.6, 0)
		cam.look_at(d.boss_pos + Vector3(0, 1.5, 0))
		for i in 40:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "look_f%d_boss.png" % f)
		d.set_stairs(true)
		cam.global_position = d.stairs_front + (d.stairs_front - d.stairs_pos).normalized() * 3.0 + Vector3(0, 2.5, 0)
		cam.look_at(d.stairs_pos + Vector3(0, 1.0, 0))
		for i in 10:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "look_f%d_stairs.png" % f)
	get_tree().quit()
