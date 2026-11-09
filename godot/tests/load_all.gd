## Загрузка всех скриптов игры и тестов: ошибки разбора видны в журнале.
## Запуск: godot --path godot res://tests/load_all.tscn
extends Node

func _ready() -> void:
	var bad := 0
	var n := 0
	for dir in ["res://scripts", "res://tests", "res://addons/cardinal", "res://addons/combat_pack", "res://animate_3_1", "res://animate_4", "res://addons/animate", "res://hybrid_movement"]:
		for p in _walk(dir):
			n += 1
			var s: Script = load(p)
			if s == null or not s.can_instantiate():
				bad += 1
				print("BAD ", p)
	print("LOADED %d scripts, bad %d" % [n, bad])
	get_tree().quit()

func _walk(d: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(d):
		if f.ends_with(".gd"):
			out.append(d + "/" + f)
	for sub in DirAccess.get_directories_at(d):
		out.append_array(_walk(d + "/" + sub))
	return out
