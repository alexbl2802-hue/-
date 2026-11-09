## Приёмы меча, отбитие, характеристики, прочность, ковка, типы оружия.
## Запуск: godot --path godot res://tests/arts.tscn -- <папка>
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
	Game.level = 15
	Game.skills = {"art_sword": 1, "art_great": 1, "art_rapier": 1, "art_dagger": 1}
	Game.stats = {"str": 0, "agi": 0, "vit": 0}
	Game.refresh()
	var p := Vector3(-60, 0, -120)
	var gob: Node3D = main.enemies.list.filter(func(e): return e.type == "goblin" and not e.dead)[0]
	gob.T["hp"] = 99999
	# 1. Приёмы всех типов оружия
	for w in ["sword_iron", "great_iron", "rapier_steel", "dagger_iron"]:
		Game.equip["weapon"] = Items.make(w)
		Game.refresh()
		h.update_look()
		h.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
		h.facing = 0.0
		gob.home = h.global_position + Vector3(0, 0, 2.5)
		gob.reset_home()
		gob.hp = 99999
		gob.set_active(true)
		for i in 10:
			await get_tree().physics_frame
		var aid: String = "art_" + Items.ALL[w].get("wt", "sword")
		h.cd[aid] = 0.0
		var hp0: float = gob.hp
		h.use_skill(aid)
		var shot := false
		for i in 120:
			await get_tree().physics_frame
			if not shot and h._art_t > 0.1 and h._art_t < h.ART_CHARGE:
				shot = true
				main.rig.yaw = PI * 0.8
				main.rig.pitch = 0.15
				main.rig.dist = 4.0
				await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png(out + "art_%s.png" % w)
			if h._art_t < 0.0 and i > 10:
				break
		_check("art %s hits" % Items.ALL[w].get("wt", "sword"), gob.hp < hp0, "%d dmg" % (hp0 - gob.hp))
	# 2. Отбитие: блок только что поднят — урона нет, враг оглушён
	Game.equip["weapon"] = Items.make("sword_iron")
	Game.refresh()
	h.touch.block = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	h._invuln = 0.0
	var hp1: float = Game.hp
	h.take_damage(30, gob.global_position, gob)
	_check("parry: no damage, enemy stunned", Game.hp == hp1 and gob.st == "stun", "hp %d→%d st %s" % [hp1, Game.hp, gob.st])
	var ghp: float = gob.hp
	gob.hit(10, Vector3.FORWARD)
	_check("stunned enemy takes double", ghp - gob.hp == 20, str(ghp - gob.hp))
	h.touch.block = false
	# 3. Характеристики
	var d0 := Game.dmg
	var hp_max0 := Game.max_hp
	Game.add_stat("str")
	Game.add_stat("vit")
	_check("stats str/vit", Game.dmg == d0 + Game.STAT_STR and Game.max_hp == hp_max0 + Game.STAT_VIT, "")
	_check("stat points", Game.stat_points_free() == 14 * 2 - 2, str(Game.stat_points_free()))
	# 4. Прочность: износ, поломка, починка
	var w0 = Game.equip["weapon"]
	w0["d"] = 1
	var d1 := Game.dmg
	Game.wear_weapon()
	_check("weapon broken weaker", Items.broken(w0) and Game.dmg < d1, "dmg %d→%d" % [d1, Game.dmg])
	Game.gold = 1000
	_check("repair", Game.repair_weapon() and w0["d"] == Items.max_dur(w0) and Game.dmg == d1, "")
	# 5. Ковка
	Game.inv = []
	Game.add_item("mat_crown")
	Game.add_item("shard", 10)
	Game.gold = 1000
	_check("forge unique", Game.forge(Items.RECIPES[0]) and Game.inv.any(func(s): return s["id"] == "u_bone_king"), "")
	main.hud.open_forge()
	main.hud.forge._tab = "forge"
	main.hud.forge._render()
	for i in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "forge_tab.png")
	main.hud.forge.close()
	main.hud.open_skills()
	main.hud.skills._tab = "stats"
	main.hud.skills._render()
	for i in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "stats_tab.png")
	main.hud.skills.close()
	Game.hp = Game.max_hp * 0.2
	for i in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "hp_red.png")
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
