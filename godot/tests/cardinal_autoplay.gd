## Кардинал играет сам: проверка моделей + игра N секунд игрового времени, затем отчёт.
## godot --path godot res://tests/cardinal_autoplay.tscn -- <папка> [секунд]
extends Node
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] + "/"
	var secs := float(args[1]) if args.size() > 1 else 60.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null or CardinalDirector.autotest == null:
		await get_tree().process_frame
	main.hud.menu._on_main()
	await get_tree().process_frame
	main.hud.touch.cardinal_pressed.emit()
	var play: Button = main.hud.cardinal._play
	play.pressed.emit()
	var at := CardinalDirector.autotest
	var t0: Vector3 = main.hero.global_position
	var shots := 0
	var frames := 0
	# Кардинал сам проходит поле и сценарии и останавливается; secs — предел на случай зависания
	while at.playing and frames < int(secs * 60):
		await get_tree().physics_frame
		frames += 1
		if frames % 300 == 0:
			if DisplayServer.get_name() != "headless" and shots < 3:
				get_viewport().get_texture().get_image().save_png(out + "play_%d.png" % shots)
			shots += 1
			print("t=%ds hero %s target %s issues %s" % [frames / 60, main.hero.global_position.round(), at._target.T.name if is_instance_valid(at._target) else "-", at.counts()])
	print("moved from ", t0.round(), " to ", main.hero.global_position.round(), " kills ", Game.kills)
	if at.playing:
		at.stop()
	print("ИТОГ: ", at._result_status(), " ", at.coverage())
	for id in at.CHECK_NAMES:
		print("  %-34s %-10s %s" % [at.CHECK_TITLES.get(id, id), at.checks[id]["status"], at.checks[id]["detail"]])
	for k in at.issues:
		var i: Dictionary = at.issues[k]
		print("%s [%s] %s: %s (x%d)" % [i.sev, i.code, i.subject, i.msg, i["count"]])
	main.hud.touch.cardinal_pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png(out + "window.png")
	get_tree().quit()
