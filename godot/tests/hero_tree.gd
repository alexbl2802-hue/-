## Дерево анимаций героя: стойка, бег, удар на бегу (ноги бегут), блок, вихрь, прыжок.
## Запуск: godot --path godot res://tests/hero_tree.tscn -- <папка>
extends Node

var main: Node
var ok := true
var cam: Camera3D

## Камера всё время сбоку от героя
func _process(_dt: float) -> void:
	if cam and main and main.hero:
		var hp: Vector3 = main.hero.global_position
		cam.global_position = hp + Vector3(4.2, 1.4, 0.6)
		cam.look_at(hp + Vector3(0, 1.0, 0))

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
	Game.level = 20
	Game.skills["whirl"] = 1
	Game.refresh()
	for e in main.enemies.list:
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
	var h: Node3D = main.hero
	_check("tree active", h._ha != null and h._ha.tree.active, "")
	var p := Vector3(-30, 0, 70)
	p.y = WorldGen.ground_at(p.x, p.z) + 0.3
	h.global_position = p
	h.facing = 0.0
	main.rig.target = null
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	var shot := func(name: String) -> void:
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "t_" + name + ".png")
	for i in 40:
		await get_tree().physics_frame
	await shot.call("idle")
	# Бег
	h.touch.move = Vector2(0, 1)
	main.rig.yaw = PI
	h.touch.run = true
	for i in 50:
		await get_tree().physics_frame
	await shot.call("run")
	# Удар на бегу: верх тела бьёт, ноги бегут
	h.attack()
	for i in 9:
		await get_tree().physics_frame
	_check("upper body only while running", h._ha._mix.filter_enabled and h._ha.weight() > 0.5, str(h._ha.weight()))
	await shot.call("run_attack")
	for i in 40:
		await get_tree().physics_frame
	_check("back to running", h._ha.weight() < 0.05, str(h._ha.weight()))
	h.touch.run = false
	h.touch.move = Vector2.ZERO
	for i in 40:
		await get_tree().physics_frame
	# Блок
	h.touch.block = true
	for i in 20:
		await get_tree().physics_frame
	_check("block pose", h._ha.current() in ["slash", "block"] and h._ha.act_scale == 0.0, h._ha.current())
	await shot.call("block")
	h.touch.block = false
	for i in 30:
		await get_tree().physics_frame
	_check("block released", h._ha.current() == "", h._ha.current())
	# Вихрь
	h.use_skill("whirl")
	for i in 20:
		await get_tree().physics_frame
	_check("whirl", h._ha.current() == "whirl", h._ha.current())
	await shot.call("whirl")
	for i in 60:
		await get_tree().physics_frame
	# Прыжок
	h.touch.jump = true
	await get_tree().physics_frame
	h.touch.jump = false
	for i in 12:
		await get_tree().physics_frame
	_check("jump pose", h._ha.current() == "air", h._ha.current())
	await shot.call("jump")
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
