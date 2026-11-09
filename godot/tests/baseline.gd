## Базовые метрики: запуск стартовой сцены, время до мира, FPS, кадры, объекты, память, draw calls.
## Запуск: godot --path godot res://tests/baseline.tscn
extends Node

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.get("hero") == null or main.get("hud") == null:
		await get_tree().process_frame
	print("BASE main_scene_to_hero_ms=%d" % (Time.get_ticks_msec() - t0))
	main.hud.menu._on_main()
	while main.get("hero") == null:
		await get_tree().process_frame
	for i in 120:
		await get_tree().process_frame
	var frames := 0
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 10000:
		await get_tree().process_frame
		frames += 1
	var secs := (Time.get_ticks_msec() - t1) / 1000.0
	print("BASE fps=%.1f frames=%d secs=%.1f" % [frames / secs, frames, secs])
	print("BASE objects=%d nodes=%d resources=%d" % [Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	print("BASE static_mem_mb=%.1f video_mem_mb=%.1f" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	print("BASE draw_calls=%d primitives=%d objects_in_frame=%d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	print("BASE physics_ms=%.2f process_ms=%.2f" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	print("BASE enemies=%d" % (main.enemies.list.size() if main.get("enemies") else -1))
	get_tree().quit()
