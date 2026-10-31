## Снимки для проверки внешнего вида: godot ... res://tests/look.tscn -- <папка>
extends Node

var main: Node
var out := ""

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] + "/"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	for e in main.enemies.list:
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
	# Лес: ищем самое густое место и ставим героя под деревьями
	var best := Vector2.ZERO
	var bn := 0
	var trees: Array = WorldGen.props["pines"] + WorldGen.props["oaks"]
	for k in range(0, trees.size(), 7):
		var c := Vector2(trees[k][0], trees[k][1])
		if c.length() > 260 or WorldGen.ground_at(c.x, c.y) > 25:
			continue
		var n := 0
		for t in trees:
			if Vector2(t[0], t[1]).distance_to(c) < 12:
				n += 1
		if n > bn:
			bn = n
			best = c
	await _shot("l_forest.png", Vector3(best.x + 1.5, 0, best.y + 1.5), 0.6, 0.12, 5.0)
	await _shot("l_forest_far.png", Vector3(best.x + 14, 0, best.y + 14), 0.8, 0.35, 12.0)
	await _shot("l_valley.png", Vector3(-60, 0, -120), 2.6, 0.45, 14.0)
	# Кролик крупным планом
	var rb: Node3D = main.enemies.list.filter(func(e): return e.type == "rabbit")[0]
	var p := Vector3(-60, 0, -120)
	rb.home = Vector3(p.x, WorldGen.ground_at(p.x, p.z - 3), p.z - 3)
	rb.reset_home()
	rb.set_physics_process(true)
	await _shot("l_rabbit.png", p, 0.0, 0.15, 3.0, 0.4)
	# Навыки цифрами
	Game.level = 10
	Game.skills = {"strength": 7, "whirl": 2}
	Game.refresh()
	main.hud.open_skills()
	await _frames(5)
	get_viewport().get_texture().get_image().save_png(out + "l_skills.png")
	get_tree().quit()

func _shot(name: String, p: Vector3, yaw: float, pitch: float, dist: float, model_yaw := -1.0) -> void:
	main.hero.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
	main.hero.velocity = Vector3.ZERO
	main.rig.yaw = yaw
	main.rig.pitch = pitch
	main.rig.dist = dist
	main.rig.snap()
	await _frames(40)
	get_viewport().get_texture().get_image().save_png(out + name)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
