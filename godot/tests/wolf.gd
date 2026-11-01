## Шипастый волк-убийца: шипы из хвоста издалека, удар лапой вблизи, опыт 68–74; снимки модели.
## Запуск: godot --path godot res://tests/wolf.tscn -- <папка>
extends Node

var main: Node
var out := ""
var ok := true

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
	var wolves: Array = main.enemies.list.filter(func(e): return e.type == "wolf")
	_check("8 wolves in the valley", wolves.size() == 8 and not wolves[0].in_dungeon, str(wolves.size()))
	var w: Node3D = wolves[0]
	var h: Node3D = main.hero
	Game.level = 12
	Game.refresh()
	Game.hp = Game.max_hp
	var p := Vector3(-60, 0, -120)
	h.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
	h.facing = PI
	w.home = Vector3(p.x, WorldGen.ground_at(p.x, p.z - 10), p.z - 10)
	w.reset_home()
	w.facing = 0.0
	w.set_active(true)
	var cam := Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	main.rig.target = null
	cam.current = true
	_frame_cam(cam, w, 4.2)
	for i in 10:
		await get_tree().process_frame
	_save("w_idle.png")
	# 1. Издалека — поднимает хвост и стреляет
	w.T["aggro"] = 30.0
	var hp0: float = Game.hp
	var aimed := false
	for i in 400:
		await get_tree().physics_frame
		_frame_cam(cam, w, 4.2)
		if w.st == "aim" and w._t > 0.4 and not aimed:
			aimed = true
			await get_tree().process_frame
			_save("w_aim.png")
		if Game.hp < hp0:
			break
	_check("wolf aims tail", aimed, "")
	_check("spikes hit hero", Game.hp < hp0, "hp %d → %d" % [hp0, Game.hp])
	# 2. Вблизи — удар лапой
	Game.hp = Game.max_hp
	w._spike_cd = 99.0
	h.global_position = w.global_position + Vector3(0, 0.2, 1.6)
	var hp1: float = Game.hp
	var swiped := false
	for i in 300:
		await get_tree().physics_frame
		_frame_cam(cam, w, 3.6)
		if w.st == "windup" and not swiped:
			swiped = true
			await get_tree().process_frame
			_save("w_swipe.png")
		if Game.hp < hp1:
			break
	_check("paw hits hero", Game.hp < hp1, "hp %d → %d" % [hp1, Game.hp])
	# 3. Опыт за волка
	var xp0 := Game.xp
	var lv0 := Game.level
	w.hit(9999, Vector3.FORWARD)
	await get_tree().process_frame
	var got := Game.xp - xp0 if Game.level == lv0 else -1
	_check("wolf xp 68–74", got >= 68 and got <= 74, str(got))
	var xs := []
	for i in 40:
		xs.append(Game.enemy_xp("goblin"))
	_check("goblin xp 27–30", xs.min() >= 27 and xs.max() <= 30, "%d..%d" % [xs.min(), xs.max()])
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _frame_cam(cam: Camera3D, w: Node3D, d: float) -> void:
	var c: Vector3 = w.global_position
	var side := Vector3(cos(w.facing), 0, -sin(w.facing))
	cam.global_position = c + side * d + Vector3(0, 1.3, 0) + Vector3(sin(w.facing), 0, cos(w.facing)) * 1.0
	cam.look_at(c + Vector3(0, 0.9, 0))

func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + name)

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
