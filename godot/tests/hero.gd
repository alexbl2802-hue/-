## Снимки героя с моделью: стоит, идёт, бежит, удар (несколько кадров), Вихрь, в бою с гоблином.
## Запуск: godot --path godot res://tests/hero.tscn -- <папка>
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
	var h: Node3D = main.hero
	print("character: ", h._char != null, " anims: ", h._anim.get_animation_list() if h._anim else [])
	var p := Vector3(-60, 0, -120)
	_place(p)
	h.facing = 0.0
	await _shot("hm_idle.png", 0.5, 0.12, 3.4, 30)
	# Ходьба и бег — джойстиком
	h.touch.move = Vector2(0, 0.5)
	await _shot("hm_walk.png", -0.9, 0.12, 3.6, 25, true)
	h.touch.run = true
	h.touch.move = Vector2(0, 1)
	await _shot("hm_run.png", -0.9, 0.15, 4.0, 25, true)
	h.touch.run = false
	h.touch.move = Vector2.ZERO
	await _frames(20)
	# Удар — кадры по ходу взмаха
	_place(p)
	h.facing = 0.0
	main.rig.yaw = 1.2
	main.rig.pitch = 0.12
	main.rig.dist = 3.6
	main.rig.snap()
	await _frames(10)
	h.attack()
	for k in 4:
		await _frames(5)
		get_viewport().get_texture().get_image().save_png(out + "hm_slash_%d.png" % k)
	await _frames(30)
	# С гоблином
	var gob: Node3D = main.enemies.list.filter(func(e): return e.type == "goblin")[0]
	_place(p)
	gob.home = Vector3(p.x, WorldGen.ground_at(p.x, p.z + 2.2), p.z + 2.2)
	gob.reset_home()
	gob.set_physics_process(true)
	gob.facing = PI
	h.facing = 0.0
	main.rig.yaw = 2.3
	main.rig.pitch = 0.25
	main.rig.dist = 6.0
	main.rig.snap()
	await _frames(10)
	h.attack()
	await _frames(7)
	get_viewport().get_texture().get_image().save_png(out + "hm_fight.png")
	# Доспехи: кожа, кольчуга, латы со шлемами
	main.enemies.reset_all()
	for gear_set in [["armor_leather", "helm_leather", "hm_gear_leather.png"], ["armor_chain", "helm_iron", "hm_gear_chain.png"], ["armor_plate", "helm_iron", "hm_gear_plate.png"]]:
		Game.equip["armor"] = Items.make(gear_set[0])
		Game.equip["helm"] = Items.make(gear_set[1])
		Game.refresh()
		_place(p + Vector3(6, 0, 0))
		h.facing = 0.0
		await _shot(gear_set[2], 0.45, 0.1, 2.8, 25)
	h.touch.run = true
	h.touch.move = Vector2(0, 1)
	await _shot("hm_gear_run.png", -1.2, 0.15, 3.6, 20)
	h.touch.move = Vector2.ZERO
	h.touch.run = false
	get_tree().quit()

func _place(p: Vector3) -> void:
	main.hero.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
	main.hero.velocity = Vector3.ZERO

func _shot(name: String, yaw: float, pitch: float, dist: float, frames: int, follow := false) -> void:
	main.rig.yaw = yaw
	main.rig.pitch = pitch
	main.rig.dist = dist
	main.rig.snap()
	await _frames(frames)
	get_viewport().get_texture().get_image().save_png(out + name)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
