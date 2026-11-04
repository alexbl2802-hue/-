## Броня по фигуре: наборы снаряжения с четырёх сторон вблизи (стойка) и кадр бега.
## Запуск: godot --path godot res://tests/armor_view.tscn -- <папка>
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
	cam.fov = 38.0
	add_child(cam)
	main.rig.target = null
	cam.current = true
	var sets := [
		["sword_iron", "armor_leather", "helm_leather", "boots_leather", "", "shield_wood"],
		["sword_crystal", "armor_chain", "helm_iron", "boots_iron", "cloak_ranger", "shield_iron"],
		["rapier_star", "armor_plate", "helm_iron", "boots_iron", "cloak_shadow", "shield_tower"],
		["great_obsidian", "", "", "", "cloak_mantle", ""],
	]
	for si in sets.size():
		for slot in Game.equip:
			Game.equip[slot] = null
		for id in sets[si]:
			if id != "":
				Game.equip[Items.get_item(id)["kind"]] = Items.make(id)
		Game.refresh()
		h.update_look()
		for i in 6:
			await get_tree().process_frame
		var fwd: Vector3 = h._model.global_transform.basis.z.normalized()
		var left := Vector3.UP.cross(fwd).normalized()
		var views := [["f", fwd], ["l", left], ["b", -fwd], ["r", -left]]
		for v in views:
			var c: Vector3 = h.global_position
			cam.global_position = c + (v[1] as Vector3) * 2.6 + Vector3(0, 1.15, 0)
			cam.look_at(c + Vector3(0, 0.95, 0))
			for i in 4:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out + "a%d_%s.png" % [si, v[0]])
	get_tree().quit()
