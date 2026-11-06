## ANIMATE: окно, генерация по описанию, показ на герое, сохранение.
## godot --path godot res://tests/animate.tscn -- <папка>
extends Node
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	main.hud.menu._on_main()
	Game.time_of_day = 0.42
	main.hud.touch.cardinal_pressed.emit()
	for i in 3:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "an_cardinal.png")
	main.hud.cardinal.visible = false
	main.hud.cardinal.animate_requested.emit()
	var p = main.hud.animate
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "an_window.png")
	for q in ["удар мечом", "быстрый бег", "прыжок", "взмах рукой"]:
		p._prompt.text = q
		p._generate()
		print(q, " → ", p._status.text)
	p._prompt.text = "удар мечом"
	p._generate()
	p._save()
	print("save: ", p._status.text)
	p.open()
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "an_window2.png")
	p._generate()
	main.rig.dist = 3.0
	main.rig.yaw = main.hero.facing + PI * 0.6
	for i in 18:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "an_preview.png")
	p._stop_show()
	print("tree active after stop: ", main.hero._ha.tree.active)
	get_tree().quit()
