## Проверка этапа 2: монстры, бой, добыча, уровни, навыки, умения, гибель и возрождение.
## Запуск: godot --path godot res://tests/combat.tscn -- <папка для снимков>
extends Node

var main: Node
var out := "user://"
var ok := true

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0] + "/"
	Game.new_game()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()  # закрываем главное меню
	await _frames(20)
	var hero: Node3D = main.hero
	var en: Node = main.enemies
	var spot := Vector3(-60, 0, -120)
	_place(spot, 2.6)
	var vp := get_viewport().get_visible_rect().size
	# 1. Гоблин замечает героя, подходит и бьёт
	var gob: Node3D = _enemy("goblin", 0)
	_move_enemy(gob, spot + Vector3(0, 0, -6))
	var hp0: float = Game.hp
	await _wait_until(func(): return Game.hp < hp0, 600)
	_check("goblin hits hero", Game.hp < hp0, "hp %d → %d" % [hp0, Game.hp])
	await _shot("c_fight.png")
	# 2. Бьём гоблина кнопкой ⚔, пока не победим
	var xp0 := Game.xp
	var kills0 := Game.kills
	for i in 30:
		if gob.dead:
			break
		_tap(Vector2(vp.x - 69.5, vp.y - 73.5))
		await _frames(25)
		Game.hp = Game.max_hp
	_check("goblin killed by ⚔", gob.dead and Game.kills == kills0 + 1, "kills %d, xp %d → %d" % [Game.kills, xp0, Game.xp])
	_check("xp for goblin", Game.xp == xp0 + 20 or Game.level > 1, "xp %d" % Game.xp)
	# 3. Добыча: гарантируем выпадение и подбираем
	var gold0 := Game.gold
	main.loot.drop("gold", 7, hero.global_position + Vector3(2, 0, 0))
	main.loot.drop("sword_steel", 1, hero.global_position + Vector3(2, 0, 0))
	await _frames(40)
	await _shot("c_loot.png")
	for it in main.loot._items.duplicate():
		hero.global_position = it["pos"] + Vector3(0, 0.3, 0)
		await _frames(12)
	_check("loot picked", Game.gold >= gold0 + 7 and Game.inv.any(func(s): return s["id"] == "sword_steel"), "gold %d, inv %s" % [Game.gold, Game.inv])
	# 4. Уровни и очки навыков
	Game.give_xp(1500, hero.global_position)
	await _frames(30)
	_check("level up", Game.level >= 6, "level %d, points %d" % [Game.level, Game.points_free()])
	await _shot("c_levelup.png")
	# 5. Окно навыков кнопкой ⭐ и изучение кликом по кнопке
	_tap(Vector2(158, 38))
	await _frames(10)
	var panel: Control = main.hud.skills
	_check("skills panel opens", panel.visible and get_tree().paused, "")
	await _shot("c_skills.png")
	for id in ["whirl", "whirl", "dash", "strength"]:
		Game.learn(id)
	panel._render()
	await _frames(5)
	await _shot("c_skills2.png")
	panel.close()
	await _frames(5)
	_check("skills learned", Game.rank("whirl") == 2 and Game.rank("dash") == 1, str(Game.skills))
	# 6. Вихрь: три слизня вокруг
	_place(spot, 2.6)
	var slimes := []
	for k in 3:
		var s: Node3D = _enemy("slime", k)
		var a := k * 2.1
		_move_enemy(s, hero.global_position + Vector3(sin(a) * 2.0, 0, cos(a) * 2.0))
		s.hp = 25
		s.T = s.T.duplicate()
		s.T["aggro"] = 0.0
		slimes.append(s)
	await _frames(10)
	_tap(Vector2(vp.x - 160, vp.y - 130))
	await _frames(8)
	await _shot("c_whirl.png")
	await _frames(30)
	_check("whirl kills 3 slimes", slimes.all(func(s): return s.dead), str(slimes.map(func(s): return s.hp)))
	_check("whirl cooldown", main.hero.cd["whirl"] > 0.0, str(main.hero.cd))
	# 7. Рывок сквозь гоблина
	var gob2: Node3D = _enemy("goblin", 1)
	hero.facing = 0.0
	_move_enemy(gob2, hero.global_position + Vector3(0, 0, 3))
	gob2.T = gob2.T.duplicate()
	gob2.T["aggro"] = 0.0
	var p0: Vector3 = hero.global_position
	var ghp: float = gob2.hp
	await _frames(5)
	_tap(Vector2(vp.x - 236, vp.y - 60))
	await _frames(40)
	_check("dash moves and hits", hero.global_position.distance_to(p0) > 5.0 and gob2.hp < ghp, "moved %.1f, goblin hp %d → %d" % [hero.global_position.distance_to(p0), ghp, gob2.hp])
	# 8. Гибель и возрождение у костра
	hero._invuln = 0.0
	hero.take_damage(99999, hero.global_position + Vector3(1, 0, 0))
	_check("hero died", hero.dead, "")
	await _frames(20)
	await _shot("c_dead.png")
	await _wait_until(func(): return not hero.dead, 600)
	var near_fire: bool = hero.global_position.distance_to(main.world.campfire.position) < 6.0
	_check("respawn at campfire", not hero.dead and near_fire and Game.hp >= Game.max_hp - 1, "pos %s" % hero.global_position)
	# 9. Зелье
	Game.hp = 30
	var pot0 := Game.potions()
	_tap(Vector2(98, 38))
	await _frames(5)
	_check("potion heals", Game.hp > 30 and Game.potions() == pot0 - 1, "hp %d, potions %d" % [Game.hp, Game.potions()])
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _enemy(kind: String, nth: int) -> Node3D:
	var k := 0
	for e in main.enemies.list:
		if e.type == kind and not e.dead:
			if k == nth:
				return e
			k += 1
	return null

func _move_enemy(e: Node3D, p: Vector3) -> void:
	e.home = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.3, p.z)
	e.reset_home()
	e.set_physics_process(true)

func _place(p: Vector3, yaw: float) -> void:
	main.hero.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
	main.hero.velocity = Vector3.ZERO
	main.rig.yaw = yaw
	main.rig.pitch = 0.4
	main.rig.dist = 9.0

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
