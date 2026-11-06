## Вход на этажи башни: герой появляется на этаже (у точки старта) и остаётся там.
## godot --path godot res://tests/tower_floors.tscn
extends Node
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null or CardinalDirector.core == null:
		await get_tree().process_frame
	main.hud.menu._on_main()
	for i in 10:
		await get_tree().physics_frame
	var ok := true
	for f in [1, 2, 3, 10]:
		main.enter_floor(f)
		for i in 90:
			await get_tree().physics_frame
		var d: Node3D = main.dungeons[DungeonDefs.floor_index(f)]
		var p: Vector3 = main.hero.global_position
		var good: bool = absf(p.y - d.Y) < 3.0 and p.distance_to(d.start_pos) < 6.0
		ok = ok and good
		print("этаж %d: герой %s, старт %s, пол %.0f → %s" % [f, p.round(), d.start_pos.round(), d.Y, "OK" if good else "ОШИБКА"])
		main.exit_dungeon()
		for i in 60:
			await get_tree().physics_frame
	print("ошибок Cardinal: ", CardinalDirector.core.error_count, " — ", "ВСЁ OK" if ok else "ЕСТЬ ОШИБКИ")
	get_tree().quit()
