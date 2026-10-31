## Проверка кузницы, рангов, осколков, атаки кролика и кобольда, эволюции навыков.
## Запуск: godot --path godot res://tests/forge.tscn -- <папка для снимков>
extends Node

var main: Node
var out := "user://"
var ok := true

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0] + "/"
	# Старое сохранение (до рангов) должно открыться без ошибок
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"name": "Алекс", "level": 3, "xp": 5, "gold": 500, "kills": 7, "chests": [],
		"inv": [{"id": "potion", "n": 2}, {"id": "sword_iron", "n": 1}], "equip": {"weapon": "sword_iron", "armor": "armor_leather", "helm": null, "amulet": null}, "skills": {}}))
	f.close()
	Game.has_save = Game.load_game()
	Game.refresh()
	_check("old save migrated", Game.equip["weapon"] is Dictionary and Game.equip["weapon"]["id"] == "sword_iron" and Game.equip["weapon"]["r"] == 0 and Game.inv[1]["r"] == 0, str(Game.equip["weapon"]))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	await _frames(5)
	# 1. Улучшение оружия за золото
	var w: Dictionary = Game.equip["weapon"]
	var d0 := Game.dmg
	var g0 := Game.gold
	_check("upgrade weapon", Game.upgrade_weapon() and w["u"] == 1 and Game.dmg == d0 + 3 and Game.gold == g0 - 25, "dmg %d → %d, gold %d → %d" % [d0, Game.dmg, g0, Game.gold])
	Game.upgrade_weapon()
	# 2. Соединение: 3 железных меча (один надет) + осколки → «Обычный»
	Game.add_item("sword_iron")
	var why := Game.can_combine("sword_iron", 0)
	_check("combine needs shards", why == "Мало осколков", why)
	Game.add_item("shard", 10)
	_check("shards stack", Game.count_of("shard") == 10 and Game.inv.filter(func(s): return s["id"] == "shard").size() == 1, "")
	var dmg_before := Game.dmg
	var res := Game.combine("sword_iron", 0)
	_check("combine 3 → rank up", res.get("r", -1) == 1 and res["u"] == 2 and Game.equip["weapon"] == res and Game.count_of("shard") == 8 and Game.inv.filter(func(s): return s["id"] == "sword_iron").is_empty(), str(res))
	_check("rank raises damage", Game.dmg > dmg_before, "dmg %d → %d" % [dmg_before, Game.dmg])
	# Окно кузницы через кнопку действия
	for i in 5:
		Game.add_item("helm_leather")
	main.hero.global_position = Vector3(20, 4.2, -2.4)
	await _frames(10)
	_tap(main.hud.touch._act_rect().get_center())
	await _frames(5)
	_check("forge opens", main.hud.forge.visible, "")
	await _shot("f_forge.png")
	main.hud.forge.close()
	# 3. Осколки падают только в подземельях
	main.loot.roll("kobold", main.hero.global_position)
	var shard_luck := 0
	for i in 200:
		var t: Dictionary = Items.LOOT["kobold"]
		if randf() < t["shard"][0]:
			shard_luck += 1
	_check("shards from dungeon monsters only", Items.LOOT["kobold"].has("shard") and not Items.LOOT["rabbit"].has("shard") and not Items.LOOT["goblin"].has("shard"), "")
	# 4. Кролик бьёт сразу, как подбежал
	var rb: Node3D = main.enemies.list.filter(func(e): return e.type == "rabbit")[0]
	var spot := Vector3(-60, 0, -120)
	main.hero.global_position = Vector3(spot.x, WorldGen.ground_at(spot.x, spot.z) + 0.2, spot.z)
	main.hero.velocity = Vector3.ZERO
	rb.home = Vector3(spot.x, WorldGen.ground_at(spot.x, spot.z - 1.5), spot.z - 1.5)
	rb.reset_home()
	rb.set_physics_process(true)
	rb.st = "chase"
	Game.hp = Game.max_hp
	var hp0 := Game.hp
	await _frames(9)  # ~0,15 с
	_check("rabbit hits at once", Game.hp < hp0, "hp %d → %d" % [hp0, Game.hp])
	_check("rabbit/kobold damage up", rb.T["dmg"] == 16 and main.enemies.list.filter(func(e): return e.type == "kobold")[0].T["dmg"] == 23, "")
	# 5. Эволюция навыка закрыта на максимуме
	Game.level = 10
	Game.skills = {"strength": 7}
	Game.refresh()
	main.hud.open_skills()
	await _frames(5)
	await _shot("f_skills.png")
	var evo := _find_button(main.hud.skills, "Эволюция")
	_check("evolution locked", evo != null and evo.disabled, "")
	main.hud.skills.close()
	# 6. Инвентарь с рангами
	Game.add_item("armor_plate", 1, 4)
	main.hud.open_inventory()
	main.hud.inventory._sel = {"eq": "weapon"}
	main.hud.inventory._render()
	await _frames(5)
	await _shot("f_inventory.png")
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _find_button(n: Node, text: String) -> Button:
	for c in n.find_children("*", "Button", true, false):
		if (c as Button).text.contains(text):
			return c
	return null

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond

func _shot(name: String) -> void:
	await _frames(3)
	get_viewport().get_texture().get_image().save_png(out + name)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 5
		ev.position = pos * Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
		ev.pressed = pressed
		Input.parse_input_event(ev)
