## Этап 1: надёжность сохранений. Своё сохранение пользователя на время теста откладывается и возвращается.
## Запуск: godot --headless --path godot res://tests/save_safety.tscn
extends Node

var ok := true

func _check(name: String, cond: bool, info := "") -> void:
	print("%s %s  %s" % ["PASS" if cond else "FAIL", name, info])
	ok = ok and cond

func _ready() -> void:
	var P: String = Game.SAVE_PATH
	var files := [P, P + ".bak", P + ".tmp", P + ".v3.bak", P + ".wiped.bak", P + ".wiped.prev.bak"]
	var keep := {}
	for f in files:
		if FileAccess.file_exists(f):
			keep[f] = FileAccess.get_file_as_bytes(f)
			DirAccess.remove_absolute(f)
	# 1. запись и чтение
	Game.new_game()
	Game.player_name = "Тест"
	Game.gold = 123
	Game.save_game()
	_check("save written", FileAccess.file_exists(P) and not FileAccess.file_exists(P + ".tmp"))
	Game.gold = 0
	_check("load", Game.load_game() and Game.gold == 123, str(Game.gold))
	# 2. второе сохранение — прежнее становится копией
	Game.gold = 456
	Game.save_game()
	_check("backup kept", FileAccess.file_exists(P + ".bak") and FileAccess.get_file_as_string(P + ".bak").contains("123"))
	# 3. основной файл испорчен (обрыв записи) — загрузка из копии
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string("{\"v\": 2, \"gold\": 4")
	f.close()
	Game.gold = 0
	_check("corrupt main -> backup", Game.load_game() and Game.gold == 123, str(Game.gold))
	# 4. сохранение от более новой версии: читается, перед перезаписью — копия .v3.bak
	f = FileAccess.open(P, FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": 3, "name": "Новее", "gold": 789, "future_field": [1, 2]}))
	f.close()
	_check("newer save loads", Game.load_game() and Game.gold == 789, str(Game.gold))
	Game.save_game()
	_check("newer save kept as .v3.bak", FileAccess.file_exists(P + ".v3.bak") and FileAccess.get_file_as_string(P + ".v3.bak").contains("future_field"))
	# 5. «Новая игра»: прогресс не загружается, но файлы отложены
	Game.wipe()
	_check("wipe: nothing to load", not Game.load_game())
	_check("wipe: progress set aside", FileAccess.file_exists(P + ".wiped.bak"))
	# вернуть файлы пользователя
	for x in files:
		DirAccess.remove_absolute(x)
	for x in keep:
		var w := FileAccess.open(x, FileAccess.WRITE)
		w.store_buffer(keep[x])
		w.close()
	print("RESULT: %s" % ("ALL OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)
