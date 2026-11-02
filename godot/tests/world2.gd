## Лавка алхимика (покупка и варка зелий, зелья не падают с монстров) и второй мир над башней:
## с 10-го этажа — на Плато ветров, деревня с лавкой и кузницей, новые монстры, портал вниз.
## Запуск: godot --path godot res://tests/world2.tscn -- <папка>
extends Node

var main: Node
var ok := true
var out := ""

func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + name + ".png")

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] + "/"
	Game.bosses = []
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	Game.level = 30
	Game.refresh()
	Game.time_of_day = 0.4
	var h: Node3D = main.hero
	for e in main.enemies.list:
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
	# Зелья не падают с монстров: в добыче нет зелий
	var potions_before := Game.potions()
	for i in 40:
		main.loot.roll("goblin", h.global_position + Vector3(50, 0, 0))
	await _frames(2)
	var pot_drops := 0
	for it in main.loot._items:
		if it["id"] == "potion":
			pot_drops += 1
	_check("no potions from monsters", not Items.LOOT["goblin"].is_empty() and pot_drops == 0, str(pot_drops))
	# Лавка в Камнеграде
	var al := Vector3(WorldGen.ALCHEMIST_POS.x, 0, WorldGen.ALCHEMIST_POS.y)
	var f: Vector3 = Alchemist.front(al, WorldGen.ALCHEMIST_YAW)
	h.global_position = Vector3(f.x, WorldGen.ground_at(f.x, f.z) + 0.3, f.z)
	h.facing = WorldGen.ALCHEMIST_YAW + PI
	main.rig.yaw = h.facing + PI
	main.rig.snap()
	await _frames(20)
	_check("alchemist act in town", main.hud.touch.act_text == "⚗ Алхимик", main.hud.touch.act_text)
	await _shot("alchemist_town")
	Game.gold = 100
	var p0 := Game.potions()
	_check("buy potion", Game.buy_potion() and Game.potions() == p0 + 1 and Game.gold == 100 - Items.POTION_PRICE, "%d %d" % [Game.potions(), Game.gold])
	Game.add_item("essence", 3)
	var e0 := Game.count_of("essence")
	var brewed := Game.brew_potion()
	_check("brew potion", brewed and Game.potions() == p0 + 2 and Game.count_of("essence") == e0 - Items.BREW_ESSENCE, "%d %d→%d" % [Game.potions(), e0, Game.count_of("essence")])
	main.hud.open_alchemist()
	await _frames(10)
	await _shot("alchemist_panel")
	main.hud.alchemist.close()
	# Башня: 10 этажей, вершина выше гор
	var peak := 0.0
	for hv in WorldGen.heights:
		peak = maxf(peak, hv)
	var top: float = main.world.tower["pos"].y + main.world.tower["height"]
	_check("tower 10 floors", DungeonDefs.TOWER.size() == 10, "")
	_check("tower 15 m above peaks", absf(top - (peak + 15.0)) < 0.5, "%.1f vs %.1f" % [top, peak])
	# С 10-го этажа — в новый мир
	for k in range(1, 11):
		Game.bosses.append(DungeonDefs.floor_index(k))
	main.enter_floor(10)
	await _frames(90)
	var d: Node3D = main.dungeons[DungeonDefs.floor_index(10)]
	_check("floor 10 stairs open", d.stairs_open, "")
	h.global_position = d.stairs_front + Vector3(0, 0.3, 0)
	await _frames(15)
	_check("stairs to new world", main.hud.touch.act_text.begins_with("Подняться в новый мир"), main.hud.touch.act_text)
	main.enter_world2()
	await _frames(90)
	_check("in world 2", main.mode == main.WORLD2 and main.world2.visible and not main.world.visible, str(main.mode))
	var w2n := 0
	for e in main.enemies.list:
		if e.world2:
			w2n += 1
	_check("new monsters on plateau", w2n >= 30, str(w2n))
	_check("hero stands on plateau", absf(h.global_position.y - main.world2.ground_at_world(h.global_position)) < 1.5, str(h.global_position))
	main.hud.visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var o: Vector3 = main.world2.ORIGIN
	cam.global_position = o + Vector3(30, 22, 40)
	cam.look_at(o + Vector3(0, 6, 0))
	await _shot("world2_village")
	cam.global_position = o + Vector3(0, 60, 150)
	cam.look_at(o + Vector3(0, 10, 0))
	await _shot("world2_far")
	# Монстры плато крупным планом
	var shown := 0
	for e in main.enemies.list:
		if e.world2 and shown < 4 and e.type in ["stone_golem", "storm_wolf", "venom_spider", "thorn_beast"]:
			if shown == ["stone_golem", "storm_wolf", "venom_spider", "thorn_beast"].find(e.type):
				e.set_active(true)
				cam.global_position = e.global_position + Vector3(4, 2.5, 4)
				cam.look_at(e.global_position + Vector3(0, 1, 0))
				await _shot("monster_" + e.type)
				shown += 1
	cam.current = false
	main.hud.visible = true
	# Лавка алхимика в деревне и портал вниз
	var af: Vector3 = Alchemist.front(main.world2.alchemist_pos, PI / 2.0) + o
	h.global_position = af + Vector3(0, 0.5, 0)
	await _frames(20)
	_check("alchemist act on plateau", main.hud.touch.act_text == "⚗ Алхимик", main.hud.touch.act_text)
	h.global_position = main.world2.portal_pos + o + Vector3(0, 0.5, 1.0)
	await _frames(20)
	_check("portal act", main.hud.touch.act_text == "Спуститься к подножию башни", main.hud.touch.act_text)
	main.leave_world2()
	await _frames(60)
	_check("back at tower", main.mode == -1 and h.global_position.distance_to(main.world.tower["door"]) < 8.0, str(h.global_position))
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
