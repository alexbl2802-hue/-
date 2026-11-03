## Первый запуск: модели и текстуры (≈230 МБ) не лежат в APK — игра скачивает их из релиза
## на GitHub в файл данных (user://data-<id>.pck) и подключает. Следующие запуски — сразу в игру;
## новая версия с теми же данными ничего не качает (id данных — хэш содержимого, его пишет сборка).
extends Control

const REPO := "https://github.com/alexbl2802-hue/-/releases/download/"
const MAIN := "res://scenes/main.tscn"

var _http: HTTPRequest
var _bar: ProgressBar
var _label: Label
var _retry: Button
var _part := ""
var _final := ""

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0b1020")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position -= Vector2(280, 60)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title := Label.new()
	title.text = "Земли Приключений"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 28)
	box.add_child(_bar)
	_retry = Button.new()
	_retry.text = "Повторить"
	_retry.visible = false
	_retry.pressed.connect(_start)
	box.add_child(_retry)
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.download_chunk_size = 1 << 20
	_http.request_completed.connect(_done)
	add_child(_http)
	await get_tree().process_frame
	# В редакторе и в сборке, где данные уже внутри, качать нечего
	if ResourceLoader.exists("res://models/hero.glb"):
		_go()
		return
	var id := str(ProjectSettings.get_setting("application/config/data_id", ""))
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	_final = "user://data-%s.pck" % id
	_part = _final + ".part"
	if id != "" and FileAccess.file_exists(_final) and ProjectSettings.load_resource_pack(_final, false):
		_go()
		return
	var base := OS.get_environment("ZEMLI_DATA_URL")   # для проверки: свой адрес вместо релиза
	_url = (base if base != "" else REPO + "v%s/" % ver) + "data-%s.pck" % id
	_start()

var _url := ""

func _start() -> void:
	_retry.visible = false
	_label.text = "Загрузка данных игры (модели и текстуры).\nНужно один раз, примерно 230 МБ — лучше по Wi-Fi."
	_bar.value = 0
	_http.download_file = _part
	var err := _http.request(_url)
	if err != OK:
		_fail("Не удалось начать загрузку (%d)" % err)

func _process(_dt: float) -> void:
	if _http and _http.get_http_client_status() == HTTPClient.STATUS_BODY:
		var total := _http.get_body_size()
		var got := _http.get_downloaded_bytes()
		if total > 0:
			_bar.value = 100.0 * got / total
			_label.text = "Загрузка данных игры: %d из %d МБ" % [got >> 20, total >> 20]

func _done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Ошибка загрузки (%d, код %d). Проверь интернет." % [result, code])
		return
	# Старые файлы данных больше не нужны
	var d := DirAccess.open("user://")
	if d:
		for f in d.get_files():
			if f.begins_with("data-") and "user://" + f != _part:
				d.remove(f)
		d.rename(_part.get_file(), _final.get_file())
	if not ProjectSettings.load_resource_pack(_final, false):
		DirAccess.remove_absolute(_final)
		_fail("Файл данных повреждён — скачаю заново.")
		return
	_go()

func _fail(msg: String) -> void:
	_label.text = msg
	_retry.visible = true

func _go() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN)
