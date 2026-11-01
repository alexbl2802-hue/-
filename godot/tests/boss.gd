## Боссы подземелий: стерегут сундук, особые удары, победа открывает сундук и сохраняется.
## Запуск: godot --path godot res://tests/boss.tscn -- <папка>
extends Node

var main: Node
var out := ""
var ok := true

func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] + "/"
	Game.bosses = []
	Game.chests = []
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	var h: Node3D = main.hero
	Game.level = 20
	Game.refresh()
	for di in 2:
		main.enter_dungeon(di)
		for i in 90:
			await get_tree().process_frame
		var d: Node3D = main.dungeons[di]
		var boss: Node3D = main.enemies.boss_of(di)
		_check("boss %d present: %s" % [di, boss.T["name"] if boss else "-"], boss != null, "")
		for e in main.enemies.list:
			if e != boss and e.in_dungeon:
				e.T = e.T.duplicate()
				e.T["aggro"] = 0.0
		# Сундук закрыт, пока жив босс
		var c: Vector3 = d.chest["pos"]
		h.global_position = c + Vector3(0, 0.3, 1.6)
		boss.T = boss.T.duplicate()
		boss.T["aggro"] = 0.0
		boss.reset_home()
		for i in 10:
			await get_tree().physics_frame
		_check("chest locked", main.hud.touch.act_text.begins_with("🔒"), main.hud.touch.act_text)
		# Особый удар: встаём на нужное расстояние и ждём
		Game.hp = Game.max_hp
		var far := 3.0 if boss.T.has("slam") else 8.0
		var dir: Vector3 = (h.global_position - boss.global_position)
		dir.y = 0
		h.global_position = boss.global_position + dir.normalized() * far + Vector3(0, 0.3, 0)
		boss.T["aggro"] = 30.0
		boss._spike_cd = 0.0
		boss.st = "chase"
		main.rig.yaw = atan2(-dir.x, -dir.z)
		main.rig.pitch = 0.3
		main.rig.dist = 9.0
		main.rig.snap()
		var hp0: float = Game.hp
		var shot := false
		for i in 600:
			await get_tree().physics_frame
			h.global_position = boss.global_position + dir.normalized() * far + Vector3(0, 0.3, 0)
			if boss.st == "aim" and boss._t > 0.3 and not shot:
				shot = true
				await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png(out + "boss%d_special.png" % di)
			if Game.hp < hp0 and shot:
				break
		_check("boss %d special hits" % di, shot and Game.hp < hp0, "hp %d → %d" % [hp0, Game.hp])
		get_viewport().get_texture().get_image().save_png(out + "boss%d_fight.png" % di)
		# Победа
		var xp0 := Game.xp
		boss.hit(99999, Vector3.FORWARD)
		for i in 20:
			await get_tree().physics_frame
		h.global_position = c + Vector3(0, 0.3, 1.6)
		for i in 10:
			await get_tree().physics_frame
		_check("boss %d beaten and saved" % di, Game.bosses.has(di) and main.enemies.boss_of(di) == null, str(Game.bosses))
		_check("chest unlocked", main.hud.touch.act_text == "Открыть сундук", main.hud.touch.act_text)
		main.exit_dungeon()
		for i in 60:
			await get_tree().process_frame
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
