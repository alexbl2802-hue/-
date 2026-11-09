## Этап 6: откуда треугольники и вызовы отрисовки — по группам (скрываем группу и смотрим разницу).
## Счётчики отрисовки не зависят от скорости видеокарты, поэтому годятся и для программного рендера.
## Запуск: xvfb-run godot --path godot --resolution 1280x720 res://tests/perf_probe.tscn [-- место]
extends Node

var main: Node

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _measure() -> Vector2:
	await _frames(3)
	return Vector2(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

## Группы: имя → узлы
func _groups() -> Dictionary:
	var g := {}
	var world: Node = main.get_node("World")
	var trees: Array = []
	var rocks: Array = []
	var grass: Array = []
	var town: Array = []
	var terrain: Array = []
	var other: Array = []
	for c in world.get_children():
		if not c is Node3D:
			continue
		var n := String(c.name).to_lower()
		if n.contains("grass"):
			grass.append(c)
		elif c is MultiMeshInstance3D and (c as MultiMeshInstance3D).multimesh and String((c as MultiMeshInstance3D).multimesh.mesh.resource_name).to_lower().contains("rock"):
			rocks.append(c)
		elif c is MultiMeshInstance3D:
			trees.append(c)
		elif n.contains("town") or c.get_script() == load("res://scripts/town.gd"):
			town.append(c)
		elif n.contains("terrain") or c.get_class().begins_with("Terrain3D") or c is MeshInstance3D:
			terrain.append(c)
		else:
			other.append(c)
	g["деревья и камни (MultiMesh)"] = trees + rocks
	g["трава"] = grass
	g["город"] = town
	g["рельеф и вода"] = terrain
	g["прочее мира"] = other
	g["монстры"] = [main.get_node("Enemies")]
	g["герой"] = [main.get_node("Hero")]
	return g

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	main.hud.menu._on_main()
	main.hud.visible = false
	var spots := {"город": Vector3(0, 0, 8), "лес и поле": Vector3(-60, 0, -99)}
	for s in spots:
		var p: Vector3 = spots[s]
		main.hero.global_position = Vector3(p.x, WorldGen.ground_at(p.x, p.z) + 0.3, p.z)
		main.hero.set_physics_process(false)
		await _frames(30)
		var base := await _measure()
		print("PERF %s: всего %d треугольников, %d вызовов отрисовки" % [s, base.x, base.y])
		var g := _groups()
		for name in g:
			var was := []
			for n in g[name]:
				was.append(n.visible)
				n.visible = false
			var m := await _measure()
			for i in g[name].size():
				g[name][i].visible = was[i]
			print("PERF   %-28s %9d треуг. (%4.1f%%)  %4d вызовов" % [name, base.x - m.x, 100.0 * (base.x - m.x) / maxf(1.0, base.x), base.y - m.y])
		# Рычаги качества: порог LOD моделей (пикс.) и тени
		var vp := get_viewport()
		for lod in [1.0, 2.0, 4.0, 8.0]:
			vp.mesh_lod_threshold = lod
			var m := await _measure()
			print("PERF   LOD-порог %.0f пикс.: %9d треуг., %4d вызовов" % [lod, m.x, m.y])
		vp.mesh_lod_threshold = 1.0
		var sun: DirectionalLight3D = main.get("_sun")
		if sun:
			sun.shadow_enabled = false
			var m2 := await _measure()
			print("PERF   без теней:          %9d треуг., %4d вызовов" % [m2.x, m2.y])
			sun.shadow_enabled = true
		for qi in Settings.QUALITY.size():
			Settings.quality = qi
			Settings.shadows = Settings.QUALITY[qi]["shadows"]
			Settings.view = Settings.QUALITY[qi]["view"]
			main.apply_settings()
			var mq := await _measure()
			print("PERF   профиль «%s»: %9d треуг., %4d вызовов" % [Settings.QUALITY[qi]["name"], mq.x, mq.y])
			if not OS.get_cmdline_user_args().is_empty():
				main.hud.visible = false
				get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/q_%s_%d.png" % [s.replace(" ", "_"), qi])
		Settings.quality = 2
		Settings.shadows = true
		Settings.view = 1
		main.apply_settings()
		main.hero.set_physics_process(true)
	get_tree().quit()
