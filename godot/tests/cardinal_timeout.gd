## CARDINAL 4.0: предел времени прогона срабатывает по реальному времени (и при ускорении ×4,
## и во время ожиданий), незавершённые проверки — NOT_TESTED с причиной, состояние возвращается.
## Запуск: godot --headless --path godot res://tests/cardinal_timeout.tscn
extends Node

var ok := true
func _check(n: String, c: bool, info := "") -> void:
	print("%s %s  %s" % ["PASS" if c else "FAIL", n, info])
	ok = ok and c

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null or CardinalDirector.autotest == null:
		await get_tree().process_frame
	main.hud.menu._on_main()
	await get_tree().process_frame
	var at: CardinalAutotest = CardinalDirector.autotest
	_check("config limit is 900 s", at.limit_seconds == 900.0, str(at.limit_seconds))
	at.limit_seconds = 15.0
	at.speed = 4
	var pos0: Vector3 = main.hero.global_position
	var t0 := Time.get_ticks_msec()
	at.start(main)
	while at.playing and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	_check("stopped by limit", not at.playing and secs >= 14.5 and secs < 20.0, "%.1f s" % secs)
	var nt := 0
	var reason := true
	for id in at.checks:
		if at.checks[id]["status"] == "NOT_TESTED":
			nt += 1
			reason = reason and str(at.checks[id]["detail"]).contains("предел")
	_check("unfinished -> NOT_TESTED with reason", nt > 0 and reason, "%d not tested" % nt)
	_check("time scale restored", is_equal_approx(Engine.time_scale, 1.0), str(Engine.time_scale))
	_check("hero position restored", main.hero.global_position.distance_to(pos0) < 0.5, str(main.hero.global_position))
	_check("result is INCOMPLETE", at._result_status() == "INCOMPLETE", at._result_status())
	print("RESULT: %s" % ("ALL OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)
