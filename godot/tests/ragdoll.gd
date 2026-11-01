## Падение по физике и реакция на удары: гоблин отшатывается от удара, падает по физике,
## герой при гибели падает так же и встаёт целым у костра.
## Запуск: godot --path godot res://tests/ragdoll.tscn -- <папка>
extends Node

var main: Node
var ok := true
var cam: Camera3D
var focus := Vector3.ZERO

func _process(_dt: float) -> void:
	if cam:
		cam.global_position = focus + Vector3(3.5, 1.8, 2.2)
		cam.look_at(focus + Vector3(0, 0.6, 0))

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	main.hud.visible = false
	Game.time_of_day = 0.4
	var h: Node3D = main.hero
	for e in main.enemies.list:
		e.T = e.T.duplicate()
		e.T["aggro"] = 0.0
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	main.rig.target = null
	# Гоблин рядом с героем
	var g: Node3D = null
	for e in main.enemies.list:
		if e.type == "goblin" and not e.in_dungeon:
			g = e
			break
	# Ровное место на площади города
	var p := Vector3(-8, WorldGen.ground_at(-8, 12) + 0.05, 12)
	g.home = p
	g.global_position = p
	h.global_position = p + Vector3(0, 0.5, -2.5)
	h.facing = 0.0
	focus = p
	for i in 40:
		await get_tree().physics_frame
	# Удар — гоблина качнуло
	g.hit(1, Vector3(0, 0, 1))
	for i in 3:
		await get_tree().physics_frame
	_check("goblin flinches", g._tilt.length() > 0.05, str(g._tilt))
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "r_flinch.png")
	for i in 30:
		await get_tree().physics_frame
	_check("flinch fades", g._tilt.length() < 0.02, str(g._tilt))
	# Смерть — падение по физике
	var sk: Skeleton3D = g._char.find_children("*", "Skeleton3D", true, false)[0]
	var hips := BoneAttachment3D.new()
	sk.add_child(hips)
	hips.bone_idx = Ragdoll._find(sk, "Hips")
	await get_tree().process_frame
	var y0: float = hips.global_position.y
	g.hit(9999, Vector3(0, 0, 1))
	_check("goblin ragdoll", g._ragdoll.active(), "")
	var k := 0
	for t in [6, 20, 50, 90]:
		while k < t:
			await get_tree().physics_frame
			focus = hips.global_position - Vector3(0, 0.4, 0)
			k += 1
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "r_goblin_%d.png" % t)
	var y1: float = hips.global_position.y
	var gy := WorldGen.ground_at(hips.global_position.x, hips.global_position.z)
	var moved: float = Vector2(hips.global_position.x - p.x, hips.global_position.z - p.z).length()
	print("hips ", y0, " → ", y1, " ground under body ", gy, " moved ", moved)
	_check("body lies on the ground", y1 - gy < 0.45 and y1 - gy > -0.1, "над землёй %.2f м" % (y1 - gy))
	_check("body did not roll away", moved < 3.5, "%.1f м" % moved)
	for i in 120:
		await get_tree().physics_frame
	_check("ragdoll removed after hide", not g._ragdoll.active() and not g.visible, "")
	g.revive()
	for i in 5:
		await get_tree().physics_frame
	_check("revived standing", g.visible and not g._ragdoll.active(), "")
	# Удар по герою — отшатывается
	Game.hp = Game.max_hp
	h._invuln = 0.0
	h.take_damage(5, h.global_position + Vector3(0, 0, 2))
	_check("hero flinch", h._flinch_a > 0.1, str(h._flinch_a))
	# Гибель героя
	focus = h.global_position
	h._invuln = 0.0
	Game.hp = 1.0
	h.take_damage(999, h.global_position + Vector3(1, 0, 0))
	_check("hero ragdoll", h._ragdoll.active() and h.dead, "")
	for i in 50:
		await get_tree().physics_frame
		focus = h._sk.global_position
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "r_hero_dead.png")
	for i in 200:
		await get_tree().physics_frame
	_check("hero respawned", not h.dead and not h._ragdoll.active() and h._ha.tree.active, "")
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
