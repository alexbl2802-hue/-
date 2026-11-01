## Башня этажей: вход у города, на этаже — комната стража за воротами. Вошёл в комнату —
## ворота закрываются; страж побеждён — ворота открываются, лестница ведёт на следующий этаж.
## Запуск: godot --path godot res://tests/tower.tscn -- <папка>
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
	Game.level = 30
	Game.refresh()
	Game.time_of_day = 0.4
	# Башня снаружи
	var td: Vector3 = main.world.tower["door"]
	h.global_position = td + Vector3(0, 0.3, -1.0)
	main.rig.yaw = 0.0
	main.rig.pitch = 0.05
	main.rig.dist = 14.0
	main.rig.target = null
	main.rig.camera.global_position = td + Vector3(10, 6, -38)
	main.rig.camera.look_at(main.world.tower["pos"] + Vector3(0, 18, 0))
	for i in 20:
		await get_tree().physics_frame
	get_viewport().get_texture().get_image().save_png(out + "tower_outside.png")
	main.rig.target = h
	h.global_position = td + Vector3(0, 0.3, -1.0)
	for i in 5:
		await get_tree().physics_frame
	_check("tower door act", main.hud.touch.act_text == "Войти в башню: этаж 1", main.hud.touch.act_text)
	for f in range(1, DungeonDefs.TOWER.size() + 1):
		main.enter_floor(f)
		for i in 90:
			await get_tree().process_frame
		var idx := DungeonDefs.floor_index(f)
		var d: Node3D = main.dungeons[idx]
		_check("floor %d mode" % f, main.mode == idx and d.visible, "")
		var boss: Node3D = main.enemies.boss_of(idx)
		_check("floor %d guard: %s lvl %d" % [f, boss.T["name"] if boss else "-", boss.level if boss else 0], boss != null and boss.level == d.def["level"] + 2, "")
		var lv_ok := true
		for e in main.enemies.list:
			if e.in_dungeon and e.dungeon_idx == -1 and absf(e.global_position.y - d.Y) < 10.0 and e.level != d.def["level"]:
				lv_ok = false
		_check("floor %d monsters level %d" % [f, d.def["level"]], lv_ok, "")
		for e in main.enemies.list:
			if e.in_dungeon and e != boss:
				e.T = e.T.duplicate()
				e.T["aggro"] = 0.0
		_check("gate open, stairs hidden", not d.gate_closed and not d.stairs_open, "")
		# Обзор этажа у ворот
		var g: Vector2i = d.gate_cells[0]
		var gc: Vector3 = d.cell_center(g.x, g.y)
		var room_dir: Vector3 = (d.boss_pos - gc)
		room_dir.y = 0
		room_dir = room_dir.normalized()
		var dirs := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
		var into := Vector3.ZERO
		for dv in dirs:
			var c2: Vector2i = d.cell_of(gc + dv * 4.0)
			if d.room.has(c2):
				into = dv
		h.global_position = gc - into * 6.0 + Vector3(0, 0.3, 0)
		main.rig.yaw = atan2(-into.x, -into.z)
		main.rig.pitch = 0.25
		main.rig.dist = 6.0
		main.rig.snap()
		for i in 15:
			await get_tree().physics_frame
		_check("guard text", main.hud.touch.act_text.begins_with("⚔ Страж этажа"), main.hud.touch.act_text)
		get_viewport().get_texture().get_image().save_png(out + "floor%d_gate.png" % f)
		# Шаг в комнату — ворота закрываются
		boss.T = boss.T.duplicate()
		boss.T["aggro"] = 0.0
		h.global_position = gc + into * 4.0 + Vector3(0, 0.3, 0)
		main.rig.yaw = atan2(-into.x, -into.z)
		main.rig.snap()
		for i in 60:
			await get_tree().physics_frame
		_check("gate closed behind", d.gate_closed, "")
		get_viewport().get_texture().get_image().save_png(out + "floor%d_room.png" % f)
		# Ворота держат: идём назад сквозь них — не проходим
		var before: Vector3 = h.global_position
		h.velocity = Vector3.ZERO
		for i in 40:
			h.velocity = -into * 8.0
			h.move_and_slide()
			await get_tree().physics_frame
		_check("gate blocks", (h.global_position - gc).dot(into) > -0.6, str((h.global_position - gc).dot(into)))
		# Победа над стражем
		boss.hit(999999, Vector3.FORWARD)
		for i in 30:
			await get_tree().physics_frame
		_check("guard beaten saved", Game.bosses.has(idx), str(Game.bosses))
		_check("gate opened", not d.gate_closed, "")
		if f < DungeonDefs.TOWER.size():
			_check("stairs open", d.stairs_open, "")
			_check("unlocked %d" % (f + 1), Game.tower_unlocked() == f + 1, str(Game.tower_unlocked()))
			h.global_position = d.stairs_front + Vector3(0, 0.3, 0)
			var sd: Vector3 = d.stairs_pos - d.stairs_front
			main.rig.yaw = atan2(-sd.x, -sd.z)
			main.rig.snap()
			for i in 15:
				await get_tree().physics_frame
			_check("stairs act", main.hud.touch.act_text == "Подняться на этаж %d" % (f + 1), main.hud.touch.act_text)
			get_viewport().get_texture().get_image().save_png(out + "floor%d_stairs.png" % f)
	# Выход из башни — к двери башни
	main.exit_dungeon()
	for i in 60:
		await get_tree().process_frame
	_check("exit to tower door", main.mode == -1 and h.global_position.distance_to(td) < 8.0, str(h.global_position))
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
