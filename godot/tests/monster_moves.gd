## Новые движения гоблина и кобольда: удар сверху, боковой взмах, удар щитом, отскок назад.
## Запуск: godot --path godot res://tests/monster_moves.tscn -- <папка>
extends Node

var main: Node
var ok := true

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	main.hud.visible = false
	Game.time_of_day = 0.4
	var h: Node3D = main.hero
	var p := Vector3(-30, WorldGen.ground_at(-30, 70) + 0.2, 70)
	h.global_position = p + Vector3(0, 0, 30)
	var g: Node3D = null
	var k: Node3D = null
	for e in main.enemies.list:
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
		if e.type == "goblin" and not e.in_dungeon and g == null:
			g = e
		if e.type == "kobold" and k == null:
			k = e
	k.in_dungeon = false
	for e in [g, k]:
		e.home = p if e == g else p + Vector3(3, 0, 0)
		e.global_position = e.home
		e.facing = 0.0
		e.set_active(true)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.global_position = p + Vector3(5.5, 1.6, 2.5)
	cam.look_at(p + Vector3(1.5, 1.0, 0))
	main.rig.target = null
	for i in 30:
		await get_tree().physics_frame
	var x0: float = g.global_position.z
	for kinds in [["overhead", "bash"], ["side", "sweep"]]:
		for e in [g, k]:
			e._start_attack()
			e._atk = kinds[0] if e == g else kinds[1]
			e._wind_len = e.T["windup"] * (1.3 if e._atk == "overhead" else 1.0)
			e._hop_plan = kinds[0] == "side"
		var shots := 0
		var seen := ""
		for i in 70:
			await get_tree().physics_frame
			if g._ap.current_animation.begins_with("gob/") and seen == "":
				seen = g._ap.current_animation
			for e in [g, k]:
				e.facing = 0.0
			if i == 18 or i == 30 or i == 48:
				await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png(out + "mm_%s_%d.png" % [kinds[0], shots])
				shots += 1
		_check(kinds[0] + " anim played", seen == "gob/" + kinds[0], seen)
	_check("goblin hopped back", g.global_position.z < x0 - 0.5, "%.2f → %.2f" % [x0, g.global_position.z])
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
