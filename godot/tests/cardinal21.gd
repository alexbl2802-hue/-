## Cardinal 2.1: проверка анимаций/скелетов и возврат героя, провалившегося под мир.
## godot --path godot res://tests/cardinal21.tscn
extends Node

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null or CardinalDirector.core == null:
		await get_tree().process_frame
	main.hud.menu._on_main()
	for i in 30:
		await get_tree().physics_frame
	var r := CardinalDirector.check_animations(main)
	print("ANIM counts: ", r["counts"])
	print("SKELETONS: ", r["skeletons"])
	var shown := 0
	for rep in r["reports"]:
		if shown < 20:
			shown += 1
			print("  ", rep)
	# Провал под мир
	var h: CharacterBody3D = main.hero
	var before := h.global_position
	# Провал: герой уходит вниз по 10 м за шаг, страж проверяет каждый шаг (как при настоящем падении)
	var guard = CardinalDirector.core.get_node("CardinalHeroGuard")
	for k in 30:
		h.global_position += Vector3(0, -10, 0)
		guard._process(0.0)
		if CardinalDirector.core.error_count > 0:
			break
	print("FALL: was ", before, " -> after guard ", h.global_position, " errors ", CardinalDirector.core.error_count)
	get_tree().quit()
