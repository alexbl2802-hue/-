## Снаряжение на герое: спереди, сбоку, сзади — с разными наборами вещей.
## Запуск: godot --path godot res://tests/gear_look.tscn -- <папка>
extends Node

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud.visible = false
	for e in main.enemies.list:
		e.set_active(false)
		e.visible = false
	var h: Node3D = main.hero
	var p := Vector3(-60, 0, -120)
	h.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.2, p.z)
	h.facing = 0.0
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	main.rig.target = null
	cam.current = true
	var sets := [
		["sword_iron", "armor_chain", "helm_iron", "boots_iron", "cloak_ranger", "shield_iron"],
		["sword_steel", "armor_plate", "helm_iron", "boots_wind", "cloak_shadow", "shield_tower"],
		["sword_rusty", "armor_leather", "helm_leather", "boots_leather", "cloak_wool", "shield_wood"],
	]
	for si in sets.size():
		for slot in Game.equip:
			Game.equip[slot] = null
		for id in sets[si]:
			Game.equip[Items.get_item(id)["kind"]] = Items.make(id)
		Game.refresh()
		h.update_look()
		for v in [["front", Vector3(0, 0, 1)], ["side", Vector3(1, 0, 0)], ["back", Vector3(0, 0, -1)]]:
			var c: Vector3 = h.global_position
			cam.global_position = c + (v[1] as Vector3) * 3.4 + Vector3(0, 1.2, 0)
			cam.look_at(c + Vector3(0, 0.95, 0))
			for i in 8:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out + "set%d_%s.png" % [si, v[0]])
	get_tree().quit()
