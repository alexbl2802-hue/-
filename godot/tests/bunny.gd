## Снимки гоблина-модели с дубиной: стойка, погоня, удар.
extends Node
var main: Node
var out := ""
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] + "/"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	var g: Node3D = main.enemies.list.filter(func(e): return e.type == "rabbit")[0]
	print("bunny model: ", g._char != null)
	var p := Vector3(-60, 0, -120)
	main.hero.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
	main.hero.facing = PI
	g.home = Vector3(p.x, WorldGen.ground_at(p.x, p.z - 9), p.z - 9)
	g.reset_home()
	g.set_active(true)
	main.rig.yaw = PI + 0.6; main.rig.pitch = 0.15; main.rig.dist = 6.0; main.rig.snap()
	for i in 12: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "bn_chase.png")
	var hp0: float = Game.hp
	for i in 400:
		await get_tree().process_frame
		if g.st == "windup":
			break
	for i in 4: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "bn_swing.png")
	for i in 120:
		await get_tree().process_frame
		if Game.hp < hp0: break
	print("bunny hit hero: ", Game.hp < hp0, " ", hp0, " -> ", Game.hp)
	get_viewport().get_texture().get_image().save_png(out + "bn_hit.png")
	# Удар ногой (второй удар) и кувырок
	for i in 200:
		await get_tree().process_frame
		if g._b_attack == g.B_KICK and g.st == "windup":
			break
	for i in 6: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "bn_kick.png")
	g._dodge()
	for i in 8: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "bn_dodge.png")
	# Стоит на месте
	g.T = g.T.duplicate(); g.T["aggro"] = 0.0
	g.reset_home()
	main.hero.global_position = g.global_position + Vector3(0.5, 0.2, 3.2)
	main.rig.yaw = 0.3; main.rig.pitch = 0.08; main.rig.dist = 2.5; main.rig.snap()
	g.facing = 0.0
	for i in 20: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "bn_stance.png")
	get_tree().quit()
