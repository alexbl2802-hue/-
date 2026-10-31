## Серии кадров движений: бег героя (спереди и сзади), прыжки кролика и шаг гоблина (сбоку).
## Запуск: godot --path godot res://tests/anim.tscn -- <папка>
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
	main.hud.visible = false
	for e in main.enemies.list:
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
	var h: Node3D = main.hero
	var p := Vector3(-60, 0, -120)
	# Герой бежит: камера едет вместе с ним
	_place(h, p)
	h.facing = 0.0
	h.touch.move = Vector2(0, 1)
	main.rig.yaw = PI; main.rig.pitch = 0.1; main.rig.dist = 3.6
	await _frames(40)
	for k in 4:
		await _frames(3)
		_save("hero_run_back_%d.png" % k)
	h.touch.run = true
	await _frames(30)
	for k in 4:
		await _frames(3)
		_save("hero_fast_back_%d.png" % k)
	main.rig.yaw = 0.0
	await _frames(20)
	for k in 4:
		await _frames(3)
		_save("hero_fast_front_%d.png" % k)
	main.rig.yaw = PI * 0.5
	await _frames(20)
	for k in 4:
		await _frames(3)
		_save("hero_fast_side_%d.png" % k)
	h.touch.run = false
	h.touch.move = Vector2.ZERO
	await _frames(10)
	# Монстры идут вдоль оси X мимо своей камеры: бродят и гонятся (за героем далеко впереди)
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	main.rig.target = null
	for kind in ["rabbit", "goblin"]:
		var e: Node3D = main.enemies.list.filter(func(x): return x.type == kind)[0]
		for mode in ["chase", "idle"]:
			var start := p + Vector3(-6, 0, 0)
			_place(h, start + (Vector3(60, 0, 0) if mode == "chase" else Vector3(0, 0, 40)))
			e.T["aggro"] = 200.0 if mode == "chase" else 0.0
			e.home = Vector3(start.x, WorldGen.ground_at(start.x, start.z), start.z)
			e.reset_home()
			e.set_active(true)
			e.st = mode
			e._wander = start + Vector3(40, 0, 0)
			e._wander_t = 100.0
			for k in 80:
				if mode == "chase":
					# «Герой» всё время в 15 м впереди — монстр бежит за ним по прямой
					var hp := e.global_position + Vector3(15, 0, 0)
					h.global_position = Vector3(hp.x, WorldGen.ground_at(hp.x, hp.z) + 0.1, hp.z)
					h.velocity = Vector3.ZERO
				await get_tree().process_frame
				if k < 30:
					continue
				if k % 5 == 0 and k >= 30 and k < 80:
					var c := Vector3(e.global_position.x, WorldGen.ground_at(e.global_position.x, e.global_position.z), e.global_position.z)
					cam.global_position = c + Vector3(0, 0.8, 3.4)
					cam.look_at(c + Vector3(0, 0.7, 0))
					await get_tree().process_frame
					_save("%s_%s_%d.png" % [kind, mode, (k - 30) / 5])
			print(kind, " ", mode, " st=", e.st, " speed=", snappedf(e._speed_now, 0.01), " anim=", e._ap.current_animation if e._ap else "", " scale=", snappedf(e._ap.speed_scale, 0.01) if e._ap else 0.0)
			e.set_active(false)
	get_tree().quit()

func _place(h: Node3D, p: Vector3) -> void:
	h.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
	h.velocity = Vector3.ZERO
	main.rig.snap()

func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + name)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
