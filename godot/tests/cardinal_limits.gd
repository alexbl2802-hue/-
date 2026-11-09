## CARDINAL 4.0: единые лимиты монстров и скрытая кнопка администратора.
## Запуск: godot --headless --path godot res://tests/cardinal_limits.tscn
extends Node

var ok := true
func _check(n: String, c: bool, info := "") -> void:
	print("%s %s  %s" % ["PASS" if c else "FAIL", n, info])
	ok = ok and c

func _awake(en) -> Array:
	var n := 0
	var bosses := 0
	for e in en.list:
		if not e.dead and e.is_physics_processing():
			n += 1
			if e.T.get("boss", false):
				bosses += 1
	return [n, bosses]

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null or CardinalDirector.core == null:
		await get_tree().process_frame
	main.hud.menu._on_main()
	await get_tree().process_frame
	_check("one active limit", Cardinal.max_active_mobs == CardinalConfig.ACTIVE_MOBS_DEFAULT and CardinalDirector.core.max_monsters == Cardinal.max_active_mobs,
		"Cardinal %d, core %d" % [Cardinal.max_active_mobs, CardinalDirector.core.max_monsters])
	_check("registered limit", Cardinal.max_registered_mobs == CardinalConfig.REGISTERED_MOBS_MAX and Cardinal.can_spawn(false), str(Cardinal.max_registered_mobs))
	CardinalDirector.core.max_monsters = 1
	_check("core setter clamps to min", Cardinal.max_active_mobs == CardinalConfig.ACTIVE_MOBS_MIN, str(Cardinal.max_active_mobs))
	# Самое людное место: герой у монстра, рядом с которым больше всего других
	var en = main.enemies
	var best = null
	var best_n := 0
	for e in en.list:
		if e.in_dungeon:
			continue
		var n := 0
		for o in en.list:
			if not o.in_dungeon and o.global_position.distance_to(e.global_position) < en.ACTIVE_RANGE:
				n += 1
		if n > best_n:
			best_n = n
			best = e
	main.hero.global_position = best.global_position + Vector3(1, 1, 0)
	Cardinal.max_active_mobs = 35
	en._update_active()
	var a35 := _awake(en)
	Cardinal.max_active_mobs = 10
	en._update_active()
	var a10 := _awake(en)
	_check("cap applies to non-boss monsters", a10[0] - a10[1] <= 10, "в радиусе %d, бодрствуют при 35: %d, при 10: %d (боссов %d)" % [best_n, a35[0], a10[0], a10[1]])
	Cardinal.max_active_mobs = CardinalConfig.ACTIVE_MOBS_DEFAULT
	# Скрытая кнопка CARDINAL
	var was := Settings.admin
	Settings.admin = false
	var ids: Array = main.hud.touch._buttons().map(func(b): return b["id"])
	_check("CARDINAL hidden for players", not ids.has("cardinal"))
	Settings.admin = true
	ids = main.hud.touch._buttons().map(func(b): return b["id"])
	_check("CARDINAL shown in admin mode", ids.has("cardinal"))
	Settings.admin = was
	print("RESULT: %s" % ("ALL OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)
