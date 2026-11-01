## Новые вещи, комбо ударов и блок: числа и снимки.
## Запуск: godot --path godot res://tests/gear.tscn -- <папка>
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
	var h: Node3D = main.hero
	Game.level = 8
	Game.inv = []
	for id in ["boots_wind", "ring_ruby", "cloak_shadow", "shield_tower"]:
		Game.add_item(id)
	for i in 4:
		Game.equip_from(0)
	Game.refresh()
	_check("new slots equipped", Game.equip["boots"] != null and Game.equip["ring"] != null and Game.equip["cloak"] != null and Game.equip["shield"] != null, str(Game.equip.keys()))
	_check("boots speed", Game.speed_bonus >= 0.19, str(Game.speed_bonus))
	_check("ring crit", Game.crit_bonus >= 0.09, str(Game.crit_bonus))
	_check("shield block", h.block_reduce() > 0.8, str(h.block_reduce()))
	Game.add_item("boots_leather")
	Game.add_item("ring_copper")
	main.hud.open_inventory()
	for i in 6:
		await get_tree().process_frame
	_save("gear_inventory.png")
	main.hud.inventory.close()
	# Блок: удар спереди снимает большую часть урона
	var p := Vector3(-60, 0, -120)
	h.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
	h.facing = 0.0
	for i in 10:
		await get_tree().physics_frame
	Game.hp = Game.max_hp
	h.touch.block = true
	for i in 8:
		await get_tree().physics_frame
	_check("blocking", h.blocking, "")
	h._invuln = 0.0
	var hp0: float = Game.hp
	h.take_damage(40, h.global_position + Vector3(0, 0, 2))
	var blocked: float = hp0 - Game.hp
	h._invuln = 0.0
	hp0 = Game.hp
	h.take_damage(40, h.global_position + Vector3(0, 0, -2))
	var back: float = hp0 - Game.hp
	_check("block front only", blocked < back * 0.4, "front %d, back %d" % [blocked, back])
	main.rig.yaw = PI * 0.8
	main.rig.pitch = 0.1
	main.rig.dist = 2.6
	main.rig.snap()
	for i in 10:
		await get_tree().process_frame
	_save("gear_block.png")
	print("block anim: ", h._anim.current_animation, " pos ", h._anim.current_animation_position, " blocking ", h.blocking, " touch.block ", h.touch.block)
	h.touch.block = false
	for i in 5:
		await get_tree().physics_frame
	# Комбо: три удара подряд
	var gob: Node3D = main.enemies.list.filter(func(e): return e.type == "goblin" and not e.dead)[0]
	gob.home = h.global_position + Vector3(0, 0, 1.8)
	gob.reset_home()
	gob.set_active(true)
	gob.hp = 9999
	gob.T["hp"] = 9999
	for i in 10:
		await get_tree().physics_frame
	var seen := []
	h.attack()
	for i in 200:
		await get_tree().physics_frame
		if h.attack_t >= 0.0 and h.attack_t > 0.15:
			h.attack()   # жмём во время удара — следующий удар в комбо
		if not seen.has(h.combo) and h.attack_t >= 0.0:
			seen.append(h.combo)
		if h.combo == 2 and h.attack_t > 0.25:
			await get_tree().process_frame
			_save("gear_combo3.png")
			break
	_check("combo 1-2-3", seen == [0, 1, 2], str(seen))
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + name)

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
