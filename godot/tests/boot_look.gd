## Снимки экрана загрузки (полоска в движении) и меню. godot ... res://tests/boot_look.tscn -- <папка>
extends Node
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var b: Control = load("res://scenes/boot.tscn").instantiate()
	b.set_process(false)
	add_child(b)
	await get_tree().process_frame
	await get_tree().process_frame
	b._phase = "x"
	for p in [0.3, 0.75]:
		b._shown = p
		b._target = p
		b._process(0.4)
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "boot_%d.png" % int(p * 100))
	b.queue_free()
	var m: Control = preload("res://scripts/ui/main_menu.gd").new()
	add_child(m)
	m.open()
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "menu.png")
	m._open_new()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "menu_new.png")
	get_tree().quit()
