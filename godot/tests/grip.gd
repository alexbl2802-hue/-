## Крупный план кисти с мечом: стойка и кадры удара
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
	main.hud.touch.visible = false
	for e in main.enemies.list:
		e.T = e.T.duplicate(); e.T["aggro"] = 0.0
	var h: Node3D = main.hero
	h.set_physics_process(false)
	var p := Vector3(-60, 0, -120)
	h.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.05, p.z)
	h._model.rotation.y = 0.0
	Game.equip["weapon"] = Items.make("sword_iron"); Game.refresh()
	var ap: AnimationPlayer = h._anim
	var cam := Camera3D.new(); main.add_child(cam); cam.current = true; cam.fov = 40
	var lamp := OmniLight3D.new(); lamp.light_energy = 2.5; lamp.omni_range = 4.0; main.add_child(lamp)
	var poses := [["Idle", 0.1], ["Right_Hand_Sword_Slash", 0.45]]
	var k := 0
	h.set_process(false)
	main.hud.visible = false
	for ps in poses:
		ap.play(ps[0]); ap.seek(ap.get_animation(ps[0]).length * ps[1], true); ap.speed_scale = 0.0
		for i in 3: await get_tree().process_frame
		var hp: Vector3 = h._sword.global_position
		var bx: Basis = h._sword.global_transform.basis.orthonormalized()
		# Смотрим поперёк рукояти: со стороны ладони и со стороны тыльной стороны кисти
		for side in [bx.z * 1.1 + bx.x * 0.4, -bx.z * 1.1 + bx.x * 0.4]:
			lamp.global_position = hp + side * 1.5 + Vector3(0, 0.3, 0)
			cam.look_at_from_position(hp + side, hp + bx.y * 0.05, bx.y)
			for i in 3: await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out + "grip_%d.png" % k)
			k += 1
	get_tree().quit()
