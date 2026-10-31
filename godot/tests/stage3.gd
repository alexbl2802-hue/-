## Проверка этапа 3: главное меню и имя, инвентарь, кузница, новые монстры,
## вход в подземелья, сундук, выход, сохранение.
## Запуск: godot --path godot res://tests/stage3.tscn -- <папка для снимков>
extends Node

var main: Node
var out := "user://"
var ok := true

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0] + "/"
	Game.wipe()
	Game.player_name = ""
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await _frames(10)
	var hud: Node = main.hud
	var menu: Control = hud.menu
	# 1. Первый запуск: «Начать игру», без «Новой игры», игра на паузе
	_check("first launch menu", menu.visible and menu._main.text == "Начать игру" and not menu._new.visible and get_tree().paused, menu._main.text)
	menu._name.text = "Алекс"
	await _shot("s3_menu_first.png")
	menu._main.pressed.emit()
	await _frames(5)
	_check("game started", not menu.visible and not get_tree().paused and Game.player_name == "Алекс" and Game.has_save and FileAccess.file_exists(Game.SAVE_PATH), Game.player_name)
	# 2. Повторное открытие меню кнопкой ☰ — уже «Продолжить»
	_tap(Vector2(218, 38))
	await _frames(5)
	_check("menu shows continue", menu.visible and menu._main.text == "Продолжить" and menu._new.visible, menu._main.text)
	await _shot("s3_menu_continue.png")
	menu._main.pressed.emit()
	await _frames(5)
	# 3. Инвентарь кнопкой 🎒, надеваем стальной меч и латы
	Game.add_item("sword_steel")
	Game.add_item("armor_plate")
	Game.add_item("helm_iron")
	_tap(Vector2(38, 38))
	await _frames(5)
	var inv: Control = hud.inventory
	_check("inventory opens", inv.visible and get_tree().paused, "")
	var dmg0 := Game.dmg
	for id in ["sword_steel", "armor_plate", "helm_iron"]:
		for i in Game.inv.size():
			if Game.inv[i]["id"] == id:
				inv._sel = {"i": i}
				inv._render()
				Game.equip_from(i)
				break
	inv._sel = {"eq": "weapon"}
	inv._render()
	await _frames(3)
	await _shot("s3_inventory.png")
	var want_dmg: int = dmg0 - 4 + Items.stat(Game.equip["weapon"], "dmg")
	var want_arm: int = Items.stat(Game.equip["armor"], "armor") + Items.stat(Game.equip["helm"], "armor")
	_check("equipment applied", Game.dmg == want_dmg and Game.armor == want_arm, "dmg %d, armor %d" % [Game.dmg, Game.armor])
	inv.close()
	await _frames(3)
	# 4. Кузница через кнопку действия
	_place(Vector3(20, 4, -2.4), 0.1)
	await _frames(10)
	_check("forge action", hud.touch.act_text == "⚒ Кузница", hud.touch.act_text)
	_tap_act()
	await _frames(5)
	_check("forge opens locked", hud.forge.visible, "")
	await _shot("s3_forge.png")
	hud.forge.close()
	await _frames(3)
	# 5. Новые монстры: кролик и кобольды
	var rabbits: Array = main.enemies.list.filter(func(e): return e.type == "rabbit")
	var kobolds: Array = main.enemies.list.filter(func(e): return e.type == "kobold")
	_check("rabbits roam the world", rabbits.size() == 12 and not rabbits[0].in_dungeon, "%d кроликов" % rabbits.size())
	_check("kobolds in dungeons", kobolds.size() == 5 and kobolds.all(func(e): return e.in_dungeon), "%d кобольдов" % kobolds.size())
	var rb: Node3D = rabbits[0]
	var spot := Vector3(-60, 0, -120)
	_place(spot, 2.6)
	rb.home = Vector3(spot.x, WorldGen.ground_at(spot.x, spot.z - 4), spot.z - 4)
	rb.reset_home()
	rb.set_physics_process(true)
	rb.T = rb.T.duplicate()
	rb.T["aggro"] = 0.0
	await _frames(30)
	await _shot("s3_rabbit.png")
	# 6. Вход в склеп через кнопку «Войти»
	var e: Dictionary = main.world.entrances[0]
	var door: Vector3 = e["door"] + e["dir"] * 1.5
	_place(door, atan2(e["dir"].x, e["dir"].z))
	await _frames(10)
	_check("entrance action", hud.touch.act_text.begins_with("Войти"), hud.touch.act_text)
	_tap_act()
	await _wait_until(func(): return main.mode == 0 and not main.hero.busy, 400)
	var d: Node3D = main.dungeons[0]
	_check("entered crypt", main.mode == 0 and main.hero.global_position.distance_to(d.start_pos) < 2.0, str(main.hero.global_position))
	await _frames(30)
	await _shot("s3_crypt.png")
	# Кобольд крупным планом
	var kb: Node3D = kobolds.filter(func(k): return absf(k.global_position.y - d.Y) < 20)[0]
	kb.T = kb.T.duplicate()
	kb.T["aggro"] = 0.0
	var kp: Vector3 = kb.global_position
	main.hero.global_position = kp + Vector3(0, 0.2, 3.5)
	main.hero.facing = PI
	main.rig.yaw = 0.0
	main.rig.pitch = 0.2
	main.rig.dist = 5.0
	main.rig.snap()
	await _frames(30)
	await _shot("s3_kobold.png")
	# 7. Сундук
	var c: Vector3 = d.chest["pos"]
	var gold0 := Game.gold
	kb.global_position = kp + Vector3(0, 0, -20)
	for k in main.enemies.list:
		if k.in_dungeon:
			k.T = k.T.duplicate()
			k.T["aggro"] = 0.0
	main.hero.global_position = c + Vector3(0, 0.3, 1.6)
	await _frames(10)
	_check("chest action", hud.touch.act_text == "Открыть сундук", hud.touch.act_text)
	_tap_act()
	await _frames(40)
	await _shot("s3_chest.png")
	for it in main.loot._items.duplicate():
		main.hero.global_position = it["pos"] + Vector3(0, 0.3, 0)
		await _frames(10)
	_check("chest opened and looted", Game.chests.has(0) and Game.gold > gold0 and Game.inv.any(func(s): return s["id"] == "amulet_life"), "gold %d → %d" % [gold0, Game.gold])
	# 8. Выход на поверхность
	main.hero.global_position = d.start_pos + Vector3(0, 0.3, 0)
	await _frames(10)
	_check("exit action", hud.touch.act_text == "Подняться на поверхность", hud.touch.act_text)
	_tap_act()
	await _wait_until(func(): return main.mode == -1 and not main.hero.busy, 400)
	_check("back on surface", main.mode == -1 and main.world.visible and main.hero.global_position.y > -50, str(main.hero.global_position))
	# 9. Пещера кристаллов
	main.enter_dungeon(1)
	await _wait_until(func(): return main.mode == 1 and not main.hero.busy, 400)
	var d1: Node3D = main.dungeons[1]
	main.hero.global_position = d1.cell_center(5, 4) + Vector3(0, 0.3, 0)
	main.rig.yaw = -2.2
	main.rig.pitch = 0.3
	main.rig.dist = 6.0
	main.rig.snap()
	await _frames(30)
	await _shot("s3_cave.png")
	_check("cave entered", main.mode == 1, "")
	# 10. Сохранение: имя, сундук, снаряжение
	var saved = JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_PATH))
	_check("saved", saved["name"] == "Алекс" and saved["chests"].has(0.0) and saved["equip"]["weapon"]["id"] == "sword_steel", str(saved["chests"]))
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _place(p: Vector3, yaw: float) -> void:
	var y := WorldGen.ground_at(p.x, p.z) + 0.2 if p.y == 0 else p.y + 0.2
	main.hero.global_position = Vector3(p.x, y, p.z)
	main.hero.velocity = Vector3.ZERO
	main.rig.yaw = yaw
	main.rig.pitch = 0.35
	main.rig.dist = 8.0
	main.rig.snap()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond

func _wait_until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().process_frame

func _shot(name: String) -> void:
	await _frames(3)
	get_viewport().get_texture().get_image().save_png(out + name)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _win(pos: Vector2) -> Vector2:
	return pos * Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size

func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 5
		ev.position = _win(pos)
		ev.pressed = pressed
		Input.parse_input_event(ev)

func _tap_act() -> void:
	_tap(main.hud.touch._act_rect().get_center())
