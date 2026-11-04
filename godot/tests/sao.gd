## Движения в стиле игры про мечника: стойка, шаг и бег, уклонения, Switch, реакции,
## «Горизонталь», след клинка, осколки при смерти монстра (замедлений времени нет).
## Запуск: godot --path godot res://tests/sao.tscn -- <папка>
extends Node

var main: Node
var ok := true
var cam: Camera3D
var out := ""

func _process(_dt: float) -> void:
	if cam and main and main.hero:
		var hp: Vector3 = main.hero.global_position
		cam.global_position = hp + Vector3(3.6, 2.0, 2.6)
		cam.look_at(hp + Vector3(0, 0.9, 0))

func _shot(name: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "sao_" + name + ".png")

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
	Game.level = 20
	Game.skills["horizontal"] = 1
	Game.refresh()
	Game.time_of_day = 0.4
	for e in main.enemies.list:
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
	var h: Node3D = main.hero
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	var p := Vector3(-30, WorldGen.ground_at(-30, 70) + 0.2, 70)
	h.global_position = p
	h.facing = 0.0
	main.rig.yaw = PI
	await _frames(30)
	# Стойка, шаг, бег — свои анимации
	_check("stance anim", h._ha.current() == "" and h._anim.has_animation("Combat_Stance"), h._ha.current())
	await _shot("stance")
	h.touch.move = Vector2(0, 0.35)
	await _frames(30)
	await _shot("walk")
	h.touch.move = Vector2(0, 1)
	h.touch.run = true
	await _frames(30)
	await _shot("run")
	h.touch.move = Vector2.ZERO
	h.touch.run = false
	await _frames(30)
	# Уклонения
	for d in [[Vector2.ZERO, "dodge_back"], [Vector2(-1, 0), "dodge_left"], [Vector2(1, 0), "dodge_right"], [Vector2(0, 1), "roll"]]:
		h.facing = 0.0
		main.rig.yaw = PI
		h.cd["dodge"] = 0.0
		h.touch.move = d[0]
		var p0: Vector3 = h.global_position
		h.dodge()
		h.touch.move = Vector2.ZERO
		_check("dodge " + d[1], h._move == d[1], h._move)
		await _frames(12)
		_check(d[1] + " invulnerable", h._invuln > 0.0, str(h._invuln))
		await _shot(d[1])
		await _frames(40)
		var moved: Vector3 = h.global_position - p0
		print(d[1], " moved ", moved)
		_check(d[1] + " moved", Vector2(moved.x, moved.z).length() > 1.0, str(moved))
		h.global_position = p
		await _frames(10)
	# Отбитие → Switch
	var g: Node3D = null
	for e in main.enemies.list:
		if e.type == "goblin" and not e.in_dungeon:
			g = e
			break
	g.home = p + Vector3(0, 0, 2.0)
	g.global_position = g.home
	h.facing = 0.0
	await _frames(5)
	h.touch.block = true
	await _frames(3)
	h.take_damage(10, g.global_position, g)
	h.touch.block = false
	_check("parry → switch", h._move == "switch", h._move)
	await _frames(8)
	await _shot("switch")
	await _frames(40)
	# Удар о землю — сбит с ног, потом встаёт
	h.global_position = p
	h._invuln = 0.0
	Game.hp = Game.max_hp
	h.take_damage(10, p + Vector3(0, 0, 2), null, "slam")
	_check("slam → knockdown", h._move == "knockdown", h._move)
	await _frames(40)
	await _shot("knockdown")
	var seen_getup := false
	for i in 200:
		await get_tree().physics_frame
		if h._move == "getup" and not seen_getup:
			seen_getup = true
			await _frames(15)
			await _shot("getup")
		if h._move == "":
			break
	_check("then getup", seen_getup, "")
	_check("stands again", h._move == "", h._move)
	# Сильный удар
	h._invuln = 0.0
	for sl in ["armor", "helm", "boots", "shield", "cloak", "ring", "amulet"]:
		Game.equip[sl] = null
	Game.stats["vit"] = 0
	Game.refresh()
	h.take_damage(roundi(Game.max_hp * 0.4), p + Vector3(0, 0, 2))
	_check("heavy hit reaction", h._move == "hit_heavy", h._move)
	await _frames(6)
	await _shot("hit_heavy")
	await _frames(40)
	Game.hp = Game.max_hp
	# «Горизонталь»: бьёт всех впереди, след клинка, замедление
	var targets := []
	for e in main.enemies.list:
		if not e.in_dungeon and e.type == "goblin" and targets.size() < 3:
			targets.append(e)
	h.global_position = p
	h.facing = 0.0
	# Посторонних монстров — подальше, чтобы герой разворачивался к нашим целям
	for e in main.enemies.list:
		if not targets.has(e) and e.global_position.distance_to(p) < 20.0:
			e.home = p + Vector3(60, 0, 60)
			e.global_position = e.home
	var offs := [Vector3(-0.9, 0, 2.0), Vector3(0, 0, 2.4), Vector3(1.0, 0, 2.0)]
	for i in targets.size():
		var e: Node3D = targets[i]
		e.home = p + offs[i]
		e.global_position = e.home
		e.hp = 99999.0
	await _frames(10)
	h.facing = 0.0
	var hp0 := []
	for e in targets:
		hp0.append(e.hp)
	h.use_horizontal()
	_check("horizontal started", h._move == "horizontal", h._move)
	var trail_seen := false
	for i in 50:
		await get_tree().physics_frame
		if h._trail.emitting:
			trail_seen = true
		if i == 24:
			await _shot("horizontal")
	var hit_n := 0
	for i in targets.size():
		var v: Vector3 = targets[i].global_position - h.global_position
		print("target ", i, " dist ", Vector2(v.x, v.z).length(), " angle ", rad_to_deg(angle_difference(h.facing, atan2(v.x, v.z))), " hp ", hp0[i], " → ", targets[i].hp)
		if targets[i].hp < hp0[i]:
			hit_n += 1
	_check("horizontal hits all in front", hit_n == targets.size(), "%d/%d" % [hit_n, targets.size()])
	_check("no sword trail (off for now)", not trail_seen, "")
	_check("no slow-motion", is_equal_approx(Engine.time_scale, 1.0), str(Engine.time_scale))
	await _frames(40)
	_check("time back to normal", is_equal_approx(Engine.time_scale, 1.0), str(Engine.time_scale))
	# Осколки при смерти
	var t0: Node3D = targets[1]
	t0.hp = 1.0
	t0.hit(50, Vector3(0, 0, 1))
	await _frames(14)
	cam.global_position = t0.global_position + Vector3(2.5, 1.4, -2.0)
	cam.look_at(t0.global_position + Vector3(0, 0.8, 0))
	set_process(false)
	var shards := 0
	for c in Fx.root.get_children():
		if c is Shatter:
			shards += 1
	_check("monster shatters", shards > 0 and not t0.visible, str(shards))
	await _shot("shatter")
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
