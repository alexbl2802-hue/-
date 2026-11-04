## Запуск: экран загрузки (scripts/ui/loading_screen.gd). Данные игры (модели и текстуры) лежат не
## в APK, а частями в релизе на GitHub (список — res://data/packs.json, tools/data_pack.py).
## Умная докачка:
## • часть, которая уже есть на телефоне (то же имя = то же содержимое), заново не качается;
## • оборванная загрузка продолжается с того места, где прервалась (запрос Range);
## • части, которых больше нет в списке (старые версии моделей), удаляются.
extends Control

const REPO := "https://github.com/alexbl2802-hue/-/releases/download/"
const MAIN := "res://scenes/main.tscn"
const DIR := "user://packs/"
const LIST := "res://data/packs.json"

var _ls: LoadingScreen
var _packs: Array = []        # [{name, size}]
var _queue: Array = []        # что ещё скачать
var _total := 0               # байт к скачиванию (только недостающие)
var _done := 0                # скачано полностью (байт)
var _base := ""
var _phase := ""              # "download" | "load"
var _load_from := 0.0
# Загрузка одной части
var _cli: HTTPClient
var _file: FileAccess
var _cur: Dictionary = {}
var _host := ""
var _path := ""
var _got := 0                 # байт текущей части на диске
var _redirects := 0
var _sent := false

func _ready() -> void:
	_ls = LoadingScreen.new()
	add_child(_ls)
	_ls.retry.pressed.connect(_resume)
	await get_tree().process_frame
	# В редакторе и в сборке, где данные уже внутри, качать нечего
	if ResourceLoader.exists("res://models/hero.glb") or not FileAccess.file_exists(LIST):
		_load_world()
		return
	_packs = JSON.parse_string(FileAccess.get_file_as_string(LIST))
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	var env := OS.get_environment("ZEMLI_DATA_URL")   # для проверки: свой адрес вместо релиза
	_base = env if env != "" else REPO + "v%s/" % ver
	DirAccess.make_dir_recursive_absolute(DIR)
	_cleanup()
	for p in _packs:
		var f: String = DIR + p["name"]
		if FileAccess.file_exists(f) and _size(f) == int(p["size"]):
			continue   # уже скачано
		_queue.append(p)
		_total += int(p["size"])
	if _queue.is_empty():
		_mount_and_load()
	else:
		_ls.text = ""
		_phase = "download"
		_next()

func _size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else -1

## Удалить части, которых нет в списке, и файл данных прежнего вида (data-*.pck)
func _cleanup() -> void:
	var keep := {}
	for p in _packs:
		keep[p["name"]] = true
		keep[p["name"] + ".part"] = true
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			if not keep.has(f):
				d.remove(f)
	var u := DirAccess.open("user://")
	if u:
		for f in u.get_files():
			if f.begins_with("data-") and f.contains(".pck"):
				u.remove(f)

func _next() -> void:
	if _queue.is_empty():
		_mount_and_load()
		return
	_cur = _queue[0]
	_redirects = 0
	_open_url(_base + str(_cur["name"]))

func _open_url(url: String) -> void:
	var tls := url.begins_with("https://")
	var rest := url.substr(url.find("://") + 3)
	_host = rest.get_slice("/", 0)
	_path = rest.substr(_host.length())
	var port := 443 if tls else 80
	var host := _host
	if host.contains(":"):
		port = int(host.get_slice(":", 1))
		host = host.get_slice(":", 0)
	_cli = HTTPClient.new()
	_cli.read_chunk_size = 1 << 18
	var err := _cli.connect_to_host(host, port, TLSOptions.client() if tls else null)
	if err != OK:
		_fail("Не удалось подключиться (%d)" % err)
		return
	_sent = false

func _process(_dt: float) -> void:
	if _phase == "download" and _cli:
		_poll()
	elif _phase == "load":
		var pr := []
		var st := ResourceLoader.load_threaded_get_status(MAIN, pr)
		if not pr.is_empty():
			_ls.target = maxf(_ls.target, lerpf(_load_from, 0.6, float(pr[0])))
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_phase = ""
			# Дальше полоску ведёт сам мир (main.gd строит его и показывает тот же экран)
			Game.set_meta("loading_from", _ls.shown)
			get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(MAIN))
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_phase = ""
			get_tree().change_scene_to_file.call_deferred(MAIN)

func _poll() -> void:
	_cli.poll()
	match _cli.get_status():
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
			return
		HTTPClient.STATUS_CONNECTED:
			if _sent:
				return
			# Докачка: что уже лежит в .part — не качаем заново
			var part: String = DIR + _cur["name"] + ".part"
			_got = maxi(0, _size(part)) if FileAccess.file_exists(part) else 0
			var headers := PackedStringArray(["User-Agent: ZemliPriklyucheniy", "Accept: */*"])
			if _got > 0:
				headers.append("Range: bytes=%d-" % _got)
			_cli.request(HTTPClient.METHOD_GET, _path, headers)
			_sent = true
		HTTPClient.STATUS_BODY:
			if _file == null:
				var code := _cli.get_response_code()
				if code in [301, 302, 303, 307, 308]:
					var loc: String = _cli.get_response_headers_as_dictionary().get("Location", _cli.get_response_headers_as_dictionary().get("location", ""))
					_cli.close()
					_redirects += 1
					if loc == "" or _redirects > 5:
						_fail("Ошибка загрузки (переадресация)")
						return
					_open_url(loc)
					return
				var part: String = DIR + _cur["name"] + ".part"
				if code == 206 and _got > 0:
					_file = FileAccess.open(part, FileAccess.READ_WRITE)
					_file.seek_end()
				elif code == 200:
					_got = 0
					_file = FileAccess.open(part, FileAccess.WRITE)
				else:
					_cli.close()
					_fail("Ошибка загрузки (код %d). Проверь интернет." % code)
					return
			var chunk := _cli.read_response_body_chunk()
			if chunk.size() > 0:
				_file.store_buffer(chunk)
				_got += chunk.size()
			_show()
		HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_CANT_CONNECT, \
				HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			if _file:
				_finish_part()
			else:
				_fail("Нет связи с сервером. Проверь интернет.")
	if _file and _cli.get_status() == HTTPClient.STATUS_CONNECTED and _sent:
		_finish_part()   # тело ответа прочитано целиком

func _finish_part() -> void:
	_file.close()
	_file = null
	_cli.close()
	var part: String = DIR + _cur["name"] + ".part"
	if _size(part) != int(_cur["size"]):
		_fail("Загрузка прервалась — нажми «Повторить», докачаю с того же места.")
		return
	DirAccess.rename_absolute(part, DIR + _cur["name"])
	_done += int(_cur["size"])
	_queue.pop_front()
	_next()

func _show() -> void:
	var cur := _got - (0 if _file == null else 0)
	var have := _done + mini(cur, int(_cur.get("size", 0)))
	_ls.target = 0.85 * float(have) / maxf(1.0, _total)
	_ls.note.text = "Данные игры: %d из %d МБ · часть %d из %d" % [have >> 20, _total >> 20, _packs.size() - _queue.size() + 1, _packs.size()] \
		if _total > 0 else ""

func _resume() -> void:
	_ls.retry.visible = false
	_ls.text = ""
	_phase = "download"
	_next()

func _mount_and_load() -> void:
	_cli = null
	for p in _packs:
		if not ProjectSettings.load_resource_pack(DIR + p["name"], false):
			DirAccess.remove_absolute(DIR + p["name"])
			_fail("Часть данных повреждена — нажми «Повторить», скачаю её заново.")
			_queue = [p]
			return
	_load_world()

func _load_world() -> void:
	_ls.note.text = ""
	_load_from = _ls.target
	_phase = "load"
	ResourceLoader.load_threaded_request(MAIN)

func _fail(msg: String) -> void:
	_phase = ""
	if _file:
		_file.close()
		_file = null
	if _cli:
		_cli.close()
	_ls.note.text = msg
	_ls.text = "Ошибка"
	_ls.retry.visible = true
