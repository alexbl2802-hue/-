## ANIMATE 4.0: разбор описаний и окно ANIMATE в игре (генерация по тексту через конвейер 4.0).
## Запуск: godot --headless --path godot res://tests/animate4_window.tscn
extends Node

var ok := true
func _check(n: String, c: bool, info := "") -> void:
	print("%s %s  %s" % ["PASS" if c else "FAIL", n, info])
	ok = ok and c

func _ready() -> void:
	# Разбор описаний (детерминированный словарь)
	var cases := [["Молниеносный колющий выпад с рывком", "thrust_dash", "forward", false],
		["рывок с бега влево", "dash", "left", true], ["блок щитом", "block_shield", "forward", false],
		["sword whirl spin", "whirl", "forward", false], ["горизонтальный удар", "horizontal", "forward", false],
		["станцуй польку", "", "forward", false]]
	for c in cases:
		var s := AnimateSpec.parse(c[0])
		_check("spec «%s»" % c[0], s["motion"] == c[1] and s["dir"] == c[2] and s["from_run"] == c[3] and s["ok"] == (c[1] != ""),
			"%s %s run=%s unknown=%s" % [s["motion"], s["dir"], s["from_run"], s["unknown"]])
	# Окно ANIMATE в игре
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	main.hud.menu._on_main()
	await get_tree().process_frame
	var p: Control = main.hud.animate
	p.open()
	p._prompt.text = "Молниеносный колющий выпад с рывком"
	p._generate()
	_check("window: 4.0 pipeline used", p._anim != null and str(p._status.text).begins_with("ANIMATE 4.0"), str(p._status.text).get_slice("\n", 0))
	_check("window: checks shown", str(p._status.text).contains("foot_sliding") and not str(p._status.text).contains("✖"), "")
	p._prompt.text = "бег"
	p._generate()
	_check("window: simple motion -> ANIMATE 3", p._anim != null and str(p._status.text).contains("ANIMATE 3"), str(p._status.text))
	p.close()
	print("RESULT: %s" % ("ALL OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)
