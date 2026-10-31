## Снимки факелов на стенах склепа и пещеры кристаллов.
## Запуск: godot --path godot res://tests/torches.tscn -- <папка>
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
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	main.rig.target = null
	for di in main.dungeons.size():
		main._set_mode(di)
		var d: Node3D = main.dungeons[di]
		print(d.def["name"], ": torches ", d.torch_spots.size())
		cam.current = true
		var k := 0
		for ts in d.torch_spots:
			var top: Vector3 = ts[0]
			var n: Vector3 = ts[1]
			var side := n.cross(Vector3.UP)
			cam.global_position = top + n * 3.2 + side * 1.6 + Vector3(0, -0.6, 0)
			cam.look_at(top + Vector3(0, -0.4, 0))
			for i in 8:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out + "d%d_torch_%d.png" % [di, k])
			k += 1
		# Общий вид
		main.hero.global_position = d.start_pos + Vector3(0, 0.2, 0)
		cam.global_position = d.start_pos + Vector3(0, 2.0, 0)
		cam.look_at(d.start_pos + Vector3(sin(d.start_yaw), 1.6, cos(d.start_yaw)) * Vector3(1, 0, 1) + Vector3(0, d.start_pos.y + 1.6, 0) + Vector3(sin(d.start_yaw) * 6, 0, cos(d.start_yaw) * 6))
		for i in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "d%d_view.png" % di)
	get_tree().quit()
