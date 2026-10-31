## Снимок кобольда крупным планом: godot ... res://tests/kobold.tscn -- <файл> <угол>
extends Node
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	main._set_mode(0)
	var kb: Node3D = main.enemies.list.filter(func(e): return e.type == "kobold")[0]
	kb.T = kb.T.duplicate()
	kb.T["aggro"] = 0.0
	kb.set_physics_process(false)
	kb._model.rotation.y = float(args[1])
	main.hero.global_position = kb.global_position + Vector3(0, 0.2, 3.2)
	main.hero.visible = false
	main.hud._banner_box.visible = false
	var l := OmniLight3D.new()
	l.light_energy = 3.0
	l.omni_range = 8.0
	main.add_child(l)
	l.global_position = kb.global_position + Vector3(0.5, 2.5, 2.0)
	main.rig.yaw = 0.0
	main.rig.pitch = 0.05
	main.rig.dist = 0.5
	main.rig.snap()
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args[0])
	get_tree().quit()
