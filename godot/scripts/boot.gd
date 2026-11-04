## Экран загрузки (картинка meshy/ui/loading_src.jpg): полоска заполняется по мере загрузки и по ней
## всё время бежит блик. Первый запуск — сначала скачивание данных игры (модели и текстуры, файл
## user://data-<id>.pck из релиза на GitHub), затем загрузка мира. Следующие запуски — только мир.
extends Control

const REPO := "https://github.com/alexbl2802-hue/-/releases/download/"
const MAIN := "res://scenes/main.tscn"

var _http: HTTPRequest
var _ls: LoadingScreen
var _part := ""
var _final := ""
var _url := ""
var _phase := ""         # "download" | "load"

func _ready() -> void:
	_ls = LoadingScreen.new()
	add_child(_ls)
	_ls.retry.pressed.connect(_download)
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.download_chunk_size = 1 << 20
	_http.request_completed.connect(_done)
	add_child(_http)
	await get_tree().process_frame
	# В редакторе и в сборке, где данные уже внутри, качать нечего
	if ResourceLoader.exists("res://models/hero.glb"):
		_load_world()
		return
	var id := str(ProjectSettings.get_setting("application/config/data_id", ""))
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	_final = "user://data-%s.pck" % id
	_part = _final + ".part"
	if id != "" and FileAccess.file_exists(_final) and ProjectSettings.load_resource_pack(_final, false):
		_load_world()
		return
	var base := OS.get_environment("ZEMLI_DATA_URL")   # для проверки: свой адрес вместо релиза
	_url = (base if base != "" else REPO + "v%s/" % ver) + "data-%s.pck" % id
	_download()

func _process(_dt: float) -> void:
	if _phase == "download" and _http.get_http_client_status() == HTTPClient.STATUS_BODY:
		var total := _http.get_body_size()
		var got := _http.get_downloaded_bytes()
		if total > 0:
			_ls.target = 0.85 * got / total
			_ls.note.text = "Данные игры: %d из %d МБ (один раз, лучше по Wi-Fi)" % [got >> 20, total >> 20]
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

var _load_from := 0.0

func _download() -> void:
	_ls.retry.visible = false
	_ls.text = ""
	_phase = "download"
	_http.download_file = _part
	var err := _http.request(_url)
	if err != OK:
		_fail("Не удалось начать загрузку (%d)" % err)

func _done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Ошибка загрузки (%d, код %d). Проверь интернет." % [result, code])
		return
	var d := DirAccess.open("user://")
	if d:
		for f in d.get_files():
			if f.begins_with("data-") and "user://" + f != _part:
				d.remove(f)
		d.rename(_part.get_file(), _final.get_file())
	if not ProjectSettings.load_resource_pack(_final, false):
		DirAccess.remove_absolute(_final)
		_fail("Файл данных повреждён — нажми «Повторить».")
		return
	_load_world()

func _load_world() -> void:
	_ls.note.text = ""
	_load_from = _ls.target
	_phase = "load"
	ResourceLoader.load_threaded_request(MAIN)

func _fail(msg: String) -> void:
	_phase = ""
	_ls.note.text = msg
	_ls.text = "Ошибка"
	_ls.retry.visible = true
