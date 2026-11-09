## Этап 5: ИИ волка, паука, скелета и гоблина — смена состояний, атака, возврат домой, обход препятствия.
## Запуск: godot --headless --path godot res://tests/monsters_ai.tscn
extends Node

var main: Node
var h: Node
var ok := true

func _check(n: String, c: bool, info := "") -> void:
	print("%s %s  %s" % ["PASS" if c else "FAIL", n, info])
	ok = ok and c

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ground(x: float, z: float, up := 0.3) -> Vector3:
	return Vector3(x, WorldGen.ground_at(x, z) + up, z)

## Ровное сухое место без деревьев рядом: ищем точку, где высота почти не меняется
func _flat_spot(from: Vector2) -> Vector2:
	for r in range(0, 400, 7):
		for k in 12:
			var a := TAU * k / 12.0
			var c := from + Vector2(cos(a), sin(a)) * r
			var y0 := WorldGen.ground_at(c.x, c.y)
			if y0 < 1.0 or WorldGen.town_dist(c.x, c.y) < WorldGen.TOWN_WALL + 10.0:
				continue
			var flat := true
			for q in 16:
				var b := TAU * q / 16.0
				for d in [6.0, 12.0]:
					if absf(WorldGen.ground_at(c.x + cos(b) * d, c.y + sin(b) * d) - y0) > 0.8:
						flat = false
			if flat:
				return c
	return from

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	h = main.hero
	Game.level = 30
	Game.refresh()
	var spot := _flat_spot(Vector2(-60, -120))
	print("площадка ", spot)
	for kind in (OS.get_cmdline_user_args() if not OS.get_cmdline_user_args().is_empty() else ["wolf", "spider", "skeleton", "goblin"]):
		var e: Node3D = null
		for x in main.enemies.list:
			if x.type == kind and not x.dead and x.guard_room == null and not x.T.get("boss", false):
				e = x
				break
		if e == null:
			_check("%s exists" % kind, false)
			continue
		e.T = e.T.duplicate()
		var dmg0: int = e.T["dmg"]
		e.T["dmg"] = 1
		var was_dungeon: bool = e.in_dungeon
		e.in_dungeon = false   # паук и скелет живут в подземельях — проверяем на той же площадке
		# все остальные монстры спят, чтобы не мешали
		for x in main.enemies.list:
			if x != e:
				x.set_active(false)
		main.enemies.set_process(false)
		e.set_active(true)
		Game.hp = Game.max_hp
		h._invuln = 0.0
		# 1. Погоня и атака
		e.home = _ground(spot.x, spot.y)
		e.global_position = e.home
		e.st = "idle"
		h.global_position = _ground(spot.x + 8.0, spot.y, 0.5)
		h.velocity = Vector3.ZERO
		var states := []
		var hp0: float = Game.hp
		var hit_at := -1.0
		for i in 60 * 8:
			await _frames(1)
			h.global_position = Vector3(h.global_position.x, h.global_position.y, h.global_position.z)   # герой стоит
			if states.is_empty() or states[-1] != e.st:
				states.append(e.st)
			if Game.hp < hp0 and hit_at < 0.0:
				hit_at = i / 60.0
		_check("%s: idle → chase → windup → recover" % kind, states.has("chase") and states.has("windup") and states.has("recover"), " → ".join(states.slice(0, 8)))
		_check("%s: attack hits hero" % kind, hit_at >= 0.0, "первый удар через %.1f с" % hit_at)
		# 2. Герой ушёл далеко — монстр возвращается домой и успокаивается
		h.global_position = _ground(spot.x + 150.0, spot.y, 1.0)
		var back := -1.0
		for i in 60 * 25:
			await _frames(1)
			if e.st == "idle" and e.global_position.distance_to(e.home) < 3.0:
				back = i / 60.0
				break
		_check("%s: returns home and calms down" % kind, back >= 0.0, "через %.1f с (состояние %s, до дома %.1f м)" % [back, e.st, e.global_position.distance_to(e.home)])
		# 3. Стена между монстром и героем — монстр обходит её
		var wall := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(1.0, 4.0, 6.0)
		cs.shape = bx
		wall.add_child(cs)
		add_child(wall)
		wall.global_position = _ground(spot.x + 4.0, spot.y, 1.8)
		e.global_position = e.home
		e.st = "idle"
		h.global_position = _ground(spot.x + 9.0, spot.y, 0.5)
		var reached := -1.0
		var closest := 99.0
		for i in 60 * 12:
			await _frames(1)
			var d: float = Vector2(e.global_position.x - h.global_position.x, e.global_position.z - h.global_position.z).length()
			closest = minf(closest, d)
			if d < float(e.T["reach"]) + 0.3:
				reached = i / 60.0
				break
		_check("%s: walks around a wall to the hero" % kind, reached >= 0.0, "дошёл за %.1f с; ближе всего %.1f м; состояние %s" % [reached, closest, e.st])
		wall.queue_free()
		e.T["dmg"] = dmg0
		e.in_dungeon = was_dungeon
		e.global_position = e.home
		e.st = "idle"
		main.enemies.set_process(true)
		h.global_position = _ground(spot.x + 150.0, spot.y, 1.0)
		await _frames(5)
	print("RESULT: %s" % ("ALL OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)
