## Снимки всех окон (стиль меню): главное меню, инвентарь, профиль, кузница, настройки.
## Запуск: godot --path godot res://tests/menus.tscn -- <папка>
extends Node

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "m_main.png")
	main.hud.menu._on_main()
	main.hud._banner_box.visible = false
	Game.add_item("sword_steel")
	Game.add_item("rapier_star")
	Game.add_item("mat_fang")
	var shots := [["m_inventory", main.hud.open_inventory, main.hud.inventory], ["m_skills", main.hud.open_skills, main.hud.skills], ["m_forge", main.hud.open_forge, main.hud.forge]]
	for s in shots:
		s[1].call()
		for i in 15:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + s[0] + ".png")
		s[2].close()
		for i in 5:
			await get_tree().process_frame
	main.hud.open_menu()
	for i in 10:
		await get_tree().process_frame
	main.hud.menu.settings.open()
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "m_settings.png")
	get_tree().quit()
