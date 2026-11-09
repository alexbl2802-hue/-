## Кнопки навыков страницами: все изученные навыки, листание пальцем по дуге.
## Запуск: godot --path godot res://tests/skill_pages.tscn -- <папка>
extends Node

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	await get_tree().process_frame
	main.hud.menu._on_main()
	Game.level = 20
	Game.skills = {"dash": 1, "horizontal": 1, "art_sword": 1, "art_great": 1, "art_rapier": 1, "art_dagger": 1}
	for i in 30:
		await get_tree().process_frame
	var t: Control = main.hud.touch
	print("skills: ", t.skill_list, " pages: ", t._pages())
	get_viewport().get_texture().get_image().save_png(out + "page1.png")
	# Палец по дуге: с кнопки слева вверх
	var c: Vector2 = t._ring_center()
	var p0: Vector2 = c + Vector2(cos(deg_to_rad(190.0)), sin(deg_to_rad(190.0))) * t.RING_IN
	var ev := InputEventScreenTouch.new(); ev.index = 3; ev.pressed = true; ev.position = p0
	Input.parse_input_event(ev)
	await get_tree().process_frame
	for k in range(1, 7):
		var a: float = deg_to_rad(190.0 + k * 6.0)
		var d := InputEventScreenDrag.new(); d.index = 3; d.position = c + Vector2(cos(a), sin(a)) * t.RING_IN
		Input.parse_input_event(d)
		await get_tree().process_frame
	var up := InputEventScreenTouch.new(); up.index = 3; up.pressed = false; up.position = p0
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "turning.png")
	for i in 30:
		await get_tree().process_frame
	print("page now: ", t._page, " hero art cd: ", main.hero.cd["art_sword"])
	get_viewport().get_texture().get_image().save_png(out + "page2.png")
	# Нажатие на кнопку второй страницы — приём срабатывает
	var b: Dictionary = {}
	for x in t._buttons():
		if x.get("skill", false):
			b = x
			break
	print("tap: ", b["id"])
	var tp := InputEventScreenTouch.new(); tp.index = 4; tp.pressed = true; tp.position = b["c"]
	Input.parse_input_event(tp)
	await get_tree().process_frame
	var tu := InputEventScreenTouch.new(); tu.index = 4; tu.pressed = false; tu.position = b["c"]
	Input.parse_input_event(tu)
	for i in 5:
		await get_tree().physics_frame
	print("cd after tap: ", main.hero.cd.get(b["id"]))
	get_tree().quit()
