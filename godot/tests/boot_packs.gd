## Этап 1: загрузчик пакетов на настоящем маленьком .pck (PCKPacker).
## Случаи: целый; повреждён (тот же размер); нет и нет сети; формат новее; старый вид списка.
## Запуск: godot --headless --path godot res://tests/boot_packs.tscn
extends Node

const PACK := "pack-zz_test-000000000000.pck"
var ok := true

func _check(name: String, cond: bool, info := "") -> void:
	print("%s %s  %s" % ["PASS" if cond else "FAIL", name, info])
	ok = ok and cond

func _make_pck(path: String) -> void:
	var src := "user://zz_hello.txt"
	var f := FileAccess.open(src, FileAccess.WRITE)
	f.store_string("hello from pack " + "x".repeat(4000))
	f.close()
	var pk := PCKPacker.new()
	pk.pck_start(path)
	pk.add_file("res://zz_test/hello.txt", src)
	pk.flush()

func _list(path: String, data) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

## Запустить загрузчик, дождаться итога: "mounted" | текст ошибки | "timeout"
func _run_boot(seconds: float) -> String:
	var boot: Control = load("res://scenes/boot.tscn").instantiate()
	add_child(boot)
	var t := 0.0
	var out := "timeout"
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		if boot.get("_phase") == "load":
			out = "mounted"
			break
		if boot._ls.retry.visible:
			out = "error: " + boot._ls.note.text
			break
	ResourceLoader.load_threaded_get_status("res://scenes/main.tscn")
	boot.set_process(false)
	boot.queue_free()
	await get_tree().process_frame
	return out

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://packs")
	var dst := "user://packs/" + PACK
	var good := "user://zz_good.pck"
	_make_pck(good)
	var size := FileAccess.get_file_as_bytes(good).size()
	var sha := FileAccess.get_sha256(good)
	var lst := "user://zz_packs.json"
	OS.set_environment("ZEMLI_FORCE_PACKS", "1")
	OS.set_environment("ZEMLI_PACKS_LIST", ProjectSettings.globalize_path(lst))
	OS.set_environment("ZEMLI_DATA_URL", "http://127.0.0.1:9/")   # сети нет: порт закрыт
	DirAccess.remove_absolute("user://packs_verified.json")
	var entry := {"name": PACK, "size": size, "sha256": sha}
	# 1. целый пакет
	DirAccess.copy_absolute(good, dst)
	_list(lst, {"format": 1, "app": "test", "packs": [entry]})
	var r := await _run_boot(20.0)
	_check("valid pack mounts", r == "mounted", r)
	_check("mounted content readable", FileAccess.file_exists("res://zz_test/hello.txt"))
	_check("checksum remembered", FileAccess.get_file_as_string("user://packs_verified.json").contains(sha))
	# 2. повреждён, тот же размер
	DirAccess.remove_absolute("user://packs_verified.json")
	var b := FileAccess.get_file_as_bytes(good)
	b[b.size() / 2] = (b[b.size() / 2] + 1) % 256
	var w := FileAccess.open(dst, FileAccess.WRITE)
	w.store_buffer(b)
	w.close()
	r = await _run_boot(20.0)
	_check("corrupt same-size pack detected", r.begins_with("error") and not FileAccess.file_exists(dst), r)
	# 3. пакета нет и сети нет — ошибка с кнопкой «Повторить», без падения
	r = await _run_boot(240.0)
	_check("missing pack offline -> retry", r.begins_with("error"), r)
	# 4. данные новее игры
	_list(lst, {"format": 99, "packs": [entry]})
	r = await _run_boot(10.0)
	_check("newer data format refused", r.contains("обнови"), r)
	# 5. старый вид списка (массив, без контрольной суммы)
	DirAccess.copy_absolute(good, dst)
	_list(lst, [{"name": PACK, "size": size}])
	r = await _run_boot(20.0)
	_check("legacy list still works", r == "mounted", r)
	for x in [dst, good, lst, "user://zz_hello.txt", "user://packs_verified.json"]:
		DirAccess.remove_absolute(x)
	print("RESULT: %s" % ("ALL OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)
