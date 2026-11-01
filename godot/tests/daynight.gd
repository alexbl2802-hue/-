## Смена дня и ночи: город и долина в полдень, на закате и ночью; ночью монстры бьют сильнее.
## Запуск: godot --path godot res://tests/daynight.tscn -- <папка>
extends Node

var ok := true

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null or main.day_night == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	main.day_night.set_process(false)
	for e in main.enemies.list:
		e.set_active(false)
	var h: Node3D = main.hero
	for v in [[0.5, "noon"], [0.745, "dusk"], [0.95, "night"]]:
		Game.time_of_day = v[0]
		main.day_night.apply()
		for place in [[Vector3(2, 4, 14), -0.5, 0.35, 10.0, "town"], [Vector3(0, 0, 60), 0.0, 0.25, 12.0, "valley"]]:
			var p: Vector3 = place[0]
			h.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
			main.rig.yaw = place[1]
			main.rig.pitch = place[2]
			main.rig.dist = place[3]
			main.rig.snap()
			for i in 12:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out + "%s_%s.png" % [place[4], v[1]])
		if v[1] == "night":
			_check("night flag", Game.is_night, "")
			_check("monsters stronger at night", DayNight.monster_mult() > 1.2, str(DayNight.monster_mult()))
		if v[1] == "noon":
			_check("day flag", not Game.is_night, "")
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
