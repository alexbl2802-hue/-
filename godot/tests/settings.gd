## Настройки: окно, применение (дальность, тени, счётчик кадров, камера) и сохранение.
## Запуск: godot --path godot res://tests/settings.tscn -- <папка>
extends Node

var ok := true

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null or main.day_night == null:
		await get_tree().process_frame
	await get_tree().process_frame
	var menu: Control = main.hud.menu
	menu.settings.open()
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "settings.png")
	# Меняем: дальность «Ближе», тени выкл, счётчик кадров вкл, чувствительность ×1.5
	menu.settings._view_btns[0].pressed.emit()
	menu.settings._shadows.pressed.emit()
	menu.settings._fps.pressed.emit()
	menu.settings._sens.value = 1.5
	await get_tree().process_frame
	_check("view applied", is_equal_approx(main.rig.camera.far, 450.0) and is_equal_approx(main.world._rock_nodes[0].visibility_range_end, 120.0), "far %s" % main.rig.camera.far)
	_check("shadows off", not main._sun.shadow_enabled and not Settings.shadows, "")
	_check("fps shown", main.hud._fps_lbl.visible, "")
	_check("sens", is_equal_approx(Settings.cam_sens, 1.5), str(Settings.cam_sens))
	var cf := ConfigFile.new()
	_check("saved", cf.load(Settings.PATH) == OK and int(cf.get_value("game", "view")) == 0 and not bool(cf.get_value("game", "shadows")), "")
	get_viewport().get_texture().get_image().save_png(out + "settings_changed.png")
	menu.settings.close()
	menu._on_main()
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "settings_game.png")
	# Вернуть как было
	Settings.view = 1
	Settings.shadows = true
	Settings.show_fps = false
	Settings.cam_sens = 1.0
	Settings.save_settings()
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	get_tree().quit()

func _check(name: String, cond: bool, info: String) -> void:
	print(("OK   " if cond else "FAIL ") + name + "  " + info)
	ok = ok and cond
