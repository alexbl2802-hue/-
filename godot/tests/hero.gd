## Снимки нового героя: godot ... res://tests/hero.tscn -- <папка>
extends Node

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var main: Node = load("res://scenes/main.tscn").instantiate()
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
	# Без доспеха и шлема — чтобы видеть саму модель
	Game.equip["armor"] = null
	Game.equip["helm"] = null
	Game.refresh()
	var shots := [["h_front.png", 0.0, 0.12, 3.0], ["h_side.png", PI / 2, 0.1, 3.0], ["h_back.png", PI, 0.35, 6.0]]
	h.facing = 0.0
	for sh in shots:
		h.global_position = Vector3(2, 4.2, 14)
		main.rig.yaw = sh[1]
		main.rig.pitch = sh[2]
		main.rig.dist = sh[3]
		main.rig.snap()
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + sh[0])
	# В движении и с ударом
	h.touch.move = Vector2(0, 1)
	main.rig.yaw = PI * 0.75
	main.rig.dist = 5.0
	for i in 20:
		await get_tree().process_frame
	h.attack()
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "h_attack.png")
	h.touch.move = Vector2.ZERO
	# В доспехе и шлеме
	Game.equip["armor"] = Items.make("armor_plate")
	Game.equip["helm"] = Items.make("helm_iron")
	Game.refresh()
	h.global_position = Vector3(2, 4.2, 14)
	h.facing = 0.0
	main.rig.yaw = 0.35
	main.rig.pitch = 0.15
	main.rig.dist = 3.2
	main.rig.snap()
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "h_armor.png")
	get_tree().quit()
