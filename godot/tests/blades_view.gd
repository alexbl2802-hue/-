## Клинки и щиты SAO крупным планом. Запуск: godot --path godot res://tests/blades_view.tscn -- <папка>
extends Node3D

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] + "/"
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#40506a")
	env.environment.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0)
	add_child(sun)
	var items := [["sword", "sword_iron"], ["sword", "sword_crystal"], ["great", "great_obsidian"], ["rapier", "rapier_star"], ["dagger", "dagger_iron"], ["sword", "u_warlord"]]
	for i in items.size():
		var b := SaoGear.blade(items[i][0])
		b.position = Vector3(-1.0 + i * 0.4, -0.5, 0)
		add_child(b)
		var w := Items.get_item(items[i][1])
		var guard := Color("#3a3a44") if w["rank"] < 2 else Color("#c8a040")
		SaoGear.paint_blade(b, WorldGen.hex(w["color"]), guard, Color("#2a1e16"), WorldGen.hex(w.get("glow", 0)), 0.7 if w.has("glow") else 0.0)
		b.get_node("Blade").scale.y = float(w["len"]) / {"sword": 1.0, "great": 1.4, "rapier": 1.15, "dagger": 0.55}[items[i][0]]
	for i in 3:
		var k: String = ["round", "heater", "tower"][i]
		var s := SaoGear.shield(k)
		s.position = Vector3(1.6 + i * 0.6, 0.2, 0)
		add_child(s)
		SaoGear.paint_shield(s, [Color("#7a5230"), Color("#9aa2ac"), Color("#eeeef2")][i], i > 0)
	var cam := Camera3D.new()
	cam.position = Vector3(0.9, 0.25, 2.6)
	cam.fov = 55
	add_child(cam)
	cam.look_at(Vector3(0.9, 0.1, 0))
	cam.current = true
	for i in 5:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "blades.png")
	cam.position = Vector3(-0.4, 0.4, 0.5)
	cam.look_at(Vector3(-0.6, 0.0, 0))
	for i in 3:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "blades_close.png")
	get_tree().quit()
