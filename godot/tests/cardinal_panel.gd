## Снимок окна CARDINAL. godot --path godot res://tests/cardinal_panel.tscn -- <папка>
extends Node
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null or CardinalDirector.core == null:
		await get_tree().process_frame
	main.hud.menu._on_main()
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "hud.png")
	main.hud.touch.cardinal_pressed.emit()
	main.hud.cardinal._t = 1.0
	var b: Button = main.hud.cardinal.find_children("*", "Button", true, false).filter(func(x): return x.text.begins_with("Проверить"))[0]
	b.pressed.emit()
	main.hud.cardinal.find_children("*", "Button", true, false).filter(func(x): return x.text == "Добыча +")[0].pressed.emit()
	for i in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "cardinal.png")
	print("LOOT ", CardinalDirector.loot_mult())
	CardinalDirector.set_loot_mult(1.0)
	get_tree().quit()
